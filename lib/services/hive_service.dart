import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';

const _uuid = Uuid();

class HiveService {
  static const String _userBox = 'user_profile';
  static const String _accountsBox = 'accounts';
  static const String _categoriesBox = 'categories';
  static const String _transactionsBox = 'transactions';
  static const String _plannedBox = 'planned_payments';
  static const String _debtCreditBox = 'debt_credits';
  static const String _templatesBox = 'templates';
  static const String _settingsBox = 'settings';

  static Future<void> init() async {
    await Hive.initFlutter();
    Hive.registerAdapter(UserProfileAdapter());
    Hive.registerAdapter(AccountAdapter());
    Hive.registerAdapter(CategoryAdapter());
    Hive.registerAdapter(TransactionAdapter());
    Hive.registerAdapter(PlannedPaymentAdapter());
    Hive.registerAdapter(DebtCreditAdapter());
    Hive.registerAdapter(TemplateAdapter());
    Hive.registerAdapter(SplitMemberAdapter());
    Hive.registerAdapter(DebtPaymentAdapter());

    await Hive.openBox<UserProfile>(_userBox);
    await Hive.openBox<Account>(_accountsBox);
    await Hive.openBox<Category>(_categoriesBox);
    await Hive.openBox<Transaction>(_transactionsBox);
    await Hive.openBox<PlannedPayment>(_plannedBox);
    await Hive.openBox<DebtCredit>(_debtCreditBox);
    await Hive.openBox<Template>(_templatesBox);
    await Hive.openBox(_settingsBox);

    _seedDefaultCategories();
  }

  // Getters
  static Box<UserProfile> get userBox => Hive.box<UserProfile>(_userBox);
  static Box<Account> get accountsBox => Hive.box<Account>(_accountsBox);
  static Box<Category> get categoriesBox => Hive.box<Category>(_categoriesBox);
  static Box<Transaction> get transactionsBox => Hive.box<Transaction>(_transactionsBox);
  static Box<PlannedPayment> get plannedBox => Hive.box<PlannedPayment>(_plannedBox);
  static Box<DebtCredit> get debtCreditBox => Hive.box<DebtCredit>(_debtCreditBox);
  static Box<Template> get templatesBox => Hive.box<Template>(_templatesBox);
  static Box get settingsBox => Hive.box(_settingsBox);

  // Analytics Cards Ordering
  static const List<String> defaultAnalyticsCardOrder = [
    'period_comparison',
    'cash_flow',
    'nature_of_spending',
    'income_expense_book',
    'net_balance',
  ];

  static List<String> getAnalyticsCardOrder() {
    try {
      final raw = settingsBox.get('analytics_card_order');
      if (raw is List) {
        final saved = List<String>.from(raw);
        final validList = saved.where((id) => defaultAnalyticsCardOrder.contains(id)).toList();
        for (final def in defaultAnalyticsCardOrder) {
          if (!validList.contains(def)) {
            validList.add(def);
          }
        }
        return validList;
      }
    } catch (_) {}
    return List<String>.from(defaultAnalyticsCardOrder);
  }

  static Future<void> saveAnalyticsCardOrder(List<String> order) async {
    try {
      await settingsBox.put('analytics_card_order', order);
    } catch (_) {}
  }

  static Future<void> resetAnalyticsCardOrder() async {
    try {
      await settingsBox.put('analytics_card_order', defaultAnalyticsCardOrder);
    } catch (_) {}
  }

  // User
  static UserProfile? getUser() => userBox.values.isNotEmpty ? userBox.values.first : null;

  static Future<void> saveUser(UserProfile user) async {
    await userBox.clear();
    await userBox.add(user);
  }

  static Future<void> clearUser() async => userBox.clear();

  // Accounts
  static List<Account> getAccounts() => accountsBox.values.toList();

  static double getNetWallet() {
    return accountsBox.values
        .where((a) => a.isEnabledForCalc)
        .fold<double>(0.0, (sum, a) => sum + a.balance);
  }

  static Future<Account> addAccount(Account acc) async {
    acc.id = _uuid.v4();
    await accountsBox.add(acc);
    return acc;
  }

  static Future<void> updateAccount(Account acc) => acc.save();

  static Future<void> deleteAccount(Account acc) async {
    final txns = transactionsBox.values
        .where((t) => t.accountId == acc.id || t.toAccountId == acc.id)
        .toList();
    for (final t in txns) {
      await t.delete();
    }
    await acc.delete();
  }

  // Categories
  static List<Category> getCategories() => categoriesBox.values.toList();

  static Future<void> addCategory(Category cat) async {
    cat.id = _uuid.v4();
    await categoriesBox.add(cat);
  }

  static Future<void> updateCategory(Category cat) => cat.save();

  static Future<void> deleteCategory(Category cat) async {
    final children = categoriesBox.values.where((c) => c.parentId == cat.id).toList();
    for (final child in children) {
      await child.delete();
    }
    await cat.delete();
  }

  /// Reorder categories: saves the full list in the given order.
  /// This clears the box and re-adds everything to preserve the new ordering.
  static Future<void> reorderCategories(List<Category> reordered) async {
    await categoriesBox.clear();
    for (final cat in reordered) {
      await categoriesBox.add(cat);
    }
  }

  // Transactions
  static List<Transaction> getTransactions() {
    final list = transactionsBox.values.toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  static Future<void> addTransaction(Transaction txn) async {
    txn.id = _uuid.v4();
    await transactionsBox.add(txn);
    _applyTransactionToBalances(txn, reverse: false);
  }

  static Future<void> deleteTransaction(Transaction txn) async {
    _applyTransactionToBalances(txn, reverse: true);
    await txn.delete();
  }

  static Future<void> updateTransaction(Transaction old, Transaction updated) async {
    _applyTransactionToBalances(old, reverse: true);
    updated.id = old.id;
    await old.delete();
    await transactionsBox.add(updated);
    _applyTransactionToBalances(updated, reverse: false);
  }

  static void _applyTransactionToBalances(Transaction txn, {required bool reverse}) {
    final factor = reverse ? -1 : 1;
    final fromAcc = _findAccount(txn.accountId);
    if (fromAcc != null) {
      if (txn.type == 'income') {
        fromAcc.balance += txn.amount * factor;
        fromAcc.save();
      } else if (txn.type == 'expense') {
        fromAcc.balance -= txn.amount * factor;
        fromAcc.save();
      } else if (txn.type == 'transfer') {
        fromAcc.balance -= txn.amount * factor;
        fromAcc.save();
        final toAcc = _findAccount(txn.toAccountId ?? '');
        if (toAcc != null) {
          toAcc.balance += txn.amount * factor;
          toAcc.save();
        }
      }
    }

    // Also account for any already collected split recoveries
    if (txn.isSplit && txn.splits != null) {
      for (final split in txn.splits!) {
        if (split.isPaid && split.paidAccountId != null) {
          final recAcc = _findAccount(split.paidAccountId!);
          if (recAcc != null) {
            recAcc.balance += split.amount * factor;
            recAcc.save();
          }
        }
      }
    }
  }

  static Future<void> markSplitMemberPaid(
    Transaction txn,
    String memberId, {
    required DateTime paidDate,
    required String targetAccountId,
  }) async {
    if (txn.splits == null) return;
    final member = txn.splits!.firstWhereOrNull((s) => s.id == memberId);
    if (member == null || member.isPaid) return;

    member.isPaid = true;
    member.paidDate = paidDate;
    member.paidAccountId = targetAccountId;

    final targetAcc = _findAccount(targetAccountId);
    if (targetAcc != null) {
      targetAcc.balance += member.amount;
      await targetAcc.save();
    }
    await txn.save();
  }

  static Future<void> unmarkSplitMemberPaid(Transaction txn, String memberId) async {
    if (txn.splits == null) return;
    final member = txn.splits!.firstWhereOrNull((s) => s.id == memberId);
    if (member == null || !member.isPaid) return;

    final targetAccountId = member.paidAccountId ?? txn.accountId;
    final targetAcc = _findAccount(targetAccountId);
    if (targetAcc != null) {
      targetAcc.balance -= member.amount;
      await targetAcc.save();
    }

    member.isPaid = false;
    member.paidDate = null;
    member.paidAccountId = null;
    await txn.save();
  }

  static Account? _findAccount(String id) {
    try {
      return accountsBox.values.firstWhere((a) => a.id == id);
    } catch (_) {
      return null;
    }
  }

  static Category? _findCategory(String? id) {
    if (id == null) return null;
    try {
      return categoriesBox.values.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  // Planned Payments
  static List<PlannedPayment> getPlanned() {
    final list = plannedBox.values.toList();
    list.sort((a, b) => a.nextDueDate.compareTo(b.nextDueDate));
    return list;
  }

  static Future<void> addPlanned(PlannedPayment p) async {
    p.id = _uuid.v4();
    await plannedBox.add(p);
  }

  static Future<void> updatePlanned(PlannedPayment p) => p.save();
  static Future<void> deletePlanned(PlannedPayment p) => p.delete();

  // Debt / Credit
  static List<DebtCredit> getDebtCredits() => debtCreditBox.values.toList();

  static Future<void> addDebtCredit(DebtCredit dc) async {
    dc.id = _uuid.v4();
    if (dc.affectsAccount) {
      final isLent = dc.direction == 'lent';
      final noteSuffix = dc.notes.trim().isNotEmpty ? ' (${dc.notes.trim()})' : '';
      final expectedType = isLent ? 'expense' : 'income';
      final cat = _findCategory(dc.categoryId);
      final validCategoryId = (cat != null && cat.type == expectedType) ? dc.categoryId : null;
      final txn = Transaction(
        id: '',
        type: expectedType,
        amount: dc.amount,
        accountId: dc.accountId,
        categoryId: validCategoryId,
        date: dc.startDate,
        note: isLent
            ? 'Lent to ${dc.personName}$noteSuffix'
            : 'Borrowed from ${dc.personName}$noteSuffix',
      );
      await addTransaction(txn);
      dc.transactionId = txn.id;
    }
    await debtCreditBox.add(dc);
  }

  static Future<void> updateDebtCredit(DebtCredit old, DebtCredit updated) async {
    updated.id = old.id;
    updated.payments ??= old.payments;
    updated.settlementTransactionId ??= old.settlementTransactionId;
    final isLent = updated.direction == 'lent';
    final noteSuffix = updated.notes.trim().isNotEmpty ? ' (${updated.notes.trim()})' : '';
    final expectedType = isLent ? 'expense' : 'income';
    final cat = _findCategory(updated.categoryId);
    final validCategoryId = (cat != null && cat.type == expectedType) ? updated.categoryId : null;

    if (old.transactionId != null && old.transactionId!.isNotEmpty) {
      final oldTxn = transactionsBox.values.firstWhereOrNull((t) => t.id == old.transactionId);
      if (updated.affectsAccount && updated.status == 'active') {
        if (oldTxn != null) {
          final updatedTxn = Transaction(
            id: oldTxn.id,
            type: expectedType,
            amount: updated.amount,
            accountId: updated.accountId,
            categoryId: validCategoryId,
            date: updated.startDate,
            note: isLent
                ? 'Lent to ${updated.personName}$noteSuffix'
                : 'Borrowed from ${updated.personName}$noteSuffix',
          );
          await updateTransaction(oldTxn, updatedTxn);
          updated.transactionId = updatedTxn.id;
        } else {
          final newTxn = Transaction(
            id: '',
            type: expectedType,
            amount: updated.amount,
            accountId: updated.accountId,
            categoryId: validCategoryId,
            date: updated.startDate,
            note: isLent
                ? 'Lent to ${updated.personName}$noteSuffix'
                : 'Borrowed from ${updated.personName}$noteSuffix',
          );
          await addTransaction(newTxn);
          updated.transactionId = newTxn.id;
        }
      } else {
        if (oldTxn != null) {
          await deleteTransaction(oldTxn);
        }
        updated.transactionId = null;
      }
    } else {
      _applyDebtCreditToBalances(old, reverse: true);
      if (updated.affectsAccount && updated.status == 'active') {
        final newTxn = Transaction(
          id: '',
          type: expectedType,
          amount: updated.amount,
          accountId: updated.accountId,
          categoryId: validCategoryId,
          date: updated.startDate,
          note: isLent
              ? 'Lent to ${updated.personName}$noteSuffix'
              : 'Borrowed from ${updated.personName}$noteSuffix',
        );
        await addTransaction(newTxn);
        updated.transactionId = newTxn.id;
      }
    }

    // Partial payments already cover the new amount: settle it.
    if (updated.status == 'active' && updated.hasPayments && updated.remainingAmount == 0) {
      updated.status = 'closed';
    }

    await old.delete();
    await debtCreditBox.add(updated);
  }

  static Future<void> deleteDebtCredit(DebtCredit dc) async {
    // 1. Delete initial transaction if exists
    if (dc.transactionId != null && dc.transactionId!.isNotEmpty) {
      final txn = transactionsBox.values.firstWhereOrNull((t) => t.id == dc.transactionId);
      if (txn != null) {
        await deleteTransaction(txn);
      }
    } else {
      _applyDebtCreditToBalances(dc, reverse: true);
    }

    // 2. Also delete settlement transaction if it was closed
    Transaction? settleTxn;
    if (dc.settlementTransactionId != null && dc.settlementTransactionId!.isNotEmpty) {
      settleTxn = transactionsBox.values.firstWhereOrNull((t) => t.id == dc.settlementTransactionId);
    }
    if (settleTxn == null && dc.status == 'closed' && !dc.hasPayments) {
      final isLent = dc.direction == 'lent';
      final expectedType = isLent ? 'income' : 'expense';
      final notePrefix = isLent ? 'Debt recovered from ${dc.personName}' : 'Debt repaid to ${dc.personName}';
      settleTxn = transactionsBox.values.firstWhereOrNull(
        (t) => t.type == expectedType && t.amount == dc.amount && t.note.startsWith(notePrefix),
      );
    }
    if (settleTxn != null) {
      await deleteTransaction(settleTxn);
    }

    // 3. Partial repayment transactions
    for (final p in dc.payments ?? const <DebtPayment>[]) {
      final id = p.transactionId;
      if (id == null || id.isEmpty) continue;
      final txn = transactionsBox.values.firstWhereOrNull((t) => t.id == id);
      if (txn != null) await deleteTransaction(txn);
    }

    await dc.delete();
  }

  /// Settles the record. Only the amount still owed after partial payments is
  /// recorded as the final settlement transaction.
  static Future<void> closeDebtCredit(DebtCredit dc, {String? targetAccountId, bool affectBalance = true}) async {
    if (dc.status == 'closed') return;
    final remaining = dc.remainingAmount;
    if (affectBalance && remaining > 0) {
      final accountId = targetAccountId ?? dc.accountId;
      final isLent = dc.direction == 'lent';
      final noteSuffix = dc.notes.trim().isNotEmpty ? ' (${dc.notes.trim()})' : '';
      final expectedType = isLent ? 'income' : 'expense';
      final cat = _findCategory(dc.categoryId);
      final validCategoryId = (cat != null && cat.type == expectedType) ? dc.categoryId : null;
      final txn = Transaction(
        id: '',
        type: expectedType,
        amount: remaining,
        accountId: accountId,
        categoryId: validCategoryId,
        date: DateTime.now(),
        note: isLent
            ? 'Debt recovered from ${dc.personName}$noteSuffix'
            : 'Debt repaid to ${dc.personName}$noteSuffix',
      );
      await addTransaction(txn);
      dc.settlementTransactionId = txn.id;
    }
    dc.status = 'closed';
    await dc.save();
  }

  static Future<void> reopenDebtCredit(DebtCredit dc) async {
    if (dc.status != 'closed') return;

    // Locate and delete settlement transaction if it exists
    Transaction? settleTxn;
    if (dc.settlementTransactionId != null && dc.settlementTransactionId!.isNotEmpty) {
      settleTxn = transactionsBox.values.firstWhereOrNull((t) => t.id == dc.settlementTransactionId);
    }
    if (settleTxn == null && !dc.hasPayments) {
      // Fallback for debts settled before settlementTransactionId tracking was introduced
      final isLent = dc.direction == 'lent';
      final expectedType = isLent ? 'income' : 'expense';
      final notePrefix = isLent ? 'Debt recovered from ${dc.personName}' : 'Debt repaid to ${dc.personName}';
      settleTxn = transactionsBox.values.firstWhereOrNull(
        (t) => t.type == expectedType && t.amount == dc.amount && t.note.startsWith(notePrefix),
      );
    }

    if (settleTxn != null) {
      await deleteTransaction(settleTxn);
    }

    dc.settlementTransactionId = null;
    dc.status = 'active';
    await dc.save();
  }

  /// Records a partial repayment. When the record affects an account, an
  /// income (lent) or expense (borrowed) transaction is created for it. The
  /// record closes on its own once nothing is left to pay.
  static Future<DebtPayment> addDebtPayment(
    DebtCredit dc, {
    required double amount,
    required DateTime date,
    required String accountId,
    String note = '',
  }) async {
    final payment = DebtPayment(
      id: _uuid.v4(),
      amount: amount,
      date: date,
      accountId: accountId,
      note: note.trim(),
    );
    if (dc.affectsAccount) {
      final isLent = dc.direction == 'lent';
      final expectedType = isLent ? 'income' : 'expense';
      final cat = _findCategory(dc.categoryId);
      final validCategoryId = (cat != null && cat.type == expectedType) ? dc.categoryId : null;
      final noteSuffix = payment.note.isNotEmpty ? ' (${payment.note})' : '';
      final txn = Transaction(
        id: '',
        type: expectedType,
        amount: amount,
        accountId: accountId,
        categoryId: validCategoryId,
        date: date,
        note: isLent
            ? 'Partial payment from ${dc.personName}$noteSuffix'
            : 'Partial payment to ${dc.personName}$noteSuffix',
      );
      await addTransaction(txn);
      payment.transactionId = txn.id;
    }
    dc.payments = [...?dc.payments, payment];
    if (dc.remainingAmount == 0) dc.status = 'closed';
    await dc.save();
    return payment;
  }

  /// Removes a partial repayment and reverses its transaction. A closed record
  /// becomes active again (its final settlement, if any, is undone too).
  static Future<void> deleteDebtPayment(DebtCredit dc, String paymentId) async {
    final list = List<DebtPayment>.from(dc.payments ?? const <DebtPayment>[]);
    final idx = list.indexWhere((p) => p.id == paymentId);
    if (idx < 0) return;
    final payment = list.removeAt(idx);
    final txnId = payment.transactionId;
    if (txnId != null && txnId.isNotEmpty) {
      final txn = transactionsBox.values.firstWhereOrNull((t) => t.id == txnId);
      if (txn != null) await deleteTransaction(txn);
    }
    final wasClosed = dc.status == 'closed';
    final hadSettlement = dc.settlementTransactionId != null && dc.settlementTransactionId!.isNotEmpty;
    dc.payments = list.isEmpty ? null : list;
    if (wasClosed) {
      if (hadSettlement) {
        final settle = transactionsBox.values.firstWhereOrNull((t) => t.id == dc.settlementTransactionId);
        if (settle != null) await deleteTransaction(settle);
        dc.settlementTransactionId = null;
      }
      dc.status = 'active';
    }
    await dc.save();
  }

  static void _applyDebtCreditToBalances(DebtCredit dc, {required bool reverse}) {
    if (dc.status != 'active') return;
    if (!dc.affectsAccount) return;
    final factor = reverse ? -1 : 1;
    final acc = _findAccount(dc.accountId);
    if (acc == null) return;

    if (dc.direction == 'lent') {
      acc.balance -= dc.amount * factor;
      acc.save();
    } else if (dc.direction == 'borrowed') {
      acc.balance += dc.amount * factor;
      acc.save();
    }
  }

  // Templates
  static List<Template> getTemplates() => templatesBox.values.toList();

  static Future<void> addTemplate(Template t) async {
    t.id = _uuid.v4();
    await templatesBox.add(t);
  }

  static Future<void> updateTemplate(Template t) => t.save();
  static Future<void> deleteTemplate(Template t) => t.delete();

  // Seed default categories
  static void _seedDefaultCategories() {
    if (categoriesBox.isNotEmpty) return;

    void addWithChildren(Category parent, List<Category> children) {
      categoriesBox.add(parent);
      for (final child in children) {
        child.parentId = parent.id;
        child.type = parent.type;
        categoriesBox.add(child);
      }
    }

    final transportId = _uuid.v4();
    addWithChildren(
      Category(id: transportId, name: 'Transport', type: 'expense', colorValue: 0xFFFFB84D, icon: '🚗'),
      [
        Category(id: _uuid.v4(), name: 'Bus', type: 'expense', colorValue: 0xFFFFB84D, icon: '🚌'),
        Category(id: _uuid.v4(), name: 'Flight', type: 'expense', colorValue: 0xFFFFB84D, icon: '✈️'),
        Category(id: _uuid.v4(), name: 'Train', type: 'expense', colorValue: 0xFFFFB84D, icon: '🚆'),
        Category(id: _uuid.v4(), name: 'Fuel', type: 'expense', colorValue: 0xFFFFB84D, icon: '⛽'),
        Category(id: _uuid.v4(), name: 'Taxi', type: 'expense', colorValue: 0xFFFFB84D, icon: '🚕'),
      ],
    );

    final foodId = _uuid.v4();
    addWithChildren(
      Category(id: foodId, name: 'Food & Dining', type: 'expense', colorValue: 0xFFFF5C7A, icon: '🍔'),
      [
        Category(id: _uuid.v4(), name: 'Groceries', type: 'expense', colorValue: 0xFFFF5C7A, icon: '🛒'),
        Category(id: _uuid.v4(), name: 'Restaurant', type: 'expense', colorValue: 0xFFFF5C7A, icon: '🍽️'),
        Category(id: _uuid.v4(), name: 'Coffee / Tea', type: 'expense', colorValue: 0xFFFF5C7A, icon: '☕'),
        Category(id: _uuid.v4(), name: 'Snacks', type: 'expense', colorValue: 0xFFFF5C7A, icon: '🍿'),
      ],
    );

    final shoppingId = _uuid.v4();
    addWithChildren(
      Category(id: shoppingId, name: 'Shopping', type: 'expense', colorValue: 0xFF9B8FFF, icon: '🛍️'),
      [
        Category(id: _uuid.v4(), name: 'Clothing', type: 'expense', colorValue: 0xFF9B8FFF, icon: '👕'),
        Category(id: _uuid.v4(), name: 'Electronics', type: 'expense', colorValue: 0xFF9B8FFF, icon: '💻'),
        Category(id: _uuid.v4(), name: 'Home & Living', type: 'expense', colorValue: 0xFF9B8FFF, icon: '🛋️'),
      ],
    );

    final billsId = _uuid.v4();
    addWithChildren(
      Category(id: billsId, name: 'Bills & Utilities', type: 'expense', colorValue: 0xFF5BA4FF, icon: '🧾'),
      [
        Category(id: _uuid.v4(), name: 'Electricity', type: 'expense', colorValue: 0xFF5BA4FF, icon: '💡'),
        Category(id: _uuid.v4(), name: 'Mobile / Recharge', type: 'expense', colorValue: 0xFF5BA4FF, icon: '📱'),
        Category(id: _uuid.v4(), name: 'Internet / WiFi', type: 'expense', colorValue: 0xFF5BA4FF, icon: '📶'),
        Category(id: _uuid.v4(), name: 'Water', type: 'expense', colorValue: 0xFF5BA4FF, icon: '🚰'),
      ],
    );

    final healthId = _uuid.v4();
    addWithChildren(
      Category(id: healthId, name: 'Health & Medical', type: 'expense', colorValue: 0xFF00D9A3, icon: '🏥'),
      [
        Category(id: _uuid.v4(), name: 'Medicine', type: 'expense', colorValue: 0xFF00D9A3, icon: '💊'),
        Category(id: _uuid.v4(), name: 'Doctor & Hospital', type: 'expense', colorValue: 0xFF00D9A3, icon: '🩺'),
        Category(id: _uuid.v4(), name: 'Fitness & Gym', type: 'expense', colorValue: 0xFF00D9A3, icon: '🏋️'),
      ],
    );

    final entId = _uuid.v4();
    addWithChildren(
      Category(id: entId, name: 'Entertainment', type: 'expense', colorValue: 0xFFFF79C6, icon: '🎬'),
      [
        Category(id: _uuid.v4(), name: 'Movies & Events', type: 'expense', colorValue: 0xFFFF79C6, icon: '🎟️'),
        Category(id: _uuid.v4(), name: 'Games', type: 'expense', colorValue: 0xFFFF79C6, icon: '🎮'),
        Category(id: _uuid.v4(), name: 'Streaming & Music', type: 'expense', colorValue: 0xFFFF79C6, icon: '📺'),
      ],
    );

    final eduId = _uuid.v4();
    addWithChildren(
      Category(id: eduId, name: 'Education', type: 'expense', colorValue: 0xFF50FA7B, icon: '📚'),
      [
        Category(id: _uuid.v4(), name: 'Courses & Fees', type: 'expense', colorValue: 0xFF50FA7B, icon: '🎓'),
        Category(id: _uuid.v4(), name: 'Books & Supplies', type: 'expense', colorValue: 0xFF50FA7B, icon: '📖'),
      ],
    );

    categoriesBox.add(Category(id: _uuid.v4(), name: 'Rent', type: 'expense', colorValue: 0xFFEF7C8E, icon: '🏠'));

    final salaryId = _uuid.v4();
    addWithChildren(
      Category(id: salaryId, name: 'Salary', type: 'income', colorValue: 0xFF00C896, icon: '💼'),
      [
        Category(id: _uuid.v4(), name: 'Monthly Salary', type: 'income', colorValue: 0xFF00C896, icon: '💵'),
        Category(id: _uuid.v4(), name: 'Bonus & Incentives', type: 'income', colorValue: 0xFF00C896, icon: '✨'),
      ],
    );

    final freelanceId = _uuid.v4();
    addWithChildren(
      Category(id: freelanceId, name: 'Freelance', type: 'income', colorValue: 0xFF5BA4FF, icon: '💻'),
      [
        Category(id: _uuid.v4(), name: 'Project Work', type: 'income', colorValue: 0xFF5BA4FF, icon: '📝'),
        Category(id: _uuid.v4(), name: 'Consulting', type: 'income', colorValue: 0xFF5BA4FF, icon: '🗣️'),
      ],
    );

    final investId = _uuid.v4();
    addWithChildren(
      Category(id: investId, name: 'Investment', type: 'income', colorValue: 0xFFFFB84D, icon: '📈'),
      [
        Category(id: _uuid.v4(), name: 'Stocks & Crypto', type: 'income', colorValue: 0xFFFFB84D, icon: '📊'),
        Category(id: _uuid.v4(), name: 'Dividends & Interest', type: 'income', colorValue: 0xFFFFB84D, icon: '💰'),
        Category(id: _uuid.v4(), name: 'Real Estate / Rental', type: 'income', colorValue: 0xFFFFB84D, icon: '🏢'),
      ],
    );

    categoriesBox.add(Category(id: _uuid.v4(), name: 'Gift / Reward', type: 'income', colorValue: 0xFFFF79C6, icon: '🎁'));
  }
}

extension _IterableExt<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    for (final e in this) {
      if (test(e)) return e;
    }
    return null;
  }
}