package com.smartwallet.smart_wallet;

import android.content.Context;

import org.json.JSONArray;
import org.json.JSONObject;

import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;

/**
 * Persists the whole wallet DB as ONE JSON file in internal storage
 * (files/smartwallet_db.json). The file format IS the Flutter backup
 * format, so it stays compatible with .smartwallet files:
 *
 *   { "format": "smartwallet_backup", "version": 1,
 *     "createdAt": "<iso>", "data": { user, accounts, categories,
 *     transactions, plannedPayments, debtCredits, templates,
 *     analyticsCardOrder } }
 *
 * On first run (no file yet) the DB is seeded from the bundled starter
 * data (res/raw/starter_wallet_data.json, the same file shipped in the
 * Flutter repo) and then written out as the live DB file.
 *
 * JSON uses org.json, which is built into Android — no libraries.
 */
public final class Store {

    public static final String FORMAT = "smartwallet_backup";
    public static final int VERSION = 1;
    private static final String FILE_NAME = "smartwallet_db.json";

    private final Context ctx;
    private WalletDb db;

    public Store(Context ctx) {
        this.ctx = ctx.getApplicationContext();
    }

    public WalletDb db() {
        if (db == null) db = load();
        return db;
    }

    // ------------------------------------------------------------------ load

    public WalletDb load() {
        File f = dbFile();
        try {
            String text;
            if (f.exists()) {
                text = readAll(new FileInputStream(f));
            } else {
                InputStream in = ctx.getResources().openRawResource(R.raw.starter_wallet_data);
                text = readAll(in);
                WalletDb seeded = parse(text);
                save(seeded); // first run: persist the seed as the live DB
                return seeded;
            }
            return parse(text);
        } catch (Exception e) {
            // A corrupt file must not crash the app on every launch.
            return new WalletDb();
        }
    }

    public void save() {
        if (db != null) save(db);
    }

    public void save(WalletDb toSave) {
        try {
            toSave.createdAt = LocalDateTime.now().toString();
            String text = toJson(toSave).toString(2);
            FileOutputStream out = new FileOutputStream(dbFile());
            out.write(text.getBytes(StandardCharsets.UTF_8));
            out.close();
            db = toSave;
        } catch (Exception ignored) {
            // Phase 1 is read-only in practice; a failed save must not crash the UI.
        }
    }

    private File dbFile() {
        return new File(ctx.getFilesDir(), FILE_NAME);
    }

    private static String readAll(InputStream in) throws Exception {
        ByteArrayOutputStream buf = new ByteArrayOutputStream();
        byte[] chunk = new byte[8192];
        int n;
        while ((n = in.read(chunk)) != -1) buf.write(chunk, 0, n);
        in.close();
        return new String(buf.toByteArray(), StandardCharsets.UTF_8);
    }

    // ------------------------------------------------------------------ parse

    public static WalletDb parse(String jsonText) throws Exception {
        JSONObject root = new JSONObject(jsonText);
        WalletDb db = new WalletDb();
        db.createdAt = root.optString("createdAt", "");
        JSONObject data = root.optJSONObject("data");
        if (data == null) return db; // not a backup file: hand back an empty DB

        db.user = parseUser(data.optJSONObject("user"));

        JSONArray accounts = data.optJSONArray("accounts");
        if (accounts != null) for (int i = 0; i < accounts.length(); i++) {
            JSONObject o = accounts.optJSONObject(i);
            if (o == null) continue;
            Account a = new Account();
            a.id = str(o, "id");
            a.name = str(o, "name");
            a.balance = o.optDouble("balance", 0);
            a.currency = o.optString("currency", "INR");
            a.colorValue = o.optLong("colorValue", 0xFF6C63FFL);
            a.emoji = o.optString("emoji", "💳");
            a.notes = o.optString("notes", "");
            a.isEnabledForCalc = o.optBoolean("isEnabledForCalc", true);
            a.imagePath = strOrNull(o, "imagePath");
            a.cardType = o.optString("cardType", "");
            db.accounts.add(a);
        }

        JSONArray categories = data.optJSONArray("categories");
        if (categories != null) for (int i = 0; i < categories.length(); i++) {
            JSONObject o = categories.optJSONObject(i);
            if (o == null) continue;
            Category c = new Category();
            c.id = str(o, "id");
            c.name = str(o, "name");
            c.type = str(o, "type");
            c.colorValue = o.optLong("colorValue", 0xFF6C63FFL);
            c.icon = o.optString("icon", "📦");
            c.imagePath = strOrNull(o, "imagePath");
            c.parentId = strOrNull(o, "parentId");
            db.categories.add(c);
        }

        JSONArray txs = data.optJSONArray("transactions");
        if (txs != null) for (int i = 0; i < txs.length(); i++) {
            JSONObject o = txs.optJSONObject(i);
            if (o == null) continue;
            Transaction t = new Transaction();
            t.id = str(o, "id");
            t.type = str(o, "type");
            t.amount = o.optDouble("amount", 0);
            t.accountId = str(o, "accountId");
            t.toAccountId = strOrNull(o, "toAccountId");
            t.categoryId = strOrNull(o, "categoryId");
            t.date = str(o, "date");
            t.note = o.optString("note", "");
            t.isSplit = o.optBoolean("isSplit", false);
            t.splits = parseSplits(o.optJSONArray("splits"));
            db.transactions.add(t);
        }

        JSONArray planned = data.optJSONArray("plannedPayments");
        if (planned != null) for (int i = 0; i < planned.length(); i++) {
            JSONObject o = planned.optJSONObject(i);
            if (o == null) continue;
            PlannedPayment p = new PlannedPayment();
            p.id = str(o, "id");
            p.name = str(o, "name");
            p.amount = o.optDouble("amount", 0);
            p.accountId = str(o, "accountId");
            p.categoryId = strOrNull(o, "categoryId");
            p.isRecurring = o.optBoolean("isRecurring", false);
            p.period = strOrNull(o, "period");
            p.nextDueDate = str(o, "nextDueDate");
            p.note = o.optString("note", "");
            p.endType = o.optString("endType", "never");
            p.untilDate = strOrNull(o, "untilDate");
            p.totalOccurrences = o.has("totalOccurrences") && !o.isNull("totalOccurrences")
                    ? o.optInt("totalOccurrences") : null;
            p.currentOccurrence = o.optInt("currentOccurrence", 1);
            p.isCompleted = o.optBoolean("isCompleted", false);
            p.lastPaidDate = strOrNull(o, "lastPaidDate");
            p.isSplit = o.optBoolean("isSplit", false);
            p.splits = parseSplits(o.optJSONArray("splits"));
            db.plannedPayments.add(p);
        }

        JSONArray debts = data.optJSONArray("debtCredits");
        if (debts != null) for (int i = 0; i < debts.length(); i++) {
            JSONObject o = debts.optJSONObject(i);
            if (o == null) continue;
            DebtCredit d = new DebtCredit();
            d.id = str(o, "id");
            d.direction = str(o, "direction");
            d.personName = str(o, "personName");
            d.amount = o.optDouble("amount", 0);
            d.accountId = str(o, "accountId");
            d.categoryId = strOrNull(o, "categoryId");
            d.startDate = str(o, "startDate");
            d.dueDate = strOrNull(o, "dueDate");
            d.status = o.optString("status", "active");
            d.notes = o.optString("notes", "");
            d.affectsAccount = o.optBoolean("affectsAccount", true);
            d.transactionId = strOrNull(o, "transactionId");
            d.settlementTransactionId = strOrNull(o, "settlementTransactionId");
            db.debtCredits.add(d);
        }

        JSONArray templates = data.optJSONArray("templates");
        if (templates != null) for (int i = 0; i < templates.length(); i++) {
            JSONObject o = templates.optJSONObject(i);
            if (o == null) continue;
            Template t = new Template();
            t.id = str(o, "id");
            t.name = str(o, "name");
            t.type = str(o, "type");
            t.amount = o.optDouble("amount", 0);
            t.accountId = str(o, "accountId");
            t.toAccountId = strOrNull(o, "toAccountId");
            t.categoryId = strOrNull(o, "categoryId");
            t.note = o.optString("note", "");
            db.templates.add(t);
        }

        JSONArray order = data.optJSONArray("analyticsCardOrder");
        if (order != null) for (int i = 0; i < order.length(); i++) {
            String s = order.optString(i, "");
            if (!s.isEmpty()) db.analyticsCardOrder.add(s);
        }
        return db;
    }

    private static UserProfile parseUser(JSONObject o) {
        if (o == null) return null;
        UserProfile u = new UserProfile();
        u.id = str(o, "id");
        u.name = str(o, "name");
        u.email = str(o, "email");
        u.photoUrl = o.optString("photoUrl", "");
        u.baseCurrency = o.optString("baseCurrency", "INR");
        u.biometricEnabled = o.optBoolean("biometricEnabled", false);
        u.isDarkMode = o.optBoolean("isDarkMode", true);
        u.dailyReminderEnabled = o.optBoolean("dailyReminderEnabled", true);
        u.dailyReminderHour = o.optInt("dailyReminderHour", 20);
        u.dailyReminderMinute = o.optInt("dailyReminderMinute", 0);
        u.plannedReminderEnabled = o.optBoolean("plannedReminderEnabled", true);
        u.plannedReminderDaysBefore = o.optInt("plannedReminderDaysBefore", 2);
        return u;
    }

    private static List<SplitMember> parseSplits(JSONArray arr) {
        List<SplitMember> out = new ArrayList<>();
        if (arr == null) return out;
        for (int i = 0; i < arr.length(); i++) {
            JSONObject o = arr.optJSONObject(i);
            if (o == null) continue;
            SplitMember s = new SplitMember();
            s.id = str(o, "id");
            s.name = str(o, "name");
            s.amount = o.optDouble("amount", 0);
            s.isPaid = o.optBoolean("isPaid", false);
            s.paidDate = strOrNull(o, "paidDate");
            s.paidAccountId = strOrNull(o, "paidAccountId");
            out.add(s);
        }
        return out;
    }

    // ------------------------------------------------------------------ write

    public static JSONObject toJson(WalletDb db) throws Exception {
        JSONObject data = new JSONObject();

        if (db.user != null) {
            JSONObject u = new JSONObject();
            u.put("id", db.user.id);
            u.put("name", db.user.name);
            u.put("email", db.user.email);
            u.put("photoUrl", db.user.photoUrl);
            u.put("baseCurrency", db.user.baseCurrency);
            u.put("biometricEnabled", db.user.biometricEnabled);
            u.put("isDarkMode", db.user.isDarkMode);
            u.put("dailyReminderEnabled", db.user.dailyReminderEnabled);
            u.put("dailyReminderHour", db.user.dailyReminderHour);
            u.put("dailyReminderMinute", db.user.dailyReminderMinute);
            u.put("plannedReminderEnabled", db.user.plannedReminderEnabled);
            u.put("plannedReminderDaysBefore", db.user.plannedReminderDaysBefore);
            data.put("user", u);
        }

        JSONArray accounts = new JSONArray();
        for (Account a : db.accounts) {
            JSONObject o = new JSONObject();
            o.put("id", a.id);
            o.put("name", a.name);
            o.put("balance", a.balance);
            o.put("currency", a.currency);
            o.put("colorValue", a.colorValue);
            o.put("emoji", a.emoji);
            o.put("notes", a.notes);
            o.put("isEnabledForCalc", a.isEnabledForCalc);
            if (a.imagePath != null) o.put("imagePath", a.imagePath);
            if (a.cardType != null && !a.cardType.isEmpty()) o.put("cardType", a.cardType);
            accounts.put(o);
        }
        data.put("accounts", accounts);

        JSONArray categories = new JSONArray();
        for (Category c : db.categories) {
            JSONObject o = new JSONObject();
            o.put("id", c.id);
            o.put("name", c.name);
            o.put("type", c.type);
            o.put("colorValue", c.colorValue);
            o.put("icon", c.icon);
            if (c.imagePath != null) o.put("imagePath", c.imagePath);
            o.put("parentId", c.parentId == null ? JSONObject.NULL : c.parentId);
            categories.put(o);
        }
        data.put("categories", categories);

        JSONArray txs = new JSONArray();
        for (Transaction t : db.transactions) {
            JSONObject o = new JSONObject();
            o.put("id", t.id);
            o.put("type", t.type);
            o.put("amount", t.amount);
            o.put("accountId", t.accountId);
            if (t.toAccountId != null) o.put("toAccountId", t.toAccountId);
            o.put("categoryId", t.categoryId == null ? JSONObject.NULL : t.categoryId);
            o.put("date", t.date);
            o.put("note", t.note);
            o.put("isSplit", t.isSplit);
            if (t.isSplit || (t.splits != null && !t.splits.isEmpty())) {
                o.put("splits", splitsJson(t.splits));
            }
            txs.put(o);
        }
        data.put("transactions", txs);

        JSONArray planned = new JSONArray();
        for (PlannedPayment p : db.plannedPayments) {
            JSONObject o = new JSONObject();
            o.put("id", p.id);
            o.put("name", p.name);
            o.put("amount", p.amount);
            o.put("accountId", p.accountId);
            o.put("categoryId", p.categoryId == null ? JSONObject.NULL : p.categoryId);
            o.put("isRecurring", p.isRecurring);
            o.put("period", p.period == null ? JSONObject.NULL : p.period);
            o.put("nextDueDate", p.nextDueDate);
            o.put("note", p.note);
            o.put("endType", p.endType);
            if (p.untilDate != null) o.put("untilDate", p.untilDate);
            if (p.totalOccurrences != null) o.put("totalOccurrences", p.totalOccurrences.intValue());
            o.put("currentOccurrence", p.currentOccurrence);
            o.put("isCompleted", p.isCompleted);
            if (p.lastPaidDate != null) o.put("lastPaidDate", p.lastPaidDate);
            o.put("isSplit", p.isSplit);
            if (p.isSplit || (p.splits != null && !p.splits.isEmpty())) {
                o.put("splits", splitsJson(p.splits));
            }
            planned.put(o);
        }
        data.put("plannedPayments", planned);

        JSONArray debts = new JSONArray();
        for (DebtCredit d : db.debtCredits) {
            JSONObject o = new JSONObject();
            o.put("id", d.id);
            o.put("direction", d.direction);
            o.put("personName", d.personName);
            o.put("amount", d.amount);
            o.put("accountId", d.accountId);
            if (d.categoryId != null) o.put("categoryId", d.categoryId);
            o.put("startDate", d.startDate);
            o.put("dueDate", d.dueDate == null ? JSONObject.NULL : d.dueDate);
            o.put("status", d.status);
            o.put("notes", d.notes);
            o.put("affectsAccount", d.affectsAccount);
            if (d.transactionId != null) o.put("transactionId", d.transactionId);
            if (d.settlementTransactionId != null) o.put("settlementTransactionId", d.settlementTransactionId);
            debts.put(o);
        }
        data.put("debtCredits", debts);

        JSONArray templates = new JSONArray();
        for (Template t : db.templates) {
            JSONObject o = new JSONObject();
            o.put("id", t.id);
            o.put("name", t.name);
            o.put("type", t.type);
            o.put("amount", t.amount);
            o.put("accountId", t.accountId);
            if (t.toAccountId != null) o.put("toAccountId", t.toAccountId);
            o.put("categoryId", t.categoryId == null ? JSONObject.NULL : t.categoryId);
            o.put("note", t.note);
            templates.put(o);
        }
        data.put("templates", templates);

        JSONArray order = new JSONArray();
        for (String s : db.analyticsCardOrder) order.put(s);
        data.put("analyticsCardOrder", order);

        JSONObject root = new JSONObject();
        root.put("format", FORMAT);
        root.put("version", VERSION);
        root.put("createdAt", db.createdAt == null ? "" : db.createdAt);
        root.put("data", data);
        return root;
    }

    private static JSONArray splitsJson(List<SplitMember> splits) throws Exception {
        JSONArray arr = new JSONArray();
        if (splits == null) return arr;
        for (SplitMember s : splits) {
            JSONObject o = new JSONObject();
            o.put("id", s.id);
            o.put("name", s.name);
            o.put("amount", s.amount);
            o.put("isPaid", s.isPaid);
            o.put("paidDate", s.paidDate == null ? JSONObject.NULL : s.paidDate);
            if (s.paidAccountId != null) o.put("paidAccountId", s.paidAccountId);
            arr.put(o);
        }
        return arr;
    }

    // ------------------------------------------------------------------ misc

    private static String str(JSONObject o, String key) {
        String v = o.optString(key, null);
        return v == null ? "" : v;
    }

    private static String strOrNull(JSONObject o, String key) {
        if (!o.has(key) || o.isNull(key)) return null;
        String v = o.optString(key, null);
        return (v == null || v.isEmpty() || "null".equals(v)) ? null : v;
    }
}
