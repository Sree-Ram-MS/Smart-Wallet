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
import '../../widgets/add_transaction_sheet.dart';
import '../../widgets/add_account_sheet.dart';
import '../../widgets/category_icon.dart';
import '../../widgets/user_avatar.dart';
import 'dashboard_cards_view.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  final PageController _pageController = PageController();
  int _currentPageIndex = 0;
  DateTime? _lastBackPress;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProvider);
    final accounts = ref.watch(accountsProvider);
    final transactions = ref.watch(transactionsProvider);
    final categories = ref.watch(categoriesProvider);
    final netWallet = ref.watch(netWalletProvider);
    final inflow = ref.watch(monthlyInflowProvider);
    final outflow = ref.watch(monthlyOutflowProvider);
    final savings = ref.watch(monthlySavingsProvider);
    final recent = ref.watch(recentTransactionsProvider);
    final debtCredits = ref.watch(debtCreditProvider);
    final upcoming = ref.watch(upcomingPaymentsProvider);
    final currency = user?.baseCurrency ?? 'INR';

    final splitTxns = transactions.where((t) => t.isSplit && t.splits != null && t.splits!.isNotEmpty).toList();

    // Build merged recent activities: transactions + debt/credit entries, sorted by date, limit 7
    final List<_RecentActivityItem> recentActivities = [];
    final enabledIds = accounts.where((a) => a.isEnabledForCalc).map((a) => a.id).toSet();
    for (final t in recent) {
      recentActivities.add(_RecentActivityItem(transaction: t, date: t.date));
    }
    for (final dc in debtCredits) {
      if (enabledIds.contains(dc.accountId)) {
        recentActivities.add(_RecentActivityItem(debtCredit: dc, date: dc.startDate));
      }
    }
    recentActivities.sort((a, b) => b.date.compareTo(a.date));
    final displayActivities = recentActivities.take(7).toList();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        final now = DateTime.now();
        if (_lastBackPress != null && now.difference(_lastBackPress!) < const Duration(seconds: 2)) {
          SystemNavigator.pop();
          return;
        }
        _lastBackPress = now;
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Press back again to exit'),
            duration: Duration(seconds: 2),
          ),
        );
      },
      child: Scaffold(
        drawer: const AppDrawer(),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _showAddTransaction(context, ref),
          child: const Icon(Icons.add_rounded, size: 28),
        ),
        appBar: AppBar(
          leading: Builder(
            builder: (ctx) => IconButton(
              onPressed: () => Scaffold.of(ctx).openDrawer(),
              icon: const Icon(Icons.menu_rounded),
            ),
          ),
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Segmented Page Switcher (Overview vs Analytics & Cards)
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: AppColors.darkCardAlt,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.darkBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () {
                        _pageController.animateToPage(
                          0,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: _currentPageIndex == 0 ? AppColors.primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          'Overview',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _currentPageIndex == 0 ? Colors.white : Colors.white60,
                          ),
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        _pageController.animateToPage(
                          1,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: _currentPageIndex == 1 ? AppColors.primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          'Analytics & Cards',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _currentPageIndex == 1 ? Colors.white : Colors.white60,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          centerTitle: true,
          actions: [
            GestureDetector(
              onTap: () => context.go('/settings'),
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: UserAvatar(user: user, radius: 18),
              ),
            ),
          ],
        ),
        body: PageView(
          controller: _pageController,
          onPageChanged: (idx) => setState(() => _currentPageIndex = idx),
          children: [
            // Page 0: Main Dashboard Overview
            CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      // 1. Top Net Wallet Card
                      _NetWalletCard(
                        netWallet: netWallet,
                        inflow: inflow,
                        outflow: outflow,
                        savings: savings,
                        currency: currency,
                      ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.2),

                      const SizedBox(height: 20),

                      // 2. My Accounts in Wallet (Credit Card Style)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'My Accounts in Wallet',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 18,
                                ),
                          ),
                          TextButton(
                            onPressed: () => context.go('/manage-accounts'),
                            child: const Text('Manage', style: TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _CreditCardsCarousel(accounts: accounts, currency: currency, ref: ref),

                      const SizedBox(height: 24),

                      // 3. Exact Order #1: Recent Activities
                      _SectionHeader(
                        title: 'Recent Activities',
                        onSeeAll: () => context.go('/transactions'),
                      ),
                      const SizedBox(height: 12),
                      if (displayActivities.isEmpty)
                        const _EmptyState(
                          icon: Icons.receipt_long_outlined,
                          message: 'No transactions yet',
                          sub: 'Tap + to add your first transaction',
                        )
                      else
                        ...displayActivities.asMap().entries.map((e) {
                          final item = e.value;
                          if (item.transaction != null) {
                            return _TransactionTile(
                              txn: item.transaction!,
                              ref: ref,
                              delay: e.key * 60,
                            );
                          } else {
                            return _DebtCreditTile(
                              dc: item.debtCredit!,
                              ref: ref,
                              delay: e.key * 60,
                            );
                          }
                        }),

                      const SizedBox(height: 24),

                      // 4. Exact Order #2: Split Bills & Shared Expenses
                      _DashboardSplitBillsSection(
                        splitTxns: splitTxns,
                        accounts: accounts,
                        categories: categories,
                        currency: currency,
                        ref: ref,
                      ),

                      const SizedBox(height: 24),

                      // 5. Exact Order #3: Upcoming Payments
                      _SectionHeader(
                        title: 'Upcoming Payments',
                        onSeeAll: () => context.go('/planned'),
                      ),
                      const SizedBox(height: 12),
                      if (upcoming.isEmpty)
                        const _EmptyState(
                          icon: Icons.calendar_month_outlined,
                          message: 'No upcoming payments',
                          sub: 'Subscriptions, EMIs and bills will appear here',
                        )
                      else
                        ...upcoming.take(4).map((p) => _UpcomingPaymentCard(
                              payment: p,
                              ref: ref,
                              currency: currency,
                            )),
                    ]),
                  ),
                ),
              ],
            ),

            // Page 1: Dashboard Cards & Analytics (Matching User Screenshots)
            DashboardCardsView(currency: currency),
          ],
        ),
      ),
    );
  }

  void _showAddTransaction(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => AddTransactionSheet(ref: ref),
    );
  }
}

// ─── Top Net Wallet Card ──────────────────────────────────────────────────────

class _NetWalletCard extends StatelessWidget {
  final double netWallet, inflow, outflow, savings;
  final String currency;
  const _NetWalletCard({
    required this.netWallet,
    required this.inflow,
    required this.outflow,
    required this.savings,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final symbol = CurrencyUtil.symbol(currency);
    final isNegative = netWallet < 0;
    final absBalance = netWallet.abs().toStringAsFixed(2);
    final balanceText = isNegative ? '-$symbol$absBalance' : '$symbol$absBalance';
    final savingsRate = inflow > 0 ? ((savings / inflow) * 100).clamp(0, 100).toStringAsFixed(0) : '0';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF2E2276), Color(0xFF1E215C), Color(0xFF13173F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.25),
            blurRadius: 28,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: NET WALLET BALANCE on left, Base: INR pill on right
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.account_balance_wallet_rounded, size: 14, color: AppColors.accent),
                  SizedBox(width: 6),
                  Text(
                    'NET WALLET BALANCE',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Base: $currency',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Main Big Balance
          Text(
            balanceText,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 14),

          // Horizontal divider line
          Divider(
            color: Colors.white.withValues(alpha: 0.15),
            height: 1,
            thickness: 1,
          ),
          const SizedBox(height: 10),

          // 3 Columns: Monthly Inflow, Monthly Outflow, Savings
          Row(
            children: [
              Expanded(
                child: _MetricColumn(
                  iconText: '↑',
                  iconColor: const Color(0xFF4ECCA3),
                  label: 'Inflow',
                  value: CurrencyUtil.format(inflow, currency),
                ),
              ),
              Expanded(
                child: _MetricColumn(
                  iconText: '↓',
                  iconColor: const Color(0xFFFF6B6B),
                  label: 'Outflow',
                  value: CurrencyUtil.format(outflow, currency),
                ),
              ),
              Expanded(
                child: _MetricColumn(
                  iconText: '🐷',
                  iconColor: const Color(0xFF9D97FF),
                  label: 'Savings ($savingsRate%)',
                  value: CurrencyUtil.format(savings, currency),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricColumn extends StatelessWidget {
  final String iconText;
  final Color iconColor;
  final String label;
  final String value;

  const _MetricColumn({
    required this.iconText,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '$iconText ',
              style: TextStyle(
                color: iconColor,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

// ─── Credit Card Style Accounts Carousel ──────────────────────────────────────

class _CreditCardsCarousel extends StatelessWidget {
  final List<Account> accounts;
  final String currency;
  final WidgetRef ref;

  const _CreditCardsCarousel({
    required this.accounts,
    required this.currency,
    required this.ref,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 136,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: accounts.length + 1,
        itemBuilder: (ctx, idx) {
          if (idx == accounts.length) {
            return _AddCreditCard(ref: ref);
          }
          final acc = accounts[idx];
          return _CreditCardItem(account: acc, ref: ref, delay: idx * 50);
        },
      ),
    );
  }
}

class _CreditCardItem extends StatelessWidget {
  final Account account;
  final WidgetRef ref;
  final int delay;

  const _CreditCardItem({
    required this.account,
    required this.ref,
    required this.delay,
  });

  void _showAccountOptions(BuildContext context) {
    final color = Color(account.colorValue);
    final isEnabled = account.isEnabledForCalc;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(color: AppColors.darkBorder, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 14),
              ListTile(
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(child: Text(account.emoji, style: const TextStyle(fontSize: 22))),
                ),
                title: Text(account.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                subtitle: Text('Balance: ${CurrencyUtil.format(account.balance, account.currency)}'),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isEnabled ? AppColors.income.withValues(alpha: 0.15) : AppColors.expense.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isEnabled ? 'Included' : 'Excluded',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isEnabled ? AppColors.income : AppColors.expense,
                    ),
                  ),
                ),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.edit_note_rounded, color: AppColors.primary),
                title: const Text('Update Balance'),
                subtitle: const Text('Directly change current account balance'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showQuickUpdateBalance(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.tune_rounded, color: AppColors.accent),
                title: const Text('Edit Account'),
                subtitle: const Text('Change name, icon, color, currency'),
                onTap: () {
                  Navigator.pop(ctx);
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => AddAccountSheet(ref: ref, existing: account),
                  );
                },
              ),
              ListTile(
                leading: Icon(
                  isEnabled ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                  color: Colors.amber,
                ),
                title: Text(isEnabled ? 'Exclude from Net Wallet' : 'Include in Net Wallet'),
                subtitle: Text(isEnabled ? 'Hide from total net calculation' : 'Count towards total net calculation'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await ref.read(accountsProvider.notifier).toggleEnable(account);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: AppColors.expense),
                title: const Text('Delete Account', style: TextStyle(color: AppColors.expense)),
                onTap: () async {
                  Navigator.pop(ctx);
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (dCtx) => AlertDialog(
                      title: const Text('Delete Account'),
                      content: Text('Are you sure you want to delete ${account.name}?'),
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
                    ref.read(accountsProvider.notifier).delete(account);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showQuickUpdateBalance(BuildContext context) {
    final balanceCtrl = TextEditingController(text: account.balance.toStringAsFixed(2));
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: SafeArea(
          child: Container(
            padding: const EdgeInsets.all(24),
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
                    Text(account.emoji, style: const TextStyle(fontSize: 24)),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Update Balance: ${account.name}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Text('Current: ${CurrencyUtil.format(account.balance, account.currency)}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: balanceCtrl,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^-?[\d.]*'))],
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
                  decoration: InputDecoration(
                    labelText: 'New Balance (${account.currency})',
                    prefixText: '${CurrencyUtil.symbol(account.currency)} ',
                    prefixStyle: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () async {
                      final newBal = double.tryParse(balanceCtrl.text.trim());
                      if (newBal != null) {
                        await ref.read(accountsProvider.notifier).updateBalance(account, newBal);
                        if (context.mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Balance for "${account.name}" updated to ${CurrencyUtil.format(newBal, account.currency)}'),
                              backgroundColor: AppColors.darkCard,
                            ),
                          );
                        }
                      }
                    },
                    child: const Text('Save Balance', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final baseColor = Color(account.colorValue);
    final isEnabled = account.isEnabledForCalc;

    // Masked dummy card digits based on account ID
    final last4 = account.id.hashCode.abs().toString().padLeft(4, '0');
    final maskedNum = '5282 •••• •••• ${last4.length >= 4 ? last4.substring(last4.length - 4) : '1289'}';

    return GestureDetector(
      onTap: () => _showAccountOptions(context),
      child: AnimatedOpacity(
        opacity: isEnabled ? 1.0 : 0.5,
        duration: const Duration(milliseconds: 250),
        child: Container(
          width: 215,
          height: 136,
          margin: const EdgeInsets.only(right: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              colors: [
                baseColor.withValues(alpha: 0.95),
                baseColor.withValues(alpha: 0.72),
                const Color(0xFF10132B),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: baseColor.withValues(alpha: isEnabled ? 0.35 : 0.1),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              children: [
                // Translucent curved background waves matching user reference image
                Positioned(
                  top: -30,
                  right: -15,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -40,
                  left: -15,
                  child: Container(
                    width: 130,
                    height: 130,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.05),
                    ),
                  ),
                ),

                // Main card content
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Top Row: Current Balance label + Amount on left; Mastercard logo on right
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Current Balance',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.75),
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  CurrencyUtil.format(account.balance, account.currency),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 18,
                                    letterSpacing: -0.3,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          // Mastercard Overlapping Circles Logo
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 28,
                                height: 16,
                                child: Stack(
                                  children: [
                                    Container(
                                      width: 16,
                                      height: 16,
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Color(0xFFEB001B), // Red circle
                                      ),
                                    ),
                                    Positioned(
                                      left: 10,
                                      child: Container(
                                        width: 16,
                                        height: 16,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: const Color(0xFFF79E1B).withValues(alpha: 0.92), // Orange circle
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 1),
                              const Text(
                                'mastercard',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 6.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      // Bottom Row: Bank Name & Masked Digits on left; Expiry / Currency on right
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${account.emoji} ${account.name}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12.5,
                                    letterSpacing: 0.1,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  maskedNum,
                                  style: const TextStyle(
                                    color: Colors.white60,
                                    fontSize: 9,
                                    letterSpacing: 0.8,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                account.currency.toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              if (!isEnabled)
                                const Text(
                                  'Excluded',
                                  style: TextStyle(color: Colors.white60, fontSize: 8),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn(delay: Duration(milliseconds: delay), duration: 300.ms);
  }
}

class _AddCreditCard extends StatelessWidget {
  final WidgetRef ref;
  const _AddCreditCard({required this.ref});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (_) => AddAccountSheet(ref: ref),
      ),
      child: Container(
        width: 110,
        height: 136,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: AppColors.darkCardAlt.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.4),
            width: 1.5,
          ),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.primary,
              child: Icon(Icons.add_rounded, color: Colors.white, size: 18),
            ),
            SizedBox(height: 6),
            Text(
              'Add Account',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Split Bills & Shared Expenses Dashboard Section ─────────────────────────

class _DashboardSplitBillsSection extends StatelessWidget {
  final List<Transaction> splitTxns;
  final List<Account> accounts;
  final List<Category> categories;
  final String currency;
  final WidgetRef ref;

  const _DashboardSplitBillsSection({
    required this.splitTxns,
    required this.accounts,
    required this.categories,
    required this.currency,
    required this.ref,
  });

  @override
  Widget build(BuildContext context) {
    double totalPending = 0;
    double totalRecovered = 0;

    for (final txn in splitTxns) {
      if (txn.splits != null) {
        for (final s in txn.splits!) {
          if (s.isPaid) {
            totalRecovered += s.amount;
          } else {
            totalPending += s.amount;
          }
        }
      }
    }

    final activeSplits = splitTxns.where((t) => t.splits != null && t.splits!.any((s) => !s.isPaid)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: 'Split Bills & Shared',
          onSeeAll: () => context.go('/split-bills'),
        ),
        const SizedBox(height: 12),
        if (splitTxns.isEmpty)
          Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => context.go('/split-bills'),
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: AppColors.darkCardAlt,
                      child: Icon(Icons.call_split_rounded, color: AppColors.primary),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('No Active Split Bills', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          SizedBox(height: 2),
                          Text('Split restaurant or shared expenses with friends', style: TextStyle(color: AppColors.darkTextSecondary, fontSize: 12)),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: AppColors.darkTextMuted),
                  ],
                ),
              ),
            ),
          )
        else ...[
          // Summary pills
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.darkCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.darkBorder),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.expense.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.hourglass_top_rounded, size: 14, color: AppColors.expense),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Pending to Collect', style: TextStyle(fontSize: 10, color: AppColors.darkTextSecondary)),
                          Text(
                            '${CurrencyUtil.symbol(currency)}${totalPending.toStringAsFixed(0)}',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.expense),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(width: 1, height: 28, color: AppColors.darkBorder),
                const SizedBox(width: 12),
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.income.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check_circle_outline_rounded, size: 14, color: AppColors.income),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Recovered', style: TextStyle(fontSize: 10, color: AppColors.darkTextSecondary)),
                          Text(
                            '${CurrencyUtil.symbol(currency)}${totalRecovered.toStringAsFixed(0)}',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.income),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Show top 2 active or recent split bills
          ...(activeSplits.isNotEmpty ? activeSplits.take(2) : splitTxns.take(2)).map((txn) {
            final acc = accounts.where((a) => a.id == txn.accountId).firstOrNull;
            final cat = categories.where((c) => c.id == txn.categoryId).firstOrNull;
            final splits = txn.splits ?? [];
            final totalFriends = splits.fold<double>(0.0, (s, e) => s + e.amount);
            final collected = splits.where((s) => s.isPaid).fold<double>(0.0, (s, e) => s + e.amount);
            final paidCount = splits.where((s) => s.isPaid).length;
            final isFullySettled = splits.isNotEmpty && paidCount == splits.length;
            final progress = totalFriends > 0 ? (collected / totalFriends).clamp(0.0, 1.0) : 1.0;

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => context.go('/split-bills'),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          CategoryIcon(category: cat, defaultEmoji: '🍽️', size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  txn.note.isNotEmpty ? txn.note : (cat?.name ?? 'Split Expense'),
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  '${DateUtil.formatDate(txn.date)} • ${acc != null ? '${acc.emoji} ${acc.name}' : ''}',
                                  style: const TextStyle(fontSize: 11, color: AppColors.darkTextSecondary),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${CurrencyUtil.symbol(currency)}${txn.amount.toStringAsFixed(0)}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              Text(
                                '$paidCount/${splits.length} paid',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isFullySettled ? AppColors.income : AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: progress,
                          backgroundColor: AppColors.darkCardAlt,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isFullySettled ? AppColors.income : AppColors.primary,
                          ),
                          minHeight: 4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ],
    );
  }
}

// ─── Transaction Tile ─────────────────────────────────────────────────────────

class _TransactionTile extends ConsumerWidget {
  final Transaction txn;
  final WidgetRef ref;
  final int delay;
  const _TransactionTile({required this.txn, required this.ref, required this.delay});

  void _showDetailsSheet(BuildContext context) {
    final categories = ref.read(categoriesProvider);
    final accounts = ref.read(accountsProvider);
    final cat = categories.where((c) => c.id == txn.categoryId).firstOrNull;
    final acc = accounts.where((a) => a.id == txn.accountId).firstOrNull;
    final color = txn.type == 'income'
        ? AppColors.income
        : txn.type == 'expense'
            ? AppColors.expense
            : AppColors.transfer;
    final sign = txn.type == 'income' ? '+' : txn.type == 'expense' ? '-' : '↔';

    showModalBottomSheet(
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
            if (cat != null)
              _DetailRow(icon: Icons.category_rounded, label: 'Category', value: '${cat.icon} ${cat.name}'),
            if (acc != null)
              _DetailRow(icon: Icons.account_balance_wallet_rounded, label: 'Account', value: '${acc.emoji} ${acc.name}'),
            _DetailRow(icon: Icons.calendar_today_rounded, label: 'Date', value: DateUtil.formatDate(txn.date)),
            if (txn.note.isNotEmpty)
              _DetailRow(icon: Icons.note_rounded, label: 'Note', value: txn.note),

            // Split breakdown if this is a split transaction
            if (txn.isSplit && txn.splits != null && txn.splits!.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Split Breakdown', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  Text(
                    '${txn.splits!.where((s) => s.isPaid).length}/${txn.splits!.length} Settled',
                    style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...txn.splits!.map((s) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              s.isPaid ? Icons.check_circle_rounded : Icons.pending_rounded,
                              size: 14,
                              color: s.isPaid ? AppColors.income : AppColors.expense,
                            ),
                            const SizedBox(width: 8),
                            Text(s.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                          ],
                        ),
                        Text(
                          '${CurrencyUtil.symbol(acc?.currency ?? 'INR')}${s.amount.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: s.isPaid ? AppColors.income : Colors.white,
                          ),
                        ),
                      ],
                    ),
                  )),
            ],

            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.delete_outline_rounded, color: AppColors.expense, size: 18),
                    label: const Text('Delete', style: TextStyle(color: AppColors.expense)),
                    onPressed: () {
                      ref.read(transactionsProvider.notifier).delete(txn);
                      Navigator.pop(ctx);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.edit_rounded, size: 18),
                    label: const Text('Edit'),
                    onPressed: () {
                      Navigator.pop(ctx);
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        builder: (_) => AddTransactionSheet(ref: ref, existing: txn),
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
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesProvider);
    final accounts = ref.watch(accountsProvider);
    final cat = categories.where((c) => c.id == txn.categoryId).firstOrNull;
    final acc = accounts.where((a) => a.id == txn.accountId).firstOrNull;

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
          cat?.name ?? (txn.note.isNotEmpty ? txn.note : txn.type),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${acc?.name ?? ''} • ${DateUtil.timeAgo(txn.date)}',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '$sign${CurrencyUtil.format(txn.amount, acc?.currency ?? 'INR')}',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
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
                    Text('Split', style: TextStyle(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    ).animate().fadeIn(delay: Duration(milliseconds: delay), duration: 300.ms);
  }
}

// ─── Recent Activity Item (Union of Transaction & DebtCredit) ────────────────

class _RecentActivityItem {
  final Transaction? transaction;
  final DebtCredit? debtCredit;
  final DateTime date;

  _RecentActivityItem({this.transaction, this.debtCredit, required this.date});
}

// ─── Debt/Credit Tile for Recent Activities ──────────────────────────────────

class _DebtCreditTile extends ConsumerWidget {
  final DebtCredit dc;
  final WidgetRef ref;
  final int delay;
  const _DebtCreditTile({required this.dc, required this.ref, required this.delay});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(accountsProvider);
    final acc = accounts.where((a) => a.id == dc.accountId).firstOrNull;
    final isLent = dc.direction == 'lent';
    final color = isLent ? AppColors.expense : AppColors.income;
    final sign = isLent ? '-' : '+';
    final label = isLent ? 'Lent to ${dc.personName}' : 'Borrowed from ${dc.personName}';
    final icon = isLent ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(child: Icon(icon, color: color, size: 22)),
        ),
        title: Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${acc?.name ?? ''} • ${DateUtil.timeAgo(dc.startDate)}',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '$sign${CurrencyUtil.format(dc.amount, acc?.currency ?? 'INR')}',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isLent ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                    size: 10,
                    color: color,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    isLent ? 'Lent' : 'Borrowed',
                    style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: Duration(milliseconds: delay), duration: 300.ms);
  }
}

// ─── Upcoming Payment Card ───────────────────────────────────────────────────

class _UpcomingPaymentCard extends StatelessWidget {
  final PlannedPayment payment;
  final WidgetRef ref;
  final String currency;

  const _UpcomingPaymentCard({
    required this.payment,
    required this.ref,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider);
    final accounts = ref.watch(accountsProvider);
    final cat = categories.where((c) => c.id == payment.categoryId).firstOrNull;
    final acc = accounts.where((a) => a.id == payment.accountId).firstOrNull;

    final now = DateTime.now();
    final isPaidToday = payment.lastPaidDate != null && DateUtil.isSameDay(payment.lastPaidDate!, now);
    final isToday = DateUtil.isSameDay(payment.nextDueDate, now);
    final isPast = payment.nextDueDate.isBefore(DateTime(now.year, now.month, now.day));
    final diffDays = payment.nextDueDate.difference(DateTime(now.year, now.month, now.day)).inDays;

    String dueLabel;
    Color dueColor;
    if (isPaidToday) {
      dueLabel = 'Paid Today';
      dueColor = AppColors.income;
    } else if (isPast) {
      dueLabel = 'Overdue (${DateUtil.formatShort(payment.nextDueDate)})';
      dueColor = AppColors.expense;
    } else if (isToday) {
      dueLabel = 'Due Today';
      dueColor = AppColors.accent;
    } else if (diffDays == 1) {
      dueLabel = 'Due Tomorrow';
      dueColor = AppColors.primary;
    } else if (diffDays <= 7) {
      dueLabel = 'Due in $diffDays days';
      dueColor = AppColors.primary;
    } else {
      dueLabel = 'Due ${DateUtil.formatShort(payment.nextDueDate)}';
      dueColor = AppColors.darkTextSecondary;
    }

    String recurrenceBadge = '';
    if (payment.isRecurring) {
      if (payment.endType == 'occurrences') {
        recurrenceBadge = '${payment.period?.toUpperCase()} (${payment.currentOccurrence}/${payment.totalOccurrences ?? '∞'})';
      } else if (payment.endType == 'until_date' && payment.untilDate != null) {
        recurrenceBadge = '${payment.period?.toUpperCase()} (Till ${DateUtil.formatShort(payment.untilDate!)})';
      } else {
        recurrenceBadge = payment.period?.toUpperCase() ?? 'RECURRING';
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.go('/planned'),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isPaidToday
                      ? AppColors.income.withValues(alpha: 0.15)
                      : isPast
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
                    Text(
                      payment.name,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          dueLabel,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isPaidToday || isPast || isToday ? FontWeight.w600 : FontWeight.normal,
                            color: dueColor,
                          ),
                        ),
                        if (recurrenceBadge.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              recurrenceBadge,
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      '${acc?.emoji ?? '💳'} ${acc?.name ?? ''}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 10),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    CurrencyUtil.format(payment.amount, acc?.currency ?? currency),
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  const SizedBox(height: 4),
                  if (isPaidToday)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.income.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.income.withValues(alpha: 0.4)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle_rounded, size: 12, color: AppColors.income),
                          SizedBox(width: 4),
                          Text(
                            'Paid',
                            style: TextStyle(
                              color: AppColors.income,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () async {
                        await ref.read(plannedPaymentsProvider.notifier).markPaid(payment);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Marked "${payment.name}" as paid & balance updated!'),
                              backgroundColor: AppColors.darkCard,
                            ),
                          );
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check, size: 12, color: Colors.white),
                            SizedBox(width: 3),
                            Text(
                              'Pay',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
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

class _SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onSeeAll;
  const _SectionHeader({required this.title, this.onSeeAll});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
        ),
        if (onSeeAll != null)
          TextButton(
            onPressed: onSeeAll,
            child: const Text('See All', style: TextStyle(color: AppColors.primary, fontSize: 13)),
          ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message, sub;
  const _EmptyState({required this.icon, required this.message, required this.sub});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.darkCard.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icon, size: 40, color: AppColors.darkTextMuted),
          const SizedBox(height: 8),
          Text(message, style: Theme.of(context).textTheme.bodyMedium),
          if (sub.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(sub, style: Theme.of(context).textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}
