import com.smartwallet.smart_wallet.Account;
import com.smartwallet.smart_wallet.Category;
import com.smartwallet.smart_wallet.SplitMember;
import com.smartwallet.smart_wallet.Transaction;
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

        System.out.println("---");
        System.out.println(checks + " checks, " + failures + " failures");
        System.out.println(failures == 0 ? "ALL TESTS PASSED" : failures + " FAILURES");
        System.exit(failures == 0 ? 0 : 1);
    }
}
