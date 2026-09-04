import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/utils.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../widgets/add_transaction_sheet.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/category_icon.dart';

class SplitBillsScreen extends ConsumerWidget {
  const SplitBillsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactions = ref.watch(transactionsProvider);
    final accounts = ref.watch(accountsProvider);
    final categories = ref.watch(categoriesProvider);
    final user = ref.watch(userProvider);
    final currency = user?.baseCurrency ?? 'INR';

    final splitTxns = transactions.where((t) => t.isSplit && t.splits != null && t.splits!.isNotEmpty).toList();

    double totalSplitOutflow = 0;
    double totalRecovered = 0;
    double totalPending = 0;

    for (final txn in splitTxns) {
      totalSplitOutflow += txn.amount;
      for (final s in txn.splits!) {
        if (s.isPaid) {
          totalRecovered += s.amount;
        } else {
          totalPending += s.amount;
        }
      }
    }

    final pendingTxns = splitTxns.where((t) => t.splits!.any((s) => !s.isPaid)).toList();
    final settledTxns = splitTxns.where((t) => t.splits!.every((s) => s.isPaid)).toList();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        context.go('/dashboard');
      },
      child: DefaultTabController(
        length: 3,
        child: Scaffold(
          drawer: const AppDrawer(),
          appBar: AppBar(
            leading: Builder(
              builder: (ctx) => IconButton(
                icon: const Icon(Icons.menu_rounded),
                onPressed: () => Scaffold.of(ctx).openDrawer(),
              ),
            ),
            title: const Text('Split Bills & Expenses'),
            bottom: const TabBar(
              tabs: [
                Tab(text: 'Pending'),
                Tab(text: 'Settled'),
                Tab(text: 'All'),
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              builder: (_) => AddTransactionSheet(ref: ref),
            ),
            child: const Icon(Icons.add_rounded, size: 28),
          ),
          body: Column(
            children: [
              // Summary Banner
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.primary.withValues(alpha: 0.15), AppColors.darkCard],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Total Paid Out', style: TextStyle(fontSize: 11, color: AppColors.darkTextSecondary)),
                            const SizedBox(height: 3),
                            Text(
                              '${CurrencyUtil.symbol(currency)}${totalSplitOutflow.toStringAsFixed(0)}',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.darkText),
                            ),
                          ],
                        ),
                      ),
                      Container(width: 1, height: 32, color: AppColors.darkBorder),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Pending to Collect', style: TextStyle(fontSize: 11, color: AppColors.darkTextSecondary)),
                            const SizedBox(height: 3),
                            Text(
                              '${CurrencyUtil.symbol(currency)}${totalPending.toStringAsFixed(0)}',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.expense),
                            ),
                          ],
                        ),
                      ),
                      Container(width: 1, height: 32, color: AppColors.darkBorder),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Collected', style: TextStyle(fontSize: 11, color: AppColors.darkTextSecondary)),
                            const SizedBox(height: 3),
                            Text(
                              '${CurrencyUtil.symbol(currency)}${totalRecovered.toStringAsFixed(0)}',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.income),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Tab Views
              Expanded(
                child: TabBarView(
                  children: [
                    _SplitList(items: pendingTxns, accounts: accounts, categories: categories, currency: currency, ref: ref),
                    _SplitList(items: settledTxns, accounts: accounts, categories: categories, currency: currency, ref: ref),
                    _SplitList(items: splitTxns, accounts: accounts, categories: categories, currency: currency, ref: ref),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SplitList extends StatelessWidget {
  final List<Transaction> items;
  final List<Account> accounts;
  final List<Category> categories;
  final String currency;
  final WidgetRef ref;

  const _SplitList({
    required this.items,
    required this.accounts,
    required this.categories,
    required this.currency,
    required this.ref,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: AppColors.darkCardAlt,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.call_split_rounded, size: 48, color: AppColors.darkTextMuted),
            ),
            const SizedBox(height: 16),
            const Text(
              'No split transactions here',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            const SizedBox(height: 6),
            const Text(
              'When you split expenses with friends, they will appear here.',
              style: TextStyle(color: AppColors.darkTextSecondary, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
      itemCount: items.length,
      separatorBuilder: (_, index) => const SizedBox(height: 12),
      itemBuilder: (ctx, i) {
        final txn = items[i];
        final account = accounts.firstWhereOrNull((a) => a.id == txn.accountId);
        final category = categories.firstWhereOrNull((c) => c.id == txn.categoryId);
        return _SplitCard(
          txn: txn,
          account: account,
          category: category,
          accounts: accounts,
          currency: currency,
          ref: ref,
        );
      },
    );
  }
}

class _SplitCard extends StatelessWidget {
  final Transaction txn;
  final Account? account;
  final Category? category;
  final List<Account> accounts;
  final String currency;
  final WidgetRef ref;

  const _SplitCard({
    required this.txn,
    required this.account,
    required this.category,
    required this.accounts,
    required this.currency,
    required this.ref,
  });

  @override
  Widget build(BuildContext context) {
    final splits = txn.splits ?? [];
    double totalFriends = 0;
    double collected = 0;
    int paidCount = 0;

    for (final s in splits) {
      totalFriends += s.amount;
      if (s.isPaid) {
        collected += s.amount;
        paidCount++;
      }
    }

    final myShare = (txn.amount - totalFriends).clamp(0, double.infinity);
    final isFullySettled = splits.isNotEmpty && paidCount == splits.length;
    final progress = totalFriends > 0 ? (collected / totalFriends).clamp(0.0, 1.0) : 1.0;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.darkCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isFullySettled ? AppColors.income.withValues(alpha: 0.3) : AppColors.darkBorder,
        ),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                CategoryIcon(category: category, defaultEmoji: '🍽️', size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        txn.note.isNotEmpty ? txn.note : (category?.name ?? 'Split Expense'),
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${DateUtil.formatDate(txn.date)} • ${account != null ? '${account!.emoji} ${account!.name}' : 'Account'}',
                        style: const TextStyle(fontSize: 12, color: AppColors.darkTextSecondary),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${CurrencyUtil.symbol(currency)}${txn.amount.toStringAsFixed(0)}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    Text(
                      'My Share: ${CurrencyUtil.symbol(currency)}${myShare.toStringAsFixed(0)}',
                      style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Recovery Progress Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '$paidCount of ${splits.length} friends paid',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isFullySettled ? AppColors.income : AppColors.darkTextSecondary,
                      ),
                    ),
                    Text(
                      '${CurrencyUtil.symbol(currency)}${collected.toStringAsFixed(0)} / ${CurrencyUtil.symbol(currency)}${totalFriends.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isFullySettled ? AppColors.income : AppColors.darkText,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: AppColors.darkCardAlt,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isFullySettled ? AppColors.income : AppColors.primary,
                    ),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),
          const Divider(height: 1),

          // Friends List
          ...splits.map((s) {
            final recAcc = s.paidAccountId != null ? accounts.firstWhereOrNull((a) => a.id == s.paidAccountId) : null;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.darkBorder, width: 0.5)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: s.isPaid ? AppColors.income.withValues(alpha: 0.15) : AppColors.darkCardAlt,
                    child: Icon(
                      s.isPaid ? Icons.check_rounded : Icons.person_outline_rounded,
                      size: 16,
                      color: s.isPaid ? AppColors.income : AppColors.darkTextSecondary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.name,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: s.isPaid ? AppColors.darkText : Colors.white,
                          ),
                        ),
                        if (s.isPaid) ...[
                          Text(
                            'Paid on ${s.paidDate != null ? DateUtil.formatDate(s.paidDate!) : 'Paid'}${recAcc != null ? ' into ${recAcc.emoji} ${recAcc.name}' : ''}',
                            style: const TextStyle(fontSize: 11, color: AppColors.income),
                          ),
                        ] else ...[
                          const Text(
                            'Pending payment',
                            style: TextStyle(fontSize: 11, color: AppColors.expense),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Text(
                    '${CurrencyUtil.symbol(currency)}${s.amount.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: s.isPaid ? AppColors.income : Colors.white,
                    ),
                  ),
                  const SizedBox(width: 10),
                  if (s.isPaid)
                    InkWell(
                      onTap: () => _confirmUnmarkPaid(context, s),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.income.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.income.withValues(alpha: 0.3)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.check_circle_rounded, size: 14, color: AppColors.income),
                            SizedBox(width: 4),
                            Text('Paid', style: TextStyle(fontSize: 11, color: AppColors.income, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    )
                  else
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => _showMarkPaidSheet(context, s),
                      child: const Text('Mark Paid', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
            );
          }),

          // Card Footer actions
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    builder: (_) => AddTransactionSheet(ref: ref, existing: txn),
                  ),
                  icon: const Icon(Icons.edit_outlined, size: 14),
                  label: const Text('Edit Split', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showMarkPaidSheet(BuildContext context, SplitMember member) {
    DateTime selectedDate = DateTime.now();
    String selectedAccId = txn.accountId;
    if (accounts.isNotEmpty && !accounts.any((a) => a.id == selectedAccId)) {
      selectedAccId = accounts.first.id;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(color: AppColors.darkBorder, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.payments_rounded, color: AppColors.income),
                  const SizedBox(width: 8),
                  Text(
                    'Collect ₹${member.amount.toStringAsFixed(0)} from ${member.name}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'This amount will be added to your selected account balance.',
                style: TextStyle(fontSize: 12, color: AppColors.darkTextSecondary),
              ),
              const SizedBox(height: 16),

              // Account Selector
              DropdownButtonFormField<String>(
                initialValue: selectedAccId,
                decoration: const InputDecoration(labelText: 'Received In Account'),
                dropdownColor: AppColors.darkCard,
                items: accounts
                    .map((a) => DropdownMenuItem(
                          value: a.id,
                          child: Text('${a.emoji} ${a.name} (${CurrencyUtil.format(a.balance, a.currency)})'),
                        ))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setModalState(() => selectedAccId = v);
                },
              ),
              const SizedBox(height: 14),

              // Date Picker
              InkWell(
                onTap: () async {
                  final d = await showDatePicker(
                    context: ctx,
                    initialDate: selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (d != null) {
                    setModalState(() => selectedDate = d);
                  }
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Date of Payment',
                    suffixIcon: Icon(Icons.calendar_today_rounded),
                  ),
                  child: Text(DateUtil.formatDate(selectedDate)),
                ),
              ),
              const SizedBox(height: 20),

              // Confirm button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.income,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    Navigator.pop(sheetCtx);
                    await ref.read(transactionsProvider.notifier).markSplitPaid(
                          txn,
                          member.id,
                          paidDate: selectedDate,
                          targetAccountId: selectedAccId,
                        );
                    if (context.mounted) {
                      final acc = accounts.firstWhereOrNull((a) => a.id == selectedAccId);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Collected ₹${member.amount.toStringAsFixed(0)} from ${member.name} & credited to ${acc?.name ?? 'account'}!'),
                          backgroundColor: AppColors.darkCard,
                        ),
                      );
                    }
                  },
                  child: const Text('Confirm Payment Received', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmUnmarkPaid(BuildContext context, SplitMember member) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unmark Payment'),
        content: Text('Are you sure you want to mark ${member.name}\'s payment as unpaid? ₹${member.amount.toStringAsFixed(0)} will be deducted back from your account balance.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.expense),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(transactionsProvider.notifier).unmarkSplitPaid(txn, member.id);
            },
            child: const Text('Unmark'),
          ),
        ],
      ),
    );
  }
}

extension _ListExt<T> on List<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    for (final e in this) {
      if (test(e)) return e;
    }
    return null;
  }
}
