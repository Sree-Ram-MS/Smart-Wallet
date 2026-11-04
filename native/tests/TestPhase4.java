import com.smartwallet.smart_wallet.Account;
import com.smartwallet.smart_wallet.BackupCodec;
import com.smartwallet.smart_wallet.Category;
import com.smartwallet.smart_wallet.CsvCodec;
import com.smartwallet.smart_wallet.DebtCredit;
import com.smartwallet.smart_wallet.MiniJson;
import com.smartwallet.smart_wallet.PlannedPayment;
import com.smartwallet.smart_wallet.SplitMember;
import com.smartwallet.smart_wallet.Template;
import com.smartwallet.smart_wallet.Transaction;
import com.smartwallet.smart_wallet.UserProfile;
import com.smartwallet.smart_wallet.WalletDb;
import com.smartwallet.smart_wallet.WalletLogic;

import java.io.ByteArrayOutputStream;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.security.MessageDigest;
import java.util.Base64;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.zip.GZIPOutputStream;

import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;

/**
 * Phase 4 compatibility tests: backup plain/encrypted round-trips
 * against a from-the-Dart-source reference implementation of the
 * Flutter encryption scheme, the real starter backup fixture, CSV
 * export/import in Flutter's format, and malformed-file rejection.
 * Run via ./build-apk.sh test.
 */
public class TestPhase4 {
    private static int failures = 0;
    private static int checks = 0;

    private static void check(String name, boolean cond) {
        checks++;
        if (!cond) { failures++; System.out.println("FAIL: " + name); }
    }

    private static void eqD(String name, double expected, double actual) {
        checks++;
        if (Math.abs(expected - actual) > 0.001) {
            failures++;
            System.out.println("FAIL: " + name + " expected " + expected + " got " + actual);
        }
    }

    private static void eqS(String name, String expected, String actual) {
        checks++;
        if (expected == null ? actual != null : !expected.equals(actual)) {
            failures++;
            System.out.println("FAIL: " + name + " expected <" + expected + "> got <" + actual + ">");
        }
    }

    private static void eqI(String name, long expected, long actual) {
        checks++;
        if (expected != actual) {
            failures++;
            System.out.println("FAIL: " + name + " expected " + expected + " got " + actual);
        }
    }

    // ------------------------------------------------------------ sample DB

    private static Account acc(String id, String name, double bal) {
        Account a = new Account();
        a.id = id; a.name = name; a.balance = bal;
        return a;
    }

    private static WalletDb sampleDb() {
        WalletDb db = new WalletDb();
        UserProfile u = new UserProfile();
        u.id = "u1"; u.name = "Ram Test"; u.email = "ram@example.com";
        u.baseCurrency = "INR";
        u.dailyReminderHour = 21; u.dailyReminderMinute = 30;
        u.plannedReminderDaysBefore = 3;
        db.user = u;

        Account a1 = acc("a1", "Bank", 1000.50);
        Account a2 = acc("a2", "Cash", 200.0);
        a2.cardType = "Cash";
        db.accounts.add(a1); db.accounts.add(a2);

        Category food = new Category(); food.id = "cFood"; food.name = "Food"; food.type = "expense";
        Category sub = new Category(); sub.id = "cSub"; sub.name = "Groceries"; sub.type = "expense"; sub.parentId = "cFood";
        Category sal = new Category(); sal.id = "cSal"; sal.name = "Salary"; sal.type = "income";
        db.categories.add(food); db.categories.add(sub); db.categories.add(sal);

        Transaction t1 = new Transaction("t1", "income", 5000, "a1", "2026-09-01T09:30:00.000");
        t1.categoryId = "cSal"; t1.note = "Salary Sep";
        Transaction t2 = new Transaction("t2", "expense", 250.25, "a1", "2026-09-02T14:15:00.000");
        t2.categoryId = "cSub"; t2.note = "Veggies, weekly";
        Transaction t3 = new Transaction("t3", "transfer", 300, "a1", "2026-09-03T10:00:00.000");
        t3.toAccountId = "a2"; t3.note = "Move to cash";
        Transaction t4 = new Transaction("t4", "expense", 2400, "a2", "2026-09-03T20:30:00.000");
        t4.categoryId = "cFood"; t4.note = "Team Dinner"; t4.isSplit = true;
        SplitMember me = new SplitMember("m1", "Me", 800, true);
        me.paidDate = "2026-09-03T20:30:00.000"; me.paidAccountId = "a2";
        SplitMember kar = new SplitMember("m2", "Karthik", 800, false);
        SplitMember rah = new SplitMember("m3", "Rahul", 800, true);
        rah.paidDate = "2026-09-04T09:00:00.000";
        t4.splits.add(me); t4.splits.add(kar); t4.splits.add(rah);
        db.transactions.add(t1); db.transactions.add(t2);
        db.transactions.add(t3); db.transactions.add(t4);

        PlannedPayment p1 = new PlannedPayment();
        p1.id = "p1"; p1.name = "Rent"; p1.amount = 15000; p1.accountId = "a1";
        p1.categoryId = "cFood"; p1.isRecurring = true; p1.period = "monthly";
        p1.nextDueDate = "2026-10-01T09:00:00.000"; p1.endType = "occurrences";
        p1.totalOccurrences = 6; p1.currentOccurrence = 2;
        PlannedPayment p2 = new PlannedPayment();
        p2.id = "p2"; p2.name = "Dinner plan"; p2.amount = 900; p2.accountId = "a2";
        p2.nextDueDate = "2026-09-10T20:00:00.000"; p2.isSplit = true;
        p2.splits.add(new SplitMember("pm1", "Me", 450, false));
        p2.splits.add(new SplitMember("pm2", "Karthik", 450, false));
        db.plannedPayments.add(p1); db.plannedPayments.add(p2);

        DebtCredit d1 = new DebtCredit();
        d1.id = "d1"; d1.direction = "lent"; d1.personName = "Alex"; d1.amount = 5000;
        d1.accountId = "a1"; d1.startDate = "2026-09-01T10:00:00.000";
        d1.status = "active"; d1.transactionId = "tx_debt1";
        DebtCredit d2 = new DebtCredit();
        d2.id = "d2"; d2.direction = "borrowed"; d2.personName = "Uncle David";
        d2.amount = 10000; d2.accountId = "a1"; d2.startDate = "2026-08-15T10:00:00.000";
        d2.status = "closed"; d2.settlementTransactionId = "tx_set1";
        db.debtCredits.add(d1); db.debtCredits.add(d2);

        Template tm1 = new Template();
        tm1.id = "tm1"; tm1.name = "Morning Coffee"; tm1.type = "expense";
        tm1.amount = 40; tm1.accountId = "a2"; tm1.categoryId = "cFood";
        tm1.note = "Daily tea/coffee";
        Template tm2 = new Template();
        tm2.id = "tm2"; tm2.name = "Top up cash"; tm2.type = "transfer";
        tm2.amount = 500; tm2.accountId = "a1"; tm2.toAccountId = "a2";
        db.templates.add(tm1); db.templates.add(tm2);

        db.analyticsCardOrder.add("card_a");
        db.analyticsCardOrder.add("card_b");
        return db;
    }

    // --------------------------- independent reference crypto (from the Dart)

    private static byte[] refHmac(byte[] key, byte[] data) throws Exception {
        Mac mac = Mac.getInstance("HmacSHA256");
        mac.init(new SecretKeySpec(key, "HmacSHA256"));
        return mac.doFinal(data);
    }

    private static byte[] concat(byte[]... parts) {
        int len = 0;
        for (byte[] p : parts) len += p.length;
        byte[] out = new byte[len];
        int pos = 0;
        for (byte[] p : parts) { System.arraycopy(p, 0, out, pos, p.length); pos += p.length; }
        return out;
    }

    /** PBKDF2-HMAC-SHA256, 10000 iterations, 32-byte key — written
     *  straight from _deriveKey in backup_service.dart. */
    private static byte[] refDeriveKey(String password, byte[] salt) throws Exception {
        byte[] pw = password.getBytes(StandardCharsets.UTF_8);
        Mac mac = Mac.getInstance("HmacSHA256");
        mac.init(new SecretKeySpec(pw, "HmacSHA256"));
        byte[] u = mac.doFinal(concat(salt, new byte[] {0, 0, 0, 1}));
        byte[] result = u.clone();
        for (int i = 1; i < 10000; i++) {
            u = mac.doFinal(u);
            for (int k = 0; k < result.length; k++) result[k] ^= u[k];
        }
        return result;
    }

    /** The _encryptPayload keystream + MAC, written from the Dart. */
    private static String[] refEncrypt(String plainText, String password,
                                       byte[] salt, byte[] iv) throws Exception {
        byte[] key = refDeriveKey(password, salt);
        ByteArrayOutputStream buf = new ByteArrayOutputStream();
        GZIPOutputStream gz = new GZIPOutputStream(buf);
        gz.write(plainText.getBytes(StandardCharsets.UTF_8));
        gz.close();
        byte[] plain = buf.toByteArray();
        byte[] cipher = new byte[plain.length];
        int blockIndex = 0;
        byte[] blockKey = null;
        for (int i = 0; i < plain.length; i++) {
            if (i % 32 == 0) {
                byte[] ctr = { (byte) (blockIndex >> 24), (byte) (blockIndex >> 16),
                        (byte) (blockIndex >> 8), (byte) blockIndex };
                blockKey = refHmac(key, concat(iv, ctr));
                blockIndex++;
            }
            cipher[i] = (byte) (plain[i] ^ blockKey[i % 32]);
        }
        byte[] mac = refHmac(key, concat(salt, iv, cipher));
        Base64.Encoder b64 = Base64.getEncoder();
        return new String[] {
                b64.encodeToString(salt), b64.encodeToString(iv),
                b64.encodeToString(cipher), b64.encodeToString(mac) };
    }

    private static String sha256HexOf(String text) throws Exception {
        MessageDigest md = MessageDigest.getInstance("SHA-256");
        byte[] d = md.digest(text.getBytes(StandardCharsets.UTF_8));
        StringBuilder sb = new StringBuilder();
        for (byte b : d) sb.append(String.format("%02x", b & 0xFF));
        return sb.toString();
    }

    // ------------------------------------------------------------------ main

    public static void main(String[] args) throws Exception {
        final String NOW = "2026-11-04T10:00:00.000";

        // ================= (a) plain backup round-trip ======================
        {
            WalletDb db = sampleDb();
            String file = BackupCodec.createPlainBackup(db, NOW);
            check("plain file starts with the plain magic",
                    file.startsWith("{\"format\":\"smartwallet_backup\""));
            BackupCodec.Inspection in = BackupCodec.inspect(file);
            check("inspect: plain not flagged encrypted", !in.isEncrypted);
            eqS("inspect: createdAt", NOW, in.createdAt);

            Map<String, Object> root = MiniJson.parseObject(file);
            check("plain file spreads the snapshot at top level",
                    root.containsKey("accounts") && root.containsKey("data"));
            @SuppressWarnings("unchecked")
            Map<String, Object> data = (Map<String, Object>) root.get("data");
            eqS("checksum = sha256 of the snapshot JSON",
                    sha256HexOf(MiniJson.write(data)), (String) root.get("checksum"));
            eqS("snapshot carries appName", "Smart Wallet", (String) data.get("appName"));

            BackupCodec.Preview pv = BackupCodec.loadPreview(file, null);
            check("preview: plain", !pv.isEncrypted);
            eqI("counts accounts", 2, pv.accountsCount);
            eqI("counts categories", 3, pv.categoriesCount);
            eqI("counts transactions", 4, pv.transactionsCount);
            eqI("counts planned", 2, pv.plannedCount);
            eqI("counts debts", 2, pv.debtsCount);
            eqI("counts templates", 2, pv.templatesCount);
            eqS("preview user name", "Ram Test", pv.userName);
            eqS("preview currency", "INR", pv.currency);
            eqS("preview createdAt", NOW, pv.createdAt);

            WalletDb back = pv.db;
            eqD("round-trip net wallet", 1200.50, WalletLogic.netWallet(back.accounts));
            eqD("round-trip Sep income", 5000,
                    WalletLogic.monthlyIncome(back.transactions, 2026, 9));
            eqD("round-trip Sep expense", 2650.25,
                    WalletLogic.monthlyExpense(back.transactions, 2026, 9));
            Transaction t4 = WalletLogic.transactionById(back, "t4");
            check("round-trip split flag", t4 != null && t4.isSplit);
            eqI("round-trip split members", 3, t4.splits.size());
            check("round-trip member paid + account kept",
                    t4.splits.get(0).isPaid && "a2".equals(t4.splits.get(0).paidAccountId));
            check("round-trip member paid, null account kept null",
                    t4.splits.get(2).isPaid && t4.splits.get(2).paidAccountId == null);
            Template tm2 = WalletLogic.templateById(back, "tm2");
            eqS("round-trip template to-account (native superset)", "a2", tm2.toAccountId);
            DebtCredit d1 = WalletLogic.debtById(back, "d1");
            eqS("round-trip debt linked tx id", "tx_debt1", d1.transactionId);
            PlannedPayment p1 = WalletLogic.plannedById(back, "p1");
            eqI("round-trip planned totalOccurrences", 6, p1.totalOccurrences);
            eqI("round-trip user reminder days", 3, back.user.plannedReminderDaysBefore);
            eqS("round-trip restored db createdAt", NOW, back.createdAt);
            eqS("round-trip comma note survives", "Veggies, weekly",
                    WalletLogic.transactionById(back, "t2").note);
            eqI("round-trip card order", 2, back.analyticsCardOrder.size());
        }

        // ================= (b) encryption ==================================
        {
            byte[] salt = new byte[16];
            byte[] iv = new byte[16];
            for (int i = 0; i < 16; i++) { salt[i] = (byte) i; iv[i] = (byte) (16 + i); }
            String plainText = "{\"note\":\"Dinner split, ₹2,400 — paid\"}";
            String pw = "correct horse battery";

            // codec output must equal the independent reference, byte for byte
            Map<String, Object> mine = BackupCodec.encryptPayload(plainText, pw, salt, iv);
            String[] ref = refEncrypt(plainText, pw, salt, iv);
            eqS("vector: salt", ref[0], (String) mine.get("salt"));
            eqS("vector: iv", ref[1], (String) mine.get("iv"));
            eqS("vector: ciphertext matches reference", ref[2], (String) mine.get("ciphertext"));
            eqS("vector: mac matches reference", ref[3], (String) mine.get("mac"));

            // and the codec must decrypt a reference-produced payload
            Map<String, Object> refMap = new LinkedHashMap<>();
            refMap.put("salt", ref[0]); refMap.put("iv", ref[1]);
            refMap.put("ciphertext", ref[2]); refMap.put("mac", ref[3]);
            eqS("codec decrypts reference payload", plainText,
                    BackupCodec.decryptPayload(refMap, pw));

            // derived keys agree with the reference PBKDF2
            byte[] k1 = BackupCodec.deriveKey(pw, salt);
            byte[] k2 = refDeriveKey(pw, salt);
            eqS("deriveKey matches reference PBKDF2",
                    Base64.getEncoder().encodeToString(k2),
                    Base64.getEncoder().encodeToString(k1));

            // full encrypted file: structure + round-trip + wrong password
            WalletDb db = sampleDb();
            String encFile = BackupCodec.createEncryptedBackup(db, "pw123", NOW, salt, iv);
            Map<String, Object> root = MiniJson.parseObject(encFile);
            StringBuilder keys = new StringBuilder();
            for (String k : root.keySet()) { if (keys.length() > 0) keys.append(','); keys.append(k); }
            eqS("encrypted file field order",
                    "format,version,createdAt,checksum,salt,iv,ciphertext,mac", keys.toString());
            eqS("encrypted magic", "smartwallet_encrypted", (String) root.get("format"));
            eqI("salt is 16 bytes", 16,
                    Base64.getDecoder().decode((String) root.get("salt")).length);
            eqI("iv is 16 bytes", 16,
                    Base64.getDecoder().decode((String) root.get("iv")).length);

            BackupCodec.Inspection in = BackupCodec.inspect(encFile);
            check("inspect: encrypted flagged", in.isEncrypted);
            BackupCodec.Preview pv = BackupCodec.loadPreview(encFile, "pw123");
            check("encrypted preview flagged", pv.isEncrypted);
            eqI("encrypted round-trip tx count", 4, pv.transactionsCount);
            eqD("encrypted round-trip net wallet", 1200.50,
                    WalletLogic.netWallet(pv.db.accounts));

            boolean wrongPw = false;
            try {
                BackupCodec.loadPreview(encFile, "wrong-password");
            } catch (BackupCodec.WrongPasswordException e) {
                wrongPw = true;
                eqS("wrong password message is Flutter's",
                        "Incorrect password or corrupted backup file.", e.getMessage());
            }
            check("wrong password rejected via MAC", wrongPw);

            boolean needPw = false;
            try {
                BackupCodec.loadPreview(encFile, null);
            } catch (BackupCodec.BackupException e) {
                needPw = "Password is required for encrypted backup.".equals(e.getMessage());
            }
            check("missing password rejected with Flutter's message", needPw);

            // a "Flutter-produced" file: snapshot encrypted by the reference
            Map<String, Object> snapshot = BackupCodec.dbToSnapshot(sampleDb(), NOW);
            String snapJson = MiniJson.write(snapshot);
            String[] refParts = refEncrypt(snapJson, "flutterpw", salt, iv);
            Map<String, Object> flutterFile = new LinkedHashMap<>();
            flutterFile.put("format", "smartwallet_encrypted");
            flutterFile.put("version", 1L);
            flutterFile.put("createdAt", NOW);
            flutterFile.put("checksum", sha256HexOf(snapJson));
            flutterFile.put("salt", refParts[0]);
            flutterFile.put("iv", refParts[1]);
            flutterFile.put("ciphertext", refParts[2]);
            flutterFile.put("mac", refParts[3]);
            BackupCodec.Preview fpv = BackupCodec.loadPreview(
                    MiniJson.write(flutterFile), "flutterpw");
            eqI("reference-encrypted file: tx count", 4, fpv.transactionsCount);
            eqD("reference-encrypted file: net wallet", 1200.50,
                    WalletLogic.netWallet(fpv.db.accounts));

            // random salt/iv path also round-trips
            String enc2 = BackupCodec.createEncryptedBackup(sampleDb(), "pw123", NOW);
            eqI("random-salt encrypted round-trip", 4,
                    BackupCodec.loadPreview(enc2, "pw123").transactionsCount);
        }

        // ================= (c) real fixture: starter backup ================
        {
            String path = "reference/starter_wallet_data.json";
            if (!Files.exists(Paths.get(path))) {
                path = "app/src/main/res/raw/starter_wallet_data.json";
            }
            String starter = new String(Files.readAllBytes(Paths.get(path)),
                    StandardCharsets.UTF_8);
            BackupCodec.Preview pv = BackupCodec.loadPreview(starter, null);
            check("starter: not encrypted", !pv.isEncrypted);
            eqI("starter accounts", 4, pv.accountsCount);
            eqI("starter categories", 10, pv.categoriesCount);
            eqI("starter transactions", 5, pv.transactionsCount);
            eqI("starter planned", 2, pv.plannedCount);
            eqI("starter debts", 2, pv.debtsCount);
            eqI("starter templates", 2, pv.templatesCount);
            eqD("starter net wallet (Phase 1 number)", 175850,
                    WalletLogic.netWallet(pv.db.accounts));
            eqS("starter user name", "My Wallet", pv.userName);
            eqS("starter currency", "INR", pv.currency);
        }

        // ================= (d) CSV =========================================
        {
            WalletDb db = sampleDb();
            String csv = CsvCodec.exportCsv(db);
            String[] lines = csv.split("\r\n");
            eqS("csv header", "ID,Type,Amount,Account,To Account,Category,Date,Note",
                    lines[0]);
            eqI("csv line count = header + 4", 5, lines.length);
            check("csv income row (date quoted, it contains a comma)",
                    lines[1].startsWith(
                    "t1,income,5000.0,Bank,,Salary,\"1 Sep 2026, 9:30 AM\",Salary Sep"));
            check("csv comma note is quoted", lines[2].contains("\"Veggies, weekly\""));
            check("csv transfer row shows both accounts",
                    lines[3].contains("transfer,300.0,Bank,Cash,,\"3 Sep 2026, 10:00 AM\""));
            check("csv split row carries category name",
                    lines[4].contains("expense,2400.0,Cash,,Food,\"3 Sep 2026, 8:30 PM\""));

            // round-trip: import goes to the first account (Flutter rule),
            // so compare field-wise against a one-account expectation.
            WalletDb target = new WalletDb();
            target.accounts.add(acc("only", "Only", 0));
            CsvCodec.ImportResult rt = CsvCodec.importCsv(target, csv, "tx_csv_1",
                    "2026-11-04T00:00:00.000");
            eqI("csv round-trip imported", 4, rt.imported);
            eqI("csv round-trip skipped", 0, rt.skipped);
            eqI("csv round-trip tx rows", 4, target.transactions.size());
            Transaction r1 = target.transactions.get(0);
            eqS("rt type", "income", r1.type);
            eqD("rt amount", 5000, r1.amount);
            eqS("rt date survives via display format", "2026-09-01T09:30:00.000", r1.date);
            eqS("rt note", "Salary Sep", r1.note);
            eqS("rt lands in first account", "only", r1.accountId);
            check("rt category dropped like Flutter", r1.categoryId == null);
            eqD("rt net balance = 5000 -250.25 -300 -2400 (transfer has no "
                    + "destination, mirrors Flutter import)", 2049.75,
                    target.accounts.get(0).balance);
            eqS("rt quoted note survives", "Veggies, weekly",
                    target.transactions.get(1).note);

            // hand-written Flutter-style CSV: CRLF, quoted comma note,
            // ISO date, bad rows
            String manual = "ID,Type,Amount,Account,To Account,Category,Date,Note\r\n"
                    + "x1,income,1200.5,Bank,,Salary,2026-10-01T08:00:00.000,Payday\r\n"
                    + "x2,expense,99.99,Bank,,Food,\"2 Oct 2026, 1:05 PM\",\"Lunch, team\"\r\n"
                    + "x3,expense,0,Bank,,Food,2026-10-02,Zero amount\r\n"
                    + "x4,expense,abc,Bank,,Food,2026-10-02,Bad amount\r\n"
                    + "x5,gift,50,Bank,,Food,2026-10-03,Unknown type\r\n"
                    + "x6,expense,10,Bank,,Food,not-a-date,Bad date falls back\r\n";
            WalletDb db2 = new WalletDb();
            db2.accounts.add(acc("first", "First", 100));
            db2.accounts.add(acc("second", "Second", 0));
            CsvCodec.ImportResult mr = CsvCodec.importCsv(db2, manual, "tx_csv_2",
                    "2026-11-04T12:00:00.000");
            eqI("manual csv imported", 4, mr.imported);
            eqI("manual csv skipped", 2, mr.skipped);
            eqI("manual csv skip reasons listed", 2, mr.skipReasons.size());
            eqD("manual csv balance moved through WalletLogic",
                    100 + 1200.5 - 99.99 - 50 - 10, db2.accounts.get(0).balance);
            eqD("manual csv second account untouched", 0, db2.accounts.get(1).balance);
            Transaction lunch = db2.transactions.get(1);
            eqS("manual csv quoted note", "Lunch, team", lunch.note);
            eqS("manual csv display date parsed", "2026-10-02T13:05:00.000", lunch.date);
            Transaction unknownType = db2.transactions.get(2);
            eqS("manual csv unknown type becomes expense", "expense", unknownType.type);
            Transaction badDate = db2.transactions.get(3);
            eqS("manual csv bad date falls back to now", "2026-11-04T12:00:00.000",
                    badDate.date);
            check("manual csv all in first account",
                    "first".equals(db2.transactions.get(0).accountId));

            // LF-only file, headers in a different order/case
            String lf = "note,amount,type,date\nBus fare,25,expense,2026-10-05\n";
            WalletDb db3 = new WalletDb();
            db3.accounts.add(acc("only", "Only", 50));
            CsvCodec.ImportResult lr = CsvCodec.importCsv(db3, lf, "tx_csv_3",
                    "2026-11-04T00:00:00.000");
            eqI("lf csv imported", 1, lr.imported);
            eqD("lf csv balance", 25, db3.accounts.get(0).balance);
            eqS("lf csv note by header name", "Bus fare", db3.transactions.get(0).note);

            // no accounts -> everything skipped, nothing crashes
            WalletDb db4 = new WalletDb();
            CsvCodec.ImportResult nr = CsvCodec.importCsv(db4, manual, "tx_csv_4",
                    "2026-11-04T00:00:00.000");
            eqI("no-account csv imported", 0, nr.imported);
            eqI("no-account csv skipped all", 6, nr.skipped);
        }

        // ================= (e) malformed files =============================
        {
            check("garbage text rejected", backupError("this is not json") != null);
            check("empty file rejected", backupError("") != null);
            check("empty object rejected", backupError("{}") != null);
            check("unknown format rejected",
                    backupError("{\"format\":\"something_else\",\"data\":{}}") != null);
            check("plain magic but no data rejected",
                    backupError("{\"format\":\"smartwallet_backup\"}") != null);
            check("section of wrong type rejected", backupError(
                    "{\"format\":\"smartwallet_backup\",\"data\":{\"transactions\":{}}}")
                    != null);
            check("row of wrong type rejected", backupError(
                    "{\"format\":\"smartwallet_backup\",\"data\":{\"accounts\":[42]}}")
                    != null);
            check("truncated json rejected",
                    backupError("{\"format\":\"smartwallet_backup\",\"data\":{\"acc") != null);

            // encrypted container with broken base64 -> clean error, not a crash
            String broken = "{\"format\":\"smartwallet_encrypted\",\"salt\":\"@@@\","
                    + "\"iv\":\"AAA=\",\"ciphertext\":\"AAA=\",\"mac\":\"AAA=\"}";
            Exception be = backupErrorFull(broken, "pw");
            check("broken base64 rejected cleanly",
                    be instanceof BackupCodec.BackupException);

            // tampered ciphertext -> MAC failure (wrong-password path)
            String encFile = BackupCodec.createEncryptedBackup(sampleDb(), "pw123", NOW);
            Map<String, Object> root = MiniJson.parseObject(encFile);
            String ct = (String) root.get("ciphertext");
            root.put("ciphertext", (ct.charAt(0) == 'A' ? 'B' : 'A') + ct.substring(1));
            Exception te = backupErrorFull(MiniJson.write(root), "pw123");
            check("tampered ciphertext fails MAC",
                    te instanceof BackupCodec.WrongPasswordException);

            // failed parses never mutate a live DB
            WalletDb live = sampleDb();
            int txBefore = live.transactions.size();
            double netBefore = WalletLogic.netWallet(live.accounts);
            backupError("garbage");
            backupErrorFull(encFile, "nope");
            eqI("live db untouched by failed imports", txBefore, live.transactions.size());
            eqD("live balances untouched", netBefore, WalletLogic.netWallet(live.accounts));

            // CSV: header-only and empty are the Flutter "empty or invalid"
            check("csv header-only rejected", csvError("ID,Type,Amount\n") != null);
            check("csv empty rejected", csvError("") != null);

            // legacy raw snapshot (no wrapper) still loads, like Flutter
            Map<String, Object> snap = BackupCodec.dbToSnapshot(sampleDb(), NOW);
            BackupCodec.Preview lp = BackupCodec.loadPreview(MiniJson.write(snap), null);
            eqI("legacy raw snapshot loads", 4, lp.transactionsCount);
        }

        System.out.println("---");
        System.out.println(checks + " checks, " + failures + " failures");
        System.out.println(failures == 0 ? "ALL TESTS PASSED" : failures + " FAILURES");
        System.exit(failures == 0 ? 0 : 1);
    }

    private static Exception backupErrorFull(String content, String password) {
        try {
            BackupCodec.loadPreview(content, password);
            return null;
        } catch (Exception e) {
            return e;
        }
    }

    private static String backupError(String content) {
        Exception e = backupErrorFull(content, "pw");
        return e == null ? null : e.getMessage();
    }

    private static String csvError(String content) {
        try {
            CsvCodec.importCsv(new WalletDb(), content, "tx_csv_x", "2026-11-04T00:00:00.000");
            return null;
        } catch (Exception e) {
            return e.getMessage();
        }
    }
}
