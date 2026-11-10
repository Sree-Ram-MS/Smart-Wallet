import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/theme/app_colors.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../core/utils/utils.dart';
import 'category_icon.dart';
import 'account_icon.dart';
import 'quick_category_dialog.dart';
import '../core/layout/responsive.dart';

const _uuid = Uuid();

class _SplitMemberEntry {
  String id;
  final TextEditingController nameCtrl;
  final TextEditingController amountCtrl;
  bool isPaid;
  DateTime? paidDate;
  String? paidAccountId;

  _SplitMemberEntry({
    required this.id,
    required String name,
    required double amount,
    this.isPaid = false,
    this.paidDate,
    this.paidAccountId,
  })  : nameCtrl = TextEditingController(text: name),
        amountCtrl = TextEditingController(
          text: amount > 0 ? (amount % 1 == 0 ? amount.toInt().toString() : amount.toStringAsFixed(2)) : '',
        );

  void dispose() {
    nameCtrl.dispose();
    amountCtrl.dispose();
  }
}

class AddTransactionSheet extends StatefulWidget {
  final WidgetRef ref;
  final Template? prefill;
  final Transaction? existing;
  final String? initialType;
  final bool initialSplit;
  const AddTransactionSheet({
    super.key,
    required this.ref,
    this.prefill,
    this.existing,
    this.initialType,
    this.initialSplit = false,
  });

  @override
  State<AddTransactionSheet> createState() => _AddTransactionSheetState();
}

class _AddTransactionSheetState extends State<AddTransactionSheet> {
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  String _type = 'expense';
  String? _selectedAccountId;
  String? _toAccountId;
  String? _selectedParentCategoryId;
  String? _selectedSubcategoryId;
  DateTime _date = DateTime.now();
  bool _saving = false;

  bool _isSplit = false;
  List<_SplitMemberEntry> _splitEntries = [];

  @override
  void initState() {
    super.initState();
    if (widget.initialType != null) {
      _type = widget.initialType!;
    }
    if (widget.existing != null) {
      final e = widget.existing!;
      _type = e.type;
      _amountCtrl.text = e.amount > 0 ? e.amount.toString() : '';
      _noteCtrl.text = e.note;
      _selectedAccountId = e.accountId;
      _toAccountId = e.toAccountId;
      _date = e.date;
      if (e.isSplit && e.splits != null && e.splits!.isNotEmpty) {
        _isSplit = true;
        _splitEntries = e.splits!
            .map((s) => _SplitMemberEntry(
                  id: s.id,
                  name: s.name,
                  amount: s.amount,
                  isPaid: s.isPaid,
                  paidDate: s.paidDate,
                  paidAccountId: s.paidAccountId,
                ))
            .toList();
      }
    } else if (widget.prefill != null) {
      final p = widget.prefill!;
      _type = p.type;
      _amountCtrl.text = p.amount > 0 ? p.amount.toString() : '';
      _noteCtrl.text = p.note;
      _selectedAccountId = p.accountId;
    } else {
      final accounts = widget.ref.read(accountsProvider);
      if (accounts.isNotEmpty) _selectedAccountId = accounts.first.id;
    }
    if (_selectedAccountId == null) {
      final accounts = widget.ref.read(accountsProvider);
      if (accounts.isNotEmpty) _selectedAccountId = accounts.first.id;
    }

    if (widget.initialSplit) {
      _isSplit = true;
      _type = 'expense';
      _splitEntries.add(_SplitMemberEntry(
        id: _uuid.v4(),
        name: 'Friend 1',
        amount: 0,
      ));
    }

    final catId = widget.existing?.categoryId ?? widget.prefill?.categoryId;
    if (catId != null) {
      final allCats = widget.ref.read(categoriesProvider);
      final matched = allCats.firstWhereOrNull((c) => c.id == catId);
      if (matched != null && (matched.type == _type || _type == 'transfer')) {
        if (matched.parentId != null && matched.parentId!.isNotEmpty) {
          _selectedParentCategoryId = matched.parentId;
          _selectedSubcategoryId = matched.id;
        } else {
          _selectedParentCategoryId = matched.id;
          _selectedSubcategoryId = null;
        }
      }
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    for (final entry in _splitEntries) {
      entry.dispose();
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
      final entry = _splitEntries.removeAt(index);
      entry.dispose();
      _splitEqually();
    });
  }

  void _splitEqually() {
    final totalAmount = double.tryParse(_amountCtrl.text) ?? 0;
    if (totalAmount <= 0 || _splitEntries.isEmpty) return;
    final totalPeople = 1 + _splitEntries.length; // Me + Friends
    final perPerson = (totalAmount / totalPeople);
    for (final entry in _splitEntries) {
      if (!entry.isPaid) {
        entry.amountCtrl.text = perPerson % 1 == 0 ? perPerson.toInt().toString() : perPerson.toStringAsFixed(2);
      }
    }
  }

  /// Creates a category of the form's current type and selects it.
  Future<void> _createCategory() async {
    final type = _type == 'income' ? 'income' : 'expense';
    final cat = await showQuickCategoryDialog(context: context, ref: widget.ref, type: type);
    if (cat == null || !mounted) return;
    setState(() {
      if (cat.parentId != null && cat.parentId!.isNotEmpty) {
        _selectedParentCategoryId = cat.parentId;
        _selectedSubcategoryId = cat.id;
      } else {
        _selectedParentCategoryId = cat.id;
        _selectedSubcategoryId = null;
      }
    });
  }

  Widget _buildTypeTab(String type, String label, Color activeColor) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSelected = _type == type;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (_type != type) {
            setState(() {
              _type = type;
              final categories = widget.ref.read(categoriesProvider);
              final cat = categories.firstWhereOrNull((c) => c.id == _selectedParentCategoryId);
              if (cat != null && cat.type != _type) {
                _selectedParentCategoryId = null;
                _selectedSubcategoryId = null;
              }
            });
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? activeColor : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: activeColor.withValues(alpha: 0.35),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (_amountCtrl.text.isEmpty || _selectedAccountId == null) return;
    final amount = double.tryParse(_amountCtrl.text);
    if (amount == null || amount <= 0) return;

    setState(() => _saving = true);
    final effectiveCategoryId = _selectedSubcategoryId ?? _selectedParentCategoryId;

    List<SplitMember>? splits;
    if (_type == 'expense' && _isSplit && _splitEntries.isNotEmpty) {
      splits = _splitEntries
          .where((e) => e.nameCtrl.text.trim().isNotEmpty)
          .map((e) => SplitMember(
                id: e.id,
                name: e.nameCtrl.text.trim(),
                amount: double.tryParse(e.amountCtrl.text) ?? 0,
                isPaid: e.isPaid,
                paidDate: e.paidDate,
                paidAccountId: e.paidAccountId,
              ))
          .toList();
    }

    final txn = Transaction(
      id: widget.existing?.id ?? '',
      type: _type,
      amount: amount,
      accountId: _selectedAccountId!,
      toAccountId: _type == 'transfer' ? _toAccountId : null,
      categoryId: _type != 'transfer' ? effectiveCategoryId : null,
      date: _date,
      note: _noteCtrl.text,
      isSplit: _type == 'expense' && _isSplit && splits != null && splits.isNotEmpty,
      splits: splits,
    );

    if (widget.existing != null) {
      await widget.ref.read(transactionsProvider.notifier).update(widget.existing!, txn);
    } else {
      await widget.ref.read(transactionsProvider.notifier).add(txn);
    }
    widget.ref.read(accountsProvider.notifier).refresh();
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    if (widget.existing == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Transaction'),
        content: const Text('Are you sure you want to delete this transaction? The account balance will be recalculated accordingly.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: AppColors.expense)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await widget.ref.read(transactionsProvider.notifier).delete(widget.existing!);
      widget.ref.read(accountsProvider.notifier).refresh();
      if (mounted) Navigator.pop(context);
    }
  }

  void _applyTemplate(Template t) {
    setState(() {
      _type = t.type;
      if (t.amount > 0) _amountCtrl.text = t.amount.toString();
      _noteCtrl.text = t.note;
      _selectedAccountId = t.accountId;
      _selectedParentCategoryId = null;
      _selectedSubcategoryId = null;
      if (t.categoryId != null) {
        final allCats = widget.ref.read(categoriesProvider);
        final matched = allCats.firstWhereOrNull((c) => c.id == t.categoryId);
        if (matched != null) {
          if (matched.parentId != null && matched.parentId!.isNotEmpty) {
            _selectedParentCategoryId = matched.parentId;
            _selectedSubcategoryId = matched.id;
          } else {
            _selectedParentCategoryId = matched.id;
          }
        }
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Auto-filled from template "${t.name}"'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showTemplatesPicker(BuildContext context, List<Template> templates) {
    final accounts = widget.ref.read(accountsProvider);
    final categories = widget.ref.read(categoriesProvider);

    showAppSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.bookmark_added_rounded, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Select Preset Template',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(),
              if (templates.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: Column(
                      children: [
                        const Icon(Icons.bookmark_border_rounded, size: 48, color: AppColors.darkTextMuted),
                        const SizedBox(height: 8),
                        const Text('No templates saved yet'),
                        const SizedBox(height: 4),
                        Text(
                          'You can create templates in Menu > Templates',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: templates.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (ctx, i) {
                      final t = templates[i];
                      final cat = categories.firstWhereOrNull((c) => c.id == t.categoryId);
                      final acc = accounts.firstWhereOrNull((a) => a.id == t.accountId);
                      final color = t.type == 'income'
                          ? AppColors.income
                          : t.type == 'expense'
                              ? AppColors.expense
                              : AppColors.transfer;

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(vertical: 4),
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: CategoryIcon(category: cat, defaultEmoji: '📋', size: 22, fontSize: 20),
                          ),
                        ),
                        title: Text(t.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          '${t.type.toUpperCase()} • ${cat?.name ?? ''} • ${acc?.name ?? ''}',
                          style: const TextStyle(fontSize: 11),
                        ),
                        trailing: t.amount > 0
                            ? Text(
                                CurrencyUtil.format(t.amount, acc?.currency ?? 'INR'),
                                style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14),
                              )
                            : const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                        onTap: () {
                          Navigator.pop(ctx);
                          _applyTemplate(t);
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveAsTemplate() async {
    final nameCtrl = TextEditingController(text: _noteCtrl.text.isNotEmpty ? _noteCtrl.text : 'My Template');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Save as Preset Template'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter a name for this preset template so you can quickly reuse it later:'),
            const SizedBox(height: 12),
            TextField(
              controller: nameCtrl,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Template Name'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save Template')),
        ],
      ),
    );

    if (confirmed == true && nameCtrl.text.trim().isNotEmpty) {
      final amount = double.tryParse(_amountCtrl.text) ?? 0;
      final effectiveCategoryId = _selectedSubcategoryId ?? _selectedParentCategoryId;
      final template = Template(
        id: '',
        name: nameCtrl.text.trim(),
        type: _type,
        amount: amount,
        accountId: _selectedAccountId ?? '',
        categoryId: effectiveCategoryId,
        note: _noteCtrl.text,
      );
      await widget.ref.read(templatesProvider.notifier).add(template);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Saved "${template.name}" as preset template!')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final accounts = widget.ref.watch(accountsProvider);
    final categories = widget.ref.watch(categoriesProvider);
    final templates = widget.ref.watch(templatesProvider);
    final parentCategories = categories
        .where((c) => (c.type == _type || _type == 'transfer') && (c.parentId == null || c.parentId!.isEmpty))
        .toList();
    if (_selectedParentCategoryId != null && !parentCategories.any((c) => c.id == _selectedParentCategoryId)) {
      _selectedParentCategoryId = null;
      _selectedSubcategoryId = null;
    }
    final subcategories = _selectedParentCategoryId != null
        ? categories.where((c) => c.parentId == _selectedParentCategoryId).toList()
        : <Category>[];
    if (_selectedSubcategoryId != null && !subcategories.any((c) => c.id == _selectedSubcategoryId)) {
      _selectedSubcategoryId = null;
    }

    final totalBill = double.tryParse(_amountCtrl.text) ?? 0;
    double friendsTotal = 0;
    for (final e in _splitEntries) {
      friendsTotal += double.tryParse(e.amountCtrl.text) ?? 0;
    }
    final myShare = (totalBill - friendsTotal).clamp(0, double.infinity);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.90,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.existing != null ? 'Edit Transaction' : 'New Transaction',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  Row(
                    children: [
                      if (widget.existing == null && templates.isNotEmpty)
                        TextButton.icon(
                          onPressed: () => _showTemplatesPicker(context, templates),
                          icon: const Icon(Icons.bookmark_added_rounded, size: 16),
                          label: const Text('Use Template', style: TextStyle(fontSize: 12)),
                        ),
                      if (widget.existing != null)
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: AppColors.expense),
                          onPressed: _delete,
                        ),
                    ],
                  ),
                ],
              ),
            ),
            // Type Segmented Control
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Container(
                height: 44,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark ? AppColors.darkCardAlt : AppColors.lightBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? AppColors.darkBorder : AppColors.lightBorder),
                ),
                child: Row(
                  children: [
                    _buildTypeTab('income', 'Income', AppColors.income),
                    _buildTypeTab('expense', 'Expense', AppColors.expense),
                    _buildTypeTab('transfer', 'Transfer', AppColors.transfer),
                  ],
                ),
              ),
            ),

            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: Column(
                  children: [
                    // Amount
                    TextField(
                      controller: _amountCtrl,
                      autofocus: widget.existing == null && widget.prefill == null,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                      ],
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                      decoration: const InputDecoration(
                        hintText: '0.00',
                        prefixText: '₹ ',
                        prefixStyle: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                        border: InputBorder.none,
                      ),
                      onChanged: (_) {
                        if (_isSplit) _splitEqually();
                        setState(() {});
                      },
                    ),
                    const SizedBox(height: 16),

                    // Account
                    _DropdownField<String>(
                      label: _type == 'transfer' ? 'From Account' : 'Account',
                      value: _selectedAccountId,
                      items: accounts
                          .map((a) => DropdownMenuItem(
                                value: a.id,
                                child: Row(
                                  children: [
                                    AccountIcon(account: a, size: 18),
                                    const SizedBox(width: 8),
                                    Text(a.name),
                                  ],
                                ),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => _selectedAccountId = v),
                    ),
                    const SizedBox(height: 12),

                    // To Account (transfer only)
                    if (_type == 'transfer') ...[
                      _DropdownField<String>(
                        label: 'To Account',
                        value: _toAccountId,
                        items: accounts
                            .where((a) => a.id != _selectedAccountId)
                            .map((a) => DropdownMenuItem(
                                  value: a.id,
                                  child: Row(
                                    children: [
                                      AccountIcon(account: a, size: 18),
                                      const SizedBox(width: 8),
                                      Text(a.name),
                                    ],
                                  ),
                                ))
                            .toList(),
                        onChanged: (v) => setState(() => _toAccountId = v),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Category & Subcategory (Row when subcategories exist)
                    if (_type != 'transfer') ...[
                      if (_selectedParentCategoryId != null && subcategories.isNotEmpty) ...[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _DropdownField<String?>(
                                label: 'Category',
                                value: _selectedParentCategoryId,
                                items: [
                                  const DropdownMenuItem(value: null, child: Text('None')),
                                  ...parentCategories.map((c) => DropdownMenuItem(
                                        value: c.id,
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            CategoryIcon(category: c, size: 16),
                                            const SizedBox(width: 6),
                                            Flexible(
                                              child: Text(c.name,
                                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                                  overflow: TextOverflow.ellipsis),
                                            ),
                                          ],
                                        ),
                                      )),
                                ],
                                onChanged: (v) {
                                  setState(() {
                                    _selectedParentCategoryId = v;
                                    _selectedSubcategoryId = null;
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _DropdownField<String?>(
                                label: 'Subcategory',
                                value: _selectedSubcategoryId,
                                items: [
                                  const DropdownMenuItem(
                                    value: null,
                                    child: Text('All / General', style: TextStyle(color: AppColors.darkTextSecondary, fontSize: 13)),
                                  ),
                                  ...subcategories.map((sub) => DropdownMenuItem(
                                        value: sub.id,
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            CategoryIcon(category: sub, size: 16),
                                            const SizedBox(width: 6),
                                            Flexible(
                                              child: Text(sub.name, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
                                            ),
                                          ],
                                        ),
                                      )),
                                ],
                                onChanged: (v) => setState(() => _selectedSubcategoryId = v),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                      ] else ...[
                        _DropdownField<String?>(
                          label: 'Category',
                          value: _selectedParentCategoryId,
                          items: [
                            const DropdownMenuItem(value: null, child: Text('No Category')),
                            ...parentCategories.map((c) => DropdownMenuItem(
                                  value: c.id,
                                  child: Row(
                                    children: [
                                      CategoryIcon(category: c, size: 18),
                                      const SizedBox(width: 8),
                                      Text(c.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                )),
                          ],
                          onChanged: (v) {
                            setState(() {
                              _selectedParentCategoryId = v;
                              _selectedSubcategoryId = null;
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                      ],
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: NewCategoryChip(onPressed: _createCategory),
                        ),
                      ),
                    ],

                    // Split Bill with Friends Section (Expense only)
                    if (_type == 'expense') ...[
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: _isSplit
                              ? AppColors.primary.withValues(alpha: 0.08)
                              : (Theme.of(context).brightness == Brightness.dark ? AppColors.darkCardAlt : AppColors.lightBg),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: _isSplit
                                ? AppColors.primary.withValues(alpha: 0.4)
                                : (Theme.of(context).brightness == Brightness.dark ? AppColors.darkBorder : AppColors.lightBorder),
                          ),
                        ),
                        child: Column(
                          children: [
                            SwitchListTile(
                              title: const Row(
                                children: [
                                  Icon(Icons.call_split_rounded, size: 20, color: AppColors.primary),
                                  SizedBox(width: 8),
                                  Text('Split with Friends', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                ],
                              ),
                              subtitle: Text(
                                _isSplit
                                    ? 'Splitting bill with ${_splitEntries.length} friends'
                                    : 'Split restaurant, trip, or group bills',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context).brightness == Brightness.dark
                                      ? AppColors.darkTextSecondary
                                      : AppColors.lightTextSecondary,
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
                                        color: AppColors.darkCard,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text('Friends Owe You', style: TextStyle(fontSize: 11, color: AppColors.darkTextSecondary)),
                                              Text(
                                                '₹${friendsTotal.toStringAsFixed(0)}',
                                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.income),
                                              ),
                                            ],
                                          ),
                                          Container(width: 1, height: 26, color: AppColors.darkBorder),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                              const Text('Your Net Share', style: TextStyle(fontSize: 11, color: AppColors.darkTextSecondary)),
                                              Text(
                                                '₹${myShare.toStringAsFixed(0)}',
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
                                                Text('Split Equally', style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600)),
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
                                                decoration: InputDecoration(
                                                  isDense: true,
                                                  hintText: 'Friend Name',
                                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                                  prefixIcon: item.isPaid
                                                      ? const Icon(Icons.check_circle_rounded, color: AppColors.income, size: 18)
                                                      : const Icon(Icons.person_outline_rounded, size: 18),
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
                                                decoration: const InputDecoration(
                                                  isDense: true,
                                                  prefixText: '₹ ',
                                                  hintText: '0',
                                                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
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
                    ],

                    // Date
                    InkWell(
                      onTap: () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: _date,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );
                        if (d == null) return;
                        if (!context.mounted) return;
                        final t = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.fromDateTime(_date),
                        );
                        if (!mounted) return;
                        setState(() {
                          _date = DateTime(d.year, d.month, d.day,
                              t?.hour ?? _date.hour, t?.minute ?? _date.minute);
                        });
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Date & Time',
                          suffixIcon: Icon(Icons.calendar_today_rounded),
                        ),
                        child: Text(DateUtil.formatDateTime(_date)),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Note
                    TextField(
                      controller: _noteCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Note (optional)',
                        suffixIcon: Icon(Icons.notes_rounded),
                      ),
                    ),
                    if (widget.existing == null) ...[
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: _saveAsTemplate,
                          icon: const Icon(Icons.bookmark_add_outlined, size: 16),
                          label: const Text('Save as Preset Template', style: TextStyle(fontSize: 12)),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ] else ...[
                      const SizedBox(height: 24),
                    ],

                    // Save button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _save,
                        child: _saving
                            ? const CircularProgressIndicator(color: Colors.white)
                            : Text(widget.existing != null ? 'Update Transaction' : 'Save Transaction'),
                      ),
                    ),
                    const SizedBox(height: 16),
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

class _DropdownField<T> extends StatelessWidget {
  final String label;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  const _DropdownField({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasMatch = items.any((item) => item.value == value);
    final effectiveValue = hasMatch ? value : null;
    return DropdownButtonFormField<T>(
      key: ValueKey(effectiveValue),
      initialValue: effectiveValue,
      items: items,
      onChanged: onChanged,
      decoration: InputDecoration(labelText: label),
      isExpanded: true,
      dropdownColor: isDark ? AppColors.darkCard : AppColors.lightCard,
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
