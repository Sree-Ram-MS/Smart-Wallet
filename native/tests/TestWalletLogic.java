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

        // ================= Phase 3: planned advance =================
        eqS("advance daily", "2026-09-16T09:00:00.000",
                WalletLogic.advanceDueDate("2026-09-15T09:00:00.000", "daily"));
        eqS("advance weekly", "2026-09-22T09:00:00.000",
                WalletLogic.advanceDueDate("2026-09-15T09:00:00.000", "weekly"));
        eqS("advance monthly", "2026-10-15T09:00:00.000",
                WalletLogic.advanceDueDate("2026-09-15T09:00:00.000", "monthly"));
        eqS("advance monthly Jan31 clamp leap", "2028-02-29T09:00:00.000",
                WalletLogic.advanceDueDate("2028-01-31T09:00:00.000", "monthly"));
        eqS("advance monthly Jan31 clamp non-leap", "2026-02-28T09:00:00.000",
                WalletLogic.advanceDueDate("2026-01-31T09:00:00.000", "monthly"));
        eqS("advance monthly Feb28 stays 28 (Flutter drift)", "2026-03-28T09:00:00.000",
                WalletLogic.advanceDueDate("2026-02-28T09:00:00.000", "monthly"));
        eqS("advance monthly year rollover", "2027-01-15T09:00:00.000",
                WalletLogic.advanceDueDate("2026-12-15T09:00:00.000", "monthly"));
        eqS("advance yearly", "2027-09-15T09:00:00.000",
                WalletLogic.advanceDueDate("2026-09-15T09:00:00.000", "yearly"));
        eqS("advance yearly Feb29 clamp", "2029-02-28T09:00:00.000",
                WalletLogic.advanceDueDate("2028-02-29T09:00:00.000", "yearly"));
        eqS("advance null period = monthly", "2026-10-15T09:00:00.000",
                WalletLogic.advanceDueDate("2026-09-15T09:00:00.000", null));

        // ================= Phase 3: planned mark-paid / skip state machine ======
        {
            WalletDb db = new WalletDb();
            db.accounts.add(acc("acc_bank", 10000, true));
            PlannedPayment p = new PlannedPayment();
            p.id = "plan1"; p.name = "Netflix"; p.amount = 649;
            p.accountId = "acc_bank"; p.categoryId = "cat_bills";
            p.isRecurring = true; p.period = "monthly";
            p.nextDueDate = "2026-09-15T09:00:00.000";
            p.endType = "never"; p.currentOccurrence = 1;
            db.plannedPayments.add(p);

            Transaction made = WalletLogic.markPlannedPaid(
                    db, p, "2026-09-15T10:30:00.000", "tx_pay1");
            check("markPaid creates tx", made != null);
            eqS("markPaid tx type", "expense", made.type);
            eqS("markPaid tx note", "Planned Payment: Netflix", made.note);
            eqS("markPaid tx date is now", "2026-09-15T10:30:00.000", made.date);
            eqS("markPaid tx category", "cat_bills", made.categoryId);
            eqD("markPaid balance effect", 9351, db.accounts.get(0).balance);
            eqS("markPaid lastPaidDate", "2026-09-15T10:30:00.000", p.lastPaidDate);
            eqS("markPaid advances due", "2026-10-15T09:00:00.000", p.nextDueDate);
            check("markPaid occurrence bumped", p.currentOccurrence == 2);
            check("markPaid not completed (never)", !p.isCompleted);
            check("markPaid tx stored", WalletLogic.transactionById(db, "tx_pay1") == made);
        }
        {
            // occurrences end: total 2 -> completes on the 2nd payment
            WalletDb db = new WalletDb();
            db.accounts.add(acc("acc_bank", 10000, true));
            PlannedPayment p = new PlannedPayment();
            p.id = "plan2"; p.name = "EMI"; p.amount = 500; p.accountId = "acc_bank";
            p.isRecurring = true; p.period = "monthly";
            p.nextDueDate = "2026-09-01T09:00:00.000";
            p.endType = "occurrences"; p.totalOccurrences = 2; p.currentOccurrence = 1;
            db.plannedPayments.add(p);
            WalletLogic.markPlannedPaid(db, p, "2026-09-01T09:00:00.000", "t1");
            check("occ 1 of 2 not completed", !p.isCompleted && p.currentOccurrence == 2);
            WalletLogic.markPlannedPaid(db, p, "2026-10-01T09:00:00.000", "t2");
            check("occ 2 of 2 completed", p.isCompleted && p.currentOccurrence == 3);
            eqD("occ both payments applied", 9000, db.accounts.get(0).balance);

            // until_date end: completing when the NEXT due passes the until date
            PlannedPayment q = new PlannedPayment();
            q.id = "plan3"; q.name = "Course"; q.amount = 100; q.accountId = "acc_bank";
            q.isRecurring = true; q.period = "monthly";
            q.nextDueDate = "2026-09-10T09:00:00.000";
            q.endType = "until_date"; q.untilDate = "2026-10-10T09:00:00.000";
            q.currentOccurrence = 1;
            db.plannedPayments.add(q);
            WalletLogic.markPlannedPaid(db, q, "2026-09-10T09:00:00.000", "t3");
            check("until: next due == until not completed", !q.isCompleted);
            WalletLogic.markPlannedPaid(db, q, "2026-10-10T09:00:00.000", "t4");
            check("until: next due after until completed", q.isCompleted);

            // non-recurring completes on pay; skip advances without a tx
            PlannedPayment r = new PlannedPayment();
            r.id = "plan4"; r.name = "One-off"; r.amount = 250; r.accountId = "acc_bank";
            r.isRecurring = false; r.nextDueDate = "2026-09-05T09:00:00.000";
            r.currentOccurrence = 1;
            db.plannedPayments.add(r);
            int txCount = db.transactions.size();
            WalletLogic.markPlannedPaid(db, r, "2026-09-05T09:00:00.000", "t5");
            check("non-recurring completed on pay", r.isCompleted);
            check("non-recurring pay recorded tx", db.transactions.size() == txCount + 1);

            PlannedPayment s = new PlannedPayment();
            s.id = "plan5"; s.name = "Gym"; s.amount = 1000; s.accountId = "acc_bank";
            s.isRecurring = true; s.period = "monthly";
            s.nextDueDate = "2026-09-01T09:00:00.000"; s.currentOccurrence = 1;
            db.plannedPayments.add(s);
            double balBefore = db.accounts.get(0).balance;
            int txBefore = db.transactions.size();
            WalletLogic.skipPlanned(s);
            eqS("skip advances due", "2026-10-01T09:00:00.000", s.nextDueDate);
            check("skip bumps occurrence", s.currentOccurrence == 2);
            check("skip makes no tx", db.transactions.size() == txBefore);
            eqD("skip no balance effect", balBefore, db.accounts.get(0).balance);
            check("skip leaves lastPaidDate null", s.lastPaidDate == null);

            // split planned payment: created tx carries FRESH unpaid members
            PlannedPayment sp = new PlannedPayment();
            sp.id = "plan6"; sp.name = "Family Plan"; sp.amount = 900; sp.accountId = "acc_bank";
            sp.isRecurring = false; sp.nextDueDate = "2026-09-01T09:00:00.000";
            sp.isSplit = true;
            sp.splits = new ArrayList<>(Arrays.asList(
                    new SplitMember("m1", "Me", 300, true),
                    new SplitMember("m2", "Dad", 600, true)));
            db.plannedPayments.add(sp);
            Transaction stx = WalletLogic.markPlannedPaid(
                    db, sp, "2026-09-01T09:00:00.000", "tsp");
            check("split pay tx is split", stx.isSplit && stx.splits.size() == 2);
            check("split pay members fresh unpaid",
                    !stx.splits.get(0).isPaid && !stx.splits.get(1).isPaid
                            && stx.splits.get(0).paidAccountId == null);
            check("split pay member ids fresh", !"m1".equals(stx.splits.get(0).id));
            eqD("split pay member amounts copied", 600, stx.splits.get(1).amount);
        }

        // ================= Phase 3: split member paid/unpaid balance effects ====
        {
            WalletDb db = new WalletDb();
            db.accounts.add(acc("acc_card", 0, true));
            db.accounts.add(acc("acc_bank", 1000, true));
            Transaction t = tx("sp1", "expense", 2400, "2026-09-03T20:30:00.000");
            t.accountId = "acc_card"; t.isSplit = true;
            t.splits = new ArrayList<>(Arrays.asList(
                    new SplitMember("mm", "Me", 800, true),
                    new SplitMember("mr", "Rahul", 800, false),
                    new SplitMember("mk", "Karthik", 800, false)));
            WalletLogic.addTransaction(db, t);
            eqD("split expense applied in full", -2400, db.accounts.get(0).balance);
            eqD("no recovery yet (Me has no paidAccount)", 1000, db.accounts.get(1).balance);

            check("mark member paid ok", WalletLogic.markSplitMemberPaid(
                    db, t, "mr", "2026-09-04T10:00:00.000", "acc_bank"));
            eqD("mark paid credits recovery account", 1800, db.accounts.get(1).balance);
            check("mark paid flags member", t.splits.get(1).isPaid
                    && "acc_bank".equals(t.splits.get(1).paidAccountId)
                    && "2026-09-04T10:00:00.000".equals(t.splits.get(1).paidDate));
            check("double mark rejected", !WalletLogic.markSplitMemberPaid(
                    db, t, "mr", "2026-09-04T10:00:00.000", "acc_bank"));
            eqD("double mark no double credit", 1800, db.accounts.get(1).balance);

            check("unmark ok", WalletLogic.unmarkSplitMemberPaid(db, t, "mr"));
            eqD("unmark debits recovery back", 1000, db.accounts.get(1).balance);
            check("unmark clears member", !t.splits.get(1).isPaid
                    && t.splits.get(1).paidAccountId == null
                    && t.splits.get(1).paidDate == null);

            // unmarking a member paid WITHOUT a recorded account moves nothing
            check("unmark Me ok", WalletLogic.unmarkSplitMemberPaid(db, t, "mm"));
            eqD("unmark Me (no account) debits nothing", -2400, db.accounts.get(0).balance);
            eqD("unmark Me bank untouched", 1000, db.accounts.get(1).balance);

            // deleting the whole split tx reverses expense AND live recoveries
            WalletLogic.markSplitMemberPaid(db, t, "mk", "2026-09-05T10:00:00.000", "acc_bank");
            eqD("second recovery credited", 1800, db.accounts.get(1).balance);
            WalletLogic.deleteTransaction(db, "sp1");
            eqD("delete split tx restores payer", 0, db.accounts.get(0).balance);
            eqD("delete split tx reverses recovery", 1000, db.accounts.get(1).balance);
        }

        // ================= Phase 3: split validation + equal split ==============
        {
            List<SplitMember> ok = Arrays.asList(
                    new SplitMember("1", "Me", 800, true),
                    new SplitMember("2", "Rahul", 800, false),
                    new SplitMember("3", "Karthik", 800.004, false));
            check("split sum within a paisa valid",
                    WalletLogic.splitValidationError(ok, 2400) == null);
            List<SplitMember> short_ = Arrays.asList(
                    new SplitMember("1", "Me", 800, true),
                    new SplitMember("2", "Rahul", 800, false));
            check("split sum short rejected",
                    WalletLogic.splitValidationError(short_, 2400) != null);
            List<SplitMember> noName = Arrays.asList(
                    new SplitMember("1", "  ", 2400, false));
            check("split blank name rejected",
                    WalletLogic.splitValidationError(noName, 2400) != null);
            List<SplitMember> zeroAmt = Arrays.asList(
                    new SplitMember("1", "Me", 2400, false),
                    new SplitMember("2", "Free", 0, false));
            check("split zero share rejected",
                    WalletLogic.splitValidationError(zeroAmt, 2400) != null);
            check("split empty rejected",
                    WalletLogic.splitValidationError(new ArrayList<SplitMember>(), 2400) != null);

            List<Double> eq3 = WalletLogic.equalSplit(2400, 3);
            eqD("equal split 2400/3 each", 800, eq3.get(0));
            eqD("equal split 2400/3 sums", 2400, eq3.get(0) + eq3.get(1) + eq3.get(2));
            List<Double> eqOdd = WalletLogic.equalSplit(100, 3);
            eqD("equal split 100/3 first", 33.33, eqOdd.get(0));
            eqD("equal split 100/3 last takes remainder", 33.34, eqOdd.get(2));
            eqD("equal split 100/3 sums exactly", 100,
                    eqOdd.get(0) + eqOdd.get(1) + eqOdd.get(2));
            check("equal split count 0 empty", WalletLogic.equalSplit(100, 0).isEmpty());
        }

        // ================= Phase 3: debts lifecycle =============================
        {
            WalletDb db = new WalletDb();
            db.accounts.add(acc("acc_bank", 10000, true));
            Category debtCat = new Category("cat_debt", "Loans Given", "expense");
            db.categories.add(debtCat);

            // create LENT with affectsAccount -> expense tx linked
            DebtCredit lent = new DebtCredit();
            lent.id = "d1"; lent.direction = "lent"; lent.personName = "Alex";
            lent.amount = 5000; lent.accountId = "acc_bank";
            lent.categoryId = "cat_debt"; lent.startDate = "2026-09-02T16:00:00.000";
            lent.notes = "Car repair"; lent.affectsAccount = true; lent.status = "active";
            WalletLogic.createDebt(db, lent, "tx_d1");
            eqD("lent create: money out", 5000, db.accounts.get(0).balance);
            eqS("lent linked tx id", "tx_d1", lent.transactionId);
            Transaction ltx = WalletLogic.transactionById(db, "tx_d1");
            eqS("lent tx type", "expense", ltx.type);
            eqS("lent tx note", "Lent to Alex (Car repair)", ltx.note);
            eqS("lent tx category kept (type matches)", "cat_debt", ltx.categoryId);
            eqS("lent tx date is start date", "2026-09-02T16:00:00.000", ltx.date);

            // settle LENT -> income back
            check("settle lent ok", WalletLogic.settleDebt(
                    db, lent, "2026-09-20T10:00:00.000", "tx_s1"));
            eqD("lent settle: money back", 10000, db.accounts.get(0).balance);
            eqS("lent status closed", "closed", lent.status);
            Transaction stx = WalletLogic.transactionById(db, "tx_s1");
            eqS("settle tx type income", "income", stx.type);
            eqS("settle tx note", "Debt recovered from Alex (Car repair)", stx.note);
            check("settle tx category dropped (type mismatch)",
                    stx.categoryId == null);
            check("double settle rejected", !WalletLogic.settleDebt(
                    db, lent, "2026-09-21T10:00:00.000", "tx_sX"));

            // reopen LENT -> settlement reversed
            check("reopen ok", WalletLogic.reopenDebt(db, lent));
            eqD("reopen reverses settlement", 5000, db.accounts.get(0).balance);
            eqS("reopen status active", "active", lent.status);
            check("settlement tx gone", WalletLogic.transactionById(db, "tx_s1") == null);
            check("initial tx still there", WalletLogic.transactionById(db, "tx_d1") != null);

            // delete active LENT -> initial reversed, record gone
            check("delete lent ok", WalletLogic.deleteDebt(db, lent));
            eqD("delete lent restores balance", 10000, db.accounts.get(0).balance);
            check("delete lent removes record", db.debtCredits.isEmpty());
            check("delete lent removes tx", db.transactions.isEmpty());

            // BORROWED full cycle
            DebtCredit bor = new DebtCredit();
            bor.id = "d2"; bor.direction = "borrowed"; bor.personName = "Uncle David";
            bor.amount = 10000; bor.accountId = "acc_bank";
            bor.startDate = "2026-09-01T12:00:00.000"; bor.affectsAccount = true;
            bor.status = "active";
            WalletLogic.createDebt(db, bor, "tx_d2");
            eqD("borrowed create: money in", 20000, db.accounts.get(0).balance);
            WalletLogic.settleDebt(db, bor, "2026-10-01T10:00:00.000", "tx_s2");
            eqD("borrowed settle: money out", 10000, db.accounts.get(0).balance);
            // delete while CLOSED removes both txs, balance unchanged net
            WalletLogic.deleteDebt(db, bor);
            eqD("delete closed borrowed nets to start", 10000, db.accounts.get(0).balance);
            check("delete closed borrowed clears txs", db.transactions.isEmpty());

            // affectsAccount = false: nothing moves, ever
            DebtCredit hist = new DebtCredit();
            hist.id = "d3"; hist.direction = "lent"; hist.personName = "Old Pal";
            hist.amount = 700; hist.accountId = "acc_bank";
            hist.startDate = "2026-08-01T10:00:00.000"; hist.affectsAccount = false;
            hist.status = "active";
            WalletLogic.createDebt(db, hist, "tx_d3");
            eqD("historical create moves nothing", 10000, db.accounts.get(0).balance);
            check("historical has no tx", db.transactions.isEmpty()
                    && hist.transactionId == null);
            WalletLogic.settleDebt(db, hist, "2026-09-01T10:00:00.000", "tx_s3");
            eqD("historical settle moves nothing", 10000, db.accounts.get(0).balance);
            check("historical settle makes no tx", db.transactions.isEmpty());
            WalletLogic.deleteDebt(db, hist);
            eqD("historical delete moves nothing", 10000, db.accounts.get(0).balance);

            // seed-style record: affectsAccount, active, NO linked tx (direct effect)
            DebtCredit seed = new DebtCredit();
            seed.id = "d4"; seed.direction = "lent"; seed.personName = "Seed";
            seed.amount = 5000; seed.accountId = "acc_bank";
            seed.startDate = "2026-09-02T16:00:00.000"; seed.affectsAccount = true;
            seed.status = "active"; // balance 10000 already reflects the -5000 in-file
            db.debtCredits.add(seed);
            WalletLogic.deleteDebt(db, seed);
            eqD("seed delete reverses direct effect", 15000, db.accounts.get(0).balance);

            // edit rebuild: change amount 5000 -> 6000 on a live lent debt
            DebtCredit ed = new DebtCredit();
            ed.id = "d5"; ed.direction = "lent"; ed.personName = "Maria";
            ed.amount = 5000; ed.accountId = "acc_bank";
            ed.startDate = "2026-09-03T10:00:00.000"; ed.affectsAccount = true;
            ed.status = "active";
            db.accounts.get(0).balance = 15000;
            WalletLogic.createDebt(db, ed, "tx_d5");
            eqD("edit setup balance", 10000, db.accounts.get(0).balance);
            DebtCredit edNew = new DebtCredit();
            edNew.id = "d5"; edNew.direction = "lent"; edNew.personName = "Maria";
            edNew.amount = 6000; edNew.accountId = "acc_bank";
            edNew.startDate = "2026-09-03T10:00:00.000"; edNew.affectsAccount = true;
            edNew.status = "active";
            check("update debt ok", WalletLogic.updateDebt(
                    db, edNew, "tx_d5b", "tx_s5b", "2026-09-10T10:00:00.000"));
            eqD("edit amount rebuild nets -6000", 9000, db.accounts.get(0).balance);
            eqS("edit relinks tx", "tx_d5b", edNew.transactionId);
            check("edit removed old tx", WalletLogic.transactionById(db, "tx_d5") == null);
            // toggling affectsAccount OFF in an edit removes the effect entirely
            DebtCredit edOff = new DebtCredit();
            edOff.id = "d5"; edOff.direction = "lent"; edOff.personName = "Maria";
            edOff.amount = 6000; edOff.accountId = "acc_bank";
            edOff.startDate = "2026-09-03T10:00:00.000"; edOff.affectsAccount = false;
            edOff.status = "active";
            WalletLogic.updateDebt(db, edOff, "tx_d5c", "tx_s5c", "2026-09-10T10:00:00.000");
            eqD("edit affects OFF restores balance", 15000, db.accounts.get(0).balance);
            check("edit affects OFF leaves no tx", db.transactions.isEmpty());

            eqD("total active lent (edited record still active)", 6000,
                    WalletLogic.totalActiveDebt(db.debtCredits, "lent"));
            DebtCredit act = new DebtCredit();
            act.id = "d6"; act.direction = "borrowed"; act.personName = "Bank";
            act.amount = 2500; act.accountId = "acc_bank"; act.status = "active";
            db.debtCredits.add(act);
            eqD("total active borrowed", 2500,
                    WalletLogic.totalActiveDebt(db.debtCredits, "borrowed"));
        }

        // ================= Phase 3: templates ===================================
        {
            com.smartwallet.smart_wallet.Template tpl =
                    new com.smartwallet.smart_wallet.Template();
            tpl.id = "tm1"; tpl.name = "Coffee"; tpl.type = "expense";
            tpl.amount = 40; tpl.accountId = "acc_cash";
            tpl.categoryId = "cat_food"; tpl.note = "Daily coffee";
            WalletDb db = new WalletDb();
            db.templates.add(tpl);
            check("template by id", WalletLogic.templateById(db, "tm1") == tpl);
            Transaction draft = WalletLogic.draftFromTemplate(
                    tpl, "tx_new", "2026-11-04T08:00:00.000");
            eqS("draft type", "expense", draft.type);
            eqD("draft amount", 40, draft.amount);
            eqS("draft account", "acc_cash", draft.accountId);
            eqS("draft category", "cat_food", draft.categoryId);
            eqS("draft note", "Daily coffee", draft.note);
            eqS("draft date is use-date", "2026-11-04T08:00:00.000", draft.date);
            check("draft not split", !draft.isSplit);
            com.smartwallet.smart_wallet.Template tr =
                    new com.smartwallet.smart_wallet.Template();
            tr.type = "transfer"; tr.amount = 1000; tr.accountId = "a1";
            tr.toAccountId = "a2"; tr.note = "Move";
            Transaction td = WalletLogic.draftFromTemplate(tr, "tx2", "2026-11-04T08:00:00.000");
            eqS("draft transfer keeps to-account", "a2", td.toAccountId);
        }

        // ================= Phase 3: reminder maths ==============================
        {
            PlannedPayment rp = new PlannedPayment();
            rp.nextDueDate = "2026-09-15T09:00:00.000";
            eqS("planned reminder 2 days before at 9am", "2026-09-13T09:00",
                    WalletLogic.plannedReminderTime(rp, 2).toString());
            eqS("planned reminder 0 days = due day 9am", "2026-09-15T09:00",
                    WalletLogic.plannedReminderTime(rp, 0).toString());
            java.time.LocalDateTime morning = java.time.LocalDateTime.of(2026, 11, 4, 8, 0);
            eqS("daily reminder later today", "2026-11-04T20:00",
                    WalletLogic.nextDailyReminder(morning, 20, 0).toString());
            java.time.LocalDateTime night = java.time.LocalDateTime.of(2026, 11, 4, 21, 30);
            eqS("daily reminder passed -> tomorrow", "2026-11-05T20:00",
                    WalletLogic.nextDailyReminder(night, 20, 0).toString());
            check("planned sorted: upcoming by due, completed last",
                    WalletLogic.plannedSorted(new WalletDb()).isEmpty());
        }

        System.out.println("---");
        System.out.println(checks + " checks, " + failures + " failures");
        System.out.println(failures == 0 ? "ALL TESTS PASSED" : failures + " FAILURES");
        System.exit(failures == 0 ? 0 : 1);
    }
}
