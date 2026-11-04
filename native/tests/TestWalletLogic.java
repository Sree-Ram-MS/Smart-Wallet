import com.smartwallet.smart_wallet.Account;
import com.smartwallet.smart_wallet.Category;
import com.smartwallet.smart_wallet.DebtCredit;
import com.smartwallet.smart_wallet.PlannedPayment;
import com.smartwallet.smart_wallet.SplitMember;
import com.smartwallet.smart_wallet.Transaction;
import com.smartwallet.smart_wallet.WalletDb;
import com.smartwallet.smart_wallet.WalletLogic;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collections;
import java.util.List;

/** Standalone JVM tests for WalletLogic. Run via ./build-apk.sh test, or manually:
 *  javac -d /tmp/tc app/src/main/java/com/smartwallet/smart_wallet/*.java tests/TestWalletLogic.java
 *  (Store.java / MainActivity.java excluded — they need Android; the script handles that.)
 */
public class TestWalletLogic {
    private static int failures = 0;
    private static int checks = 0;

    private static void check(String name, boolean cond) {
        checks++;
        System.out.println((cond ? "PASS " : "FAIL ") + name);
        if (!cond) failures++;
    }

    private static void eqD(String name, double expected, double actual) {
        boolean ok = Math.abs(expected - actual) < 0.001;
        checks++;
        System.out.println((ok ? "PASS " : "FAIL ") + name + " expected=" + expected + " actual=" + actual);
        if (!ok) failures++;
    }

    private static void eqS(String name, String expected, String actual) {
        boolean ok = expected == null ? actual == null : expected.equals(actual);
        checks++;
        System.out.println((ok ? "PASS " : "FAIL ") + name + " expected=" + expected + " actual=" + actual);
        if (!ok) failures++;
    }

    private static Account acc(String id, double balance, boolean enabled) {
        Account a = new Account(id, id, balance);
        a.isEnabledForCalc = enabled;
        return a;
    }

    private static Transaction tx(String id, String type, double amount, String date) {
        Transaction t = new Transaction(id, type, amount, "acc_bank", date);
        return t;
    }

    public static void main(String[] args) {
        // ---- net wallet respects isEnabledForCalc (starter-data numbers) ----
        List<Account> starter = Arrays.asList(
                acc("acc_bank", 54200, true),
                acc("acc_savings", 120000, true),
                acc("acc_cash", 4850, true),
                acc("acc_credit_card", -3200, true));
        eqD("net wallet starter total", 175850, WalletLogic.netWallet(starter));

        List<Account> withDisabled = new ArrayList<>(starter);
        withDisabled.add(acc("acc_old", 999999, false));
        eqD("net wallet ignores disabled account", 175850, WalletLogic.netWallet(withDisabled));

        List<Account> oneDisabled = Arrays.asList(
                acc("a", 1000, true), acc("b", 500, false));
        eqD("net wallet one disabled", 1000, WalletLogic.netWallet(oneDisabled));
        eqD("net wallet empty", 0, WalletLogic.netWallet(Collections.<Account>emptyList()));
        eqD("net wallet null", 0, WalletLogic.netWallet(null));

        // ---- monthly income / expense (starter-data month: Sep 2026) ----
        List<Transaction> txs = Arrays.asList(
                tx("tx_001", "income", 75000, "2026-09-01T09:30:00.000"),
                tx("tx_002", "expense", 22000, "2026-09-01T11:00:00.000"),
                tx("tx_003", "expense", 1850, "2026-09-02T14:15:00.000"),
                tx("tx_004", "expense", 1200, "2026-09-02T18:40:00.000"),
                tx("tx_005", "expense", 2400, "2026-09-03T20:30:00.000"),
                tx("tx_oct", "income", 5000, "2026-10-01T09:00:00.000"),
                tx("tx_aug", "expense", 700, "2026-08-31T09:00:00.000"));
        eqD("Sep income", 75000, WalletLogic.monthlyIncome(txs, 2026, 9));
        eqD("Sep expense", 27450, WalletLogic.monthlyExpense(txs, 2026, 9));
        eqD("Sep net", 47550, WalletLogic.monthlyNet(txs, 2026, 9));
        eqD("Oct income", 5000, WalletLogic.monthlyIncome(txs, 2026, 10));
        eqD("Oct expense none", 0, WalletLogic.monthlyExpense(txs, 2026, 10));
        eqD("wrong year income", 0, WalletLogic.monthlyIncome(txs, 2025, 9));
        eqD("empty month expense", 0, WalletLogic.monthlyExpense(txs, 2026, 11));

        // ---- transfer excluded from income AND expense ----
        List<Transaction> withTransfer = new ArrayList<>(txs);
        withTransfer.add(tx("tx_tr", "transfer", 10000, "2026-09-10T10:00:00.000"));
        eqD("transfer not income", 75000, WalletLogic.monthlyIncome(withTransfer, 2026, 9));
        eqD("transfer not expense", 27450, WalletLogic.monthlyExpense(withTransfer, 2026, 9));
        eqD("transfer not net", 47550, WalletLogic.monthlyNet(withTransfer, 2026, 9));

        // ---- recent transactions: newest first, limit honoured ----
        List<Transaction> recent = WalletLogic.recentTransactions(withTransfer, 3);
        check("recent size limited", recent.size() == 3);
        eqS("recent newest first", "tx_oct", recent.get(0).id);
        eqS("recent second", "tx_tr", recent.get(1).id);
        eqS("recent third", "tx_005", recent.get(2).id);
        check("recent all", WalletLogic.recentTransactions(txs, -1).size() == txs.size());
        check("recent does not mutate caller order", txs.get(0).id.equals("tx_001"));

        // ---- splits ----
        Transaction split = tx("tx_005", "expense", 2400, "2026-09-03T20:30:00.000");
        split.isSplit = true;
        split.splits = Arrays.asList(
                new SplitMember("sp_001", "Me", 800, true),
                new SplitMember("sp_002", "Rahul", 800, true),
                new SplitMember("sp_003", "Karthik", 800, false));
        eqD("split paid", 1600, WalletLogic.splitPaidAmount(split));
        eqD("split unpaid", 800, WalletLogic.splitUnpaidAmount(split));
        eqD("split none paid-safe", 0, WalletLogic.splitPaidAmount(tx("x", "expense", 10, "2026-09-01T00:00:00.000")));

        // ---- lookups ----
        Category food = new Category("cat_food", "Food & Dining", "expense");
        check("category by id", WalletLogic.categoryById(
                Collections.singletonList(food), "cat_food") == food);
        check("category missing null", WalletLogic.categoryById(
                Collections.singletonList(food), "nope") == null);
        check("account by id", WalletLogic.accountById(starter, "acc_cash") == starter.get(2));

        // ---- date parts ----
        check("yearOf", WalletLogic.yearOf("2026-09-01T09:30:00.000") == 2026);
        check("monthOf", WalletLogic.monthOf("2026-09-01T09:30:00.000") == 9);
        check("yearOf bad", WalletLogic.yearOf("nope") == -1);
        check("monthOf null", WalletLogic.monthOf(null) == -1);

        // ---- INR formatting, Indian grouping ----
        eqS("fmt 4850", "₹4,850", WalletLogic.formatINR(4850));
        eqS("fmt starter net", "₹1,75,850", WalletLogic.formatINR(175850));
        eqS("fmt negative", "-₹3,200", WalletLogic.formatINR(-3200));
        eqS("fmt small", "₹999", WalletLogic.formatINR(999));
        eqS("fmt zero", "₹0", WalletLogic.formatINR(0));
        eqS("fmt crore", "₹1,00,00,000", WalletLogic.formatINR(10000000));
        eqS("fmt paise", "₹1,234.50", WalletLogic.formatINR(1234.5));
        eqS("signed income", "+₹75,000", WalletLogic.formatSigned(
                tx("i", "income", 75000, "2026-09-01T00:00:00.000")));
        eqS("signed expense", "-₹2,400", WalletLogic.formatSigned(
                tx("e", "expense", 2400, "2026-09-01T00:00:00.000")));
        eqS("signed transfer neutral", "₹10,000", WalletLogic.formatSigned(
                tx("t", "transfer", 10000, "2026-09-01T00:00:00.000")));

        // ================= Phase 2: apply / reverse balance effects =================
        {
            List<Account> accs = new ArrayList<>(Arrays.asList(
                    acc("acc_bank", 1000, true), acc("acc_cash", 500, true)));
            Transaction inc = tx("i1", "income", 250, "2026-09-05T10:00:00.000");
            WalletLogic.applyTransaction(accs, inc);
            eqD("apply income adds", 1250, accs.get(0).balance);
            WalletLogic.reverseTransaction(accs, inc);
            eqD("reverse income restores", 1000, accs.get(0).balance);

            Transaction exp = tx("e1", "expense", 200, "2026-09-05T10:00:00.000");
            WalletLogic.applyTransaction(accs, exp);
            eqD("apply expense subtracts", 800, accs.get(0).balance);
            WalletLogic.reverseTransaction(accs, exp);
            eqD("reverse expense restores", 1000, accs.get(0).balance);

            Transaction tr = tx("t1", "transfer", 300, "2026-09-05T10:00:00.000");
            tr.toAccountId = "acc_cash";
            WalletLogic.applyTransaction(accs, tr);
            eqD("apply transfer from", 700, accs.get(0).balance);
            eqD("apply transfer to", 800, accs.get(1).balance);
            WalletLogic.reverseTransaction(accs, tr);
            eqD("reverse transfer from", 1000, accs.get(0).balance);
            eqD("reverse transfer to", 500, accs.get(1).balance);
        }

        // ================= Phase 2: add / update (edit) / delete via WalletDb ======
        {
            WalletDb db = new WalletDb();
            db.accounts.add(acc("acc_bank", 1000, true));
            db.accounts.add(acc("acc_cash", 500, true));

            Transaction e1 = tx("e1", "expense", 200, "2026-09-05T10:00:00.000");
            WalletLogic.addTransaction(db, e1);
            eqD("add expense applies", 800, db.accounts.get(0).balance);
            check("add appends tx", db.transactions.size() == 1);

            Transaction e1b = tx("e1", "expense", 350, "2026-09-05T10:00:00.000");
            check("update found", WalletLogic.updateTransaction(db, e1b));
            eqD("edit amount nets (reverse old + apply new)", 650, db.accounts.get(0).balance);

            Transaction e1c = tx("e1", "income", 350, "2026-09-05T10:00:00.000");
            WalletLogic.updateTransaction(db, e1c);
            eqD("edit type expense->income", 1350, db.accounts.get(0).balance);

            Transaction e1d = tx("e1", "transfer", 100, "2026-09-05T10:00:00.000");
            e1d.toAccountId = "acc_cash";
            WalletLogic.updateTransaction(db, e1d);
            // reverse income 350: 1350-350=1000; apply transfer 100: bank 900, cash 600
            eqD("edit to transfer from-side", 900, db.accounts.get(0).balance);
            eqD("edit to transfer to-side", 600, db.accounts.get(1).balance);

            check("delete found", WalletLogic.deleteTransaction(db, "e1"));
            eqD("delete reverses from-side", 1000, db.accounts.get(0).balance);
            eqD("delete reverses to-side", 500, db.accounts.get(1).balance);
            check("delete removes tx", db.transactions.isEmpty());
            check("delete missing id false", !WalletLogic.deleteTransaction(db, "nope"));
            check("update missing id false", !WalletLogic.updateTransaction(
                    db, tx("ghost", "income", 1, "2026-09-05T10:00:00.000")));
        }

        // ================= Phase 2: account delete guards =================
        {
            WalletDb db = new WalletDb();
            db.accounts.add(acc("used_acc", 0, true));
            db.accounts.add(acc("planned_acc", 0, true));
            db.accounts.add(acc("debt_acc", 0, true));
            db.accounts.add(acc("free_acc", 0, true));
            Transaction t = tx("x", "expense", 10, "2026-09-05T10:00:00.000");
            t.accountId = "used_acc";
            db.transactions.add(t);
            PlannedPayment p = new PlannedPayment();
            p.id = "p1"; p.accountId = "planned_acc";
            db.plannedPayments.add(p);
            DebtCredit d = new DebtCredit();
            d.id = "d1"; d.accountId = "debt_acc";
            db.debtCredits.add(d);

            check("account guard: used by tx blocked",
                    WalletLogic.accountDeleteBlockReason(db, "used_acc") != null);
            check("account guard: used by planned blocked",
                    WalletLogic.accountDeleteBlockReason(db, "planned_acc") != null);
            check("account guard: used by debt blocked",
                    WalletLogic.accountDeleteBlockReason(db, "debt_acc") != null);
            check("account guard: unreferenced allowed",
                    WalletLogic.accountDeleteBlockReason(db, "free_acc") == null);

            // transfer to-side also counts as a reference
            Transaction tr = tx("y", "transfer", 10, "2026-09-06T10:00:00.000");
            tr.accountId = "used_acc"; tr.toAccountId = "free_acc";
            db.transactions.add(tr);
            check("account guard: transfer to-side blocked",
                    WalletLogic.accountDeleteBlockReason(db, "free_acc") != null);
        }

        // ================= Phase 2: category delete guards =================
        {
            WalletDb db = new WalletDb();
            Category used = new Category("used_cat", "Food", "expense");
            Category parent = new Category("parent_cat", "Bills", "expense");
            Category child = new Category("child_cat", "WiFi", "expense");
            child.parentId = "parent_cat";
            Category plannedCat = new Category("planned_cat", "Rent", "expense");
            Category free = new Category("free_cat", "Misc", "expense");
            db.categories.addAll(Arrays.asList(used, parent, child, plannedCat, free));
            Transaction t = tx("x", "expense", 10, "2026-09-05T10:00:00.000");
            t.categoryId = "used_cat";
            db.transactions.add(t);
            PlannedPayment p = new PlannedPayment();
            p.id = "p1"; p.accountId = "a"; p.categoryId = "planned_cat";
            db.plannedPayments.add(p);

            check("category guard: used by tx blocked",
                    WalletLogic.categoryDeleteBlockReason(db, "used_cat") != null);
            check("category guard: used by planned blocked",
                    WalletLogic.categoryDeleteBlockReason(db, "planned_cat") != null);
            check("category guard: has children blocked",
                    WalletLogic.categoryDeleteBlockReason(db, "parent_cat") != null);
            check("category guard: unused child allowed",
                    WalletLogic.categoryDeleteBlockReason(db, "child_cat") == null);
            check("category guard: unused top-level allowed",
                    WalletLogic.categoryDeleteBlockReason(db, "free_cat") == null);
        }

        // ================= Phase 2: history filter + search =================
        {
            List<Category> cats = Arrays.asList(
                    new Category("cat_salary", "Salary & Income", "income"),
                    new Category("cat_fuel", "Fuel / Petrol", "expense"));
            List<Account> accs = Arrays.asList(
                    acc("acc_bank", 0, true), acc("acc_cash", 0, true));
            Transaction s = tx("s", "income", 75000, "2026-09-01T09:30:00.000");
            s.categoryId = "cat_salary"; s.note = "September salary";
            Transaction f = tx("f", "expense", 1200, "2026-09-02T18:40:00.000");
            f.accountId = "acc_cash"; f.categoryId = "cat_fuel"; f.note = "Petrol refill";
            Transaction mv = tx("mv", "transfer", 5000, "2026-09-03T10:00:00.000");
            mv.toAccountId = "acc_cash"; mv.note = "Move to cash";
            List<Transaction> all = Arrays.asList(s, f, mv);

            check("filter all", WalletLogic.filterTransactions(
                    all, "all", "", cats, accs).size() == 3);
            check("filter expense only", WalletLogic.filterTransactions(
                    all, "expense", "", cats, accs).size() == 1);
            check("search by note", WalletLogic.filterTransactions(
                    all, "all", "petrol", cats, accs).size() == 1);
            check("search by category name", WalletLogic.filterTransactions(
                    all, "all", "fuel", cats, accs).size() == 1);
            check("search by account name (id-named)", WalletLogic.filterTransactions(
                    all, "all", "acc_cash", cats, accs).size() == 2);
            check("search + wrong type empty", WalletLogic.filterTransactions(
                    all, "income", "petrol", cats, accs).isEmpty());
            List<Transaction> sorted = WalletLogic.filterTransactions(
                    all, "all", "", cats, accs);
            eqS("filter returns newest first", "mv", sorted.get(0).id);
        }

        // ================= Phase 2: picker ordering (parents then subs) ============
        {
            Category pkSalary = new Category("cat_salary", "Salary", "income");
            Category pkFood = new Category("cat_food", "Food", "expense");
            Category pkGroc = new Category("cat_groc", "Groceries", "expense");
            pkGroc.parentId = "cat_food";
            Category pkRent = new Category("cat_rent", "Rent", "expense");
            List<Category> cats = Arrays.asList(pkSalary, pkFood, pkGroc, pkRent);
            List<Category> picker = WalletLogic.categoriesForPicker(cats, "expense");
            check("picker expense size", picker.size() == 3);
            eqS("picker parent first", "cat_food", picker.get(0).id);
            eqS("picker sub after parent", "cat_groc", picker.get(1).id);
            eqS("picker next parent", "cat_rent", picker.get(2).id);
            check("picker income only salary",
                    WalletLogic.categoriesForPicker(cats, "income").size() == 1);
        }

        System.out.println("---");
        System.out.println(checks + " checks, " + failures + " failures");
        System.out.println(failures == 0 ? "ALL TESTS PASSED" : failures + " FAILURES");
        System.exit(failures == 0 ? 0 : 1);
    }
}
