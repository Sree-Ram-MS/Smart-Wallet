import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/utils.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/category_icon.dart';
import '../../widgets/account_icon.dart';

const _uuid = Uuid();

class _SplitMemberEntry {
  final String id;
  final TextEditingController nameCtrl;
  final TextEditingController amountCtrl;
  bool isPaid;

  _SplitMemberEntry({
    required this.id,
    required String name,
    required double amount,
    this.isPaid = false,
  })  : nameCtrl = TextEditingController(text: name),
        amountCtrl = TextEditingController(
            text: amount > 0
                ? amount.toStringAsFixed(amount.truncateToDouble() == amount ? 0 : 2)
                : '');

  void dispose() {
    nameCtrl.dispose();
    amountCtrl.dispose();
  }
}

class PlannedPaymentsScreen extends ConsumerWidget {
  const PlannedPaymentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final payments = ref.watch(plannedPaymentsProvider);
    final accounts = ref.watch(accountsProvider);
    final categories = ref.watch(categoriesProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        context.go('/dashboard');
      },
      child: Scaffold(
        drawer: const AppDrawer(),
        appBar: AppBar(
          leading: Builder(
            builder: (ctx) => IconButton(
              icon: const Icon(Icons.menu_rounded),
              onPressed: () => Scaffold.of(ctx).openDrawer(),
            ),
          ),
          title: const Text('Planned Payments'),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _showAddSheet(context, ref, accounts, categories),
          child: const Icon(Icons.add_rounded),
        ),
        body: payments.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.calendar_month_outlined, size: 56, color: AppColors.darkTextMuted),
                    const SizedBox(height: 12),
                    Text('No planned payments', style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(height: 4),
                    Text('Add subscriptions, EMIs, or bills',
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                itemCount: payments.length,
                itemBuilder: (ctx, i) {
                  final p = payments[i];
                  final acc = accounts.firstWhereOrNull((a) => a.id == p.accountId);
                  final cat = categories.firstWhereOrNull((c) => c.id == p.categoryId);
                  final isPaidToday = p.lastPaidDate != null && DateUtil.isSameDay(p.lastPaidDate!, DateTime.now());
                  final overdue = p.nextDueDate.isBefore(DateTime.now()) && !p.isCompleted;

                  String endInfo = '';
                  if (p.isRecurring) {
                    if (p.endType == 'occurrences') {
                      endInfo = ' • ${p.currentOccurrence}/${p.totalOccurrences ?? '∞'} times';
                    } else if (p.endType == 'until_date' && p.untilDate != null) {
                      endInfo = ' • Till ${DateUtil.formatShort(p.untilDate!)}';
                    } else {
                      endInfo = ' • Ongoing';
                    }
                  }

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: p.isCompleted || isPaidToday
                                      ? AppColors.income.withValues(alpha: 0.15)
                                      : overdue
                                          ? AppColors.expense.withValues(alpha: 0.15)
                                          : AppColors.primary.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Center(
                                  child: CategoryIcon(category: cat, defaultEmoji: '📅', size: 24, fontSize: 22),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            p.name,
                                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                  fontWeight: FontWeight.w600,
                                                  decoration: p.isCompleted
                                                      ? TextDecoration.lineThrough
                                                      : null,
                                                ),
                                          ),
                                        ),
                                        if (p.isCompleted)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: AppColors.income.withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: const Text('COMPLETED',
                                                style: TextStyle(
                                                    color: AppColors.income,
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold)),
                                          )
                                        else if (isPaidToday)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: AppColors.income.withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: const Text('PAID TODAY',
                                                style: TextStyle(
                                                    color: AppColors.income,
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold)),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      isPaidToday
                                          ? 'Next: ${DateUtil.formatDate(p.nextDueDate)}${p.isRecurring ? ' • ${p.period?.toUpperCase()}$endInfo' : ''}'
                                          : 'Due: ${DateUtil.formatDate(p.nextDueDate)}${p.isRecurring ? ' • ${p.period?.toUpperCase()}$endInfo' : ''}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: p.isCompleted
                                            ? AppColors.darkTextMuted
                                            : isPaidToday
                                                ? AppColors.income
                                                : overdue
                                                    ? AppColors.expense
                                                    : null,
                                        fontWeight: overdue || isPaidToday ? FontWeight.w600 : FontWeight.normal,
                                      ),
                                    ),
                                     Text(
                                       '${acc?.emoji ?? '💳'} ${acc?.name ?? ''}',
                                       style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11),
                                     ),
                                     if (p.isSplit && p.splits != null && p.splits!.isNotEmpty) ...[
                                       const SizedBox(height: 4),
                                       Container(
                                         padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                         decoration: BoxDecoration(
                                           color: AppColors.primary.withValues(alpha: 0.15),
                                           borderRadius: BorderRadius.circular(5),
                                         ),
                                         child: Row(
                                           mainAxisSize: MainAxisSize.min,
                                           children: [
                                             const Icon(Icons.call_split_rounded, size: 11, color: AppColors.primary),
                                             const SizedBox(width: 4),
                                             Text(
                                               'Split (${p.splits!.length} friends • ${CurrencyUtil.format(p.splits!.fold(0.0, (s, e) => s + e.amount), acc?.currency ?? 'INR')} share)',
                                               style: const TextStyle(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.w600),
                                             ),
                                           ],
                                         ),
                                       ),
                                     ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    CurrencyUtil.format(p.amount, acc?.currency ?? 'INR'),
                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                                  ),
                                  if (p.isRecurring)
                                    const Icon(Icons.repeat_rounded, size: 14, color: AppColors.primary),
                                ],
                              ),
                            ],
                          ),
                          if (!p.isCompleted) ...[
                            const SizedBox(height: 10),
                            const Divider(height: 1),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton.icon(
                                  icon: const Icon(Icons.edit_outlined, size: 16),
                                  label: const Text('Edit', style: TextStyle(fontSize: 12)),
                                  onPressed: () => _showAddSheet(context, ref, accounts, categories, existing: p),
                                ),
                                const SizedBox(width: 8),
                                if (isPaidToday)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: AppColors.income.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: AppColors.income.withValues(alpha: 0.4)),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.check_circle_rounded, size: 14, color: AppColors.income),
                                        SizedBox(width: 4),
                                        Text(
                                          'Paid Today',
                                          style: TextStyle(
                                            color: AppColors.income,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                else
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                                    label: const Text('Mark Paid', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                    onPressed: () async {
                                      await ref.read(plannedPaymentsProvider.notifier).markPaid(p);
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Marked "${p.name}" as paid & recorded transaction!'),
                                            backgroundColor: AppColors.darkCard,
                                          ),
                                        );
                                      }
                                    },
                                  ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ).animate().fadeIn(delay: Duration(milliseconds: i * 40), duration: 300.ms);
                },
              ),
      ),
    );
  }

  void _showAddSheet(BuildContext context, WidgetRef ref, List<Account> accounts,
      List<Category> categories, {PlannedPayment? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _PlannedPaymentSheet(
        ref: ref,
        accounts: accounts,
        categories: categories,
        existing: existing,
      ),
    );
  }
}

class _PlannedPaymentSheet extends StatefulWidget {
  final WidgetRef ref;
  final List<Account> accounts;
  final List<Category> categories;
  final PlannedPayment? existing;

  const _PlannedPaymentSheet({
    required this.ref,
    required this.accounts,
    required this.categories,
    this.existing,
  });

  @override
  State<_PlannedPaymentSheet> createState() => _PlannedPaymentSheetState();
}

class _PlannedPaymentSheetState extends State<_PlannedPaymentSheet> {
  final _nameCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _occurrencesCtrl = TextEditingController(text: '12');
  String? _accountId;
  String? _selectedParentCategoryId;
  String? _selectedSubcategoryId;
  bool _isRecurring = false;
  String _period = 'monthly';
  DateTime _dueDate = DateTime.now().add(const Duration(days: 30));
  String _endType = 'never'; // 'never' | 'until_date' | 'occurrences'
  DateTime? _untilDate;
  bool _saving = false;
  bool _isSplit = false;
  List<_SplitMemberEntry> _splitEntries = [];

  @override
  void initState() {
    super.initState();
    final p = widget.existing;
    if (p != null) {
      _nameCtrl.text = p.name;
      _amountCtrl.text = p.amount > 0 ? p.amount.toString() : '';
      _noteCtrl.text = p.note;
      _accountId = p.accountId;
      _isRecurring = p.isRecurring;
      _period = p.period ?? 'monthly';
      _dueDate = p.nextDueDate;
      _endType = p.endType;
      _untilDate = p.untilDate;
      _isSplit = p.isSplit;
      if (p.isSplit && p.splits != null && p.splits!.isNotEmpty) {
        _splitEntries = p.splits!
            .map((s) => _SplitMemberEntry(id: s.id, name: s.name, amount: s.amount, isPaid: s.isPaid))
            .toList();
      }
      if (p.totalOccurrences != null) {
        _occurrencesCtrl.text = p.totalOccurrences.toString();
      }
      if (p.categoryId != null) {
        final matched = widget.categories.firstWhereOrNull((c) => c.id == p.categoryId);
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
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    _occurrencesCtrl.dispose();
    for (final e in _splitEntries) {
      e.dispose();
    }
    super.dispose();
  }

  void _addSplitMember() {
    setState(() {
      _splitEntries.add(_SplitMemberEntry(
        id: _uuid.v4(),
        name: 'Friend ${_splitEntries.length + 1}',
        amount: 0,
      ));
      _splitEqually();
    });
  }

  void _removeSplitMember(int index) {
    setState(() {
      _splitEntries[index].dispose();
      _splitEntries.removeAt(index);
      if (_splitEntries.isNotEmpty) {
        _splitEqually();
      }
    });
  }

  void _splitEqually() {
    final total = double.tryParse(_amountCtrl.text) ?? 0;
    if (total <= 0 || _splitEntries.isEmpty) return;
    final count = _splitEntries.length + 1; // You + friends
    final each = (total / count).roundToDouble();
    for (final e in _splitEntries) {
      e.amountCtrl.text = each.toStringAsFixed(0);
    }
  }

  Future<void> _save() async {
    if (_nameCtrl.text.isEmpty || _accountId == null) return;
    final amount = double.tryParse(_amountCtrl.text) ?? 0;
    final totalOcc = _isRecurring && _endType == 'occurrences'
        ? int.tryParse(_occurrencesCtrl.text)
        : null;
    final effectiveCategoryId = _selectedSubcategoryId ?? _selectedParentCategoryId;

    List<SplitMember>? splits;
    if (_isSplit && _splitEntries.isNotEmpty) {
      splits = _splitEntries
          .map((e) => SplitMember(
                id: e.id,
                name: e.nameCtrl.text.trim().isEmpty ? 'Friend' : e.nameCtrl.text.trim(),
                amount: double.tryParse(e.amountCtrl.text) ?? 0,
                isPaid: false,
              ))
          .toList();
    }

    setState(() => _saving = true);

    if (widget.existing != null) {
      final p = widget.existing!;
      p.name = _nameCtrl.text;
      p.amount = amount;
      p.accountId = _accountId!;
      p.categoryId = effectiveCategoryId;
      p.isRecurring = _isRecurring;
      p.period = _isRecurring ? _period : null;
      p.nextDueDate = _dueDate;
      p.note = _noteCtrl.text;
      p.endType = _isRecurring ? _endType : 'never';
      p.untilDate = _isRecurring && _endType == 'until_date' ? _untilDate : null;
      p.totalOccurrences = totalOcc;
      p.isSplit = _isSplit;
      p.splits = splits;
      await widget.ref.read(plannedPaymentsProvider.notifier).update(p);
    } else {
      final p = PlannedPayment(
        id: '',
        name: _nameCtrl.text,
        amount: amount,
        accountId: _accountId!,
        categoryId: effectiveCategoryId,
        isRecurring: _isRecurring,
        period: _isRecurring ? _period : null,
        nextDueDate: _dueDate,
        note: _noteCtrl.text,
        endType: _isRecurring ? _endType : 'never',
        untilDate: _isRecurring && _endType == 'until_date' ? _untilDate : null,
        totalOccurrences: totalOcc,
        currentOccurrence: 1,
        isCompleted: false,
        isSplit: _isSplit,
        splits: splits,
      );
      await widget.ref.read(plannedPaymentsProvider.notifier).add(p);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final parentCategories = widget.categories
        .where((c) => c.type == 'expense' && (c.parentId == null || c.parentId!.isEmpty))
        .toList();
    final subcategories = _selectedParentCategoryId != null
        ? widget.categories.where((c) => c.parentId == _selectedParentCategoryId).toList()
        : <Category>[];

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedAcc = widget.accounts.firstWhereOrNull((a) => a.id == _accountId);
    final totalAmount = double.tryParse(_amountCtrl.text) ?? 0;
    final friendsTotal = _splitEntries.fold<double>(
        0.0, (s, e) => s + (double.tryParse(e.amountCtrl.text) ?? 0));
    final myShare = totalAmount - friendsTotal;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  Text(
                    widget.existing != null ? 'Edit Payment' : 'Add Planned Payment',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  if (widget.existing != null)
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: AppColors.expense),
                      onPressed: () async {
                        await widget.ref.read(plannedPaymentsProvider.notifier).delete(widget.existing!);
                        if (context.mounted) Navigator.pop(context);
                      },
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
                      decoration: const InputDecoration(labelText: 'Name / Bill (e.g. Netflix, Rent, Car EMI)'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _amountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                      decoration: const InputDecoration(labelText: 'Amount'),
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
                      dropdownColor: isDark ? AppColors.darkCard : AppColors.lightCard,
                    ),
                    // Category & Subcategory Row
                    if (_selectedParentCategoryId != null && subcategories.isNotEmpty) ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String?>(
                              key: ValueKey('planned_parent_$_selectedParentCategoryId'),
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
                              dropdownColor: isDark ? AppColors.darkCard : AppColors.lightCard,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: DropdownButtonFormField<String?>(
                              key: ValueKey('planned_sub_$_selectedSubcategoryId'),
                              initialValue: _selectedSubcategoryId,
                              isExpanded: true,
                              items: [
                                DropdownMenuItem(
                                  value: null,
                                  child: Text(
                                    'All / General',
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
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
                              dropdownColor: isDark ? AppColors.darkCard : AppColors.lightCard,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ] else ...[
                      DropdownButtonFormField<String?>(
                        key: ValueKey('planned_parent_$_selectedParentCategoryId'),
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
                        decoration: const InputDecoration(labelText: 'Category'),
                        dropdownColor: isDark ? AppColors.darkCard : AppColors.lightCard,
                      ),
                      const SizedBox(height: 12),
                    ],
                    // Due date
                    InkWell(
                      onTap: () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: _dueDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );
                        if (d != null) setState(() => _dueDate = d);
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Next Due Date',
                          suffixIcon: Icon(Icons.calendar_today_rounded),
                        ),
                        child: Text(DateUtil.formatDate(_dueDate)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Recurring Switch
                    SwitchListTile(
                      value: _isRecurring,
                      onChanged: (v) => setState(() => _isRecurring = v),
                      title: const Text('Recurring Payment'),
                      subtitle: const Text('Repeats automatically across cycles'),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      tileColor: isDark ? AppColors.darkCardAlt : AppColors.lightBg,
                    ),
                    if (_isRecurring) ...[
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _period,
                        isExpanded: true,
                        items: ['daily', 'weekly', 'monthly', 'yearly']
                            .map((p) => DropdownMenuItem(
                                  value: p,
                                  child: Text(p[0].toUpperCase() + p.substring(1)),
                                ),)
                            .toList(),
                        onChanged: (v) => setState(() => _period = v ?? 'monthly'),
                        decoration: const InputDecoration(labelText: 'Frequency / Cycle'),
                        dropdownColor: isDark ? AppColors.darkCard : AppColors.lightCard,
                      ),
                      const SizedBox(height: 16),

                      // Recurrence End Condition
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkCardAlt : AppColors.lightBg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'How does recurrence end?',
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary,
                                  ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                ChoiceChip(
                                  label: const Text('Ongoing (No End)'),
                                  selected: _endType == 'never',
                                  onSelected: (sel) {
                                    if (sel) setState(() => _endType = 'never');
                                  },
                                ),
                                ChoiceChip(
                                  label: const Text('End on Date'),
                                  selected: _endType == 'until_date',
                                  onSelected: (sel) {
                                    if (sel) {
                                      setState(() {
                                        _endType = 'until_date';
                                        _untilDate ??= DateTime.now().add(const Duration(days: 365));
                                      });
                                    }
                                  },
                                ),
                                ChoiceChip(
                                  label: const Text('End after Occurrences'),
                                  selected: _endType == 'occurrences',
                                  onSelected: (sel) {
                                    if (sel) setState(() => _endType = 'occurrences');
                                  },
                                ),
                              ],
                            ),
                            if (_endType == 'until_date') ...[
                              const SizedBox(height: 14),
                              InkWell(
                                onTap: () async {
                                  final d = await showDatePicker(
                                    context: context,
                                    initialDate: _untilDate ?? DateTime.now().add(const Duration(days: 365)),
                                    firstDate: DateTime.now(),
                                    lastDate: DateTime(2100),
                                  );
                                  if (d != null) setState(() => _untilDate = d);
                                },
                                child: InputDecorator(
                                  decoration: const InputDecoration(
                                    labelText: 'Repeat Until Date',
                                    suffixIcon: Icon(Icons.event_busy_rounded),
                                  ),
                                  child: Text(_untilDate != null
                                      ? DateUtil.formatDate(_untilDate!)
                                      : 'Select Till Date'),
                                ),
                              ),
                            ],
                            if (_endType == 'occurrences') ...[
                              const SizedBox(height: 14),
                              TextField(
                                controller: _occurrencesCtrl,
                                keyboardType: TextInputType.number,
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                decoration: const InputDecoration(
                                  labelText: 'Total Occurrences / Installments',
                                  hintText: 'e.g. 12 times',
                                  suffixText: 'times',
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    // Split Bill Section
                    Container(
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkCardAlt : AppColors.lightBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                      ),
                      child: Column(
                        children: [
                          SwitchListTile(
                            title: const Text('Split with Friends', style: TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Text(
                              _isSplit
                                  ? 'Splitting payment with ${_splitEntries.length} friends'
                                  : 'Split subscriptions, rent, or recurring bills',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                              ),
                            ),
                            value: _isSplit,
                            activeTrackColor: AppColors.primary,
                            onChanged: (val) {
                              setState(() {
                                _isSplit = val;
                                if (val && _splitEntries.isEmpty) {
                                  _splitEntries.add(_SplitMemberEntry(id: _uuid.v4(), name: 'Friend 1', amount: 0));
                                  _splitEqually();
                                }
                              });
                            },
                          ),
                          if (_isSplit) ...[
                            const Divider(height: 1),
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                children: [
                                  // Summary calculation banner
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: isDark ? AppColors.darkCard : AppColors.lightCard,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text('Friends Owe You',
                                                style: TextStyle(
                                                    fontSize: 11,
                                                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)),
                                            Text(
                                              '${CurrencyUtil.symbol(selectedAcc?.currency ?? 'INR')} ${friendsTotal.toStringAsFixed(0)}',
                                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.income),
                                            ),
                                          ],
                                        ),
                                        Container(width: 1, height: 26, color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Text('Your Net Share',
                                                style: TextStyle(
                                                    fontSize: 11,
                                                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)),
                                            Text(
                                              '${CurrencyUtil.symbol(selectedAcc?.currency ?? 'INR')} ${myShare.toStringAsFixed(0)}',
                                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.primary),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 10),

                                  // Quick "Split Equally" Action
                                  Row(
                                    children: [
                                      Text(
                                        'Friends (${_splitEntries.length})',
                                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                      ),
                                      const Spacer(),
                                      InkWell(
                                        onTap: _splitEqually,
                                        borderRadius: BorderRadius.circular(6),
                                        child: const Padding(
                                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          child: Row(
                                            children: [
                                              Icon(Icons.auto_fix_high_rounded, size: 14, color: AppColors.primary),
                                              SizedBox(width: 4),
                                              Text('Split Equally',
                                                  style: TextStyle(
                                                      fontSize: 12,
                                                      color: AppColors.primary,
                                                      fontWeight: FontWeight.w600)),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),

                                  // Friends rows
                                  ..._splitEntries.asMap().entries.map((entry) {
                                    final i = entry.key;
                                    final item = entry.value;
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            flex: 3,
                                            child: TextField(
                                              controller: item.nameCtrl,
                                              decoration: const InputDecoration(
                                                isDense: true,
                                                hintText: 'Friend Name',
                                                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                                prefixIcon: Icon(Icons.person_outline_rounded, size: 18),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            flex: 2,
                                            child: TextField(
                                              controller: item.amountCtrl,
                                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                                              onChanged: (_) => setState(() {}),
                                              decoration: InputDecoration(
                                                isDense: true,
                                                prefixText: '${CurrencyUtil.symbol(selectedAcc?.currency ?? 'INR')} ',
                                                hintText: '0',
                                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                              ),
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.darkTextMuted),
                                            onPressed: () => _removeSplitMember(i),
                                          ),
                                        ],
                                      ),
                                    );
                                  }),

                                  // Add friend button
                                  OutlinedButton.icon(
                                    onPressed: _addSplitMember,
                                    icon: const Icon(Icons.add_rounded, size: 16),
                                    label: const Text('Add Friend', style: TextStyle(fontSize: 12)),
                                    style: OutlinedButton.styleFrom(
                                      visualDensity: VisualDensity.compact,
                                      side: const BorderSide(color: AppColors.primary),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _noteCtrl,
                      decoration: const InputDecoration(labelText: 'Note (optional)'),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _save,
                        child: _saving
                            ? const CircularProgressIndicator(color: Colors.white)
                            : Text(widget.existing != null ? 'Update Payment' : 'Save Payment'),
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

