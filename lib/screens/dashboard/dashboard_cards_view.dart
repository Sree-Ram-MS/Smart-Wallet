import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/layout/responsive.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/utils.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../widgets/category_icon.dart';
import '../../widgets/account_icon.dart';

class DashboardCardsView extends ConsumerStatefulWidget {
  final String currency;
  const DashboardCardsView({super.key, required this.currency});

  @override
  ConsumerState<DashboardCardsView> createState() => _DashboardCardsViewState();
}

class _DashboardCardsViewState extends ConsumerState<DashboardCardsView> {
  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  // Cash flow sub-filter (0: Cash flow, 1: Expenses, 2: Income)
  int _cashflowFilter = 0;

  // Spending sub-filter (0: All, 1: Must, 2: Need, 3: Want)
  int _spendingFilter = 0;

  @override
  Widget build(BuildContext context) {
    final cardOrder = ref.watch(analyticsCardOrderProvider);

    if (context.isWide) return _buildWideGrid(context, cardOrder);

    return ReorderableListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      physics: const BouncingScrollPhysics(),
      buildDefaultDragHandles: false,
      proxyDecorator: _proxyDecorator,
      onReorderStart: (index) {
        HapticFeedback.mediumImpact();
      },
      onReorderItem: (oldIndex, newIndex) {
        HapticFeedback.selectionClick();
        ref.read(analyticsCardOrderProvider.notifier).reorder(oldIndex, newIndex);
      },
      header: _buildHeader(context),
      itemCount: cardOrder.length,
      itemBuilder: (context, index) {
        final cardId = cardOrder[index];
        return Padding(
          key: ValueKey(cardId),
          padding: const EdgeInsets.only(bottom: 18),
          child: _buildCardById(cardId, index),
        );
      },
    );
  }

  // ─── Wide layout: responsive 2–3 column grid ──────────────────────────────────

  Widget _buildWideGrid(BuildContext context, List<String> cardOrder) {
    return LayoutBuilder(builder: (context, constraints) {
      final columns = constraints.maxWidth >= 1150 ? 3 : 2;
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(context),
            MasonryColumns(
              columns: columns,
              spacing: 18,
              children: [
                for (var i = 0; i < cardOrder.length; i++)
                  Padding(
                    key: ValueKey(cardOrder[i]),
                    padding: const EdgeInsets.only(bottom: 18),
                    child: _buildCardById(cardOrder[i], i),
                  ),
              ],
            ),
          ],
        ),
      );
    });
  }

  /// Wide layouts have no drag-to-reorder list; offer a move menu instead.
  Widget _buildMoveMenu(int index) {
    final count = ref.read(analyticsCardOrderProvider).length;
    return PopupMenuButton<int>(
      tooltip: 'Move card',
      icon: Icon(
        Icons.more_horiz_rounded,
        size: 18,
        color: _isDark ? Colors.white70 : AppColors.lightTextSecondary,
      ),
      onSelected: (target) => ref.read(analyticsCardOrderProvider.notifier).reorder(index, target),
      itemBuilder: (_) => [
        PopupMenuItem(value: 0, enabled: index > 0, child: const Text('Move to first')),
        PopupMenuItem(value: index - 1, enabled: index > 0, child: const Text('Move earlier')),
        PopupMenuItem(value: index + 1, enabled: index < count - 1, child: const Text('Move later')),
        PopupMenuItem(value: count - 1, enabled: index < count - 1, child: const Text('Move to last')),
      ],
    );
  }

  // ─── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text(
                'Analytics & Insights',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: _isDark ? Colors.white : AppColors.lightText,
                ),
              ),
              const SizedBox(width: 8),
              Tooltip(
                message: context.isWide ? 'Use the ⋯ menu on a card to reorder' : 'Drag handles to reorder cards',
                child: Icon(
                  Icons.swap_vert_rounded,
                  size: 18,
                  color: _isDark ? Colors.white.withValues(alpha: 0.35) : AppColors.lightTextMuted,
                ),
              ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: () {
                  ref.read(analyticsCardOrderProvider.notifier).resetToDefault();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Card order reset to default'),
                      duration: const Duration(seconds: 2),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  );
                },
                icon: Icon(
                  Icons.restart_alt_rounded,
                  size: 18,
                  color: _isDark ? Colors.white.withValues(alpha: 0.6) : AppColors.lightTextSecondary,
                ),
                tooltip: 'Reset card order',
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                ),
                child: Text(
                  'Base: ${widget.currency}',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Proxy Decorator (Floating Dragged Card) ────────────────────────────────

  Widget _proxyDecorator(Widget child, int index, Animation<double> animation) {
    return AnimatedBuilder(
      animation: animation,
      builder: (BuildContext context, Widget? child) {
        final animValue = Curves.easeInOutCubic.transform(animation.value);
        final elevation = lerpDouble(0, 16, animValue)!;
        final scale = lerpDouble(1.0, 1.025, animValue)!;

        return Transform.scale(
          scale: scale,
          child: Material(
            color: Colors.transparent,
            elevation: elevation,
            shadowColor: AppColors.primary.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.5 * animValue),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.2 * animValue),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: child,
            ),
          ),
        );
      },
      child: child,
    );
  }

  // ─── Card Selector Dispatcher ───────────────────────────────────────────────

  Widget _buildCardById(String cardId, int index) {
    switch (cardId) {
      case 'period_comparison':
        return _buildPeriodComparisonCard(index);
      case 'cash_flow':
        return _buildCashFlowCard(index);
      case 'nature_of_spending':
        return _buildSpendingNatureCard(index);
      case 'income_expense_book':
        return _buildIncomeExpenseBookCard(index);
      case 'net_balance':
        return _buildNetBalanceCard(index);
      default:
        return const SizedBox.shrink();
    }
  }

  // ─── Card Header Action Helper ──────────────────────────────────────────────

  Widget _buildCardHeader({
    required String title,
    String? subtitle,
    required int index,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _isDark ? Colors.white : AppColors.lightText,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: _isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 8),
        if (context.isWide)
          _buildMoveMenu(index)
        else
        ReorderableDragStartListener(
          index: index,
          child: MouseRegion(
            cursor: SystemMouseCursors.grab,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: _isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _isDark ? Colors.white.withValues(alpha: 0.1) : AppColors.lightBorder),
              ),
              child: Icon(
                Icons.drag_indicator_rounded,
                size: 18,
                color: _isDark ? Colors.white70 : AppColors.lightTextSecondary,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ─── 1. Period to Period Comparison Card ────────────────────────────────────

  Widget _buildPeriodComparisonCard(int index) {
    final analytics = ref.watch(dashboardAnalyticsProvider);

    double currentTotal = 0;
    List<FlSpot> currentSpots = [];
    List<FlSpot> prevSpots = [];
    List<FlSpot> lastYearSpots = [];

    if (_cashflowFilter == 0) {
      currentTotal = analytics.netCashFlow;
      currentSpots = analytics.cashFlowSpots;
      prevSpots = analytics.prevCashFlowSpots;
      lastYearSpots = analytics.lastYearCashFlowSpots;
    } else if (_cashflowFilter == 1) {
      currentTotal = analytics.totalExpense;
      currentSpots = analytics.expenseSpots;
      prevSpots = analytics.prevExpenseSpots;
      lastYearSpots = analytics.lastYearExpenseSpots;
    } else {
      currentTotal = analytics.totalIncome;
      currentSpots = analytics.incomeSpots;
      prevSpots = analytics.prevIncomeSpots;
      lastYearSpots = analytics.lastYearIncomeSpots;
    }

    final symbol = CurrencyUtil.symbol(widget.currency);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardHeader(
            title: 'Period to Period Comparison',
            subtitle: 'How am I doing versus the previous period, and the same period from last year?',
            index: index,
          ),
          const SizedBox(height: 16),
          Text(
            'LAST 30 DAYS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: _isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$symbol${currentTotal.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: _isDark ? Colors.white : AppColors.lightText,
            ),
          ),
          const SizedBox(height: 14),

          // Filter Pills: [ Cash flow ] [ Expenses ] [ Income ]
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: _isDark ? AppColors.darkCardAlt : AppColors.lightBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _isDark ? Colors.white10 : AppColors.lightBorder),
            ),
            child: Row(
              children: [
                _buildSubFilterTab('Cash flow', 0, _cashflowFilter, (idx) {
                  setState(() => _cashflowFilter = idx);
                }),
                _buildSubFilterTab('Expenses', 1, _cashflowFilter, (idx) {
                  setState(() => _cashflowFilter = idx);
                }),
                _buildSubFilterTab('Income', 2, _cashflowFilter, (idx) {
                  setState(() => _cashflowFilter = idx);
                }),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // RepaintBoundary for silky smooth chart rendering
          RepaintBoundary(
            child: SizedBox(
              height: 160,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (v) => FlLine(
                      color: _isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.06),
                      strokeWidth: 1,
                      dashArray: [4, 4],
                    ),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 36,
                        getTitlesWidget: (v, m) {
                          if (v == 0) return Text('0', style: TextStyle(color: _isDark ? Colors.white38 : AppColors.lightTextMuted, fontSize: 9));
                          if (v > 0) return Text('${v ~/ 1000}k', style: TextStyle(color: _isDark ? Colors.white38 : AppColors.lightTextMuted, fontSize: 9));
                          return Text('${v ~/ 1000}k', style: TextStyle(color: _isDark ? Colors.white38 : AppColors.lightTextMuted, fontSize: 9));
                        },
                      ),
                    ),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 20,
                        // One label slot per point; on wider charts fl_chart
                        // otherwise picks fractional steps and repeats labels.
                        interval: 1,
                        getTitlesWidget: (v, m) {
                          final idx = v.toInt();
                          if (idx == 0) return Text('30d ago', style: TextStyle(color: _isDark ? Colors.white38 : AppColors.lightTextMuted, fontSize: 9));
                          if (idx == 3) return Text('15d ago', style: TextStyle(color: _isDark ? Colors.white38 : AppColors.lightTextMuted, fontSize: 9));
                          if (idx == 6) return Text('Today', style: TextStyle(color: _isDark ? Colors.white38 : AppColors.lightTextMuted, fontSize: 9));
                          return const SizedBox();
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    // Current Period (Glowing Blue Line with Area)
                    LineChartBarData(
                      spots: currentSpots.isEmpty ? const [FlSpot(0, 0)] : currentSpots,
                      isCurved: true,
                      color: const Color(0xFF5BA4FF),
                      barWidth: 2.5,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: const Color(0xFF5BA4FF).withValues(alpha: 0.15),
                      ),
                    ),
                    // Previous Period (Orange/Gold Line)
                    LineChartBarData(
                      spots: prevSpots.isEmpty ? const [FlSpot(0, 0)] : prevSpots,
                      isCurved: true,
                      color: const Color(0xFFFFB038),
                      barWidth: 2,
                      dotData: const FlDotData(show: false),
                    ),
                    // Same Period Last Year (Red/Pink Line)
                    LineChartBarData(
                      spots: lastYearSpots.isEmpty ? const [FlSpot(0, 0)] : lastYearSpots,
                      isCurved: true,
                      color: const Color(0xFFFF5252),
                      barWidth: 1.5,
                      dashArray: [4, 4],
                      dotData: const FlDotData(show: false),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Legends: Current, Previous, Same period last year
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: const [
              _ChartLegendPill(color: Color(0xFF5BA4FF), label: 'Current period'),
              _ChartLegendPill(color: Color(0xFFFF5252), label: 'Previous period'),
              _ChartLegendPill(color: Color(0xFFFFB038), label: 'Same period last year'),
            ],
          ),
        ],
      ),
    );
  }

  // ─── 2. Cash Flow Card ──────────────────────────────────────────────────────

  Widget _buildCashFlowCard(int index) {
    final analytics = ref.watch(dashboardAnalyticsProvider);
    final netCashFlow = analytics.netCashFlow;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardHeader(
            title: 'Cash Flow',
            subtitle: 'Am I spending less than I make?',
            index: index,
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('LAST 30 DAYS', style: TextStyle(fontSize: 10, color: _isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)),
                  const SizedBox(height: 2),
                  Text(
                    CurrencyUtil.format(netCashFlow, widget.currency),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: netCashFlow < 0
                          ? AppColors.expense
                          : (_isDark ? Colors.white : AppColors.lightText),
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('vs past period', style: TextStyle(fontSize: 10, color: _isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)),
                  const SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: (netCashFlow >= 0 ? AppColors.income : AppColors.expense).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      netCashFlow >= 0 ? '+Positive Flow' : '-Deficit',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: netCashFlow >= 0 ? AppColors.income : AppColors.expense,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── 3. The Nature of Spending Card ─────────────────────────────────────────

  Widget _buildSpendingNatureCard(int index) {
    final analytics = ref.watch(dashboardAnalyticsProvider);
    final categories = ref.watch(categoriesProvider);
    final totalSpending = analytics.totalSpending;
    final sortedCats = analytics.topSpendingCategories;
    final dailySpending = analytics.dailySpending;
    final symbol = CurrencyUtil.symbol(widget.currency);

    final List<Color> barColors = [
      const Color(0xFFFF5252), // Red
      const Color(0xFF76FF03), // Lime green
      const Color(0xFFFF9100), // Orange
      const Color(0xFF00E5FF), // Cyan
      const Color(0xFFE040FB), // Magenta
      const Color(0xFFFFD600), // Yellow
    ];

    final maxDailySpend = dailySpending.fold<double>(0.0, (m, v) => v > m ? v : m);
    final chartMaxY = maxDailySpend > 0 ? maxDailySpend * 1.2 : 80.0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardHeader(
            title: 'The Nature of Spending',
            subtitle: 'How much must I pay, need to pay, or I just want to spend?',
            index: index,
          ),
          const SizedBox(height: 16),
          Text(
            'LAST 30 DAYS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: _isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$symbol${totalSpending.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: _isDark ? Colors.white : AppColors.lightText,
            ),
          ),
          const SizedBox(height: 14),

          // Filter Pills: [ All ] [ Must ] [ Need ] [ Want ]
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: _isDark ? AppColors.darkCardAlt : AppColors.lightBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _isDark ? Colors.white10 : AppColors.lightBorder),
            ),
            child: Row(
              children: [
                _buildSubFilterTab('All', 0, _spendingFilter, (idx) => setState(() => _spendingFilter = idx)),
                _buildSubFilterTab('Must', 1, _spendingFilter, (idx) => setState(() => _spendingFilter = idx)),
                _buildSubFilterTab('Need', 2, _spendingFilter, (idx) => setState(() => _spendingFilter = idx)),
                _buildSubFilterTab('Want', 3, _spendingFilter, (idx) => setState(() => _spendingFilter = idx)),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // RepaintBoundary for BarChart
          RepaintBoundary(
            child: SizedBox(
              height: 130,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: chartMaxY,
                  barTouchData: BarTouchData(enabled: false),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (v, m) {
                          final idx = v.toInt();
                          if (idx == 0) return Text('30d ago', style: TextStyle(color: _isDark ? Colors.white38 : AppColors.lightTextMuted, fontSize: 9));
                          if (idx == 10) return Text('20d ago', style: TextStyle(color: _isDark ? Colors.white38 : AppColors.lightTextMuted, fontSize: 9));
                          if (idx == 20) return Text('10d ago', style: TextStyle(color: _isDark ? Colors.white38 : AppColors.lightTextMuted, fontSize: 9));
                          if (idx == 29) return Text('Today', style: TextStyle(color: _isDark ? Colors.white38 : AppColors.lightTextMuted, fontSize: 9));
                          return const SizedBox();
                        },
                      ),
                    ),
                  ),
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  barGroups: List.generate(30, (i) {
                    final spend = (dailySpending.length > i) ? dailySpending[i] : 0.0;
                    final hasSpend = spend > 0;
                    return BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: hasSpend ? spend : chartMaxY * 0.05,
                          color: hasSpend
                              ? (i % 3 == 0
                                  ? const Color(0xFFFF5252)
                                  : (i % 3 == 1 ? const Color(0xFF76FF03) : const Color(0xFFFF9100)))
                              : (_isDark ? const Color(0xFF2E2E38) : AppColors.lightBg),
                          width: 7,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Legend dots: Must, Need, Want
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _ChartLegendPill(color: Color(0xFFFF5252), label: 'Must'),
              SizedBox(width: 14),
              _ChartLegendPill(color: Color(0xFFFF9100), label: 'Need'),
              SizedBox(width: 14),
              _ChartLegendPill(color: Color(0xFF76FF03), label: 'Want'),
            ],
          ),
          const SizedBox(height: 24),

          // TOP CATEGORIES with horizontal progress bars
          Text(
            'TOP CATEGORIES',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: _isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 14),

          if (sortedCats.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text('No category expenses recorded yet', style: TextStyle(color: _isDark ? Colors.white60 : AppColors.lightTextMuted)),
              ),
            )
          else
            ...sortedCats.take(6).toList().asMap().entries.map((entry) {
              final idx = entry.key;
              final catItem = entry.value;
              final cat = categories.where((c) => c.id == catItem.key).firstOrNull;
              final color = barColors[idx % barColors.length];
              final progress = totalSpending > 0 ? (catItem.value / totalSpending).clamp(0.05, 1.0) : 0.0;

              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          cat?.name ?? 'Other',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: _isDark ? Colors.white : AppColors.lightText),
                        ),
                        Text(
                          '$symbol${catItem.value.toStringAsFixed(2)}',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _isDark ? Colors.white : AppColors.lightText),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Stack(
                      children: [
                        Container(
                          height: 12,
                          decoration: BoxDecoration(
                            color: _isDark ? const Color(0xFF2E2E38) : AppColors.lightBg,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        FractionallySizedBox(
                          widthFactor: progress,
                          child: Container(
                            height: 12,
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  // ─── 4. Income & Expenses Book Card ─────────────────────────────────────────

  Widget _buildIncomeExpenseBookCard(int index) {
    final analytics = ref.watch(dashboardAnalyticsProvider);
    final categories = ref.watch(categoriesProvider);
    final totalIncome = analytics.totalIncome;
    final totalExpense = analytics.totalExpense;
    final incomeCatMap = analytics.incomeCategoryMap;
    final expenseCatMap = analytics.expenseCategoryMap;

    final symbol = CurrencyUtil.symbol(widget.currency);
    final totalBook = totalIncome + totalExpense;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardHeader(
            title: 'Income & Expenses Book in ${widget.currency}',
            subtitle: 'Want to see where your money goes?',
            index: index,
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('LAST 30 DAYS', style: TextStyle(fontSize: 10, color: _isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)),
                  const SizedBox(height: 2),
                  Text(
                    '$symbol${totalBook.toStringAsFixed(2)}',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: _isDark ? Colors.white : AppColors.lightText),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('vs past period', style: TextStyle(fontSize: 10, color: _isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)),
                  const SizedBox(height: 2),
                  Text(
                    '-100%',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: totalIncome >= totalExpense ? AppColors.income : AppColors.expense,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          Divider(color: _isDark ? AppColors.darkBorder : AppColors.lightBorder),
          const SizedBox(height: 12),

          // Section 1: Income
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Income', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: _isDark ? Colors.white : AppColors.lightText)),
              Text(
                '${totalIncome.toStringAsFixed(2)}   0%',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _isDark ? Colors.white : AppColors.lightText),
              ),
            ],
          ),
          const SizedBox(height: 8),

          if (incomeCatMap.isEmpty)
            _buildReportRow(
              emoji: '💰',
              name: 'Income',
              amount: 0.0,
              pct: '---',
            )
          else
            ...incomeCatMap.entries.map((entry) {
              final cat = categories.where((c) => c.id == entry.key).firstOrNull;
              final pct = totalIncome > 0 ? '${(entry.value / totalIncome * 100).toStringAsFixed(0)}%' : '0%';
              return _buildReportRow(
                category: cat,
                emoji: '💰',
                name: cat?.name ?? 'Unknown Income',
                amount: entry.value,
                pct: pct,
              );
            }),

          const SizedBox(height: 16),
          Divider(color: _isDark ? AppColors.darkBorder : AppColors.lightBorder),
          const SizedBox(height: 12),

          // Section 2: Expenses
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Expenses', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: _isDark ? Colors.white : AppColors.lightText)),
              Text(
                '${totalExpense.toStringAsFixed(2)}   0%',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _isDark ? Colors.white : AppColors.lightText),
              ),
            ],
          ),
          const SizedBox(height: 8),

          if (expenseCatMap.isEmpty)
            _buildReportRow(
              emoji: '🍽️',
              name: 'Food & Drinks',
              amount: 0.0,
              pct: '---',
            )
          else
            ...expenseCatMap.entries.map((entry) {
              final cat = categories.where((c) => c.id == entry.key).firstOrNull;
              final pct = totalExpense > 0 ? '${(entry.value / totalExpense * 100).toStringAsFixed(0)}%' : '0%';
              return _buildReportRow(
                category: cat,
                emoji: '🏷️',
                name: cat?.name ?? 'Unknown Expense',
                amount: entry.value,
                pct: pct,
              );
            }),
        ],
      ),
    );
  }

  Widget _buildReportRow({
    Category? category,
    String? emoji,
    required String name,
    required double amount,
    required String pct,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          CategoryIcon(category: category, defaultEmoji: emoji ?? '🏷️', size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              name,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: _isDark ? Colors.white : AppColors.lightText),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            amount > 0 ? amount.toStringAsFixed(2) : '0',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _isDark ? Colors.white : AppColors.lightText),
          ),
          const SizedBox(width: 14),
          SizedBox(
            width: 32,
            child: Text(
              pct,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 12, color: AppColors.income, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // ─── 5. Net Balance Card ────────────────────────────────────────────────────

  Widget _buildNetBalanceCard(int index) {
    final netWallet = ref.watch(netWalletProvider);
    final accounts = ref.watch(accountsProvider);
    final enabledCount = accounts.where((a) => a.isEnabledForCalc).length;
    final totalCount = accounts.length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardHeader(
            title: 'Total Net Balance',
            subtitle: 'Sum of accounts included in wallet balance',
            index: index,
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                CurrencyUtil.format(netWallet, widget.currency),
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: netWallet < 0 ? AppColors.expense : (_isDark ? Colors.white : AppColors.lightText),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
                ),
                child: Text(
                  '$enabledCount/$totalCount Included',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(color: _isDark ? AppColors.darkBorder : AppColors.lightBorder),
          const SizedBox(height: 8),
          if (accounts.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Text(
                  'No accounts added yet',
                  style: TextStyle(color: _isDark ? Colors.white38 : AppColors.lightTextMuted, fontSize: 13),
                ),
              ),
            )
          else
            ...accounts.map((a) {
              final isIncluded = a.isEnabledForCalc;
              return InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  ref.read(accountsProvider.notifier).toggleEnable(a);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        isIncluded
                            ? '${a.name} excluded from Total Net Balance'
                            : '${a.name} included in Total Net Balance',
                      ),
                      duration: const Duration(seconds: 2),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                  child: Row(
                    children: [
                      Opacity(
                        opacity: isIncluded ? 1.0 : 0.45,
                        child: AccountIcon(account: a, size: 18),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                a.name,
                                style: TextStyle(
                                  color: isIncluded
                                      ? (_isDark ? Colors.white : AppColors.lightText)
                                      : (_isDark ? Colors.white38 : AppColors.lightTextMuted),
                                  fontWeight: isIncluded ? FontWeight.w600 : FontWeight.normal,
                                  decoration: isIncluded ? null : TextDecoration.lineThrough,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (!isIncluded) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: AppColors.expense.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'Excluded',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.expense,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Text(
                        CurrencyUtil.format(a.balance, a.currency),
                        style: TextStyle(
                          color: isIncluded
                              ? (_isDark ? Colors.white : AppColors.lightText)
                              : (_isDark ? Colors.white38 : AppColors.lightTextMuted),
                          fontWeight: isIncluded ? FontWeight.bold : FontWeight.normal,
                          decoration: isIncluded ? null : TextDecoration.lineThrough,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        isIncluded ? Icons.check_circle_rounded : Icons.remove_circle_outline_rounded,
                        size: 16,
                        color: isIncluded ? AppColors.income : (_isDark ? Colors.white24 : Colors.grey.shade400),
                      ),
                    ],
                  ),
                ),
              );
            }),
          if (accounts.any((a) => !a.isEnabledForCalc)) ...[
            const SizedBox(height: 8),
            Text(
              'Tap an account to toggle include/exclude. Excluded accounts do not contribute to Total Net Balance.',
              style: TextStyle(
                fontSize: 10,
                fontStyle: FontStyle.italic,
                color: _isDark ? Colors.white38 : AppColors.lightTextMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─── Sub-filter Tab Widget ──────────────────────────────────────────────────

  Widget _buildSubFilterTab(String label, int index, int currentSelected, Function(int) onSelect) {
    final isSelected = currentSelected == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onSelect(index);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF5BA4FF) : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFF5BA4FF).withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.white : (_isDark ? Colors.white60 : AppColors.lightTextSecondary),
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}

class _ChartLegendPill extends StatelessWidget {
  final Color color;
  final String label;
  const _ChartLegendPill({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(fontSize: 10, color: isDark ? Colors.white70 : AppColors.lightTextSecondary, fontWeight: FontWeight.w500)),
      ],
    );
  }
}
