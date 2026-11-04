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
        // Phase 3 (mirrors Flutter _applyTransactionToBalances): split
        // recoveries already collected move with the transaction too —
        // applying credits each paid member's recovery account, reversing
        // debits them back. Members paid without a recorded account
        // (paidAccountId == null, e.g. the seeded "Me") never moved money
        // and are skipped, exactly as in Flutter.
        if (t.isSplit && t.splits != null) {
            for (SplitMember s : t.splits) {
                if (s != null && s.isPaid && s.paidAccountId != null) {
                    Account rec = accountById(accounts, s.paidAccountId);
                    if (rec != null) rec.balance += sign * s.amount;
                }
            }
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
     * NEW one. The new transaction keeps the old one's id. Since Phase 3
     * the editor supplies the full split member list (paid state
     * preserved), so reversing the old record — recoveries included —
     * and applying the new one stays consistent.
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

    // ================================================ Phase 3: planned payments

    public static PlannedPayment plannedById(WalletDb db, String id) {
        if (db == null || id == null) return null;
        for (PlannedPayment p : db.plannedPayments) {
            if (p != null && id.equals(p.id)) return p;
        }
        return null;
    }

    /** Upcoming first (by next due date), completed ones at the end. */
    public static List<PlannedPayment> plannedSorted(WalletDb db) {
        List<PlannedPayment> upcoming = new ArrayList<>();
        List<PlannedPayment> done = new ArrayList<>();
        if (db != null) {
            for (PlannedPayment p : db.plannedPayments) if (p != null) {
                (p.isCompleted ? done : upcoming).add(p);
            }
        }
        Comparator<PlannedPayment> byDue = new Comparator<PlannedPayment>() {
            @Override public int compare(PlannedPayment a, PlannedPayment b) {
                String da = a.nextDueDate == null ? "" : a.nextDueDate;
                String db2 = b.nextDueDate == null ? "" : b.nextDueDate;
                return da.compareTo(db2);
            }
        };
        Collections.sort(upcoming, byDue);
        Collections.sort(done, byDue);
        upcoming.addAll(done);
        return upcoming;
    }

    /** Overdue = due date is in the past and not completed. Compares the
     *  date part only, so a payment due today is never "overdue". */
    public static boolean isOverdue(PlannedPayment p, String todayIso) {
        if (p == null || p.isCompleted || p.nextDueDate == null || todayIso == null) {
            return false;
        }
        return p.nextDueDate.substring(0, Math.min(10, p.nextDueDate.length()))
                .compareTo(todayIso.substring(0, Math.min(10, todayIso.length()))) < 0;
    }

    /**
     * Advance an ISO datetime by one recurrence period, mirroring the
     * Flutter markPaid switch: daily +1d, weekly +7d, yearly +1y,
     * monthly (and anything else) +1 month with the day clamped to the
     * target month's length (Jan 31 -> Feb 28/29, then Feb 28 -> Mar 28).
     */
    public static String advanceDueDate(String iso, String period) {
        java.time.LocalDateTime dt = parseIso(iso);
        if (dt == null) return iso;
        java.time.LocalDateTime next;
        if ("daily".equals(period)) {
            next = dt.plusDays(1);
        } else if ("weekly".equals(period)) {
            next = dt.plusDays(7);
        } else if ("yearly".equals(period)) {
            next = dt.plusYears(1); // java.time clamps Feb 29 -> Feb 28
        } else { // "monthly" or null/unknown — Flutter's default branch
            java.time.YearMonth ym = java.time.YearMonth.from(dt).plusMonths(1);
            int day = Math.min(dt.getDayOfMonth(), ym.lengthOfMonth());
            next = java.time.LocalDateTime.of(ym.getYear(), ym.getMonthValue(), day,
                    dt.getHour(), dt.getMinute(), dt.getSecond());
        }
        return formatIso(next);
    }

    /**
     * Shared post-payment / post-skip state machine (Flutter markPaid,
     * minus the transaction): non-recurring completes; recurring
     * advances the due date, bumps the occurrence counter and completes
     * when the end condition is met (occurrences: counter passes the
     * total; until_date: new due date is after the until date).
     */
    public static void advancePlanned(PlannedPayment p) {
        if (p == null || p.isCompleted) return;
        if (!p.isRecurring) {
            p.isCompleted = true;
            return;
        }
        p.nextDueDate = advanceDueDate(p.nextDueDate, p.period);
        p.currentOccurrence += 1;
        if ("occurrences".equals(p.endType) && p.totalOccurrences != null) {
            if (p.currentOccurrence > p.totalOccurrences) p.isCompleted = true;
        } else if ("until_date".equals(p.endType) && p.untilDate != null) {
            if (p.nextDueDate != null && p.nextDueDate.compareTo(p.untilDate) > 0) {
                p.isCompleted = true;
            }
        }
    }

    /**
     * Mark a planned payment paid, Flutter-style: builds the expense
     * transaction (dated now, note "Planned Payment: {name}", splits
     * copied with FRESH unpaid members), applies its balance effect via
     * addTransaction, stamps lastPaidDate, then advances/completes.
     * Returns the created transaction.
     */
    public static Transaction markPlannedPaid(WalletDb db, PlannedPayment p,
                                              String nowIso, String txId) {
        if (db == null || p == null) return null;
        Transaction t = new Transaction();
        t.id = txId;
        t.type = "expense";
        t.amount = p.amount;
        t.accountId = p.accountId;
        t.categoryId = p.categoryId;
        t.date = nowIso;
        t.note = "Planned Payment: " + (p.name == null ? "" : p.name);
        t.isSplit = p.isSplit && p.splits != null && !p.splits.isEmpty();
        if (t.isSplit) {
            int i = 0;
            for (SplitMember s : p.splits) {
                SplitMember copy = new SplitMember();
                copy.id = txId + "_m" + (++i);
                copy.name = s.name;
                copy.amount = s.amount;
                copy.isPaid = false;
                t.splits.add(copy);
            }
        }
        addTransaction(db, t);
        p.lastPaidDate = nowIso;
        advancePlanned(p);
        return t;
    }

    /** Skip one occurrence: advance/complete exactly like paying, but no
     *  transaction and no lastPaidDate. (Flutter has no Skip — small
     *  native extra, kept on the same state machine for consistency.) */
    public static void skipPlanned(PlannedPayment p) {
        advancePlanned(p);
    }

    // ==================================================== Phase 3: split members

    /** Split transactions (flag set and members present), newest first. */
    public static List<Transaction> splitTransactions(WalletDb db) {
        List<Transaction> out = new ArrayList<>();
        if (db != null) {
            for (Transaction t : db.transactions) {
                if (t != null && t.isSplit && t.splits != null && !t.splits.isEmpty()) {
                    out.add(t);
                }
            }
        }
        return recentTransactions(out, -1);
    }

    public static SplitMember splitMemberById(Transaction t, String memberId) {
        if (t == null || t.splits == null || memberId == null) return null;
        for (SplitMember s : t.splits) if (s != null && memberId.equals(s.id)) return s;
        return null;
    }

    /**
     * Mark a member paid (Flutter markSplitMemberPaid): flags the
     * member, stamps the date + the account the money was received
     * into, and CREDITS that account by the member's share.
     */
    public static boolean markSplitMemberPaid(WalletDb db, Transaction t,
                                              String memberId, String paidDateIso,
                                              String targetAccountId) {
        SplitMember s = splitMemberById(t, memberId);
        if (db == null || s == null || s.isPaid) return false;
        s.isPaid = true;
        s.paidDate = paidDateIso;
        s.paidAccountId = targetAccountId;
        Account acc = accountById(db.accounts, targetAccountId);
        if (acc != null) acc.balance += s.amount;
        return true;
    }

    /**
     * Unmark a member (Flutter unmarkSplitMemberPaid): debits the
     * recovery back out and clears the member. Deliberate consistency
     * deviation: Flutter debits paidAccountId OR, when it is null,
     * falls back to debiting the transaction's account — but a member
     * paid with no recorded account never credited anything, so
     * debiting on unmark would invent a loss. Native debits only a
     * recorded recovery account.
     */
    public static boolean unmarkSplitMemberPaid(WalletDb db, Transaction t, String memberId) {
        SplitMember s = splitMemberById(t, memberId);
        if (db == null || s == null || !s.isPaid) return false;
        if (s.paidAccountId != null) {
            Account acc = accountById(db.accounts, s.paidAccountId);
            if (acc != null) acc.balance -= s.amount;
        }
        s.isPaid = false;
        s.paidDate = null;
        s.paidAccountId = null;
        return true;
    }

    /** Sum of member shares. */
    public static double splitSum(List<SplitMember> members) {
        double sum = 0;
        if (members != null) for (SplitMember s : members) if (s != null) sum += s.amount;
        return sum;
    }

    /**
     * Why a split member list is not saveable for a transaction of
     * totalAmount, or null when valid: at least one member, every name
     * non-blank, every share > 0, and the shares summing to the total
     * within 0.01. (Flutter never validates the sum — its model leaves
     * your own share as the unstated remainder. Native validates
     * because its member list INCLUDES "Me", so the shares must add up.)
     */
    public static String splitValidationError(List<SplitMember> members, double totalAmount) {
        if (members == null || members.isEmpty()) return "Add at least one person to the split.";
        for (SplitMember s : members) {
            if (s == null || s.name == null || s.name.trim().isEmpty()) {
                return "Every person in the split needs a name.";
            }
            if (s.amount <= 0) return "Every share must be more than zero.";
        }
        if (Math.abs(splitSum(members) - totalAmount) > 0.01) {
            return "Shares add up to " + formatINR(splitSum(members))
                    + " but the amount is " + formatINR(totalAmount)
                    + ". Adjust the shares or tap Split Equally.";
        }
        return null;
    }

    /**
     * Equal shares of a total across count people, to the paisa: each
     * share is the total/count rounded to 2dp, and the LAST share takes
     * the remainder so the shares always sum exactly to the total.
     * (Flutter's equal split computes total/(friends + 1) per friend —
     * "Me" counts as one person. Native's member list includes Me, so
     * count = members.size().)
     */
    public static List<Double> equalSplit(double total, int count) {
        List<Double> out = new ArrayList<>();
        if (count <= 0) return out;
        double each = Math.round((total / count) * 100.0) / 100.0;
        double assigned = 0;
        for (int i = 0; i < count - 1; i++) {
            out.add(each);
            assigned += each;
        }
        out.add(Math.round((total - assigned) * 100.0) / 100.0);
        return out;
    }

    // ==================================================== Phase 3: debts & credits

    public static DebtCredit debtById(WalletDb db, String id) {
        if (db == null || id == null) return null;
        for (DebtCredit d : db.debtCredits) if (d != null && id.equals(d.id)) return d;
        return null;
    }

    private static String debtNoteSuffix(DebtCredit d) {
        return d.notes != null && !d.notes.trim().isEmpty()
                ? " (" + d.notes.trim() + ")" : "";
    }

    /** Note of the initial transaction Flutter creates for a debt/credit. */
    public static String debtInitialNote(DebtCredit d) {
        return ("lent".equals(d.direction)
                ? "Lent to " + d.personName
                : "Borrowed from " + d.personName) + debtNoteSuffix(d);
    }

    /** Note of the settlement transaction Flutter creates on close. */
    public static String debtSettlementNote(DebtCredit d) {
        return ("lent".equals(d.direction)
                ? "Debt recovered from " + d.personName
                : "Debt repaid to " + d.personName) + debtNoteSuffix(d);
    }

    private static String debtSettlementPrefix(DebtCredit d) {
        return "lent".equals(d.direction)
                ? "Debt recovered from " + d.personName
                : "Debt repaid to " + d.personName;
    }

    /**
     * The category a linked transaction may carry: Flutter only keeps
     * the debt's category when its type matches the transaction's
     * expected type (lent -> expense, borrowed -> income for the
     * initial transaction; the reverse for settlement), else null.
     */
    public static String debtCategoryFor(WalletDb db, DebtCredit d, String txType) {
        if (d == null || d.categoryId == null) return null;
        Category c = categoryById(db.categories, d.categoryId);
        return c != null && txType.equals(c.type) ? d.categoryId : null;
    }

    private static Transaction buildDebtTx(WalletDb db, DebtCredit d, String txId,
                                           String type, String note, String dateIso) {
        Transaction t = new Transaction();
        t.id = txId;
        t.type = type;
        t.amount = d.amount;
        t.accountId = d.accountId;
        t.categoryId = debtCategoryFor(db, d, type);
        t.date = dateIso;
        t.note = note;
        return t;
    }

    /**
     * Create a debt/credit (Flutter addDebtCredit): when it affects the
     * account, the initial transaction is created and linked —
     * lent = expense out, borrowed = income in.
     */
    public static void createDebt(WalletDb db, DebtCredit d, String txId) {
        if (db == null || d == null) return;
        if (d.affectsAccount) {
            String type = "lent".equals(d.direction) ? "expense" : "income";
            Transaction t = buildDebtTx(db, d, txId, type, debtInitialNote(d), d.startDate);
            addTransaction(db, t);
            d.transactionId = txId;
        }
        db.debtCredits.add(d);
    }

    /**
     * Find the settlement transaction: by stored id, else Flutter's
     * legacy fallback (matching type + amount + note prefix) for
     * records settled before settlementTransactionId was tracked.
     */
    public static Transaction findSettlementTx(WalletDb db, DebtCredit d) {
        if (db == null || d == null) return null;
        if (d.settlementTransactionId != null) {
            Transaction t = transactionById(db, d.settlementTransactionId);
            if (t != null) return t;
        }
        if (!"closed".equals(d.status)) return null;
        String type = "lent".equals(d.direction) ? "income" : "expense";
        String prefix = debtSettlementPrefix(d);
        for (Transaction t : db.transactions) {
            if (t != null && type.equals(t.type)
                    && Math.abs(t.amount - d.amount) < 0.001
                    && t.note != null && t.note.startsWith(prefix)) {
                return t;
            }
        }
        return null;
    }

    /** Reverse-and-forget both of a debt's balance effects (if any),
     *  leaving the record itself in place. Used by delete and update. */
    private static void stripDebtEffects(WalletDb db, DebtCredit d) {
        if (d == null) return;
        if (d.transactionId != null) {
            Transaction t = transactionById(db, d.transactionId);
            if (t != null) deleteTransaction(db, t.id);
        } else if (d.affectsAccount && "active".equals(d.status)) {
            // Imported/seeded record with no linked transaction: Flutter
            // treats its effect as already inside the stored balance
            // (_applyDebtCreditToBalances) and reverses it directly.
            Account acc = accountById(db.accounts, d.accountId);
            if (acc != null) {
                if ("lent".equals(d.direction)) acc.balance += d.amount;
                else if ("borrowed".equals(d.direction)) acc.balance -= d.amount;
            }
        }
        Transaction settle = findSettlementTx(db, d);
        if (settle != null) deleteTransaction(db, settle.id);
    }

    /**
     * Settle/close (Flutter closeDebtCredit with affectBalance =
     * the record's own affectsAccount, as the Flutter UI passes):
     * creates the settlement transaction — lent = income "Debt
     * recovered from …", borrowed = expense "Debt repaid to …" — into
     * the record's account, links it, and closes the record.
     */
    public static boolean settleDebt(WalletDb db, DebtCredit d, String nowIso, String txId) {
        if (db == null || d == null || "closed".equals(d.status)) return false;
        if (d.affectsAccount) {
            String type = "lent".equals(d.direction) ? "income" : "expense";
            Transaction t = buildDebtTx(db, d, txId, type, debtSettlementNote(d), nowIso);
            addTransaction(db, t);
            d.settlementTransactionId = txId;
        }
        d.status = "closed";
        return true;
    }

    /** Reopen (Flutter reopenDebtCredit): delete the settlement
     *  transaction (reversing it) and go back to active. */
    public static boolean reopenDebt(WalletDb db, DebtCredit d) {
        if (db == null || d == null || !"closed".equals(d.status)) return false;
        Transaction settle = findSettlementTx(db, d);
        if (settle != null) deleteTransaction(db, settle.id);
        d.settlementTransactionId = null;
        d.status = "active";
        return true;
    }

    /**
     * Delete (Flutter deleteDebtCredit): the linked initial
     * transaction and any settlement transaction are deleted (which
     * reverses their balance effects), then the record is removed.
     * Seed records without a linked transaction reverse their direct
     * effect instead (see stripDebtEffects).
     */
    public static boolean deleteDebt(WalletDb db, DebtCredit d) {
        if (db == null || d == null) return false;
        stripDebtEffects(db, d);
        return db.debtCredits.remove(d);
    }

    /**
     * Edit a debt/credit by REBUILDING its linked transactions from
     * the new field values. Flutter updates the initial transaction in
     * place and leaves settlement handling to close/reopen; rebuilding
     * reaches the same balances with one code path for every field
     * combination (amount/person/account/direction/affects/status) and
     * no half-updated links. `updated` carries the same id as the old
     * record; its transactionId/settlementTransactionId are rewritten.
     * settleDateIso is only used when a closed record has no previous
     * settlement date to preserve.
     */
    public static boolean updateDebt(WalletDb db, DebtCredit updated,
                                     String newTxId, String newSettleTxId,
                                     String settleDateIso) {
        if (db == null || updated == null || updated.id == null) return false;
        int idx = -1;
        DebtCredit old = null;
        for (int i = 0; i < db.debtCredits.size(); i++) {
            if (db.debtCredits.get(i) != null && updated.id.equals(db.debtCredits.get(i).id)) {
                idx = i;
                old = db.debtCredits.get(i);
                break;
            }
        }
        if (old == null) return false;
        Transaction oldSettle = findSettlementTx(db, old);
        String keepSettleDate = oldSettle != null ? oldSettle.date : settleDateIso;
        stripDebtEffects(db, old);
        db.debtCredits.set(idx, updated);
        updated.transactionId = null;
        updated.settlementTransactionId = null;
        if (updated.affectsAccount) {
            String type = "lent".equals(updated.direction) ? "expense" : "income";
            Transaction t = buildDebtTx(db, updated, newTxId, type,
                    debtInitialNote(updated), updated.startDate);
            addTransaction(db, t);
            updated.transactionId = newTxId;
            if ("closed".equals(updated.status)) {
                String stype = "lent".equals(updated.direction) ? "income" : "expense";
                Transaction s = buildDebtTx(db, updated, newSettleTxId, stype,
                        debtSettlementNote(updated), keepSettleDate);
                addTransaction(db, s);
                updated.settlementTransactionId = newSettleTxId;
            }
        }
        return true;
    }

    /** Outstanding (active) totals per direction. */
    public static double totalActiveDebt(List<DebtCredit> debts, String direction) {
        double sum = 0;
        if (debts != null) {
            for (DebtCredit d : debts) {
                if (d != null && direction.equals(d.direction)
                        && "active".equals(d.status)) {
                    sum += d.amount;
                }
            }
        }
        return sum;
    }

    // ==================================================== Phase 3: templates

    public static Template templateById(WalletDb db, String id) {
        if (db == null || id == null) return null;
        for (Template t : db.templates) if (t != null && id.equals(t.id)) return t;
        return null;
    }

    /** A draft transaction from a template (Flutter's AddTransactionSheet
     *  prefill): every field copied, dated when used, never a split. */
    public static Transaction draftFromTemplate(Template tpl, String txId, String dateIso) {
        if (tpl == null) return null;
        Transaction t = new Transaction();
        t.id = txId;
        t.type = tpl.type;
        t.amount = tpl.amount;
        t.accountId = tpl.accountId;
        t.toAccountId = tpl.toAccountId;
        t.categoryId = tpl.categoryId;
        t.date = dateIso;
        t.note = tpl.note;
        t.isSplit = false;
        return t;
    }

    // ==================================================== Phase 3: reminder maths

    /**
     * When the daily reminder should next fire: today at hour:minute,
     * or tomorrow if that time has already passed (Flutter: strictly
     * before now -> tomorrow; native uses "not after now" so an alarm
     * is never scheduled in the past).
     */
    public static java.time.LocalDateTime nextDailyReminder(
            java.time.LocalDateTime now, int hour, int minute) {
        java.time.LocalDateTime candidate = now.toLocalDate().atTime(hour, minute);
        return candidate.isAfter(now) ? candidate : candidate.plusDays(1);
    }

    /** Planned-payment reminder moment: the due DATE minus daysBefore,
     *  at 09:00 (Flutter schedulePlannedPaymentReminders). */
    public static java.time.LocalDateTime plannedReminderTime(
            PlannedPayment p, int daysBefore) {
        if (p == null || p.nextDueDate == null || p.nextDueDate.length() < 10) return null;
        try {
            java.time.LocalDate due = java.time.LocalDate.parse(p.nextDueDate.substring(0, 10));
            return due.minusDays(daysBefore).atTime(9, 0);
        } catch (Exception e) {
            return null;
        }
    }

    // ------------------------------------------------------------- ISO helpers

    static java.time.LocalDateTime parseIso(String iso) {
        if (iso == null || iso.length() < 10) return null;
        try {
            String s = iso.length() >= 19 ? iso.substring(0, 19) : iso;
            if (s.length() == 10) s = s + "T00:00:00";
            return java.time.LocalDateTime.parse(s);
        } catch (Exception e) {
            return null;
        }
    }

    static String formatIso(java.time.LocalDateTime dt) {
        return dt.format(java.time.format.DateTimeFormatter.ofPattern("yyyy-MM-dd'T'HH:mm:ss.SSS"));
    }

    /** Current moment as a backup-format ISO string (tests pass their own). */
    public static String nowIso() {
        return formatIso(java.time.LocalDateTime.now());
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
