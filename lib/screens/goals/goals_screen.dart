import 'dart:math' as math;

import 'package:emoji_picker_flutter/emoji_picker_flutter.dart' hide Category, CategoryIcon;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/layout/responsive.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/utils.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../widgets/account_icon.dart';
import '../../widgets/app_drawer.dart';

// ─── Progress maths (shared with the dashboard) ──────────────────────────────

/// Saved amount, target and pace for one goal.
class GoalProgress {
  final Goal goal;
  final double saved;
  final Account? linkedAccount;

  GoalProgress(this.goal, this.saved, this.linkedAccount);

  double get target => goal.targetAmount;
  double get remaining => math.max(0, target - saved);
  double get fraction => target <= 0 ? 0 : (saved / target).clamp(0.0, 1.0);
  int get percent => (fraction * 100).floor();
  bool get reached => target > 0 && saved >= target - 0.005;

  /// "Save ₹X/month to reach by …", "On track", "Behind", etc.
  String paceText(String currency) {
    if (reached) return 'Target reached 🎉';
    final deadline = goal.deadline;
    if (deadline == null) return '${CurrencyUtil.format(remaining, currency)} to go · no deadline';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final end = DateTime(deadline.year, deadline.month, deadline.day);
    final days = end.difference(today).inDays;
    if (days < 0) return 'Deadline passed · ${CurrencyUtil.format(remaining, currency)} to go';
    if (days < 56) {
      final weeks = math.max(1, (days / 7).ceil());
      return 'Save ${CurrencyUtil.format(remaining / weeks, currency)}/week to reach by ${DateUtil.formatDate(deadline)}';
    }
    final months = math.max(1, (days / 30.44).ceil());
    return 'Save ${CurrencyUtil.format(remaining / months, currency)}/month to reach by ${DateUtil.formatDate(deadline)}';
  }

  /// null when there is no deadline; otherwise whether savings keep up with
  /// a straight line from the start date to the deadline.
  bool? get onTrack {
    final deadline = goal.deadline;
    if (deadline == null || reached) return null;
    final start = goal.createdAt;
    final total = deadline.difference(start).inHours;
    if (total <= 0) return saved >= target;
    final elapsed = DateTime.now().difference(start).inHours.clamp(0, total);
    final expected = target * elapsed / total;
    return saved + 0.005 >= expected;
  }
}

GoalProgress goalProgressOf(Goal g, List<Account> accounts) {
  final linked = g.linkedAccountId == null
      ? null
      : accounts.where((a) => a.id == g.linkedAccountId).firstOrNull;
  final saved = linked != null ? math.max(0.0, linked.balance) : g.contributedAmount;
  return GoalProgress(g, saved, linked);
}

// ─── Screen ──────────────────────────────────────────────────────────────────

class GoalsScreen extends ConsumerWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goals = ref.watch(goalsProvider);
    final accounts = ref.watch(accountsProvider);
    final currency = ref.watch(userProvider)?.baseCurrency ?? 'INR';
    final active = goals.where((g) => !g.isCompleted).toList()
      ..sort((a, b) {
        if (a.deadline == null && b.deadline == null) return a.createdAt.compareTo(b.createdAt);
        if (a.deadline == null) return 1;
        if (b.deadline == null) return -1;
        return a.deadline!.compareTo(b.deadline!);
      });
    final completed = goals.where((g) => g.isCompleted).toList()
      ..sort((a, b) => (b.completedAt ?? b.createdAt).compareTo(a.completedAt ?? a.createdAt));

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
            leading: context.isWide
                ? null
                : Builder(
                    builder: (ctx) => IconButton(
                      icon: const Icon(Icons.menu_rounded),
                      onPressed: () => Scaffold.of(ctx).openDrawer(),
                    ),
                  ),
            title: const Text('Savings Goals'),
            bottom: TabBar(tabs: [
              Tab(text: 'Active (${active.length})'),
              Tab(text: 'Completed (${completed.length})'),
            ]),
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => showGoalSheet(context, ref),
            child: const Icon(Icons.add_rounded, size: 28),
          ),
          body: TabBarView(
            children: [
              _GoalList(goals: active, accounts: accounts, currency: currency, ref: ref),
              _GoalList(goals: completed, accounts: accounts, currency: currency, ref: ref, completedTab: true),
            ],
          ),
        ),
      ),
    );
  }
}

void showGoalSheet(BuildContext context, WidgetRef ref, {Goal? existing}) {
  showAppSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _GoalSheet(ref: ref, existing: existing),
  );
}

class _GoalList extends StatelessWidget {
  final List<Goal> goals;
  final List<Account> accounts;
  final String currency;
  final WidgetRef ref;
  final bool completedTab;

  const _GoalList({
    required this.goals,
    required this.accounts,
    required this.currency,
    required this.ref,
    this.completedTab = false,
  });

  @override
  Widget build(BuildContext context) {
    if (goals.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                completedTab ? Icons.emoji_events_outlined : Icons.savings_outlined,
                size: 56,
                color: AppColors.darkTextMuted,
              ),
              const SizedBox(height: 12),
              Text(
                completedTab ? 'No completed goals yet' : 'No savings goals yet',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              if (!completedTab) ...[
                const SizedBox(height: 4),
                Text(
                  'Set a target for a trip, a gadget or an emergency fund',
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => showGoalSheet(context, ref),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Create a goal'),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return ResponsiveList.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
      minItemWidth: 360,
      itemCount: goals.length,
      itemBuilder: (ctx, i) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: GoalCard(
          progress: goalProgressOf(goals[i], accounts),
          currency: currency,
          ref: ref,
        ).animate().fadeIn(delay: Duration(milliseconds: i * 40), duration: 300.ms),
      ),
    );
  }
}

// ─── Progress ring ───────────────────────────────────────────────────────────

class GoalRing extends StatelessWidget {
  final double fraction;
  final Color color;
  final String emoji;
  final double size;

  const GoalRing({super.key, required this.fraction, required this.color, required this.emoji, this.size = 64});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: fraction,
              strokeWidth: size * 0.09,
              strokeCap: StrokeCap.round,
              backgroundColor: isDark ? AppColors.darkCardAlt : AppColors.lightBorder,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          Text(emoji, style: TextStyle(fontSize: size * 0.36)),
        ],
      ),
    );
  }
}

// ─── Goal card ───────────────────────────────────────────────────────────────

class GoalCard extends StatelessWidget {
  final GoalProgress progress;
  final String currency;
  final WidgetRef ref;

  const GoalCard({super.key, required this.progress, required this.currency, required this.ref});

  @override
  Widget build(BuildContext context) {
    final g = progress.goal;
    final color = Color(g.colorValue);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final onTrack = progress.onTrack;
    final contributions = List<GoalContribution>.from(g.contributions ?? const <GoalContribution>[])
      ..sort((a, b) => b.date.compareTo(a.date));

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    GoalRing(fraction: progress.fraction, color: color, emoji: g.emoji),
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              g.name,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '${progress.percent}%',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text.rich(
                        TextSpan(children: [
                          TextSpan(
                            text: CurrencyUtil.format(progress.saved, currency),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          TextSpan(
                            text: ' of ${CurrencyUtil.format(progress.target, currency)}',
                            style: TextStyle(color: muted),
                          ),
                        ]),
                        style: const TextStyle(fontSize: 13),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        g.isCompleted && g.completedAt != null
                            ? 'Completed ${DateUtil.formatDate(g.completedAt!)}'
                            : progress.paceText(currency),
                        style: TextStyle(fontSize: 11.5, color: muted),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          if (!g.isCompleted && onTrack != null)
                            _Pill(
                              text: onTrack ? 'On track' : 'Behind',
                              color: onTrack ? AppColors.income : AppColors.expense,
                            ),
                          if (progress.linkedAccount != null)
                            _Pill(
                              text: '${progress.linkedAccount!.emoji} ${progress.linkedAccount!.name}',
                              color: AppColors.transfer,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded, size: 20),
                  onSelected: (v) => _onMenu(context, v),
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'edit', child: Text('Edit goal')),
                    PopupMenuItem(
                      value: g.isCompleted ? 'reopen' : 'complete',
                      child: Text(g.isCompleted ? 'Move back to active' : 'Mark as completed'),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text('Delete goal', style: TextStyle(color: AppColors.expense)),
                    ),
                  ],
                ),
              ],
            ),
            if (!g.isCompleted) ...[
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Row(
                  children: [
                    if (progress.linkedAccount == null)
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _addContribution(context),
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text('Add money'),
                        ),
                      )
                    else
                      Expanded(
                        child: Text(
                          'Progress follows this account\'s balance',
                          style: TextStyle(fontSize: 11, color: muted),
                        ),
                      ),
                    if (progress.reached) ...[
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () => _complete(context),
                        icon: const Icon(Icons.emoji_events_rounded, size: 18),
                        label: const Text('Complete'),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            if (contributions.isNotEmpty && progress.linkedAccount == null)
              Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.only(right: 8),
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  title: Text(
                    'Contributions (${contributions.length})',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  children: contributions
                      .map((c) => Row(
                            children: [
                              Icon(Icons.savings_outlined, size: 14, color: color),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${DateUtil.formatDate(c.date)}${c.note.isNotEmpty ? ' • ${c.note}' : ''}',
                                  style: const TextStyle(fontSize: 12),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                CurrencyUtil.format(c.amount, currency),
                                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: color),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.expense),
                                tooltip: 'Remove contribution',
                                visualDensity: VisualDensity.compact,
                                onPressed: () => ref.read(goalsProvider.notifier).removeContribution(g, c.id),
                              ),
                            ],
                          ))
                      .toList(),
                ),
              )
            else
              const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _onMenu(BuildContext context, String v) async {
    final g = progress.goal;
    switch (v) {
      case 'edit':
        showGoalSheet(context, ref, existing: g);
        break;
      case 'complete':
        await _complete(context);
        break;
      case 'reopen':
        await ref.read(goalsProvider.notifier).setCompleted(g, false);
        break;
      case 'delete':
        final ok = await showDialog<bool>(
          context: context,
          builder: (dCtx) => AlertDialog(
            title: const Text('Delete Goal'),
            content: Text('Delete "${g.name}" and its contributions? Account balances are not affected.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Cancel')),
              TextButton(
                onPressed: () => Navigator.pop(dCtx, true),
                child: const Text('Delete', style: TextStyle(color: AppColors.expense)),
              ),
            ],
          ),
        );
        if (ok == true) await ref.read(goalsProvider.notifier).delete(g);
        break;
    }
  }

  Future<void> _complete(BuildContext context) async {
    final g = progress.goal;
    await ref.read(goalsProvider.notifier).setCompleted(g, true);
    if (context.mounted && progress.reached) showGoalCelebration(context, g);
  }

  Future<void> _addContribution(BuildContext context) async {
    final g = progress.goal;
    final wasReached = progress.reached;
    final added = await showDialog<double>(
      context: context,
      builder: (_) => _ContributionDialog(ref: ref, goal: g, currency: currency, remaining: progress.remaining),
    );
    if (added == null || !context.mounted) return;
    final nowSaved = progress.saved + added;
    if (!wasReached && nowSaved >= g.targetAmount - 0.005) {
      await ref.read(goalsProvider.notifier).setCompleted(g, true);
      if (context.mounted) showGoalCelebration(context, g);
    }
  }
}

class _Pill extends StatelessWidget {
  final String text;
  final Color color;
  const _Pill({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

/// A short "goal reached" celebration.
void showGoalCelebration(BuildContext context, Goal g) {
  showDialog(
    context: context,
    builder: (dCtx) => AlertDialog(
      contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 8),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🎉', style: TextStyle(fontSize: 56))
              .animate()
              .scale(begin: const Offset(0.3, 0.3), duration: 500.ms, curve: Curves.elasticOut)
              .then()
              .shake(hz: 3, duration: 500.ms),
          const SizedBox(height: 12),
          const Text('Goal reached!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(
            '${g.emoji} ${g.name} is fully funded. Nicely done.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          const Text(
            'It now sits in the Completed tab.',
            style: TextStyle(fontSize: 12, color: AppColors.darkTextSecondary),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Great!')),
      ],
    ),
  );
}

// ─── Contribution dialog ─────────────────────────────────────────────────────

class _ContributionDialog extends StatefulWidget {
  final WidgetRef ref;
  final Goal goal;
  final String currency;
  final double remaining;

  const _ContributionDialog({
    required this.ref,
    required this.goal,
    required this.currency,
    required this.remaining,
  });

  @override
  State<_ContributionDialog> createState() => _ContributionDialogState();
}

class _ContributionDialogState extends State<_ContributionDialog> {
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  DateTime _date = DateTime.now();
  String? _error;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;
    if (amount <= 0) {
      setState(() => _error = 'Enter an amount above zero');
      return;
    }
    await widget.ref.read(goalsProvider.notifier).addContribution(
          widget.goal,
          amount: amount,
          date: _date,
          note: _noteCtrl.text.trim(),
        );
    if (mounted) Navigator.pop(context, amount);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Add to ${widget.goal.name}'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${CurrencyUtil.format(widget.remaining, widget.currency)} to go. '
              'This sets money aside for the goal; account balances do not change.',
              style: const TextStyle(fontSize: 12, color: AppColors.darkTextSecondary),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _amountCtrl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
              decoration: InputDecoration(
                labelText: 'Amount',
                prefixText: '${CurrencyUtil.symbol(widget.currency)} ',
                errorText: _error,
              ),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                );
                if (d != null) setState(() => _date = d);
              },
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Date',
                  suffixIcon: Icon(Icons.calendar_today_rounded),
                ),
                child: Text(DateUtil.formatDate(_date)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _noteCtrl,
              decoration: const InputDecoration(labelText: 'Note (optional)'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(onPressed: _save, child: const Text('Add')),
      ],
    );
  }
}

// ─── Add / edit goal sheet ───────────────────────────────────────────────────

class _GoalSheet extends StatefulWidget {
  final WidgetRef ref;
  final Goal? existing;
  const _GoalSheet({required this.ref, this.existing});

  @override
  State<_GoalSheet> createState() => _GoalSheetState();
}

class _GoalSheetState extends State<_GoalSheet> {
  final _nameCtrl = TextEditingController();
  final _targetCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _emoji = '🎯';
  Color _color = AppColors.chartColors.first;
  DateTime? _deadline;
  String? _linkedAccountId;
  bool _showEmoji = false;
  bool _saving = false;
  String? _nameError;
  String? _targetError;

  @override
  void initState() {
    super.initState();
    final g = widget.existing;
    if (g != null) {
      _nameCtrl.text = g.name;
      final t = g.targetAmount;
      _targetCtrl.text = t == t.roundToDouble() ? t.toStringAsFixed(0) : t.toStringAsFixed(2);
      _notesCtrl.text = g.notes;
      _emoji = g.emoji;
      _color = Color(g.colorValue);
      _deadline = g.deadline;
      _linkedAccountId = g.linkedAccountId;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _targetCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final target = double.tryParse(_targetCtrl.text.trim()) ?? 0;
    setState(() {
      _nameError = name.isEmpty ? 'Give the goal a name' : null;
      _targetError = target <= 0 ? 'Enter a target above zero' : null;
    });
    if (_nameError != null || _targetError != null) return;
    setState(() => _saving = true);
    final notifier = widget.ref.read(goalsProvider.notifier);
    final g = widget.existing;
    if (g != null) {
      g
        ..name = name
        ..emoji = _emoji
        ..colorValue = _color.toARGB32()
        ..targetAmount = target
        ..deadline = _deadline
        ..linkedAccountId = _linkedAccountId
        ..notes = _notesCtrl.text.trim();
      await notifier.update(g);
    } else {
      await notifier.add(Goal(
        id: '',
        name: name,
        emoji: _emoji,
        colorValue: _color.toARGB32(),
        targetAmount: target,
        deadline: _deadline,
        linkedAccountId: _linkedAccountId,
        createdAt: DateTime.now(),
        notes: _notesCtrl.text.trim(),
      ));
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accounts = widget.ref.read(accountsProvider);
    final currency = widget.ref.read(userProvider)?.baseCurrency ?? 'INR';
    final linkedValid = accounts.any((a) => a.id == _linkedAccountId);

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
                    widget.existing != null ? 'Edit Goal' : 'New Savings Goal',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => setState(() => _showEmoji = !_showEmoji),
                          child: Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: _color.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: _color, width: 2),
                            ),
                            child: Center(child: Text(_emoji, style: const TextStyle(fontSize: 28))),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _nameCtrl,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: InputDecoration(
                              labelText: 'Goal name',
                              hintText: 'e.g. Goa trip, New laptop',
                              errorText: _nameError,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => setState(() => _showEmoji = !_showEmoji),
                        icon: const Icon(Icons.emoji_emotions_outlined, size: 16),
                        label: Text(_showEmoji ? 'Hide emojis' : 'Choose emoji', style: const TextStyle(fontSize: 12)),
                      ),
                    ),
                    if (_showEmoji)
                      SizedBox(
                        height: 240,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: EmojiPicker(
                            onEmojiSelected: (_, e) => setState(() {
                              _emoji = e.emoji;
                              _showEmoji = false;
                            }),
                            config: Config(
                              height: 240,
                              emojiViewConfig: EmojiViewConfig(
                                columns: 8,
                                backgroundColor: isDark ? AppColors.darkCardAlt : AppColors.lightCard,
                              ),
                              categoryViewConfig: CategoryViewConfig(
                                backgroundColor: isDark ? AppColors.darkCard : AppColors.lightBg,
                              ),
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: AppColors.chartColors.map((c) {
                        final selected = c.toARGB32() == _color.toARGB32();
                        return GestureDetector(
                          onTap: () => setState(() => _color = c),
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: c,
                              shape: BoxShape.circle,
                              border: Border.all(color: selected ? Colors.white : Colors.transparent, width: 2.5),
                            ),
                            child: selected ? const Icon(Icons.check_rounded, size: 16, color: Colors.white) : null,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _targetCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                      decoration: InputDecoration(
                        labelText: 'Target amount',
                        prefixText: '${CurrencyUtil.symbol(currency)} ',
                        errorText: _targetError,
                      ),
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: () async {
                        final now = DateTime.now();
                        final d = await showDatePicker(
                          context: context,
                          initialDate: _deadline ?? DateTime(now.year, now.month + 6, now.day),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );
                        if (d != null) setState(() => _deadline = d);
                      },
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Target date (optional)',
                          suffixIcon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_deadline != null)
                                IconButton(
                                  icon: const Icon(Icons.clear, size: 16),
                                  onPressed: () => setState(() => _deadline = null),
                                ),
                              const Icon(Icons.calendar_today_rounded),
                            ],
                          ),
                        ),
                        child: Text(_deadline != null ? DateUtil.formatDate(_deadline!) : 'No deadline'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String?>(
                      initialValue: linkedValid ? _linkedAccountId : null,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Track with an account (optional)',
                        helperText: 'Linked: progress = that account\'s balance. Otherwise add money manually.',
                        helperMaxLines: 2,
                      ),
                      dropdownColor: isDark ? AppColors.darkCard : AppColors.lightCard,
                      items: [
                        const DropdownMenuItem(value: null, child: Text('Not linked (manual contributions)')),
                        ...accounts.map((a) => DropdownMenuItem(
                              value: a.id,
                              child: Row(
                                children: [
                                  AccountIcon(account: a, size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text(a.name, overflow: TextOverflow.ellipsis)),
                                ],
                              ),
                            )),
                      ],
                      onChanged: (v) => setState(() => _linkedAccountId = v),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _notesCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(labelText: 'Notes (optional)'),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _save,
                        child: Text(widget.existing != null ? 'Update Goal' : 'Create Goal'),
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
