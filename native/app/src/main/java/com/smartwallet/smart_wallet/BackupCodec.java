package com.smartwallet.smart_wallet;

import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.ArrayList;
import java.util.Base64;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.zip.GZIPInputStream;
import java.util.zip.GZIPOutputStream;

import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;

/**
 * The .smartwallet backup format, byte-compatible with the Flutter
 * app's BackupService (lib/services/backup_service.dart) in BOTH
 * directions. Pure Java — no Android imports — so the JVM tests run
 * it directly; JSON goes through MiniJson.
 *
 * File shapes (compact JSON, like Dart's jsonEncode):
 *   plain:     { format:"smartwallet_backup", version:1, createdAt,
 *                checksum, data:{snapshot}, ...snapshot-spread }
 *   encrypted: { format:"smartwallet_encrypted", version:1, createdAt,
 *                checksum, salt, iv, ciphertext, mac }
 * where "snapshot" is the database map itself (keys: version,
 * createdAt, appName, user, accounts, categories, transactions,
 * plannedPayments, debtCredits, templates, analyticsCardOrder) and
 * checksum is the lowercase hex SHA-256 of the snapshot's JSON text.
 *
 * Encryption (Flutter's hand-rolled scheme, replicated exactly):
 *   key        = PBKDF2-HMAC-SHA256(password UTF-8, salt, 10000
 *                iterations, 32-byte output, single block index 1)
 *   plaintext  = gzip(UTF-8(snapshot JSON))
 *   keystream  = block j (0-based) is HMAC-SHA256(key, iv || BE32(j));
 *                ciphertext = plaintext XOR keystream (32-byte blocks)
 *   mac        = base64(HMAC-SHA256(key, salt || iv || ciphertext))
 *   salt, iv   = 16 random bytes each, base64 in the file
 * A wrong password fails the MAC check — that is the exact condition
 * Flutter relies on ("Incorrect password or corrupted backup file.").
 */
public final class BackupCodec {

    private BackupCodec() {}

    public static final String MAGIC_PLAIN = "smartwallet_backup";
    public static final String MAGIC_ENCRYPTED = "smartwallet_encrypted";
    public static final int VERSION = 1;

    public static class BackupException extends Exception {
        public BackupException(String msg) { super(msg); }
    }

    /** The file's MAC did not verify: wrong password (or corruption). */
    public static class WrongPasswordException extends BackupException {
        public WrongPasswordException() {
            super("Incorrect password or corrupted backup file.");
        }
    }

    /** A fully-parsed backup, ready to preview and (on confirm) restore. */
    public static class Preview {
        public WalletDb db;
        public boolean isEncrypted;
        public String createdAt = "";
        public int accountsCount, categoriesCount, transactionsCount;
        public int plannedCount, debtsCount, templatesCount;
        public String userName = "User";
        public String currency = "INR";
    }

    public static class Inspection {
        public boolean isEncrypted;
        public String createdAt = "";
    }

    // ============================================================ file level

    public static String createPlainBackup(WalletDb db, String createdAtIso) {
        Map<String, Object> snapshot = dbToSnapshot(db, createdAtIso);
        String snapshotJson = MiniJson.write(snapshot);
        Map<String, Object> file = new LinkedHashMap<>();
        file.put("format", MAGIC_PLAIN);
        file.put("version", (long) VERSION);
        file.put("createdAt", createdAtIso);
        file.put("checksum", sha256Hex(snapshotJson));
        file.put("data", snapshot);
        file.putAll(snapshot); // Flutter spreads the snapshot at top level too
        return MiniJson.write(file);
    }

    public static String createEncryptedBackup(WalletDb db, String password,
                                               String createdAtIso) throws BackupException {
        byte[] salt = new byte[16];
        byte[] iv = new byte[16];
        java.security.SecureRandom rng = new java.security.SecureRandom();
        rng.nextBytes(salt);
        rng.nextBytes(iv);
        return createEncryptedBackup(db, password, createdAtIso, salt, iv);
    }

    /** Test hook: fixed salt/IV makes the output deterministic. */
    public static String createEncryptedBackup(WalletDb db, String password, String createdAtIso,
                                        byte[] salt, byte[] iv) throws BackupException {
        Map<String, Object> snapshot = dbToSnapshot(db, createdAtIso);
        String snapshotJson = MiniJson.write(snapshot);
        Map<String, Object> payload = encryptPayload(snapshotJson, password, salt, iv);
        Map<String, Object> file = new LinkedHashMap<>();
        file.put("format", MAGIC_ENCRYPTED);
        file.put("version", (long) VERSION);
        file.put("createdAt", createdAtIso);
        file.put("checksum", sha256Hex(snapshotJson));
        file.putAll(payload);
        return MiniJson.write(file);
    }

    /** Flutter's inspectFile: format + createdAt without decrypting. */
    public static Inspection inspect(String content) throws BackupException {
        Map<String, Object> file = parseFile(content);
        Inspection in = new Inspection();
        in.isEncrypted = MAGIC_ENCRYPTED.equals(str(file, "format", ""));
        in.createdAt = str(file, "createdAt", "");
        return in;
    }

    /**
     * Flutter's loadBackupPreview + parse: decrypts if needed and
     * parses the WHOLE database before returning, so a malformed file
     * can never half-mutate the live DB (restore only happens with the
     * returned Preview, after explicit confirmation).
     */
    public static Preview loadPreview(String content, String password)
            throws BackupException {
        Map<String, Object> file = parseFile(content);
        String format = str(file, "format", "");
        Map<String, Object> data;
        boolean encrypted;
        if (MAGIC_ENCRYPTED.equals(format)) {
            encrypted = true;
            if (password == null || password.trim().isEmpty()) {
                throw new BackupException("Password is required for encrypted backup.");
            }
            String plain = decryptPayload(file, password.trim());
            data = parseSnapshot(plain);
        } else if (MAGIC_PLAIN.equals(format)) {
            encrypted = false;
            Object d = file.get("data");
            if (!(d instanceof Map)) {
                throw new BackupException("Unrecognized Smart Wallet backup file format.");
            }
            data = castMap(d);
        } else if (file.containsKey("accounts") || file.containsKey("transactions")) {
            encrypted = false; // legacy / raw snapshot, as in Flutter
            data = file;
        } else {
            throw new BackupException("Unrecognized Smart Wallet backup file format.");
        }

        Preview p = new Preview();
        p.isEncrypted = encrypted;
        p.db = snapshotToDb(data);
        p.accountsCount = p.db.accounts.size();
        p.categoriesCount = p.db.categories.size();
        p.transactionsCount = p.db.transactions.size();
        p.plannedCount = p.db.plannedPayments.size();
        p.debtsCount = p.db.debtCredits.size();
        p.templatesCount = p.db.templates.size();
        p.createdAt = str(file, "createdAt", "");
        if (p.createdAt.isEmpty()) p.createdAt = str(data, "createdAt", "");
        if (p.db.user != null) {
            if (p.db.user.name != null && !p.db.user.name.isEmpty()) {
                p.userName = p.db.user.name;
            }
            if (p.db.user.baseCurrency != null && !p.db.user.baseCurrency.isEmpty()) {
                p.currency = p.db.user.baseCurrency;
            }
        }
        p.db.createdAt = p.createdAt;
        return p;
    }

    private static Map<String, Object> parseFile(String content) throws BackupException {
        if (content == null || content.trim().isEmpty()) {
            throw new BackupException("Unrecognized Smart Wallet backup file format.");
        }
        try {
            return MiniJson.parseObject(content);
        } catch (MiniJson.JsonException e) {
            throw new BackupException("Unrecognized Smart Wallet backup file format.");
        }
    }

    private static Map<String, Object> parseSnapshot(String json) throws BackupException {
        try {
            return MiniJson.parseObject(json);
        } catch (MiniJson.JsonException e) {
            throw new BackupException("Corrupted backup file.");
        }
    }

    // ============================================================ crypto

    /**
     * PBKDF2-HMAC-SHA256 exactly as Flutter's _deriveKey: the password
     * bytes are the HMAC key; U1 = HMAC(salt || INT32_BE(1)); then
     * 9,999 more chained HMACs XOR-accumulated (10,000 total).
     */
    public static byte[] deriveKey(String password, byte[] salt) {
        try {
            Mac mac = Mac.getInstance("HmacSHA256");
            mac.init(new SecretKeySpec(
                    password.getBytes(StandardCharsets.UTF_8), "HmacSHA256"));
            byte[] first = new byte[salt.length + 4];
            System.arraycopy(salt, 0, first, 0, salt.length);
            first[salt.length + 3] = 1; // block index 1, big-endian
            byte[] u = mac.doFinal(first);
            byte[] result = u.clone();
            for (int i = 1; i < 10000; i++) {
                u = mac.doFinal(u);
                for (int k = 0; k < result.length; k++) result[k] ^= u[k];
            }
            return result;
        } catch (Exception e) {
            throw new IllegalStateException("HmacSHA256 unavailable", e);
        }
    }

    private static byte[] hmac(byte[] key, byte[]... parts) {
        try {
            Mac mac = Mac.getInstance("HmacSHA256");
            mac.init(new SecretKeySpec(key, "HmacSHA256"));
            for (byte[] part : parts) mac.update(part);
            return mac.doFinal();
        } catch (Exception e) {
            throw new IllegalStateException("HmacSHA256 unavailable", e);
        }
    }

    /** Flutter's _encryptPayload with caller-supplied salt/IV. */
    public static Map<String, Object> encryptPayload(String plainText, String password,
                                              byte[] salt, byte[] iv)
            throws BackupException {
        if (password == null || password.isEmpty()) {
            throw new BackupException("Password is required for encrypted backup.");
        }
        byte[] key = deriveKey(password, salt);
        byte[] plainBytes = gzip(plainText.getBytes(StandardCharsets.UTF_8));
        byte[] cipher = xorKeystream(key, iv, plainBytes);
        byte[] mac = hmac(key, salt, iv, cipher);
        Map<String, Object> out = new LinkedHashMap<>();
        out.put("salt", Base64.getEncoder().encodeToString(salt));
        out.put("iv", Base64.getEncoder().encodeToString(iv));
        out.put("ciphertext", Base64.getEncoder().encodeToString(cipher));
        out.put("mac", Base64.getEncoder().encodeToString(mac));
        return out;
    }

    /** Flutter's _decryptPayload: MAC first, then XOR + gunzip. */
    public static String decryptPayload(Map<String, Object> file, String password)
            throws BackupException {
        byte[] salt, iv, cipher;
        String expectedMac;
        try {
            salt = Base64.getDecoder().decode(strReq(file, "salt"));
            iv = Base64.getDecoder().decode(strReq(file, "iv"));
            cipher = Base64.getDecoder().decode(strReq(file, "ciphertext"));
            expectedMac = strReq(file, "mac");
        } catch (BackupException e) {
            throw e;
        } catch (Exception e) {
            throw new BackupException("Corrupted backup file.");
        }
        byte[] key = deriveKey(password, salt);
        String actualMac = Base64.getEncoder().encodeToString(hmac(key, salt, iv, cipher));
        if (!actualMac.equals(expectedMac)) throw new WrongPasswordException();
        byte[] plainBytes = xorKeystream(key, iv, cipher);
        try {
            return new String(gunzip(plainBytes), StandardCharsets.UTF_8);
        } catch (Exception e) {
            throw new BackupException("Corrupted backup file.");
        }
    }

    /**
     * The HMAC counter-mode keystream. Flutter computes an initial
     * block from iv||"enc" and then replaces it at byte 0 (i % 32 == 0),
     * so the effective block j is HMAC(key, iv || BE32(j)) — replicated
     * here directly.
     */
    private static byte[] xorKeystream(byte[] key, byte[] iv, byte[] data) {
        byte[] out = new byte[data.length];
        int blockIndex = 0;
        byte[] blockKey = null;
        for (int i = 0; i < data.length; i++) {
            if (i % 32 == 0) {
                byte[] ctr = {
                        (byte) (blockIndex >> 24), (byte) (blockIndex >> 16),
                        (byte) (blockIndex >> 8), (byte) blockIndex };
                blockKey = hmac(key, iv, ctr);
                blockIndex++;
            }
            out[i] = (byte) (data[i] ^ blockKey[i % 32]);
        }
        return out;
    }

    private static byte[] gzip(byte[] raw) throws BackupException {
        try {
            ByteArrayOutputStream buf = new ByteArrayOutputStream();
            GZIPOutputStream gz = new GZIPOutputStream(buf);
            gz.write(raw);
            gz.close();
            return buf.toByteArray();
        } catch (Exception e) {
            throw new BackupException("Compression failed.");
        }
    }

    private static byte[] gunzip(byte[] gz) throws Exception {
        GZIPInputStream in = new GZIPInputStream(new ByteArrayInputStream(gz));
        ByteArrayOutputStream buf = new ByteArrayOutputStream();
        byte[] chunk = new byte[8192];
        int n;
        while ((n = in.read(chunk)) != -1) buf.write(chunk, 0, n);
        in.close();
        return buf.toByteArray();
    }

    public static String sha256Hex(String text) {
        try {
            MessageDigest md = MessageDigest.getInstance("SHA-256");
            byte[] digest = md.digest(text.getBytes(StandardCharsets.UTF_8));
            StringBuilder sb = new StringBuilder();
            for (byte b : digest) sb.append(String.format("%02x", b & 0xFF));
            return sb.toString();
        } catch (Exception e) {
            throw new IllegalStateException("SHA-256 unavailable", e);
        }
    }

    // ============================================================ snapshot <-> db

    /**
     * WalletDb -> the Flutter snapshot map. Key order and field sets
     * mirror createDatabaseSnapshot() exactly (nulls included, as
     * Dart writes them), with ONE superset: a template's toAccountId
     * is written when set (Flutter's snapshot omits the field and
     * Flutter's restore ignores unknown keys, so files stay
     * interchangeable; omitting it would lose native data).
     */
    public static Map<String, Object> dbToSnapshot(WalletDb db, String createdAtIso) {
        Map<String, Object> snap = new LinkedHashMap<>();
        snap.put("version", (long) VERSION);
        snap.put("createdAt", createdAtIso);
        snap.put("appName", "Smart Wallet");

        if (db.user == null) {
            snap.put("user", null);
        } else {
            UserProfile u = db.user;
            Map<String, Object> m = new LinkedHashMap<>();
            m.put("id", u.id);
            m.put("name", u.name);
            m.put("email", u.email);
            m.put("photoUrl", u.photoUrl);
            m.put("baseCurrency", u.baseCurrency);
            m.put("biometricEnabled", u.biometricEnabled);
            m.put("isDarkMode", u.isDarkMode);
            m.put("dailyReminderEnabled", u.dailyReminderEnabled);
            m.put("dailyReminderHour", (long) u.dailyReminderHour);
            m.put("dailyReminderMinute", (long) u.dailyReminderMinute);
            m.put("plannedReminderEnabled", u.plannedReminderEnabled);
            m.put("plannedReminderDaysBefore", (long) u.plannedReminderDaysBefore);
            snap.put("user", m);
        }

        List<Object> accounts = new ArrayList<>();
        for (Account a : db.accounts) {
            Map<String, Object> m = new LinkedHashMap<>();
            m.put("id", a.id);
            m.put("name", a.name);
            m.put("balance", a.balance);
            m.put("currency", a.currency);
            m.put("colorValue", a.colorValue);
            m.put("emoji", a.emoji);
            m.put("notes", a.notes);
            m.put("isEnabledForCalc", a.isEnabledForCalc);
            m.put("imagePath", a.imagePath);
            m.put("cardType", a.cardType);
            accounts.add(m);
        }
        snap.put("accounts", accounts);

        List<Object> categories = new ArrayList<>();
        for (Category c : db.categories) {
            Map<String, Object> m = new LinkedHashMap<>();
            m.put("id", c.id);
            m.put("name", c.name);
            m.put("type", c.type);
            m.put("colorValue", c.colorValue);
            m.put("icon", c.icon);
            m.put("imagePath", c.imagePath);
            m.put("parentId", c.parentId);
            categories.add(m);
        }
        snap.put("categories", categories);

        List<Object> txs = new ArrayList<>();
        for (Transaction t : db.transactions) {
            Map<String, Object> m = new LinkedHashMap<>();
            m.put("id", t.id);
            m.put("type", t.type);
            m.put("amount", t.amount);
            m.put("accountId", t.accountId);
            m.put("toAccountId", t.toAccountId);
            m.put("categoryId", t.categoryId);
            m.put("date", t.date);
            m.put("note", t.note);
            m.put("isSplit", t.isSplit);
            m.put("splits", splitsToList(t.isSplit ? t.splits : null));
            txs.add(m);
        }
        snap.put("transactions", txs);

        List<Object> planned = new ArrayList<>();
        for (PlannedPayment p : db.plannedPayments) {
            Map<String, Object> m = new LinkedHashMap<>();
            m.put("id", p.id);
            m.put("name", p.name);
            m.put("amount", p.amount);
            m.put("accountId", p.accountId);
            m.put("categoryId", p.categoryId);
            m.put("isRecurring", p.isRecurring);
            m.put("period", p.period);
            m.put("nextDueDate", p.nextDueDate);
            m.put("note", p.note);
            m.put("endType", p.endType);
            m.put("untilDate", p.untilDate);
            m.put("totalOccurrences",
                    p.totalOccurrences == null ? null : (long) p.totalOccurrences);
            m.put("currentOccurrence", (long) p.currentOccurrence);
            m.put("isCompleted", p.isCompleted);
            m.put("lastPaidDate", p.lastPaidDate);
            m.put("isSplit", p.isSplit);
            m.put("splits", splitsToList(p.isSplit ? p.splits : null));
            planned.add(m);
        }
        snap.put("plannedPayments", planned);

        List<Object> debts = new ArrayList<>();
        for (DebtCredit d : db.debtCredits) {
            Map<String, Object> m = new LinkedHashMap<>();
            m.put("id", d.id);
            m.put("direction", d.direction);
            m.put("personName", d.personName);
            m.put("amount", d.amount);
            m.put("accountId", d.accountId);
            m.put("categoryId", d.categoryId);
            m.put("startDate", d.startDate);
            m.put("dueDate", d.dueDate);
            m.put("status", d.status);
            m.put("notes", d.notes);
            m.put("affectsAccount", d.affectsAccount);
            m.put("transactionId", d.transactionId);
            m.put("settlementTransactionId", d.settlementTransactionId);
            debts.add(m);
        }
        snap.put("debtCredits", debts);

        List<Object> templates = new ArrayList<>();
        for (Template t : db.templates) {
            Map<String, Object> m = new LinkedHashMap<>();
            m.put("id", t.id);
            m.put("name", t.name);
            m.put("type", t.type);
            m.put("amount", t.amount);
            m.put("accountId", t.accountId);
            m.put("categoryId", t.categoryId);
            m.put("note", t.note);
            if (t.toAccountId != null) m.put("toAccountId", t.toAccountId);
            templates.add(m);
        }
        snap.put("templates", templates);

        List<Object> order = new ArrayList<>();
        order.addAll(db.analyticsCardOrder);
        snap.put("analyticsCardOrder", order);
        return snap;
    }

    private static Object splitsToList(List<SplitMember> splits) {
        if (splits == null) return null;
        List<Object> out = new ArrayList<>();
        for (SplitMember s : splits) {
            Map<String, Object> m = new LinkedHashMap<>();
            m.put("id", s.id);
            m.put("name", s.name);
            m.put("amount", s.amount);
            m.put("isPaid", s.isPaid);
            m.put("paidDate", s.paidDate);
            m.put("paidAccountId", s.paidAccountId);
            out.add(m);
        }
        return out;
    }

    /**
     * Snapshot map -> WalletDb, with the same defaults Flutter's
     * restoreDatabase uses. Structural problems (a section that is not
     * a list, a row that is not an object) are rejected outright.
     */
    public static WalletDb snapshotToDb(Map<String, Object> data) throws BackupException {
        WalletDb db = new WalletDb();

        Object userObj = data.get("user");
        if (userObj != null) {
            Map<String, Object> u = asMap(userObj, "user");
            UserProfile up = new UserProfile();
            up.id = str(u, "id", "guest_user");
            up.name = str(u, "name", "User");
            up.email = str(u, "email", "");
            up.photoUrl = str(u, "photoUrl", "");
            up.baseCurrency = str(u, "baseCurrency", "INR");
            up.biometricEnabled = bool(u, "biometricEnabled", false);
            up.isDarkMode = bool(u, "isDarkMode", true);
            up.dailyReminderEnabled = bool(u, "dailyReminderEnabled", true);
            up.dailyReminderHour = integer(u, "dailyReminderHour", 20);
            up.dailyReminderMinute = integer(u, "dailyReminderMinute", 0);
            up.plannedReminderEnabled = bool(u, "plannedReminderEnabled", true);
            up.plannedReminderDaysBefore = integer(u, "plannedReminderDaysBefore", 2);
            db.user = up;
        }

        for (Map<String, Object> o : rows(data, "accounts")) {
            Account a = new Account();
            a.id = str(o, "id", "");
            a.name = str(o, "name", "");
            a.balance = dbl(o, "balance", 0);
            a.currency = str(o, "currency", "INR");
            a.colorValue = lng(o, "colorValue", 0xFF6C63FFL);
            a.emoji = str(o, "emoji", "💳");
            a.notes = str(o, "notes", "");
            a.isEnabledForCalc = bool(o, "isEnabledForCalc", true);
            a.imagePath = strOrNull(o, "imagePath");
            String ct = strOrNull(o, "cardType");
            a.cardType = ct == null ? "Mastercard" : ct;
            db.accounts.add(a);
        }

        for (Map<String, Object> o : rows(data, "categories")) {
            Category c = new Category();
            c.id = str(o, "id", "");
            c.name = str(o, "name", "");
            c.type = str(o, "type", "expense");
            c.colorValue = lng(o, "colorValue", 0xFF6C63FFL);
            c.icon = str(o, "icon", "📦");
            c.imagePath = strOrNull(o, "imagePath");
            c.parentId = strOrNull(o, "parentId");
            db.categories.add(c);
        }

        for (Map<String, Object> o : rows(data, "transactions")) {
            Transaction t = new Transaction();
            t.id = str(o, "id", "");
            t.type = str(o, "type", "expense");
            t.amount = dbl(o, "amount", 0);
            t.accountId = str(o, "accountId", "");
            t.toAccountId = strOrNull(o, "toAccountId");
            t.categoryId = strOrNull(o, "categoryId");
            t.date = str(o, "date", "");
            t.note = str(o, "note", "");
            t.isSplit = bool(o, "isSplit", false);
            t.splits = splitsFrom(o.get("splits"));
            db.transactions.add(t);
        }

        for (Map<String, Object> o : rows(data, "plannedPayments")) {
            PlannedPayment p = new PlannedPayment();
            p.id = str(o, "id", "");
            p.name = str(o, "name", "");
            p.amount = dbl(o, "amount", 0);
            p.accountId = str(o, "accountId", "");
            p.categoryId = strOrNull(o, "categoryId");
            p.isRecurring = bool(o, "isRecurring", false);
            p.period = strOrNull(o, "period");
            p.nextDueDate = str(o, "nextDueDate", "");
            p.note = str(o, "note", "");
            p.endType = str(o, "endType", "never");
            p.untilDate = strOrNull(o, "untilDate");
            Object to = o.get("totalOccurrences");
            p.totalOccurrences = to instanceof Number ? ((Number) to).intValue() : null;
            p.currentOccurrence = integer(o, "currentOccurrence", 1);
            p.isCompleted = bool(o, "isCompleted", false);
            p.lastPaidDate = strOrNull(o, "lastPaidDate");
            p.isSplit = bool(o, "isSplit", false);
            p.splits = splitsFrom(o.get("splits"));
            db.plannedPayments.add(p);
        }

        for (Map<String, Object> o : rows(data, "debtCredits")) {
            DebtCredit d = new DebtCredit();
            d.id = str(o, "id", "");
            d.direction = str(o, "direction", "lent");
            d.personName = str(o, "personName", "");
            d.amount = dbl(o, "amount", 0);
            d.accountId = str(o, "accountId", "");
            d.categoryId = strOrNull(o, "categoryId");
            d.startDate = str(o, "startDate", "");
            d.dueDate = strOrNull(o, "dueDate");
            d.status = str(o, "status", "active");
            d.notes = str(o, "notes", "");
            d.affectsAccount = bool(o, "affectsAccount", true);
            d.transactionId = strOrNull(o, "transactionId");
            d.settlementTransactionId = strOrNull(o, "settlementTransactionId");
            db.debtCredits.add(d);
        }

        for (Map<String, Object> o : rows(data, "templates")) {
            Template t = new Template();
            t.id = str(o, "id", "");
            t.name = str(o, "name", "");
            t.type = str(o, "type", "expense");
            t.amount = dbl(o, "amount", 0);
            t.accountId = str(o, "accountId", "");
            t.categoryId = strOrNull(o, "categoryId");
            t.note = str(o, "note", "");
            t.toAccountId = strOrNull(o, "toAccountId");
            db.templates.add(t);
        }

        Object order = data.get("analyticsCardOrder");
        if (order != null) {
            if (!(order instanceof List)) {
                throw new BackupException("Invalid backup: analyticsCardOrder is not a list.");
            }
            for (Object item : (List<?>) order) {
                if (item != null) db.analyticsCardOrder.add(String.valueOf(item));
            }
        }
        return db;
    }

    private static List<SplitMember> splitsFrom(Object raw) throws BackupException {
        List<SplitMember> out = new ArrayList<>();
        if (raw == null) return out;
        if (!(raw instanceof List)) {
            throw new BackupException("Invalid backup: splits is not a list.");
        }
        for (Object item : (List<?>) raw) {
            Map<String, Object> o = asMap(item, "split member");
            SplitMember s = new SplitMember();
            s.id = str(o, "id", "");
            s.name = str(o, "name", "");
            s.amount = dbl(o, "amount", 0);
            s.isPaid = bool(o, "isPaid", false);
            s.paidDate = strOrNull(o, "paidDate");
            s.paidAccountId = strOrNull(o, "paidAccountId");
            out.add(s);
        }
        return out;
    }

    // ============================================================ map helpers

    @SuppressWarnings("unchecked")
    private static Map<String, Object> castMap(Object o) {
        return (Map<String, Object>) o;
    }

    private static Map<String, Object> asMap(Object o, String what) throws BackupException {
        if (!(o instanceof Map)) {
            throw new BackupException("Invalid backup: " + what + " is not an object.");
        }
        return castMap(o);
    }

    private static List<Map<String, Object>> rows(Map<String, Object> data, String key)
            throws BackupException {
        List<Map<String, Object>> out = new ArrayList<>();
        Object raw = data.get(key);
        if (raw == null) return out;
        if (!(raw instanceof List)) {
            throw new BackupException("Invalid backup: " + key + " is not a list.");
        }
        for (Object item : (List<?>) raw) out.add(asMap(item, key + " entry"));
        return out;
    }

    private static String str(Map<String, Object> m, String key, String def) {
        Object v = m.get(key);
        if (v == null) return def;
        return v instanceof String ? (String) v : String.valueOf(v);
    }

    private static String strOrNull(Map<String, Object> m, String key) {
        Object v = m.get(key);
        if (v == null) return null;
        String s = v instanceof String ? (String) v : String.valueOf(v);
        return s.isEmpty() ? null : s;
    }

    private static String strReq(Map<String, Object> m, String key) throws BackupException {
        Object v = m.get(key);
        if (!(v instanceof String)) {
            throw new BackupException("Corrupted backup file.");
        }
        return (String) v;
    }

    private static boolean bool(Map<String, Object> m, String key, boolean def) {
        Object v = m.get(key);
        return v instanceof Boolean ? ((Boolean) v).booleanValue() : def;
    }

    private static double dbl(Map<String, Object> m, String key, double def) {
        Object v = m.get(key);
        return v instanceof Number ? ((Number) v).doubleValue() : def;
    }

    private static long lng(Map<String, Object> m, String key, long def) {
        Object v = m.get(key);
        return v instanceof Number ? ((Number) v).longValue() : def;
    }

    private static int integer(Map<String, Object> m, String key, int def) {
        Object v = m.get(key);
        return v instanceof Number ? ((Number) v).intValue() : def;
    }
}
