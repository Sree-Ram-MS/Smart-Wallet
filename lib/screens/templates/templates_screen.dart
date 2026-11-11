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
import '../../widgets/category_search_field.dart';
import '../../widgets/add_transaction_sheet.dart';
import '../../widgets/category_icon.dart';
import '../../widgets/account_icon.dart';
import '../../core/layout/responsive.dart';

class TemplatesScreen extends ConsumerWidget {
  const TemplatesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templates = ref.watch(templatesProvider);
    final accounts = ref.watch(accountsProvider);
    final categories = ref.watch(categoriesProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        context.go('/dashboard');
      },
      child: Scaffold(
      drawer: context.isWide ? null : const AppDrawer(),
      appBar: AppBar(
        leading: context.isWide ? null : Builder(builder: (ctx) => IconButton(
          icon: const Icon(Icons.menu_rounded),
          onPressed: () => Scaffold.of(ctx).openDrawer(),
        )),
        title: const Text('Templates'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddSheet(context, ref, accounts, categories),
        child: const Icon(Icons.add_rounded),
      ),
      body: templates.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.bookmark_border_rounded, size: 56, color: AppColors.darkTextMuted),
                  const SizedBox(height: 12),
                  Text('No templates yet', style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 4),
                  Text('Save quick-fill presets for common transactions',
                      style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center),
                ],
              ),
            )
          : ResponsiveList.builder(
              padding: const EdgeInsets.all(16),
              itemCount: templates.length,
              itemBuilder: (ctx, i) {
                final t = templates[i];
                final acc = accounts.firstWhereOrNull((a) => a.id == t.accountId);
                final cat = categories.firstWhereOrNull((c) => c.id == t.categoryId);
                final color = t.type == 'income'
                    ? AppColors.income
                    : t.type == 'expense'
                        ? AppColors.expense
                        : AppColors.transfer;

                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: CategoryIcon(category: cat, defaultEmoji: '📋', size: 24, fontSize: 22),
                      ),
                    ),
                    title: Text(t.name,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      '${cat?.name ?? t.type} • ${acc?.name ?? ''}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          CurrencyUtil.format(t.amount, acc?.currency ?? 'INR'),
                          style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 15),
                        ),
                        Text(t.type, style: TextStyle(color: color, fontSize: 10)),
                      ],
                    ),
                    onTap: () => _useTemplate(context, ref, t),
                    onLongPress: () => _showAddSheet(context, ref, accounts, categories, existing: t),
                  ),
                ).animate().fadeIn(delay: Duration(milliseconds: i * 50), duration: 350.ms);
              },
            ),
      ),
    );
  }

  void _useTemplate(BuildContext context, WidgetRef ref, Template t) {
    // Open Add Transaction sheet pre-filled with template data
    showAppSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _PrefilledTransactionSheet(ref: ref, template: t),
    );
  }

  void _showAddSheet(BuildContext context, WidgetRef ref, List<Account> accounts, List<Category> categories, {Template? existing}) {
    showAppSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _TemplateSheet(ref: ref, accounts: accounts, categories: categories, existing: existing),
    );
  }
}

// ─── Pre-filled Transaction Sheet ─────────────────────────────────────────────

class _PrefilledTransactionSheet extends StatelessWidget {
  final WidgetRef ref;
  final Template template;
  const _PrefilledTransactionSheet({required this.ref, required this.template});

  @override
  Widget build(BuildContext context) {
    return AddTransactionSheet(ref: ref, prefill: template);
  }
}



// ─── Template Add/Edit Sheet ─────────────────────────────────────────────────

class _TemplateSheet extends StatefulWidget {
  final WidgetRef ref;
  final List<Account> accounts;
  final List<Category> categories;
  final Template? existing;
  const _TemplateSheet({required this.ref, required this.accounts, required this.categories, this.existing});

  @override
  State<_TemplateSheet> createState() => _TemplateSheetState();
}

class _TemplateSheetState extends State<_TemplateSheet> {
  final _nameCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  String _type = 'expense';
  String? _accountId;
  String? _selectedParentCategoryId;
  String? _selectedSubcategoryId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final t = widget.existing;
    if (t != null) {
      _nameCtrl.text = t.name;
      _amountCtrl.text = t.amount.toString();
      _noteCtrl.text = t.note;
      _type = t.type;
      _accountId = t.accountId;
      if (t.categoryId != null) {
        final matched = widget.categories.firstWhereOrNull((c) => c.id == t.categoryId);
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
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameCtrl.text.isEmpty || _accountId == null) return;
    final amount = double.tryParse(_amountCtrl.text) ?? 0;
    final effectiveCategoryId = _selectedSubcategoryId ?? _selectedParentCategoryId;
    setState(() => _saving = true);

    if (widget.existing != null) {
      final t = widget.existing!;
      t.name = _nameCtrl.text;
      t.type = _type;
      t.amount = amount;
      t.accountId = _accountId!;
      t.categoryId = effectiveCategoryId;
      t.note = _noteCtrl.text;
      await widget.ref.read(templatesProvider.notifier).update(t);
    } else {
      final t = Template(
        id: '',
        name: _nameCtrl.text,
        type: _type,
        amount: amount,
        accountId: _accountId!,
        categoryId: effectiveCategoryId,
        note: _noteCtrl.text,
      );
      await widget.ref.read(templatesProvider.notifier).add(t);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.90),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(children: [
                Text(widget.existing != null ? 'Edit Template' : 'New Template',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                const Spacer(),
                if (widget.existing != null)
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: AppColors.expense),
                    onPressed: () async {
                      await widget.ref.read(templatesProvider.notifier).delete(widget.existing!);
                      if (context.mounted) Navigator.pop(context);
                    },
                  ),
              ]),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(children: [
                  TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Template Name')),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _type,
                    isExpanded: true,
                    items: ['income', 'expense', 'transfer'].map((t) => DropdownMenuItem(value: t, child: Text(t[0].toUpperCase() + t.substring(1), overflow: TextOverflow.ellipsis))).toList(),
                    onChanged: (v) => setState(() {
                      _type = v ?? 'expense';
                      _selectedParentCategoryId = null;
                      _selectedSubcategoryId = null;
                    }),
                    decoration: const InputDecoration(labelText: 'Type'),
                    dropdownColor: isDark ? AppColors.darkCard : AppColors.lightCard,
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
                  const SizedBox(height: 12),
                  if (_type != 'transfer') ...[
                    CategoryPickerPair(
                      type: _type,
                      categoryId: _selectedParentCategoryId,
                      subcategoryId: _selectedSubcategoryId,
                      onChanged: (cat, sub) => setState(() {
                        _selectedParentCategoryId = cat;
                        _selectedSubcategoryId = sub;
                      }),
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextField(controller: _noteCtrl, decoration: const InputDecoration(labelText: 'Note (optional)')),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity, height: 52,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _save,
                      child: _saving ? const CircularProgressIndicator(color: Colors.white) : const Text('Save Template'),
                    ),
                  ),
                ]),
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
    for (final e in this) { if (test(e)) return e; }
    return null;
  }
}
