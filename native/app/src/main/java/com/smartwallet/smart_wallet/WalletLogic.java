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

    // ------------------------------------------------- Phase 2: balance FX

    /**
     * Apply a transaction's balance effect to its account(s):
     * income +amount, expense -amount, transfer -from / +to.
     * Account.balance is the stored field (as in Flutter); everything
     * else (net wallet, cards) reads it, so this is the ONLY place
     * balances change when transactions are added/edited/deleted.
     */
    public static void applyTransaction(List<Account> accounts, Transaction t) {
        move(accounts, t, +1);
    }

    /** Undo a transaction's balance effect (exact inverse of apply). */
    public static void reverseTransaction(List<Account> accounts, Transaction t) {
        move(accounts, t, -1);
    }

    private static void move(List<Account> accounts, Transaction t, int sign) {
        if (accounts == null || t == null || t.type == null) return;
        if ("income".equals(t.type)) {
            Account a = accountById(accounts, t.accountId);
            if (a != null) a.balance += sign * t.amount;
        } else if ("expense".equals(t.type)) {
            Account a = accountById(accounts, t.accountId);
            if (a != null) a.balance -= sign * t.amount;
        } else if ("transfer".equals(t.type)) {
            Account from = accountById(accounts, t.accountId);
            Account to = accountById(accounts, t.toAccountId);
            if (from != null) from.balance -= sign * t.amount;
            if (to != null && to != from) to.balance += sign * t.amount;
        }
    }

    /** Add a transaction and apply its balance effect. */
    public static void addTransaction(WalletDb db, Transaction t) {
        if (db == null || t == null) return;
        applyTransaction(db.accounts, t);
        db.transactions.add(t);
    }

    /** Delete by id: reverse the balance effect, then remove. */
    public static boolean deleteTransaction(WalletDb db, String txId) {
        if (db == null || txId == null) return false;
        for (int i = 0; i < db.transactions.size(); i++) {
            Transaction t = db.transactions.get(i);
            if (t != null && txId.equals(t.id)) {
                reverseTransaction(db.accounts, t);
                db.transactions.remove(i);
                return true;
            }
        }
        return false;
    }

    /**
     * Edit = reverse the OLD transaction, swap it in the list, apply the
     * NEW one. The new transaction keeps the old one's id. Splits are the
     * caller's problem: the UI blocks editing split transactions, and
     * this method copies nothing — it uses exactly what it is given.
     */
    public static boolean updateTransaction(WalletDb db, Transaction updated) {
        if (db == null || updated == null || updated.id == null) return false;
        for (int i = 0; i < db.transactions.size(); i++) {
            Transaction old = db.transactions.get(i);
            if (old != null && updated.id.equals(old.id)) {
                reverseTransaction(db.accounts, old);
                db.transactions.set(i, updated);
                applyTransaction(db.accounts, updated);
                return true;
            }
        }
        return false;
    }

    public static Transaction transactionById(WalletDb db, String txId) {
        if (db == null || txId == null) return null;
        for (Transaction t : db.transactions) {
            if (t != null && txId.equals(t.id)) return t;
        }
        return null;
    }

    // ------------------------------------------------- Phase 2: filtering

    /**
     * History filtering: type filter ("all" | "income" | "expense" |
     * "transfer") plus a case-insensitive text search over note,
     * category name and account name(s). Returns newest first.
     */
    public static List<Transaction> filterTransactions(List<Transaction> txs,
            String typeFilter, String query,
            List<Category> categories, List<Account> accounts) {
        String q = query == null ? "" : query.trim().toLowerCase();
        List<Transaction> matched = new ArrayList<>();
        if (txs != null) {
            for (Transaction t : txs) {
                if (t == null) continue;
                if (typeFilter != null && !"all".equals(typeFilter)
                        && !typeFilter.equals(t.type)) continue;
                if (!q.isEmpty()) {
                    boolean hit = t.note != null && t.note.toLowerCase().contains(q);
                    Category c = categoryById(categories, t.categoryId);
                    if (!hit && c != null && c.name != null) {
                        hit = c.name.toLowerCase().contains(q);
                    }
                    Account a = accountById(accounts, t.accountId);
                    if (!hit && a != null && a.name != null) {
                        hit = a.name.toLowerCase().contains(q);
                    }
                    Account to = accountById(accounts, t.toAccountId);
                    if (!hit && to != null && to.name != null) {
                        hit = to.name.toLowerCase().contains(q);
                    }
                    if (!hit) continue;
                }
                matched.add(t);
            }
        }
        return recentTransactions(matched, -1);
    }

    // ------------------------------------------------ Phase 2: delete guards

    /**
     * Why an account cannot be deleted, or null when deletion is safe.
     * Any reference from a transaction (either side of a transfer), a
     * planned payment, a debt/credit or a template blocks deletion —
     * deleting would leave a dangling reference.
     */
    public static String accountDeleteBlockReason(WalletDb db, String accountId) {
        if (db == null || accountId == null) return "Unknown account.";
        for (Transaction t : db.transactions) {
            if (t != null && (accountId.equals(t.accountId)
                    || accountId.equals(t.toAccountId))) {
                return "This account is used by transactions. "
                        + "Delete or move those transactions first.";
            }
        }
        for (PlannedPayment p : db.plannedPayments) {
            if (p != null && accountId.equals(p.accountId)) {
                return "This account is used by a planned payment. "
                        + "Delete that planned payment first.";
            }
        }
        for (DebtCredit d : db.debtCredits) {
            if (d != null && accountId.equals(d.accountId)) {
                return "This account is used by a debt / credit record. "
                        + "Delete that record first.";
            }
        }
        for (Template t : db.templates) {
            if (t != null && (accountId.equals(t.accountId)
                    || accountId.equals(t.toAccountId))) {
                return "This account is used by a template. "
                        + "Delete that template first.";
            }
        }
        return null;
    }

    /**
     * Why a category cannot be deleted, or null when deletion is safe:
     * used by any transaction/planned payment/debt/template, or it has
     * sub-categories of its own.
     */
    public static String categoryDeleteBlockReason(WalletDb db, String categoryId) {
        if (db == null || categoryId == null) return "Unknown category.";
        for (Category c : db.categories) {
            if (c != null && categoryId.equals(c.parentId)) {
                return "This category has sub-categories. "
                        + "Delete or re-parent them first.";
            }
        }
        for (Transaction t : db.transactions) {
            if (t != null && categoryId.equals(t.categoryId)) {
                return "This category is used by transactions. "
                        + "Re-categorise those transactions first.";
            }
        }
        for (PlannedPayment p : db.plannedPayments) {
            if (p != null && categoryId.equals(p.categoryId)) {
                return "This category is used by a planned payment. "
                        + "Change that planned payment first.";
            }
        }
        for (DebtCredit d : db.debtCredits) {
            if (d != null && categoryId.equals(d.categoryId)) {
                return "This category is used by a debt / credit record. "
                        + "Change that record first.";
            }
        }
        for (Template t : db.templates) {
            if (t != null && categoryId.equals(t.categoryId)) {
                return "This category is used by a template. "
                        + "Change that template first.";
            }
        }
        return null;
    }

    /** Categories of one type ordered for a picker: each top-level
     *  category followed by its sub-categories. */
    public static List<Category> categoriesForPicker(List<Category> categories, String type) {
        List<Category> out = new ArrayList<>();
        if (categories == null || type == null) return out;
        for (Category c : categories) {
            if (c != null && c.parentId == null && type.equals(c.type)) {
                out.add(c);
                for (Category sub : categories) {
                    if (sub != null && c.id != null && c.id.equals(sub.parentId)) {
                        out.add(sub);
                    }
                }
            }
        }
        return out;
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
