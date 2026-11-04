package com.smartwallet.smart_wallet;

import java.util.ArrayList;
import java.util.Collections;
import java.util.Comparator;
import java.util.List;

/**
 * All money maths for Smart Wallet. Pure Java — NO Android imports —
 * so it runs unchanged in the JVM tests (tests/TestWalletLogic.java).
 *
 * Dates are the ISO-8601 strings stored in the backup JSON
 * ("2026-09-01T09:30:00.000"); year/month are read from the string,
 * which is exact for that format and needs no date library.
 */
public final class WalletLogic {

    private WalletLogic() {}

    // ---------------------------------------------------------------- totals

    /** Net wallet = sum of balances of accounts enabled for calculation. */
    public static double netWallet(List<Account> accounts) {
        double sum = 0;
        if (accounts == null) return 0;
        for (Account a : accounts) {
            if (a != null && a.isEnabledForCalc) sum += a.balance;
        }
        return sum;
    }

    /** Income in one calendar month. Transfers never count as income. */
    public static double monthlyIncome(List<Transaction> txs, int year, int month) {
        return monthlySum(txs, year, month, "income");
    }

    /** Expense in one calendar month. Transfers never count as expense. */
    public static double monthlyExpense(List<Transaction> txs, int year, int month) {
        return monthlySum(txs, year, month, "expense");
    }

    private static double monthlySum(List<Transaction> txs, int year, int month, String type) {
        double sum = 0;
        if (txs == null) return 0;
        for (Transaction t : txs) {
            if (t == null || !type.equals(t.type)) continue;
            if (yearOf(t.date) == year && monthOf(t.date) == month) sum += t.amount;
        }
        return sum;
    }

    /** Net flow (income - expense) in one calendar month; transfers excluded. */
    public static double monthlyNet(List<Transaction> txs, int year, int month) {
        return monthlyIncome(txs, year, month) - monthlyExpense(txs, year, month);
    }

    // ---------------------------------------------------------------- splits

    public static double splitPaidAmount(Transaction t) {
        double sum = 0;
        if (t == null || t.splits == null) return 0;
        for (SplitMember s : t.splits) if (s != null && s.isPaid) sum += s.amount;
        return sum;
    }

    public static double splitUnpaidAmount(Transaction t) {
        double sum = 0;
        if (t == null || t.splits == null) return 0;
        for (SplitMember s : t.splits) if (s != null && !s.isPaid) sum += s.amount;
        return sum;
    }

    // ---------------------------------------------------------------- queries

    /** Most recent transactions first (ISO strings sort chronologically). */
    public static List<Transaction> recentTransactions(List<Transaction> txs, int limit) {
        List<Transaction> out = new ArrayList<>();
        if (txs != null) {
            for (Transaction t : txs) if (t != null) out.add(t);
        }
        Collections.sort(out, new Comparator<Transaction>() {
            @Override public int compare(Transaction a, Transaction b) {
                String da = a.date == null ? "" : a.date;
                String db = b.date == null ? "" : b.date;
                return db.compareTo(da); // descending
            }
        });
        if (limit >= 0 && out.size() > limit) return new ArrayList<>(out.subList(0, limit));
        return out;
    }

    public static Account accountById(List<Account> accounts, String id) {
        if (accounts == null || id == null) return null;
        for (Account a : accounts) if (a != null && id.equals(a.id)) return a;
        return null;
    }

    public static Category categoryById(List<Category> categories, String id) {
        if (categories == null || id == null) return null;
        for (Category c : categories) if (c != null && id.equals(c.id)) return c;
        return null;
    }

    // ---------------------------------------------------------------- dates

    /** Year from an ISO date string, or -1 when unparseable. */
    public static int yearOf(String iso) {
        return parsePart(iso, 0, 4);
    }

    /** Month (1-12) from an ISO date string, or -1 when unparseable. */
    public static int monthOf(String iso) {
        return parsePart(iso, 5, 7);
    }

    private static int parsePart(String iso, int from, int to) {
        if (iso == null || iso.length() < to) return -1;
        try {
            return Integer.parseInt(iso.substring(from, to));
        } catch (NumberFormatException e) {
            return -1;
        }
    }

    // ---------------------------------------------------------------- format

    /**
     * INR formatting with Indian digit grouping (lakh/crore style):
     * 4850 -> "₹4,850", 175850 -> "₹1,75,850", -3200 -> "-₹3,200".
     * Whole rupees show no decimals; paise show 2 decimals.
     */
    public static String formatINR(double amount) {
        boolean negative = amount < 0;
        double abs = Math.abs(amount);
        long rupees = (long) Math.floor(abs + 1e-9);
        int paise = (int) Math.round((abs - rupees) * 100.0);
        if (paise == 100) { rupees += 1; paise = 0; }
        String body = indianGroup(Long.toString(rupees));
        if (paise != 0) {
            body += "." + (paise < 10 ? "0" : "") + paise;
        }
        return (negative ? "-₹" : "₹") + body;
    }

    /** Signed amount for a transaction row: +₹ income, -₹ expense, ₹ transfer. */
    public static String formatSigned(Transaction t) {
        if (t == null) return "";
        if ("income".equals(t.type)) return "+" + formatINR(t.amount);
        if ("expense".equals(t.type)) return "-" + formatINR(t.amount);
        return formatINR(t.amount); // transfer: neutral
    }

    /** Indian grouping: last 3 digits, then groups of 2. */
    static String indianGroup(String digits) {
        int len = digits.length();
        if (len <= 3) return digits;
        StringBuilder sb = new StringBuilder();
        String head = digits.substring(0, len - 3);
        String tail = digits.substring(len - 3);
        int i = head.length() % 2;
        if (i > 0) sb.append(head, 0, i);
        for (; i < head.length(); i += 2) {
            if (sb.length() > 0) sb.append(',');
            sb.append(head, i, i + 2);
        }
        sb.append(',').append(tail);
        return sb.toString();
    }
}
