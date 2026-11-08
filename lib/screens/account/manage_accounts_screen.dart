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
import '../../widgets/add_account_sheet.dart';
import '../../widgets/account_icon.dart';
import '../../widgets/card_network_badge.dart';
import '../../core/layout/responsive.dart';

class ManageAccountsScreen extends ConsumerWidget {
  const ManageAccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(accountsProvider);
    final user = ref.watch(userProvider);
    final netWallet = ref.watch(netWalletProvider);
    final currency = user?.baseCurrency ?? 'INR';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        context.go('/dashboard');
      },
      child: Scaffold(
        drawer: context.isWide ? null : const AppDrawer(),
        appBar: AppBar(
          // Wide layouts navigate from the sidebar.
          leading: context.isWide ? null : Builder(
            builder: (ctx) => IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () {
                if (Navigator.canPop(context)) {
                  Navigator.pop(context);
                } else {
                  context.go('/dashboard');
                }
              },
            ),
          ),
          title: const Text('Manage Accounts'),
          actions: [
            IconButton(
              tooltip: 'Add Account',
              icon: const Icon(Icons.add_rounded),
              onPressed: () => showAppSheet(
                context: context,
                isScrollControlled: true,
                builder: (_) => AddAccountSheet(ref: ref),
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => showAppSheet(
            context: context,
            isScrollControlled: true,
            builder: (_) => AddAccountSheet(ref: ref),
          ),
          child: const Icon(Icons.add_rounded, size: 28),
        ),
        body: ContentWidth(
          maxWidth: 1200,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
            children: [
              // Top Net Wallet Summary Banner
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2E2276), Color(0xFF191C4A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'TOTAL NET BALANCE',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.1,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${accounts.where((a) => a.isEnabledForCalc).length}/${accounts.length} Active',
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      CurrencyUtil.format(netWallet, currency),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Balance of all accounts included in calculations',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 350.ms),

              const SizedBox(height: 20),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'All Accounts (${accounts.length})',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    'Tap to edit or update balance',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              if (accounts.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: Column(
                      children: [
                        const Icon(Icons.account_balance_wallet_outlined, size: 64, color: AppColors.darkTextMuted),
                        const SizedBox(height: 12),
                        Text('No accounts found', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 4),
                        Text('Tap "+ Add Account" to create your first account', style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ),
                )
              else if (context.isWide)
                GridRows(
                  columns: 2,
                  children: [
                    for (final e in accounts.asMap().entries)
                      _AccountManageCard(account: e.value, ref: ref, delay: e.key * 50),
                  ],
                )
              else
                ...accounts.asMap().entries.map((e) {
                  final acc = e.value;
                  return _AccountManageCard(
                    account: acc,
                    ref: ref,
                    delay: e.key * 50,
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountManageCard extends StatelessWidget {
  final Account account;
  final WidgetRef ref;
  final int delay;

  const _AccountManageCard({
    required this.account,
    required this.ref,
    required this.delay,
  });

  void _showQuickUpdateBalance(BuildContext context) {
    final balanceCtrl = TextEditingController(text: account.balance.toStringAsFixed(2));
    showAppSheet(
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
                Row(
                  children: [
                    AccountIcon(account: account, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Update Balance', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                          Text(account.name, style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
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
                    child: const Text('Update Balance', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = Color(account.colorValue);
    final isEnabled = account.isEnabledForCalc;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: color.withValues(alpha: isEnabled ? 0.35 : 0.15), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                // Account Icon Badge
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: color.withValues(alpha: 0.3)),
                  ),
                  child: Center(child: AccountIcon(account: account, size: 24)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        account.name,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              account.currency,
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary),
                            ),
                          ),
                          const SizedBox(width: 8),
                          CardNetworkBadge(
                            cardType: account.cardType,
                            onCard: false,
                            scale: 0.75,
                          ),
                          const SizedBox(width: 8),
                          if (!isEnabled) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: AppColors.expense.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'Excluded from Net',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.expense),
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          if (account.balance < 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: AppColors.expense.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'Negative',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.expense),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Balance
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      CurrencyUtil.format(account.balance, account.currency),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: account.balance < 0 ? AppColors.expense : (isEnabled ? color : Colors.grey),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 10),

            // Quick Actions Bar
            Row(
              children: [
                // Quick Update Balance Button
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.edit_note_rounded, size: 18),
                    label: const Text('Update Balance', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    onPressed: () => _showQuickUpdateBalance(context),
                  ),
                ),
                const SizedBox(width: 8),

                // Edit full details button
                IconButton(
                  tooltip: 'Edit Account Details',
                  style: IconButton.styleFrom(
                    backgroundColor: isDark ? AppColors.darkCardAlt : AppColors.lightBg,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.tune_rounded, size: 18),
                  onPressed: () => showAppSheet(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => AddAccountSheet(ref: ref, existing: account),
                  ),
                ),
                const SizedBox(width: 4),

                // Include in Net Wallet Calculation Toggle
                IconButton(
                  tooltip: isEnabled ? 'Included in Net Wallet (Tap to exclude)' : 'Excluded from Net Wallet (Tap to include)',
                  style: IconButton.styleFrom(
                    backgroundColor: isEnabled ? AppColors.primary.withValues(alpha: 0.15) : (isDark ? AppColors.darkCardAlt : AppColors.lightBg),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: Icon(
                    isEnabled ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                    size: 18,
                    color: isEnabled ? AppColors.primary : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                  ),
                  onPressed: () => ref.read(accountsProvider.notifier).toggleEnable(account),
                ),
              ],
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: Duration(milliseconds: delay), duration: 300.ms);
  }
}
