import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/utils.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/category_icon.dart';
import '../../widgets/account_icon.dart';
import '../../core/layout/responsive.dart';

/// Debts screen — "I Lent" (direction = 'lent')
class DebtsScreen extends ConsumerWidget {
  const DebtsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = ref.watch(debtCreditProvider);
    final accounts = ref.watch(accountsProvider);
    final categories = ref.watch(categoriesProvider);
    final lent = all.where((d) => d.direction == 'lent').toList();
    final active = lent.where((d) => d.status == 'active').toList();
    final closed = lent.where((d) => d.status == 'closed').toList();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        context.go('/dashboard');
      },
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          drawer: context.isWide ? null : const AppDrawer(),
          appBar: AppBar(
            leading: context.isWide ? null : Builder(
              builder: (ctx) => IconButton(
                icon: const Icon(Icons.menu_rounded),
                onPressed: () => Scaffold.of(ctx).openDrawer(),
              ),
            ),
            title: const Text('Debts (I Lent)'),
            bottom: const TabBar(tabs: [Tab(text: 'Active'), Tab(text: 'Recovered')]),
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _showAddSheet(context, ref, accounts, categories),
            child: const Icon(Icons.add_rounded, size: 28),
          ),
          body: TabBarView(
            children: [
              _DebtList(items: active, accounts: accounts, categories: categories, ref: ref, direction: 'lent'),
              _DebtList(items: closed, accounts: accounts, categories: categories, ref: ref, isClosed: true, direction: 'lent'),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddSheet(
    BuildContext context,
    WidgetRef ref,
    List<Account> accounts,
    List<Category> categories, {
    DebtCredit? existing,
  }) {
    showAppSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _DebtCreditSheet(
        ref: ref,
        accounts: accounts,
        categories: categories,
        direction: 'lent',
        existing: existing,
      ),
    );
  }
}

/// Credits screen — "I Borrowed" (direction = 'borrowed')
class CreditsScreen extends ConsumerWidget {
  const CreditsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = ref.watch(debtCreditProvider);
    final accounts = ref.watch(accountsProvider);
    final categories = ref.watch(categoriesProvider);
    final borrowed = all.where((d) => d.direction == 'borrowed').toList();
    final active = borrowed.where((d) => d.status == 'active').toList();
    final closed = borrowed.where((d) => d.status == 'closed').toList();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        context.go('/dashboard');
      },
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          drawer: context.isWide ? null : const AppDrawer(),
          appBar: AppBar(
            leading: context.isWide ? null : Builder(
              builder: (ctx) => IconButton(
                icon: const Icon(Icons.menu_rounded),
                onPressed: () => Scaffold.of(ctx).openDrawer(),
              ),
            ),
            title: const Text('Credits (I Borrowed)'),
            bottom: const TabBar(tabs: [Tab(text: 'Active'), Tab(text: 'Repaid')]),
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _showAddSheet(context, ref, accounts, categories),
            child: const Icon(Icons.add_rounded, size: 28),
          ),
          body: TabBarView(
            children: [
              _DebtList(items: active, accounts: accounts, categories: categories, ref: ref, direction: 'borrowed'),
              _DebtList(items: closed, accounts: accounts, categories: categories, ref: ref, isClosed: true, direction: 'borrowed'),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddSheet(
    BuildContext context,
    WidgetRef ref,
    List<Account> accounts,
    List<Category> categories, {
    DebtCredit? existing,
  }) {
    showAppSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _DebtCreditSheet(
        ref: ref,
        accounts: accounts,
        categories: categories,
        direction: 'borrowed',
        existing: existing,
      ),
    );
  }
}

// ─── Shared list widget ───────────────────────────────────────────────────────

class _DebtList extends StatelessWidget {
  final List<DebtCredit> items;
  final List<Account> accounts;
  final List<Category> categories;
  final WidgetRef ref;
  final bool isClosed;
  final String direction;

  const _DebtList({
    required this.items,
    required this.accounts,
    required this.categories,
    required this.ref,
    required this.direction,
    this.isClosed = false,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isClosed ? Icons.check_circle_outline_rounded : Icons.people_outline_rounded,
              size: 56,
              color: AppColors.darkTextMuted,
            ),
            const SizedBox(height: 12),
            Text(
              isClosed ? 'No settled records' : 'No active entries',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      );
    }

    return ResponsiveList.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
      itemCount: items.length,
      itemBuilder: (ctx, i) {
        final d = items[i];
        final acc = accounts.firstWhereOrNull((a) => a.id == d.accountId);
        final cat = categories.firstWhereOrNull((c) => c.id == d.categoryId);
        final overdue = d.dueDate != null && d.dueDate!.isBefore(DateTime.now()) && !isClosed;
        final color = d.direction == 'lent' ? AppColors.income : AppColors.expense;

        final isDark = Theme.of(context).brightness == Brightness.dark;

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.15),
              child: Text(
                d.personName.isNotEmpty ? d.personName[0].toUpperCase() : '?',
                style: TextStyle(color: color, fontWeight: FontWeight.bold),
              ),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    d.personName,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (!d.affectsAccount) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkCardAlt : AppColors.lightBg,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                    ),
                    child: Text(
                      'No Balance Effect',
                      style: TextStyle(
                        fontSize: 9,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      '${d.direction == 'lent' ? 'Lent' : 'Borrowed'}: ${DateUtil.formatDate(d.startDate)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11),
                    ),
                    if (cat != null) ...[
                      const SizedBox(width: 6),
                      Text('• ${cat.name}', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11)),
                    ],
                  ],
                ),
                if (d.dueDate != null)
                  Text(
                    'Due: ${DateUtil.formatDate(d.dueDate!)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: overdue ? AppColors.expense : AppColors.darkTextSecondary,
                      fontWeight: overdue ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                Text(
                  '${acc?.emoji ?? '💳'} ${acc?.name ?? ''}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 10),
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      CurrencyUtil.format(d.amount, acc?.currency ?? 'INR'),
                      style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                    if (isClosed)
                      const Text('Settled ✓', style: TextStyle(fontSize: 11, color: AppColors.income, fontWeight: FontWeight.bold)),
                  ],
                ),
                if (isClosed) ...[
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.undo_rounded, color: AppColors.accent, size: 22),
                    tooltip: d.direction == 'lent' ? 'Undo Recovered' : 'Undo Repaid',
                    onPressed: () => _confirmUndo(context, d),
                  ),
                ],
              ],
            ),
            isThreeLine: true,
            onTap: () => _showOptions(context, d),
          ),
        ).animate().fadeIn(delay: Duration(milliseconds: i * 40), duration: 300.ms);
      },
    );
  }

  void _confirmUndo(BuildContext context, DebtCredit d) {
    final isLent = d.direction == 'lent';
    final acc = accounts.firstWhereOrNull((a) => a.id == d.accountId);
    final cur = acc?.currency ?? 'INR';
    final formattedAmt = CurrencyUtil.format(d.amount, cur);

    showDialog(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.undo_rounded, color: AppColors.accent),
            const SizedBox(width: 8),
            Text(isLent ? 'Undo Recovery' : 'Undo Repayment'),
          ],
        ),
        content: Text(
          'Revert this record for "${d.personName}" back to active?\n\n'
          '• Status will return to Active.\n'
          '${d.affectsAccount ? "• The ${isLent ? 'recovery (+$formattedAmt)' : 'repayment (-$formattedAmt)'} transaction record will be deleted and account balance restored." : "• No account balance was affected."}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(dCtx);
              await ref.read(debtCreditProvider.notifier).reopen(d);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    behavior: SnackBarBehavior.floating,
                    content: Text(
                      isLent
                          ? 'Recovery undone! Debt moved back to Active.'
                          : 'Repayment undone! Credit moved back to Active.',
                    ),
                  ),
                );
              }
            },
            child: const Text('Undo & Reopen', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showOptions(BuildContext context, DebtCredit d) {
    final isLent = d.direction == 'lent';
    showAppSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Text(
                      '${d.personName} • ${CurrencyUtil.format(d.amount, 'INR')}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
              ),
              if (!isClosed) ...[
                ListTile(
                  leading: const Icon(Icons.check_circle_outline_rounded, color: AppColors.income),
                  title: Text(isLent ? 'Mark as Recovered' : 'Mark as Repaid'),
                  subtitle: Text(
                    d.affectsAccount
                        ? (isLent ? 'Deposits money back into account balance' : 'Deducts repayment from account balance')
                        : 'Settles this record without altering account balance',
                  ),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await ref.read(debtCreditProvider.notifier).close(d, affectBalance: d.affectsAccount);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          behavior: SnackBarBehavior.floating,
                          content: Text(isLent ? 'Marked as recovered!' : 'Marked as repaid!'),
                        ),
                      );
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.edit_outlined, color: AppColors.primary),
                  title: const Text('Edit Details'),
                  onTap: () {
                    Navigator.pop(ctx);
                    showAppSheet(
                      context: context,
                      isScrollControlled: true,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                      ),
                      builder: (_) => _DebtCreditSheet(
                        ref: ref,
                        accounts: accounts,
                        categories: categories,
                        direction: d.direction,
                        existing: d,
                      ),
                    );
                  },
                ),
              ] else ...[
                ListTile(
                  leading: const Icon(Icons.undo_rounded, color: AppColors.accent),
                  title: Text(isLent ? 'Undo Recovered' : 'Undo Repaid'),
                  subtitle: Text(
                    isLent
                        ? 'Revert to active debt and remove recovery transaction'
                        : 'Revert to active credit and remove repayment transaction',
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _confirmUndo(context, d);
                  },
                ),
              ],
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: AppColors.expense),
                title: const Text('Delete Record', style: TextStyle(color: AppColors.expense)),
                onTap: () async {
                  Navigator.pop(ctx);
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (dCtx) => AlertDialog(
                      title: const Text('Delete Record'),
                      content: Text('Delete this ${isLent ? "debt" : "credit"} record for ${d.personName}?'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Cancel')),
                        TextButton(
                          onPressed: () => Navigator.pop(dCtx, true),
                          child: const Text('Delete', style: TextStyle(color: AppColors.expense)),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    await ref.read(debtCreditProvider.notifier).delete(d);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Add/Edit Sheet ───────────────────────────────────────────────────────────

class _DebtCreditSheet extends StatefulWidget {
  final WidgetRef ref;
  final List<Account> accounts;
  final List<Category> categories;
  final String direction;
  final DebtCredit? existing;

  const _DebtCreditSheet({
    required this.ref,
    required this.accounts,
    required this.categories,
    required this.direction,
    this.existing,
  });

  @override
  State<_DebtCreditSheet> createState() => _DebtCreditSheetState();
}

class _DebtCreditSheetState extends State<_DebtCreditSheet> {
  final _nameCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String? _accountId;
  String? _selectedParentCategoryId;
  String? _selectedSubcategoryId;
  DateTime _startDate = DateTime.now();
  DateTime? _dueDate;
  bool _affectsAccount = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final d = widget.existing;
    if (d != null) {
      _nameCtrl.text = d.personName;
      _amountCtrl.text = d.amount.toString();
      _notesCtrl.text = d.notes;
      _accountId = d.accountId;
      _startDate = d.startDate;
      _dueDate = d.dueDate;
      _affectsAccount = d.affectsAccount;
      if (d.categoryId != null) {
        final matched = widget.categories.firstWhereOrNull((c) => c.id == d.categoryId);
        if (matched != null) {
          if (matched.parentId != null && matched.parentId!.isNotEmpty) {
            _selectedParentCategoryId = matched.parentId;
            _selectedSubcategoryId = matched.id;
          } else {
            _selectedParentCategoryId = matched.id;
            _selectedSubcategoryId = null;
          }
        }
      }
    } else {
      if (widget.accounts.isNotEmpty) _accountId = widget.accounts.first.id;
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      _affectsAccount = !_startDate.isBefore(today);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _amountCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty || _accountId == null) return;
    final amount = double.tryParse(_amountCtrl.text) ?? 0;
    final isLent = (widget.existing?.direction ?? widget.direction) == 'lent';
    final effectiveCategoryId = _selectedSubcategoryId ?? _selectedParentCategoryId;
    setState(() => _saving = true);

    if (widget.existing != null) {
      final old = widget.existing!;
      final updated = DebtCredit(
        id: old.id,
        direction: old.direction,
        personName: _nameCtrl.text.trim(),
        amount: amount,
        accountId: _accountId!,
        categoryId: effectiveCategoryId,
        startDate: _startDate,
        dueDate: _dueDate,
        status: old.status,
        notes: _notesCtrl.text.trim(),
        affectsAccount: _affectsAccount,
        transactionId: old.transactionId,
      );
      await widget.ref.read(debtCreditProvider.notifier).update(old, updated);
    } else {
      final dc = DebtCredit(
        id: '',
        direction: widget.direction,
        personName: _nameCtrl.text.trim(),
        amount: amount,
        accountId: _accountId!,
        categoryId: effectiveCategoryId,
        startDate: _startDate,
        dueDate: _dueDate,
        notes: _notesCtrl.text.trim(),
        affectsAccount: _affectsAccount,
      );
      await widget.ref.read(debtCreditProvider.notifier).add(dc);
    }
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isLent
                ? (_affectsAccount
                    ? (widget.existing != null ? 'Debt updated & balance adjusted' : 'Debt added & transaction recorded!')
                    : 'Debt recorded (opening balance, no balance change)')
                : (_affectsAccount
                    ? (widget.existing != null ? 'Credit updated & balance adjusted' : 'Credit added & transaction recorded!')
                    : 'Credit recorded (opening balance, no balance change)'),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLent = widget.direction == 'lent';
    final selectedAcc = widget.accounts.firstWhereOrNull((a) => a.id == _accountId);
    final catType = isLent ? 'expense' : 'income';
    final parentCategories = widget.categories
        .where((c) => (c.type == catType || catType.isEmpty) && (c.parentId == null || c.parentId!.isEmpty))
        .toList();
    final subcategories = _selectedParentCategoryId != null
        ? widget.categories.where((c) => c.parentId == _selectedParentCategoryId).toList()
        : <Category>[];

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.92),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  Text(
                    widget.existing != null
                        ? (isLent ? 'Edit Debt' : 'Edit Credit')
                        : (isLent ? 'Add Debt (I Lent)' : 'Add Credit (I Borrowed)'),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    TextField(
                      controller: _nameCtrl,
                      decoration: InputDecoration(
                        labelText: isLent ? 'Borrower Name (Who took money)' : 'Lender Name (Who gave money)',
                        hintText: 'e.g. John Doe, Sarah',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _amountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                      decoration: InputDecoration(
                        labelText: 'Amount',
                        prefixText: '${CurrencyUtil.symbol(selectedAcc?.currency ?? 'INR')} ',
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _accountId,
                      isExpanded: true,
                      items: widget.accounts
                          .map((a) => DropdownMenuItem(
                                value: a.id,
                                child: Row(
                                  children: [
                                    AccountIcon(account: a, size: 18),
                                    const SizedBox(width: 8),
                                    Expanded(child: Text(a.name, overflow: TextOverflow.ellipsis)),
                                  ],
                                ),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => _accountId = v),
                      decoration: const InputDecoration(labelText: 'Account'),
                      dropdownColor: Theme.of(context).brightness == Brightness.dark ? AppColors.darkCard : AppColors.lightCard,
                    ),
                    // Category & Subcategory Row
                    if (_selectedParentCategoryId != null && subcategories.isNotEmpty) ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String?>(
                              key: ValueKey('debt_parent_$_selectedParentCategoryId'),
                              initialValue: _selectedParentCategoryId,
                              isExpanded: true,
                              items: [
                                const DropdownMenuItem(value: null, child: Text('None', overflow: TextOverflow.ellipsis)),
                                ...parentCategories.map((c) => DropdownMenuItem(
                                      value: c.id,
                                      child: Row(
                                        children: [
                                          CategoryIcon(category: c, size: 16),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(c.name,
                                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                                overflow: TextOverflow.ellipsis),
                                          ),
                                        ],
                                      ),
                                    )),
                              ],
                              onChanged: (v) => setState(() {
                                _selectedParentCategoryId = v;
                                _selectedSubcategoryId = null;
                              }),
                              decoration: const InputDecoration(labelText: 'Category'),
                              dropdownColor: Theme.of(context).brightness == Brightness.dark ? AppColors.darkCard : AppColors.lightCard,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: DropdownButtonFormField<String?>(
                              key: ValueKey('debt_sub_$_selectedSubcategoryId'),
                              initialValue: _selectedSubcategoryId,
                              isExpanded: true,
                              items: [
                                DropdownMenuItem(
                                  value: null,
                                  child: Text(
                                    'All / General',
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Theme.of(context).brightness == Brightness.dark
                                          ? AppColors.darkTextSecondary
                                          : AppColors.lightTextSecondary,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                ...subcategories.map((sub) => DropdownMenuItem(
                                      value: sub.id,
                                      child: Row(
                                        children: [
                                          CategoryIcon(category: sub, size: 16),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(sub.name, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
                                          ),
                                        ],
                                      ),
                                    )),
                              ],
                              onChanged: (v) => setState(() => _selectedSubcategoryId = v),
                              decoration: const InputDecoration(labelText: 'Subcategory'),
                              dropdownColor: Theme.of(context).brightness == Brightness.dark ? AppColors.darkCard : AppColors.lightCard,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ] else ...[
                      DropdownButtonFormField<String?>(
                        key: ValueKey('debt_parent_$_selectedParentCategoryId'),
                        initialValue: _selectedParentCategoryId,
                        isExpanded: true,
                        items: [
                          const DropdownMenuItem(value: null, child: Text('No Category', overflow: TextOverflow.ellipsis)),
                          ...parentCategories.map((c) => DropdownMenuItem(
                                value: c.id,
                                child: Row(
                                  children: [
                                    CategoryIcon(category: c, size: 18),
                                    const SizedBox(width: 8),
                                    Expanded(child: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
                                  ],
                                ),
                              )),
                        ],
                        onChanged: (v) => setState(() {
                          _selectedParentCategoryId = v;
                          _selectedSubcategoryId = null;
                        }),
                        decoration: const InputDecoration(labelText: 'Category (Optional)'),
                        dropdownColor: Theme.of(context).brightness == Brightness.dark ? AppColors.darkCard : AppColors.lightCard,
                      ),
                      const SizedBox(height: 12),
                    ],
                    // Start date
                    InkWell(
                      onTap: () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: _startDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );
                        if (d != null) {
                          setState(() {
                            _startDate = d;
                          });
                        }
                      },
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: isLent ? 'Lent Date' : 'Borrowed Date',
                          suffixIcon: const Icon(Icons.calendar_today_rounded),
                        ),
                        child: Text(DateUtil.formatDate(_startDate)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Due date
                    InkWell(
                      onTap: () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: _dueDate ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );
                        if (d != null) setState(() => _dueDate = d);
                      },
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Due Date (optional)',
                          suffixIcon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_dueDate != null)
                                IconButton(
                                  icon: const Icon(Icons.clear, size: 16),
                                  onPressed: () => setState(() => _dueDate = null),
                                ),
                              const Icon(Icons.calendar_today_rounded),
                            ],
                          ),
                        ),
                        child: Text(_dueDate != null ? DateUtil.formatDate(_dueDate!) : 'No due date set'),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ─── Affect Account Balance Toggle ───
                    Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark ? AppColors.darkCardAlt : AppColors.lightBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _affectsAccount
                              ? AppColors.primary.withValues(alpha: 0.4)
                              : (Theme.of(context).brightness == Brightness.dark ? AppColors.darkBorder : AppColors.lightBorder),
                        ),
                      ),
                      child: SwitchListTile(
                        value: _affectsAccount,
                        onChanged: (val) => setState(() => _affectsAccount = val),
                        activeThumbColor: AppColors.primary,
                        title: const Text(
                          'Affect Account Balance',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                        subtitle: Text(
                          _affectsAccount
                              ? (isLent
                                  ? 'Deducts ${CurrencyUtil.format(double.tryParse(_amountCtrl.text) ?? 0, selectedAcc?.currency ?? 'INR')} from ${selectedAcc?.name ?? 'account'} & records transaction'
                                  : 'Adds ${CurrencyUtil.format(double.tryParse(_amountCtrl.text) ?? 0, selectedAcc?.currency ?? 'INR')} to ${selectedAcc?.name ?? 'account'} & records transaction')
                              : 'Opening balance record — does NOT change account balance or create transaction',
                          style: TextStyle(
                            fontSize: 11,
                            color: _affectsAccount
                                ? AppColors.primary
                                : (Theme.of(context).brightness == Brightness.dark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),
                    TextField(
                      controller: _notesCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(labelText: 'Notes (optional)'),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _save,
                        child: _saving
                            ? const CircularProgressIndicator(color: Colors.white)
                            : Text(widget.existing != null ? 'Update Record' : 'Save Record'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
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
