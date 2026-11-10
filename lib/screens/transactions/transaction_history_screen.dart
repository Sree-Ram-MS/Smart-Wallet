import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/utils.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/add_transaction_sheet.dart';
import '../../widgets/category_icon.dart';
import '../../widgets/debt_link_badge.dart';
import '../../core/layout/responsive.dart';

class TransactionHistoryScreen extends ConsumerStatefulWidget {
  const TransactionHistoryScreen({super.key});
  @override
  ConsumerState<TransactionHistoryScreen> createState() => _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends ConsumerState<TransactionHistoryScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  // Filter States
  String? _filterType; // null = All, 'expense', 'income', 'transfer', 'split'
  final Set<String> _filterAccountIds = {};
  final Set<String> _filterCategoryIds = {};
  double? _minAmount;
  double? _maxAmount;
  DateTimeRange? _dateRange;
  String? _datePresetLabel;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  int get _activeFilterCount {
    int count = 0;
    if (_filterType != null) count++;
    if (_filterAccountIds.isNotEmpty) count += _filterAccountIds.length;
    if (_filterCategoryIds.isNotEmpty) count += _filterCategoryIds.length;
    if (_minAmount != null || _maxAmount != null) count++;
    if (_dateRange != null) count++;
    return count;
  }

  void _clearAllFilters() {
    setState(() {
      _filterType = null;
      _filterAccountIds.clear;
      _filterCategoryIds.clear;
      _minAmount = null;
      _maxAmount = null;
      _dateRange = null;
      _datePresetLabel = null;
    });
  }

  List<Transaction> _filter(List<Transaction> all, List<Account> accounts, List<Category> categories) {
    final catMap = {for (final c in categories) c.id: c};

    return all.where((t) {
      final acc = accounts.firstWhereOrNull((a) => a.id == t.accountId);
      final cat = catMap[t.categoryId];

      // 1. Text search query
      if (_query.isNotEmpty) {
        final q = _query.toLowerCase();
        final matchNote = t.note.toLowerCase().contains(q);
        final matchCat = cat?.name.toLowerCase().contains(q) ?? false;
        final matchAcc = acc?.name.toLowerCase().contains(q) ?? false;
        final matchAmount = t.amount.toString().contains(q);
        final matchSplit = t.splits?.any((s) => s.name.toLowerCase().contains(q)) ?? false;
        if (!matchNote && !matchCat && !matchAcc && !matchAmount && !matchSplit) {
          return false;
        }
      }

      // 2. Transaction type
      if (_filterType != null) {
        if (_filterType == 'split') {
          if (!t.isSplit) return false;
        } else if (t.type != _filterType) {
          return false;
        }
      }

      // 3. Multi-Account Filter
      if (_filterAccountIds.isNotEmpty) {
        final matchAcc = _filterAccountIds.contains(t.accountId) ||
            (t.type == 'transfer' && t.toAccountId != null && _filterAccountIds.contains(t.toAccountId));
        if (!matchAcc) return false;
      }

      // 4. Hierarchical Category Filter
      if (_filterCategoryIds.isNotEmpty) {
        final catId = t.categoryId;
        final parentId = cat?.parentId;
        final matchCat = (catId != null && _filterCategoryIds.contains(catId)) ||
            (parentId != null && _filterCategoryIds.contains(parentId));
        if (!matchCat) return false;
      }

      // 5. Amount Range Filter
      if (_minAmount != null && t.amount < _minAmount!) return false;
      if (_maxAmount != null && t.amount > _maxAmount!) return false;

      // 6. Date Range Filter
      if (_dateRange != null) {
        final start = DateTime(_dateRange!.start.year, _dateRange!.start.month, _dateRange!.start.day);
        final end = DateTime(_dateRange!.end.year, _dateRange!.end.month, _dateRange!.end.day, 23, 59, 59);
        if (t.date.isBefore(start) || t.date.isAfter(end)) return false;
      }

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(transactionsProvider);
    final accounts = ref.watch(accountsProvider);
    final categories = ref.watch(categoriesProvider);
    final user = ref.watch(userProvider);
    final currency = user?.baseCurrency ?? 'INR';

    final filtered = _filter(all, accounts, categories);
    final debtLinks = ref.watch(debtLinkedTxnProvider);
    final totalSum = filtered.fold<double>(0.0, (s, t) => s + (t.type == 'expense' ? -t.amount : t.amount));

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        context.go('/dashboard');
      },
      child: Scaffold(
        drawer: context.isWide ? null : const AppDrawer(),
        appBar: AppBar(
          leading: context.isWide ? null : Builder(
            builder: (ctx) => IconButton(
              icon: const Icon(Icons.menu_rounded),
              onPressed: () => Scaffold.of(ctx).openDrawer(),
            ),
          ),
          title: const Text('Transaction History'),
          actions: [
            Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.tune_rounded),
                  tooltip: 'Search & Filters',
                  onPressed: () => _showFilterSheet(accounts, categories, all),
                ),
                if (_activeFilterCount > 0)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$_activeFilterCount',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
        body: ContentWidth(
          maxWidth: 1000,
          child: Column(
            children: [
              // Search Input Field
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    hintText: 'Search notes, categories, accounts, tags...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _query.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _query = '');
                            },
                          )
                        : null,
                  ),
                ),
              ),

              // Active Filter Chips Bar
              if (_activeFilterCount > 0)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    children: [
                      // Clear all button
                      InkWell(
                        onTap: _clearAllFilters,
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: AppColors.expense.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.expense.withValues(alpha: 0.3)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.delete_sweep_rounded, size: 14, color: AppColors.expense),
                              SizedBox(width: 4),
                              Text(
                                'Clear all',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.expense),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Type Chip
                      if (_filterType != null)
                        _FilterBadgeChip(
                          label: 'Type: ${_filterType!.toUpperCase()}',
                          onRemove: () => setState(() => _filterType = null),
                        ),

                      // Account Chips
                      ..._filterAccountIds.map((accId) {
                        final acc = accounts.firstWhereOrNull((a) => a.id == accId);
                        return _FilterBadgeChip(
                          label: '${acc?.emoji ?? '💳'} ${acc?.name ?? 'Account'}',
                          onRemove: () => setState(() => _filterAccountIds.remove(accId)),
                        );
                      }),

                      // Category Chips
                      ..._filterCategoryIds.map((catId) {
                        final cat = categories.firstWhereOrNull((c) => c.id == catId);
                        return _FilterBadgeChip(
                          label: '${cat?.icon ?? '🏷️'} ${cat?.name ?? 'Category'}',
                          onRemove: () => setState(() => _filterCategoryIds.remove(catId)),
                        );
                      }),

                      // Amount Chip
                      if (_minAmount != null || _maxAmount != null)
                        _FilterBadgeChip(
                          label: _minAmount != null && _maxAmount != null
                              ? 'Amount: $currency $_minAmount – $_maxAmount'
                              : _minAmount != null
                                  ? 'Amount: >= $currency $_minAmount'
                                  : 'Amount: <= $currency $_maxAmount',
                          onRemove: () => setState(() {
                            _minAmount = null;
                            _maxAmount = null;
                          }),
                        ),

                      // Date Range Chip
                      if (_dateRange != null)
                        _FilterBadgeChip(
                          label: _datePresetLabel ??
                              '${DateUtil.formatShort(_dateRange!.start)} – ${DateUtil.formatShort(_dateRange!.end)}',
                          onRemove: () => setState(() {
                            _dateRange = null;
                            _datePresetLabel = null;
                          }),
                        ),
                    ],
                  ),
                ),

              // Summary Header Count
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${filtered.length} ${filtered.length == 1 ? 'transaction' : 'transactions'} found',
                      style: const TextStyle(fontSize: 12, color: AppColors.darkTextSecondary, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      'Net: ${CurrencyUtil.format(totalSum, currency)}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: totalSum >= 0 ? AppColors.income : AppColors.expense,
                      ),
                    ),
                  ],
                ),
              ),

              // Transactions List
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.receipt_long_outlined, size: 56, color: AppColors.darkTextMuted),
                            const SizedBox(height: 12),
                            Text('No transactions match your search/filters',
                                style: Theme.of(context).textTheme.bodyMedium),
                            const SizedBox(height: 8),
                            if (_activeFilterCount > 0 || _query.isNotEmpty)
                              TextButton.icon(
                                onPressed: () {
                                  _searchCtrl.clear();
                                  setState(() {
                                    _query = '';
                                    _clearAllFilters();
                                  });
                                },
                                icon: const Icon(Icons.restart_alt_rounded, size: 16),
                                label: const Text('Reset All Filters'),
                              ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                        itemCount: filtered.length,
                        itemBuilder: (ctx, i) => _TxnListTile(
                          txn: filtered[i],
                          accounts: accounts,
                          categories: categories,
                          linkedDebt: debtLinks[filtered[i].id],
                          ref: ref,
                          delay: i < 15 ? i * 25 : 0,
                        ),
                      ),
              ),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => showAppSheet(
            context: context,
            isScrollControlled: true,
            builder: (_) => AddTransactionSheet(ref: ref),
          ),
          child: const Icon(Icons.add_rounded),
        ),
      ),
    );
  }

  // ─── Filter Bottom Sheet ───────────────────────────────────────────────────

  void _showFilterSheet(List<Account> accounts, List<Category> categories, List<Transaction> allTransactions) {
    // Local copy of filter states for bottom sheet
    String? localType = _filterType;
    final Set<String> localAccounts = Set.from(_filterAccountIds);
    final Set<String> localCategories = Set.from(_filterCategoryIds);
    double? localMin = _minAmount;
    double? localMax = _maxAmount;
    DateTimeRange? localRange = _dateRange;
    String? localPreset = _datePresetLabel;

    final minCtrl = TextEditingController(text: localMin != null ? localMin.toStringAsFixed(0) : '');
    final maxCtrl = TextEditingController(text: localMax != null ? localMax.toStringAsFixed(0) : '');

    final parentCategories = categories.where((c) => c.parentId == null).toList();

    showAppSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF18181E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setLocal) {
        // Calculate preview count with local filters
        final previewMatches = allTransactions.where((t) {
          if (localType != null) {
            if (localType == 'split' && !t.isSplit) return false;
            if (localType != 'split' && t.type != localType) return false;
          }
          if (localAccounts.isNotEmpty) {
            final match = localAccounts.contains(t.accountId) ||
                (t.type == 'transfer' && t.toAccountId != null && localAccounts.contains(t.toAccountId));
            if (!match) return false;
          }
          if (localCategories.isNotEmpty) {
            final cat = categories.firstWhereOrNull((c) => c.id == t.categoryId);
            final match = (t.categoryId != null && localCategories.contains(t.categoryId)) ||
                (cat?.parentId != null && localCategories.contains(cat!.parentId));
            if (!match) return false;
          }
          if (localMin != null && t.amount < localMin!) return false;
          if (localMax != null && t.amount > localMax!) return false;
          if (localRange != null) {
            final s = DateTime(localRange!.start.year, localRange!.start.month, localRange!.start.day);
            final e = DateTime(localRange!.end.year, localRange!.end.month, localRange!.end.day, 23, 59, 59);
            if (t.date.isBefore(s) || t.date.isAfter(e)) return false;
          }
          return true;
        }).length;

        // In the wide-layout dialog the sheet simply fills the dialog.
        final wide = context.isWide;
        return DraggableScrollableSheet(
          initialChildSize: wide ? 1.0 : 0.85,
          minChildSize: wide ? 1.0 : 0.5,
          maxChildSize: wide ? 1.0 : 0.95,
          expand: false,
          builder: (_, scrollCtrl) => Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Filter Transactions',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    TextButton(
                      onPressed: () {
                        setLocal(() {
                          localType = null;
                          localAccounts.clear();
                          localCategories.clear();
                          localMin = null;
                          localMax = null;
                          localRange = null;
                          localPreset = null;
                          minCtrl.clear();
                          maxCtrl.clear();
                        });
                      },
                      child: const Text('Reset All', style: TextStyle(color: AppColors.expense)),
                    ),
                  ],
                ),
                const Divider(color: Colors.white12),

                // Scrollable filters content
                Expanded(
                  child: ListView(
                    controller: scrollCtrl,
                    children: [
                      // 1. Transaction Type
                      const _SectionHeader(title: 'Transaction Type', icon: Icons.swap_horiz_rounded),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _SelectableChip(
                            label: 'All Types',
                            isSelected: localType == null,
                            onTap: () => setLocal(() => localType = null),
                          ),
                          _SelectableChip(
                            label: '💸 Expense',
                            isSelected: localType == 'expense',
                            onTap: () => setLocal(() => localType = 'expense'),
                          ),
                          _SelectableChip(
                            label: '💰 Income',
                            isSelected: localType == 'income',
                            onTap: () => setLocal(() => localType = 'income'),
                          ),
                          _SelectableChip(
                            label: '↔ Transfer',
                            isSelected: localType == 'transfer',
                            onTap: () => setLocal(() => localType = 'transfer'),
                          ),
                          _SelectableChip(
                            label: '✂ Split Bills',
                            isSelected: localType == 'split',
                            onTap: () => setLocal(() => localType = 'split'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // 2. Date Range & Presets
                      const _SectionHeader(title: 'Date Range', icon: Icons.calendar_month_rounded),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _SelectableChip(
                            label: 'All Time',
                            isSelected: localRange == null,
                            onTap: () => setLocal(() {
                              localRange = null;
                              localPreset = null;
                            }),
                          ),
                          _SelectableChip(
                            label: 'Today',
                            isSelected: localPreset == 'Today',
                            onTap: () {
                              final now = DateTime.now();
                              setLocal(() {
                                localRange = DateTimeRange(start: now, end: now);
                                localPreset = 'Today';
                              });
                            },
                          ),
                          _SelectableChip(
                            label: 'Last 7 Days',
                            isSelected: localPreset == 'Last 7 Days',
                            onTap: () {
                              final now = DateTime.now();
                              setLocal(() {
                                localRange = DateTimeRange(start: now.subtract(const Duration(days: 7)), end: now);
                                localPreset = 'Last 7 Days';
                              });
                            },
                          ),
                          _SelectableChip(
                            label: 'This Month',
                            isSelected: localPreset == 'This Month',
                            onTap: () {
                              final now = DateTime.now();
                              setLocal(() {
                                localRange = DateTimeRange(start: DateTime(now.year, now.month, 1), end: now);
                                localPreset = 'This Month';
                              });
                            },
                          ),
                          _SelectableChip(
                            label: 'Last 30 Days',
                            isSelected: localPreset == 'Last 30 Days',
                            onTap: () {
                              final now = DateTime.now();
                              setLocal(() {
                                localRange = DateTimeRange(start: now.subtract(const Duration(days: 30)), end: now);
                                localPreset = 'Last 30 Days';
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.date_range_rounded, size: 18),
                        label: Text(
                          localRange != null
                              ? '${DateUtil.formatShort(localRange!.start)} – ${DateUtil.formatShort(localRange!.end)}'
                              : 'Select Custom Date Range',
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () async {
                          final picked = await showDateRangePicker(
                            context: context,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2100),
                            initialDateRange: localRange,
                          );
                          if (picked != null) {
                            setLocal(() {
                              localRange = picked;
                              localPreset = null;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 20),

                      // 3. Amount Range
                      const _SectionHeader(title: 'Amount Range', icon: Icons.monetization_on_outlined),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: minCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Min Amount',
                                prefixText: '₹ ',
                                isDense: true,
                              ),
                              onChanged: (v) {
                                setLocal(() => localMin = double.tryParse(v));
                              },
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 10),
                            child: Text('–', style: TextStyle(color: Colors.white60, fontSize: 18)),
                          ),
                          Expanded(
                            child: TextField(
                              controller: maxCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Max Amount',
                                prefixText: '₹ ',
                                isDense: true,
                              ),
                              onChanged: (v) {
                                setLocal(() => localMax = double.tryParse(v));
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          _SelectableChip(
                            label: '< ₹500',
                            isSelected: localMin == null && localMax == 500,
                            onTap: () => setLocal(() {
                              localMin = null;
                              localMax = 500;
                              minCtrl.text = '';
                              maxCtrl.text = '500';
                            }),
                          ),
                          _SelectableChip(
                            label: '₹500 – ₹2,000',
                            isSelected: localMin == 500 && localMax == 2000,
                            onTap: () => setLocal(() {
                              localMin = 500;
                              localMax = 2000;
                              minCtrl.text = '500';
                              maxCtrl.text = '2000';
                            }),
                          ),
                          _SelectableChip(
                            label: '> ₹2,000',
                            isSelected: localMin == 2000 && localMax == null,
                            onTap: () => setLocal(() {
                              localMin = 2000;
                              localMax = null;
                              minCtrl.text = '2000';
                              maxCtrl.text = '';
                            }),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // 4. Accounts (Multi-Select)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const _SectionHeader(title: 'Accounts', icon: Icons.account_balance_wallet_outlined),
                          if (localAccounts.isNotEmpty)
                            TextButton(
                              onPressed: () => setLocal(() => localAccounts.clear()),
                              child: const Text('Select All', style: TextStyle(fontSize: 11)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _SelectableChip(
                            label: 'All Accounts',
                            isSelected: localAccounts.isEmpty,
                            onTap: () => setLocal(() => localAccounts.clear()),
                          ),
                          ...accounts.map((acc) {
                            final selected = localAccounts.contains(acc.id);
                            return _SelectableChip(
                              label: '${acc.emoji} ${acc.name}',
                              isSelected: selected,
                              onTap: () {
                                setLocal(() {
                                  if (selected) {
                                    localAccounts.remove(acc.id);
                                  } else {
                                    localAccounts.add(acc.id);
                                  }
                                });
                              },
                            );
                          }),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // 5. Categories & Subcategories (Tree Selection)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const _SectionHeader(title: 'Categories', icon: Icons.category_outlined),
                          if (localCategories.isNotEmpty)
                            TextButton(
                              onPressed: () => setLocal(() => localCategories.clear()),
                              child: const Text('Select All', style: TextStyle(fontSize: 11)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _SelectableChip(
                            label: 'All Categories',
                            isSelected: localCategories.isEmpty,
                            onTap: () => setLocal(() => localCategories.clear()),
                          ),
                          ...parentCategories.map((parent) {
                            final selected = localCategories.contains(parent.id);
                            final children = categories.where((c) => c.parentId == parent.id).toList();

                            return Container(
                              margin: const EdgeInsets.only(bottom: 4),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _SelectableChip(
                                    label: '${parent.icon} ${parent.name}',
                                    isSelected: selected,
                                    onTap: () {
                                      setLocal(() {
                                        if (selected) {
                                          localCategories.remove(parent.id);
                                        } else {
                                          localCategories.add(parent.id);
                                        }
                                      });
                                    },
                                  ),
                                  if (children.isNotEmpty) ...[
                                    Padding(
                                      padding: const EdgeInsets.only(left: 14, top: 4),
                                      child: Wrap(
                                        spacing: 6,
                                        children: children.map((ch) {
                                          final chSelected = localCategories.contains(ch.id);
                                          return _SelectableChip(
                                            label: '${ch.icon} ${ch.name}',
                                            isSelected: chSelected,
                                            isSmall: true,
                                            onTap: () {
                                              setLocal(() {
                                                if (chSelected) {
                                                  localCategories.remove(ch.id);
                                                } else {
                                                  localCategories.add(ch.id);
                                                }
                                              });
                                            },
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),

                // Apply button with live matching count
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () {
                      setState(() {
                        _filterType = localType;
                        _filterAccountIds
                          ..clear()
                          ..addAll(localAccounts);
                        _filterCategoryIds
                          ..clear()
                          ..addAll(localCategories);
                        _minAmount = localMin;
                        _maxAmount = localMax;
                        _dateRange = localRange;
                        _datePresetLabel = localPreset;
                      });
                      Navigator.pop(ctx);
                    },
                    child: Text(
                      'Apply Filters ($previewMatches)',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}

// ─── Helper Widgets ──────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  const _SectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
      ],
    );
  }
}

class _SelectableChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isSmall;

  const _SelectableChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.isSmall = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.symmetric(horizontal: isSmall ? 8 : 12, vertical: isSmall ? 4 : 7),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : const Color(0xFF262832),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.white10,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: isSmall ? 11 : 12.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : Colors.white70,
          ),
        ),
      ),
    );
  }
}

class _FilterBadgeChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;
  const _FilterBadgeChip({required this.label, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: Chip(
        label: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
        deleteIcon: const Icon(Icons.close_rounded, size: 13),
        onDeleted: onRemove,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        backgroundColor: const Color(0xFF282834),
        side: const BorderSide(color: Colors.white12),
      ),
    );
  }
}

class _TxnListTile extends StatelessWidget {
  final Transaction txn;
  final List<Account> accounts;
  final List<Category> categories;
  final DebtCredit? linkedDebt;
  final WidgetRef ref;
  final int delay;
  const _TxnListTile({
    required this.txn,
    required this.accounts,
    required this.categories,
    this.linkedDebt,
    required this.ref,
    required this.delay,
  });

  void _showDetailsSheet(BuildContext context) {
    final cat = categories.firstWhereOrNull((c) => c.id == txn.categoryId);
    final acc = accounts.firstWhereOrNull((a) => a.id == txn.accountId);
    final toAcc = accounts.firstWhereOrNull((a) => a.id == txn.toAccountId);
    final color = txn.type == 'income'
        ? AppColors.income
        : txn.type == 'expense'
            ? AppColors.expense
            : AppColors.transfer;
    final sign = txn.type == 'income' ? '+' : txn.type == 'expense' ? '-' : '↔';

    showAppSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.darkBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Header amount & type
            Center(
              child: Column(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: CategoryIcon(
                        category: cat,
                        icon: txn.type == 'transfer' ? '↔' : null,
                        size: 32,
                        fontSize: 28,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '$sign${CurrencyUtil.format(txn.amount, acc?.currency ?? 'INR')}',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      txn.type.toUpperCase(),
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 12),

            // Detail rows
            if (cat != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    const Icon(Icons.category_rounded, size: 18, color: AppColors.darkTextMuted),
                    const SizedBox(width: 10),
                    Text('Category', style: Theme.of(context).textTheme.bodySmall),
                    const Spacer(),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CategoryIcon(category: cat, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          cat.name,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            _DetailRow(
              icon: Icons.account_balance_wallet_rounded,
              label: txn.type == 'transfer' ? 'From Account' : 'Account',
              value: '${acc?.emoji ?? '💳'} ${acc?.name ?? 'Unknown'}',
            ),
            if (txn.type == 'transfer' && toAcc != null)
              _DetailRow(
                icon: Icons.arrow_forward_rounded,
                label: 'To Account',
                value: '${toAcc.emoji} ${toAcc.name}',
              ),
            _DetailRow(
              icon: Icons.calendar_today_rounded,
              label: 'Date & Time',
              value: DateUtil.formatDateTime(txn.date),
            ),
            if (txn.note.isNotEmpty)
              _DetailRow(
                icon: Icons.notes_rounded,
                label: 'Note',
                value: txn.note,
              ),

            // Split Breakdown section
            if (txn.isSplit && txn.splits != null && txn.splits!.isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.darkCardAlt,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.call_split_rounded, size: 16, color: AppColors.primary),
                            SizedBox(width: 6),
                            Text('Split Breakdown', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          ],
                        ),
                        Builder(
                          builder: (_) {
                            final totalFriends = txn.splits!.fold<double>(0.0, (s, e) => s + e.amount);
                            final myShare = (txn.amount - totalFriends).clamp(0.0, double.infinity);
                            return Text(
                              'My Share: ${CurrencyUtil.format(myShare, acc?.currency ?? 'INR')}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primary),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Divider(height: 1),
                    const SizedBox(height: 8),
                    ...txn.splits!.map((s) {
                      final recAcc = s.paidAccountId != null ? accounts.firstWhereOrNull((a) => a.id == s.paidAccountId) : null;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Icon(
                              s.isPaid ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                              size: 16,
                              color: s.isPaid ? AppColors.income : AppColors.darkTextMuted,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(s.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                  if (s.isPaid)
                                    Text(
                                      'Paid on ${s.paidDate != null ? DateUtil.formatDate(s.paidDate!) : 'Paid'}${recAcc != null ? ' into ${recAcc.emoji} ${recAcc.name}' : ''}',
                                      style: const TextStyle(fontSize: 11, color: AppColors.income),
                                    )
                                  else
                                    const Text('Pending payment', style: TextStyle(fontSize: 11, color: AppColors.expense)),
                                ],
                              ),
                            ),
                            Text(
                              CurrencyUtil.format(s.amount, acc?.currency ?? 'INR'),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: s.isPaid ? AppColors.income : Colors.white,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          context.go('/split-bills');
                        },
                        icon: const Icon(Icons.arrow_forward_rounded, size: 14),
                        label: const Text('Manage in Split Bills', style: TextStyle(fontSize: 11)),
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Action Buttons (Edit & Delete)
            Row(
              children: [
                // Delete button
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.expense,
                      side: const BorderSide(color: AppColors.expense),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: const Text('Delete', style: TextStyle(fontWeight: FontWeight.w600)),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (dCtx) => AlertDialog(
                          title: const Text('Delete Transaction'),
                          content: const Text(
                              'Are you sure you want to delete this transaction? Account balance will be recalculated automatically.'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(dCtx, false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(dCtx, true),
                              child: const Text('Delete', style: TextStyle(color: AppColors.expense)),
                            ),
                          ],
                        ),
                      );

                      if (confirm == true) {
                        await ref.read(transactionsProvider.notifier).delete(txn);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Transaction deleted & balance adjusted!'),
                              backgroundColor: AppColors.darkCard,
                            ),
                          );
                        }
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                // Edit button
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.edit_rounded),
                    label: const Text('Edit', style: TextStyle(fontWeight: FontWeight.w600)),
                    onPressed: () {
                      Navigator.pop(ctx);
                      showAppSheet(
                        context: context,
                        isScrollControlled: true,
                        builder: (_) => AddTransactionSheet(
                          ref: ref,
                          existing: txn,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cat = categories.firstWhereOrNull((c) => c.id == txn.categoryId);
    final acc = accounts.firstWhereOrNull((a) => a.id == txn.accountId);
    final isTransfer = txn.type == 'transfer';
    final toAcc = isTransfer ? accounts.firstWhereOrNull((a) => a.id == txn.toAccountId) : null;
    final title = isTransfer
        ? '${acc?.name ?? 'Unknown'} → ${toAcc?.name ?? 'Unknown'}'
        : (cat?.name ?? (txn.note.isNotEmpty ? txn.note : txn.type));
    final color = txn.type == 'income'
        ? AppColors.income
        : txn.type == 'expense'
            ? AppColors.expense
            : AppColors.transfer;
    final sign = txn.type == 'income' ? '+' : txn.type == 'expense' ? '-' : '↔';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: () => _showDetailsSheet(context),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: CategoryIcon(
              category: cat,
              icon: txn.type == 'transfer' ? '↔' : null,
              size: 22,
              fontSize: 20,
            ),
          ),
        ),
        title: Text(
          title,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (txn.note.isNotEmpty)
              Text(txn.note, style: Theme.of(context).textTheme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(isTransfer ? 'Transfer • ${DateUtil.formatDate(txn.date)}' : '${acc?.name ?? ''} • ${DateUtil.formatDate(txn.date)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11)),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '$sign${CurrencyUtil.format(txn.amount, acc?.currency ?? 'INR')}',
              style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 15),
            ),
            if (txn.isSplit && txn.splits != null) ...[
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.call_split_rounded, size: 10, color: AppColors.primary),
                    SizedBox(width: 2),
                    Text('Split',
                        style: TextStyle(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
            if (linkedDebt != null) ...[
              const SizedBox(height: 2),
              DebtLinkBadge(debt: linkedDebt!),
            ],
          ],
        ),
        isThreeLine: txn.note.isNotEmpty || txn.isSplit || linkedDebt != null,
      ),
    ).animate().fadeIn(delay: Duration(milliseconds: delay), duration: 300.ms);
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _DetailRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.darkTextMuted),
          const SizedBox(width: 10),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const Spacer(),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
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
