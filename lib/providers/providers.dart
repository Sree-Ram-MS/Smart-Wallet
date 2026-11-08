import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import '../services/auth_service.dart';
import '../services/cloud_sync_service.dart';
import '../services/hive_service.dart';
import '../services/notification_service.dart';
import '../services/widget_service.dart';

const _uuid = Uuid();

void _syncHomeWidget() {
  final user = HiveService.getUser();
  if (user != null) {
    final net = HiveService.getNetWallet();
    WidgetService.updateWidgetData(netBalance: net, currency: user.baseCurrency);
  }
}

// ─── User Provider ────────────────────────────────────────────────────────────

class UserNotifier extends StateNotifier<UserProfile?> {
  UserNotifier() : super(HiveService.getUser() ?? _defaultUser());

  static UserProfile _defaultUser() {
    return UserProfile(
      id: 'guest_user',
      name: 'Guest User',
      email: 'guest@smartwallet.local',
      isDarkMode: true,
    );
  }

  Future<void> setUser(UserProfile user) async {
    await HiveService.saveUser(user);
    state = user.copyWith();
    _syncNotifications();
  }

  Future<void> updateUser(UserProfile user) async {
    await HiveService.saveUser(user);
    state = user.copyWith();
    _syncNotifications();
  }

  Future<bool> connectGoogleAccount() async {
    final current = state ?? _defaultUser();
    final linked = await AuthService.linkGoogleAccount(current);
    if (linked != null) {
      state = linked;
      _syncNotifications();
      CloudSyncService.instance.start();
      return true;
    }
    return false;
  }

  Future<void> clearUser() async {
    await HiveService.clearUser();
    state = _defaultUser();
  }

  void refresh() {
    state = HiveService.getUser() ?? _defaultUser();
    _syncNotifications();
    _syncHomeWidget();
  }

  Future<void> toggleDarkMode() async {
    final current = state ?? _defaultUser();
    final updated = current.copyWith(isDarkMode: !current.isDarkMode);
    await HiveService.saveUser(updated);
    state = updated;
  }

  Future<void> toggleBiometric() async {
    final current = state ?? _defaultUser();
    final updated = current.copyWith(biometricEnabled: !current.biometricEnabled);
    await HiveService.saveUser(updated);
    state = updated;
  }

  Future<void> setBaseCurrency(String currency) async {
    final current = state ?? _defaultUser();
    final updated = current.copyWith(baseCurrency: currency);
    await HiveService.saveUser(updated);
    state = updated;
  }

  Future<void> setDailyReminder({
    required bool enabled,
    int? hour,
    int? minute,
  }) async {
    final current = state ?? _defaultUser();
    final updated = current.copyWith(
      dailyReminderEnabled: enabled,
      dailyReminderHour: hour ?? current.dailyReminderHour,
      dailyReminderMinute: minute ?? current.dailyReminderMinute,
    );
    await HiveService.saveUser(updated);
    state = updated;
    _syncNotifications();
  }

  Future<void> setPlannedReminder({
    required bool enabled,
    int? daysBefore,
  }) async {
    final current = state ?? _defaultUser();
    final updated = current.copyWith(
      plannedReminderEnabled: enabled,
      plannedReminderDaysBefore: daysBefore ?? current.plannedReminderDaysBefore,
    );
    await HiveService.saveUser(updated);
    state = updated;
    _syncNotifications();
  }

  void _syncNotifications() {
    final payments = HiveService.getPlanned();
    NotificationService.syncAllNotifications(user: state, payments: payments);
  }
}

final userProvider = StateNotifierProvider<UserNotifier, UserProfile?>((ref) => UserNotifier());

// ─── Accounts Provider ────────────────────────────────────────────────────────

class AccountsNotifier extends StateNotifier<List<Account>> {
  final Ref _ref;
  AccountsNotifier(this._ref) : super(HiveService.getAccounts());

  void _syncHomeWidget() {
    final user = _ref.read(userProvider);
    final net = HiveService.getNetWallet();
    if (user != null) {
      WidgetService.updateWidgetData(netBalance: net, currency: user.baseCurrency);
    }
  }

  Future<void> add(Account acc) async {
    await HiveService.addAccount(acc);
    state = HiveService.getAccounts();
    _syncHomeWidget();
  }

  Future<void> update(Account acc) async {
    await HiveService.updateAccount(acc);
    state = HiveService.getAccounts();
    _syncHomeWidget();
  }

  Future<void> updateBalance(Account acc, double newBalance) async {
    acc.balance = newBalance;
    await HiveService.updateAccount(acc);
    state = HiveService.getAccounts();
    _syncHomeWidget();
  }

  Future<void> delete(Account acc) async {
    await HiveService.deleteAccount(acc);
    state = HiveService.getAccounts();
    _syncHomeWidget();
  }

  Future<void> toggleEnable(Account acc) async {
    acc.isEnabledForCalc = !acc.isEnabledForCalc;
    await HiveService.updateAccount(acc);
    state = HiveService.getAccounts();
    _syncHomeWidget();
  }

  void refresh() {
    state = HiveService.getAccounts();
    _syncHomeWidget();
  }
}

final accountsProvider = StateNotifierProvider<AccountsNotifier, List<Account>>(
  (ref) => AccountsNotifier(ref),
);

// ─── Categories Provider ──────────────────────────────────────────────────────

class CategoriesNotifier extends StateNotifier<List<Category>> {
  CategoriesNotifier() : super(HiveService.getCategories());

  Future<void> add(Category cat) async {
    await HiveService.addCategory(cat);
    state = HiveService.getCategories();
  }

  Future<void> update(Category cat) async {
    await HiveService.updateCategory(cat);
    state = HiveService.getCategories();
  }

  Future<void> delete(Category cat) async {
    await HiveService.deleteCategory(cat);
    state = HiveService.getCategories();
  }

  /// Reorder parent categories for a given type ('expense'/'income').
  /// Keeps children grouped under their parents.
  Future<void> reorderParents(List<Category> newParentOrder, String type) async {
    final all = List<Category>.from(state);
    // Categories of the other type (preserve their order)
    final otherType = all.where((c) => c.type != type).toList();
    // Build new order: parent followed by its children
    final reorderedForType = <Category>[];
    for (final parent in newParentOrder) {
      reorderedForType.add(parent);
      reorderedForType.addAll(all.where((c) => c.parentId == parent.id));
    }
    // Also add any orphan subcategories of this type
    final parentIds = newParentOrder.map((p) => p.id).toSet();
    final orphans = all.where((c) =>
        c.type == type &&
        c.parentId != null &&
        c.parentId!.isNotEmpty &&
        !parentIds.contains(c.parentId)).toList();
    reorderedForType.addAll(orphans);

    final fullList = [...reorderedForType, ...otherType];
    await HiveService.reorderCategories(fullList);
    state = HiveService.getCategories();
  }

  void refresh() {
    state = HiveService.getCategories();
  }
}

final categoriesProvider = StateNotifierProvider<CategoriesNotifier, List<Category>>(
  (ref) => CategoriesNotifier(),
);

// ─── Transactions Provider ───────────────────────────────────────────────────

class TransactionsNotifier extends StateNotifier<List<Transaction>> {
  final Ref _ref;
  TransactionsNotifier(this._ref) : super(HiveService.getTransactions());

  Future<void> add(Transaction txn) async {
    await HiveService.addTransaction(txn);
    state = HiveService.getTransactions();
    _ref.read(accountsProvider.notifier).refresh();
    _syncHomeWidget();
  }

  Future<void> delete(Transaction txn) async {
    await HiveService.deleteTransaction(txn);
    state = HiveService.getTransactions();
    _ref.read(accountsProvider.notifier).refresh();
    _syncHomeWidget();
  }

  Future<void> update(Transaction old, Transaction updated) async {
    await HiveService.updateTransaction(old, updated);
    state = HiveService.getTransactions();
    _ref.read(accountsProvider.notifier).refresh();
    _syncHomeWidget();
  }

  Future<void> markSplitPaid(
    Transaction txn,
    String memberId, {
    required DateTime paidDate,
    required String targetAccountId,
  }) async {
    await HiveService.markSplitMemberPaid(txn, memberId, paidDate: paidDate, targetAccountId: targetAccountId);
    state = HiveService.getTransactions();
    _ref.read(accountsProvider.notifier).refresh();
    _syncHomeWidget();
  }

  Future<void> unmarkSplitPaid(Transaction txn, String memberId) async {
    await HiveService.unmarkSplitMemberPaid(txn, memberId);
    state = HiveService.getTransactions();
    _ref.read(accountsProvider.notifier).refresh();
    _syncHomeWidget();
  }

  void refresh() {
    state = HiveService.getTransactions();
    _syncHomeWidget();
  }
}

final transactionsProvider = StateNotifierProvider<TransactionsNotifier, List<Transaction>>(
  (ref) => TransactionsNotifier(ref),
);

// ─── Planned Payments Provider ───────────────────────────────────────────────

class PlannedPaymentsNotifier extends StateNotifier<List<PlannedPayment>> {
  final Ref _ref;
  PlannedPaymentsNotifier(this._ref) : super(HiveService.getPlanned());

  Future<void> add(PlannedPayment p) async {
    await HiveService.addPlanned(p);
    state = HiveService.getPlanned();
    _syncNotifications();
  }

  Future<void> update(PlannedPayment p) async {
    await HiveService.updatePlanned(p);
    state = HiveService.getPlanned();
    _syncNotifications();
  }

  Future<void> delete(PlannedPayment p) async {
    await HiveService.deletePlanned(p);
    state = HiveService.getPlanned();
    _syncNotifications();
  }

  /// Marks a planned payment as paid, records an expense transaction, and advances its cycle or completes it
  Future<void> markPaid(PlannedPayment p, {bool recordTransaction = true}) async {
    p.lastPaidDate = DateTime.now();
    if (recordTransaction) {
      final splitList = p.isSplit && p.splits != null
          ? p.splits!
              .map((s) => SplitMember(
                    id: _uuid.v4(),
                    name: s.name,
                    amount: s.amount,
                    isPaid: false,
                  ))
              .toList()
          : null;
      final txn = Transaction(
        id: '',
        type: 'expense',
        amount: p.amount,
        accountId: p.accountId,
        categoryId: p.categoryId,
        date: DateTime.now(),
        note: 'Planned Payment: ${p.name}',
        isSplit: p.isSplit,
        splits: splitList,
      );
      await _ref.read(transactionsProvider.notifier).add(txn);
    }

    if (!p.isRecurring) {
      p.isCompleted = true;
    } else {
      // Calculate next due date
      DateTime next = p.nextDueDate;
      switch (p.period) {
        case 'daily':
          next = next.add(const Duration(days: 1));
          break;
        case 'weekly':
          next = next.add(const Duration(days: 7));
          break;
        case 'yearly':
          next = DateTime(next.year + 1, next.month, next.day, next.hour, next.minute);
          break;
        case 'monthly':
        default:
          int nextMonth = next.month + 1;
          int nextYear = next.year;
          if (nextMonth > 12) {
            nextMonth = 1;
            nextYear += 1;
          }
          final daysInNextMonth = DateTime(nextYear, nextMonth + 1, 0).day;
          final targetDay = next.day > daysInNextMonth ? daysInNextMonth : next.day;
          next = DateTime(nextYear, nextMonth, targetDay, next.hour, next.minute);
          break;
      }
      p.nextDueDate = next;
      p.currentOccurrence += 1;

      // Check End Conditions
      if (p.endType == 'occurrences' && p.totalOccurrences != null) {
        if (p.currentOccurrence > p.totalOccurrences!) {
          p.isCompleted = true;
        }
      } else if (p.endType == 'until_date' && p.untilDate != null) {
        if (p.nextDueDate.isAfter(p.untilDate!)) {
          p.isCompleted = true;
        }
      }
    }

    await HiveService.updatePlanned(p);
    state = HiveService.getPlanned();
    _syncNotifications();
  }

  void _syncNotifications() {
    final user = _ref.read(userProvider);
    NotificationService.syncAllNotifications(user: user, payments: state);
  }

  void refresh() {
    state = HiveService.getPlanned();
    _syncNotifications();
  }
}

final plannedPaymentsProvider =
    StateNotifierProvider<PlannedPaymentsNotifier, List<PlannedPayment>>(
  (ref) => PlannedPaymentsNotifier(ref),
);

// ─── DebtCredit Provider ─────────────────────────────────────────────────────

class DebtCreditNotifier extends StateNotifier<List<DebtCredit>> {
  final Ref _ref;
  DebtCreditNotifier(this._ref) : super(HiveService.getDebtCredits());

  Future<void> add(DebtCredit dc) async {
    await HiveService.addDebtCredit(dc);
    state = HiveService.getDebtCredits();
    _ref.read(accountsProvider.notifier).refresh();
    _ref.read(transactionsProvider.notifier).refresh();
  }

  Future<void> update(DebtCredit old, DebtCredit updated) async {
    await HiveService.updateDebtCredit(old, updated);
    state = HiveService.getDebtCredits();
    _ref.read(accountsProvider.notifier).refresh();
    _ref.read(transactionsProvider.notifier).refresh();
  }

  Future<void> delete(DebtCredit dc) async {
    await HiveService.deleteDebtCredit(dc);
    state = HiveService.getDebtCredits();
    _ref.read(accountsProvider.notifier).refresh();
    _ref.read(transactionsProvider.notifier).refresh();
  }

  Future<void> close(DebtCredit dc, {String? targetAccountId, bool affectBalance = true}) async {
    await HiveService.closeDebtCredit(dc, targetAccountId: targetAccountId, affectBalance: affectBalance);
    state = HiveService.getDebtCredits();
    _ref.read(accountsProvider.notifier).refresh();
    _ref.read(transactionsProvider.notifier).refresh();
  }

  Future<void> reopen(DebtCredit dc) async {
    await HiveService.reopenDebtCredit(dc);
    state = HiveService.getDebtCredits();
    _ref.read(accountsProvider.notifier).refresh();
    _ref.read(transactionsProvider.notifier).refresh();
  }

  void refresh() {
    state = HiveService.getDebtCredits();
  }
}

final debtCreditProvider = StateNotifierProvider<DebtCreditNotifier, List<DebtCredit>>(
  (ref) => DebtCreditNotifier(ref),
);

// ─── Templates Provider ──────────────────────────────────────────────────────

class TemplatesNotifier extends StateNotifier<List<Template>> {
  TemplatesNotifier() : super(HiveService.getTemplates());

  Future<void> add(Template t) async {
    await HiveService.addTemplate(t);
    state = HiveService.getTemplates();
  }

  Future<void> update(Template t) async {
    await HiveService.updateTemplate(t);
    state = HiveService.getTemplates();
  }

  Future<void> delete(Template t) async {
    await HiveService.deleteTemplate(t);
    state = HiveService.getTemplates();
  }

  void refresh() {
    state = HiveService.getTemplates();
  }
}

final templatesProvider = StateNotifierProvider<TemplatesNotifier, List<Template>>(
  (ref) => TemplatesNotifier(),
);

// ─── Derived / computed providers ────────────────────────────────────────────

/// Set of enabled account IDs for calculation
final enabledAccountIdsProvider = Provider<Set<String>>((ref) {
  final accounts = ref.watch(accountsProvider);
  return accounts.where((a) => a.isEnabledForCalc).map((a) => a.id).toSet();
});

/// Net wallet balance (enabled accounts only)
final netWalletProvider = Provider<double>((ref) {
  final accounts = ref.watch(accountsProvider);
  return accounts.where((a) => a.isEnabledForCalc).fold(0.0, (sum, a) => sum + a.balance);
});

/// Monthly inflow for current month (enabled accounts only)
final monthlyInflowProvider = Provider<double>((ref) {
  final txns = ref.watch(transactionsProvider);
  final enabledIds = ref.watch(enabledAccountIdsProvider);
  final now = DateTime.now();
  return txns
      .where((t) =>
          enabledIds.contains(t.accountId) &&
          t.type == 'income' &&
          t.date.year == now.year &&
          t.date.month == now.month)
      .fold(0.0, (s, t) => s + t.amount);
});

/// Monthly outflow for current month (enabled accounts only)
final monthlyOutflowProvider = Provider<double>((ref) {
  final txns = ref.watch(transactionsProvider);
  final enabledIds = ref.watch(enabledAccountIdsProvider);
  final now = DateTime.now();
  return txns
      .where((t) =>
          enabledIds.contains(t.accountId) &&
          t.type == 'expense' &&
          t.date.year == now.year &&
          t.date.month == now.month)
      .fold(0.0, (s, t) => s + t.amount);
});

/// Monthly savings (enabled accounts only)
final monthlySavingsProvider = Provider<double>((ref) {
  return ref.watch(monthlyInflowProvider) - ref.watch(monthlyOutflowProvider);
});

/// Recent transactions on dashboard (enabled accounts only, up to 5)
final recentTransactionsProvider = Provider<List<Transaction>>((ref) {
  final txns = ref.watch(transactionsProvider);
  final enabledIds = ref.watch(enabledAccountIdsProvider);
  return txns.where((t) => enabledIds.contains(t.accountId)).take(5).toList();
});

/// Active upcoming planned payments (not completed, sorted by due date, up to 5 for dashboard or list)
final upcomingPaymentsProvider = Provider<List<PlannedPayment>>((ref) {
  final planned = ref.watch(plannedPaymentsProvider);
  final list = planned.where((p) => !p.isCompleted).toList();
  list.sort((a, b) => a.nextDueDate.compareTo(b.nextDueDate));
  return list;
});

// ─── Analytics Cards Order Provider ──────────────────────────────────────────

class AnalyticsCardOrderNotifier extends StateNotifier<List<String>> {
  AnalyticsCardOrderNotifier() : super(HiveService.getAnalyticsCardOrder());

  Future<void> reorder(int oldIndex, int newIndex) async {
    final list = List<String>.from(state);
    if (oldIndex < 0 || oldIndex >= list.length) return;
    final item = list.removeAt(oldIndex);
    final targetIndex = newIndex.clamp(0, list.length);
    list.insert(targetIndex, item);
    state = list;
    await HiveService.saveAnalyticsCardOrder(list);
  }

  Future<void> resetToDefault() async {
    await HiveService.resetAnalyticsCardOrder();
    state = HiveService.getAnalyticsCardOrder();
  }

  void refresh() {
    state = HiveService.getAnalyticsCardOrder();
  }
}

final analyticsCardOrderProvider = StateNotifierProvider<AnalyticsCardOrderNotifier, List<String>>(
  (ref) => AnalyticsCardOrderNotifier(),
);

/// Reloads all data across all providers (used after backup restore)
void refreshAllData(WidgetRef ref) {
  ref.read(userProvider.notifier).refresh();
  ref.read(accountsProvider.notifier).refresh();
  ref.read(categoriesProvider.notifier).refresh();
  ref.read(transactionsProvider.notifier).refresh();
  ref.read(plannedPaymentsProvider.notifier).refresh();
  ref.read(debtCreditProvider.notifier).refresh();
  ref.read(templatesProvider.notifier).refresh();
  ref.read(analyticsCardOrderProvider.notifier).refresh();
}

// ─── Precomputed & Cached Dashboard Analytics Provider ───────────────────────

class DashboardAnalyticsData {
  final double totalIncome;
  final double totalExpense;
  final double netCashFlow;
  // Spots for Period comparison
  final List<FlSpot> cashFlowSpots;
  final List<FlSpot> expenseSpots;
  final List<FlSpot> incomeSpots;
  final List<FlSpot> prevCashFlowSpots;
  final List<FlSpot> prevExpenseSpots;
  final List<FlSpot> prevIncomeSpots;
  final List<FlSpot> lastYearCashFlowSpots;
  final List<FlSpot> lastYearExpenseSpots;
  final List<FlSpot> lastYearIncomeSpots;
  // Spending
  final double totalSpending;
  final List<double> dailySpending;
  final List<MapEntry<String, double>> topSpendingCategories;
  // Income & Expense Book
  final Map<String, double> incomeCategoryMap;
  final Map<String, double> expenseCategoryMap;

  const DashboardAnalyticsData({
    required this.totalIncome,
    required this.totalExpense,
    required this.netCashFlow,
    required this.cashFlowSpots,
    required this.expenseSpots,
    required this.incomeSpots,
    required this.prevCashFlowSpots,
    required this.prevExpenseSpots,
    required this.prevIncomeSpots,
    required this.lastYearCashFlowSpots,
    required this.lastYearExpenseSpots,
    required this.lastYearIncomeSpots,
    required this.totalSpending,
    required this.dailySpending,
    required this.topSpendingCategories,
    required this.incomeCategoryMap,
    required this.expenseCategoryMap,
  });

  static const empty = DashboardAnalyticsData(
    totalIncome: 0,
    totalExpense: 0,
    netCashFlow: 0,
    cashFlowSpots: [],
    expenseSpots: [],
    incomeSpots: [],
    prevCashFlowSpots: [],
    prevExpenseSpots: [],
    prevIncomeSpots: [],
    lastYearCashFlowSpots: [],
    lastYearExpenseSpots: [],
    lastYearIncomeSpots: [],
    totalSpending: 0,
    dailySpending: [],
    topSpendingCategories: [],
    incomeCategoryMap: {},
    expenseCategoryMap: {},
  );
}

final dashboardAnalyticsProvider = Provider<DashboardAnalyticsData>((ref) {
  final transactions = ref.watch(transactionsProvider);
  final enabledIds = ref.watch(enabledAccountIdsProvider);
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final thirtyDaysAgo = today.subtract(const Duration(days: 30));

  double totalIncome = 0;
  double totalExpense = 0;
  final Map<String, double> spendingCatMap = {};
  final Map<String, double> incomeCatMap = {};
  final Map<String, double> expenseCatMap = {};
  final List<double> dailySpending = List.filled(30, 0.0);

  // Map for fast date lookup: 'YYYY-MM-DD' -> {income, expense}
  final Map<String, ({double income, double expense})> dateTotals = {};

  for (final t in transactions) {
    if (!enabledIds.contains(t.accountId)) continue;

    final key = '${t.date.year}-${t.date.month.toString().padLeft(2, '0')}-${t.date.day.toString().padLeft(2, '0')}';
    final current = dateTotals[key] ?? (income: 0.0, expense: 0.0);
    if (t.type == 'income') {
      dateTotals[key] = (income: current.income + t.amount, expense: current.expense);
    } else if (t.type == 'expense') {
      dateTotals[key] = (income: current.income, expense: current.expense + t.amount);
    }

    if (t.date.isAfter(thirtyDaysAgo)) {
      final catId = t.categoryId ?? 'Other';
      if (t.type == 'income') {
        totalIncome += t.amount;
        incomeCatMap[catId] = (incomeCatMap[catId] ?? 0) + t.amount;
      } else if (t.type == 'expense') {
        totalExpense += t.amount;
        spendingCatMap[catId] = (spendingCatMap[catId] ?? 0) + t.amount;
        expenseCatMap[catId] = (expenseCatMap[catId] ?? 0) + t.amount;

        final dayDiff = today.difference(DateTime(t.date.year, t.date.month, t.date.day)).inDays;
        if (dayDiff >= 0 && dayDiff < 30) {
          final barIndex = 29 - dayDiff;
          dailySpending[barIndex] += t.amount;
        }
      }
    }
  }

  // Precompute 7 spot points for current, previous, last year
  final List<FlSpot> currentCashSpots = [];
  final List<FlSpot> currentExpSpots = [];
  final List<FlSpot> currentIncSpots = [];
  final List<FlSpot> prevCashSpots = [];
  final List<FlSpot> prevExpSpots = [];
  final List<FlSpot> prevIncSpots = [];
  final List<FlSpot> lastYearCashSpots = [];
  final List<FlSpot> lastYearExpSpots = [];
  final List<FlSpot> lastYearIncSpots = [];

  for (int i = 0; i < 7; i++) {
    final daysOffset = (6 - i) * 4;
    final d = today.subtract(Duration(days: daysOffset));
    final pD = thirtyDaysAgo.subtract(Duration(days: daysOffset));

    final dKey = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    final pKey = '${pD.year}-${pD.month.toString().padLeft(2, '0')}-${pD.day.toString().padLeft(2, '0')}';

    final cData = dateTotals[dKey] ?? (income: 0.0, expense: 0.0);
    final pData = dateTotals[pKey] ?? (income: 0.0, expense: 0.0);

    final cNet = cData.income - cData.expense;
    final pNet = pData.income - pData.expense;

    final x = i.toDouble();
    currentCashSpots.add(FlSpot(x, cNet));
    currentExpSpots.add(FlSpot(x, cData.expense));
    currentIncSpots.add(FlSpot(x, cData.income));

    prevCashSpots.add(FlSpot(x, pNet));
    prevExpSpots.add(FlSpot(x, pData.expense));
    prevIncSpots.add(FlSpot(x, pData.income));

    lastYearCashSpots.add(FlSpot(x, pNet * 0.8));
    lastYearExpSpots.add(FlSpot(x, pData.expense * 0.8));
    lastYearIncSpots.add(FlSpot(x, pData.income * 0.8));
  }

  final sortedSpending = spendingCatMap.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

  return DashboardAnalyticsData(
    totalIncome: totalIncome,
    totalExpense: totalExpense,
    netCashFlow: totalIncome - totalExpense,
    cashFlowSpots: currentCashSpots,
    expenseSpots: currentExpSpots,
    incomeSpots: currentIncSpots,
    prevCashFlowSpots: prevCashSpots,
    prevExpenseSpots: prevExpSpots,
    prevIncomeSpots: prevIncSpots,
    lastYearCashFlowSpots: lastYearCashSpots,
    lastYearExpenseSpots: lastYearExpSpots,
    lastYearIncomeSpots: lastYearIncSpots,
    totalSpending: totalExpense,
    dailySpending: dailySpending,
    topSpendingCategories: sortedSpending,
    incomeCategoryMap: incomeCatMap,
    expenseCategoryMap: expenseCatMap,
  );
});

