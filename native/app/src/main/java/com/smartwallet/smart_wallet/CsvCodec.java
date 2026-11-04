package com.smartwallet.smart_wallet;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;

/**
 * Transaction CSV, byte-compatible with the Flutter app's Import /
 * Export screen (which uses package:csv):
 *
 *   ID,Type,Amount,Account,To Account,Category,Date,Note
 *
 * Export: account/category NAMES resolved from ids (blank when the id
 * no longer exists), Amount as a Dart double string ("75000.0"),
 * Date in Flutter's display format "d MMM yyyy, h:mm a"
 * (DateUtil.formatDateTime), rows joined with CRLF and fields quoted
 * when they contain a comma, quote or newline (package:csv rules).
 *
 * Import mirrors Flutter's _importCSV exactly where it has behaviour:
 * only the Type / Amount / Date / Note columns are read (matched
 * case-insensitively by header name); the ID, Account, To Account and
 * Category columns are IGNORED and every imported transaction lands
 * in the FIRST account with no category; a type outside
 * income/expense/transfer becomes "expense"; rows with amount <= 0
 * (or unparseable, which Flutter reads as 0) are skipped; there is no
 * duplicate detection. Native additionally returns per-row skip
 * reasons for the summary dialog, and (documented extra) understands
 * Flutter's own exported date format on import, so a Flutter-exported
 * file keeps its dates here — Flutter importing its own export
 * cannot parse that format and silently uses "now" instead.
 *
 * Pure Java — no Android imports — JVM-tested.
 */
public final class CsvCodec {

    private CsvCodec() {}

    public static class CsvException extends Exception {
        public CsvException(String msg) { super(msg); }
    }

    public static class ImportResult {
        public int imported = 0;
        public int skipped = 0;
        public final List<String> skipReasons = new ArrayList<>();
    }

    public static final String[] HEADERS = {
            "ID", "Type", "Amount", "Account", "To Account", "Category", "Date", "Note" };

    // ---------------------------------------------------------------- export

    public static String exportCsv(WalletDb db) {
        StringBuilder sb = new StringBuilder();
        appendRow(sb, HEADERS);
        if (db != null) {
            for (Transaction t : db.transactions) {
                if (t == null) continue;
                Account acc = WalletLogic.accountById(db.accounts, t.accountId);
                Account to = WalletLogic.accountById(db.accounts, t.toAccountId);
                Category cat = WalletLogic.categoryById(db.categories, t.categoryId);
                appendRow(sb, new String[] {
                        t.id == null ? "" : t.id,
                        t.type == null ? "" : t.type,
                        MiniJson.dartDouble(t.amount),
                        acc == null || acc.name == null ? "" : acc.name,
                        to == null || to.name == null ? "" : to.name,
                        cat == null || cat.name == null ? "" : cat.name,
                        formatCsvDate(t.date),
                        t.note == null ? "" : t.note });
            }
        }
        return sb.toString();
    }

    private static void appendRow(StringBuilder sb, String[] fields) {
        for (int i = 0; i < fields.length; i++) {
            if (i > 0) sb.append(',');
            sb.append(escape(fields[i]));
        }
        sb.append("\r\n");
    }

    /** package:csv quoting: quote when the field contains the
     *  delimiter, a quote, CR or LF; embedded quotes are doubled. */
    static String escape(String field) {
        if (field == null) return "";
        if (field.contains(",") || field.contains("\"")
                || field.contains("\n") || field.contains("\r")) {
            return '"' + field.replace("\"", "\"\"") + '"';
        }
        return field;
    }

    // ---------------------------------------------------------------- parse

    /**
     * A small RFC-4180-style parser: quoted fields, doubled quotes,
     * CRLF or LF row endings (Flutter reads with eol '\n'; a CRLF
     * file's \r is part of the line ending, not the last field).
     */
    public static List<List<String>> parseCsv(String content) {
        List<List<String>> rows = new ArrayList<>();
        if (content == null || content.isEmpty()) return rows;
        List<String> row = new ArrayList<>();
        StringBuilder field = new StringBuilder();
        boolean inQuotes = false;
        boolean fieldWasQuoted = false;
        boolean rowHasData = false;
        int i = 0;
        int n = content.length();
        while (i < n) {
            char c = content.charAt(i);
            if (inQuotes) {
                if (c == '"') {
                    if (i + 1 < n && content.charAt(i + 1) == '"') {
                        field.append('"');
                        i += 2;
                    } else {
                        inQuotes = false;
                        i++;
                    }
                } else {
                    field.append(c);
                    i++;
                }
            } else if (c == '"' && field.length() == 0 && !fieldWasQuoted) {
                inQuotes = true;
                fieldWasQuoted = true;
                rowHasData = true;
                i++;
            } else if (c == ',') {
                row.add(field.toString());
                field.setLength(0);
                fieldWasQuoted = false;
                rowHasData = true;
                i++;
            } else if (c == '\n' || c == '\r') {
                if (c == '\r' && i + 1 < n && content.charAt(i + 1) == '\n') i++;
                i++;
                row.add(field.toString());
                field.setLength(0);
                fieldWasQuoted = false;
                rows.add(row);
                row = new ArrayList<>();
                rowHasData = false;
            } else {
                field.append(c);
                rowHasData = true;
                i++;
            }
        }
        if (inQuotes || rowHasData || field.length() > 0 || !row.isEmpty()) {
            row.add(field.toString());
            rows.add(row);
        }
        return rows;
    }

    // ---------------------------------------------------------------- import

    /**
     * Import Flutter-format CSV into the DB, moving balances through
     * WalletLogic.addTransaction like any normal add. Every row is
     * independent: a bad row is skipped (with a reason) and never
     * aborts the rest, exactly like Flutter's per-row try/catch.
     *
     * @param idBase prefix for generated transaction ids
     *               (Flutter assigns fresh ids too — the CSV's own ID
     *               column is ignored), e.g. "tx_csv_1699999999999"
     * @param nowIso fallback date for unparseable date cells
     */
    public static ImportResult importCsv(WalletDb db, String content,
                                         String idBase, String nowIso)
            throws CsvException {
        List<List<String>> rows = parseCsv(content);
        if (rows.size() < 2) throw new CsvException("CSV is empty or invalid.");
        List<String> headers = rows.get(0);
        int typeIdx = headerIndex(headers, "type");
        int amtIdx = headerIndex(headers, "amount");
        int dateIdx = headerIndex(headers, "date");
        int noteIdx = headerIndex(headers, "note");

        ImportResult result = new ImportResult();
        String firstAccountId = db != null && !db.accounts.isEmpty()
                ? db.accounts.get(0).id : null;

        for (int r = 1; r < rows.size(); r++) {
            List<String> row = rows.get(r);
            int rowNo = r + 1; // 1-based, counting the header row
            try {
                if (firstAccountId == null) {
                    skip(result, rowNo, "no accounts in the wallet");
                    continue;
                }
                String amountRaw = cell(row, amtIdx);
                double amount = amountRaw == null ? 0 : parseAmount(amountRaw);
                if (amount <= 0) {
                    skip(result, rowNo, "amount missing or not positive");
                    continue;
                }
                String typeRaw = cell(row, typeIdx);
                String type = typeRaw == null ? "expense" : typeRaw;
                if (!"income".equals(type) && !"expense".equals(type)
                        && !"transfer".equals(type)) {
                    type = "expense";
                }
                String dateRaw = cell(row, dateIdx);
                String date = dateRaw == null ? nowIso : parseCsvDate(dateRaw, nowIso);
                String note = cell(row, noteIdx);
                if (note == null) note = "";

                Transaction t = new Transaction();
                t.id = idBase + "_" + r;
                t.type = type;
                t.amount = amount;
                t.accountId = firstAccountId;
                t.date = date;
                t.note = note;
                t.isSplit = false;
                WalletLogic.addTransaction(db, t);
                result.imported++;
            } catch (Exception e) {
                skip(result, rowNo, "row could not be read");
            }
        }
        return result;
    }

    private static void skip(ImportResult result, int rowNo, String reason) {
        result.skipped++;
        result.skipReasons.add("Row " + rowNo + ": " + reason);
    }

    /** Cell by column index; null when the column is absent from the
     *  header (Flutter then uses its default). A row shorter than the
     *  header throws in Flutter and the row is skipped — mirrored by
     *  the IndexOutOfBoundsException reaching importCsv's catch. */
    private static String cell(List<String> row, int idx) {
        if (idx < 0) return null;
        return row.get(idx);
    }

    private static int headerIndex(List<String> headers, String name) {
        for (int i = 0; i < headers.size(); i++) {
            if (headers.get(i) != null && headers.get(i).equalsIgnoreCase(name)) {
                return i;
            }
        }
        return -1;
    }

    private static double parseAmount(String raw) {
        try {
            return Double.parseDouble(raw.trim());
        } catch (Exception e) {
            return 0;
        }
    }

    // ---------------------------------------------------------------- dates

    private static final String[] MONTHS = {
            "Jan", "Feb", "Mar", "Apr", "May", "Jun",
            "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" };

    /** Flutter DateUtil.formatDateTime: "d MMM yyyy, h:mm a". */
    public static String formatCsvDate(String iso) {
        LocalDateTime dt = WalletLogic.parseIso(iso);
        if (dt == null) return iso == null ? "" : iso;
        int hour = dt.getHour();
        int hour12 = ((hour + 11) % 12) + 1;
        String ampm = hour < 12 ? "AM" : "PM";
        return dt.getDayOfMonth() + " " + MONTHS[dt.getMonthValue() - 1] + " "
                + dt.getYear() + ", " + hour12 + ":"
                + String.format("%02d", dt.getMinute()) + " " + ampm;
    }

    /**
     * Read a CSV date cell back to an ISO string. Order: ISO-8601 as
     * Dart's DateTime.tryParse accepts (this is all Flutter tries),
     * then Flutter's own display format (native extra, so its
     * exported files round-trip), else nowIso.
     */
    public static String parseCsvDate(String raw, String nowIso) {
        if (raw == null) return nowIso;
        String s = raw.trim();
        if (s.isEmpty()) return nowIso;
        // Dart's DateTime.tryParse also accepts a space separator and
        // omitted seconds; WalletLogic.parseIso wants the strict form.
        String norm = s;
        if (norm.length() > 10 && norm.charAt(10) == ' ') {
            norm = norm.substring(0, 10) + 'T' + norm.substring(11);
        }
        if (norm.length() == 16) norm = norm + ":00"; // yyyy-MM-ddTHH:mm
        LocalDateTime iso = WalletLogic.parseIso(norm);
        if (iso != null) return WalletLogic.formatIso(iso);
        LocalDateTime display = parseDisplayDate(s);
        if (display != null) return WalletLogic.formatIso(display);
        return nowIso;
    }

    /** Parse "2 Sep 2026, 2:15 PM" (DateUtil.formatDateTime output). */
    static LocalDateTime parseDisplayDate(String s) {
        try {
            int comma = s.indexOf(", ");
            if (comma < 0) return null;
            String[] d = s.substring(0, comma).trim().split("\\s+");
            String[] t = s.substring(comma + 2).trim().split("\\s+");
            if (d.length != 3 || t.length != 2) return null;
            int day = Integer.parseInt(d[0]);
            int month = -1;
            for (int i = 0; i < MONTHS.length; i++) {
                if (MONTHS[i].equalsIgnoreCase(d[1])) { month = i + 1; break; }
            }
            if (month < 0) return null;
            int year = Integer.parseInt(d[2]);
            String[] hm = t[0].split(":");
            if (hm.length != 2) return null;
            int hour = Integer.parseInt(hm[0]);
            int minute = Integer.parseInt(hm[1]);
            boolean pm = "PM".equalsIgnoreCase(t[1]);
            if (!pm && !"AM".equalsIgnoreCase(t[1])) return null;
            if (hour < 1 || hour > 12) return null;
            hour = (hour % 12) + (pm ? 12 : 0);
            return LocalDateTime.of(year, month, day, hour, minute);
        } catch (Exception e) {
            return null;
        }
    }
}
