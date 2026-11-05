import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/responsive_layout.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/money.dart';
import '../../settings/providers/settings_provider.dart';
import '../models/report_data.dart';
import '../providers/reports_providers.dart';
import '../utils/category_icons.dart';

/// Mind & Money — Nothing OS Minimalist Financial Reports View.
/// Displays month navigation, compact 3-metric financial summary,
/// Income vs. Expense bar comparison, Category expense donut chart,
/// and a 6-month spending trend line chart with responsive sizing and zero clipping.
class ReportsView extends ConsumerWidget {
  const ReportsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final settings = ref.watch(settingsProvider);
    final selectedMonth = ref.watch(selectedReportMonthProvider);
    final reportAsync = ref.watch(financialReportProvider);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(financialReportProvider);
          await ref.read(financialReportProvider.future);
        },
        child: ResponsiveContentWrapper(
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
            children: [
              // 1. Minimalist Month Selector Header
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.primarySurfaceDark
                      : AppColors.primarySurfaceLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark
                        ? AppColors.borderDividerDark
                        : AppColors.borderDividerLight,
                    width: 1.0,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left_rounded),
                      tooltip: 'Previous Month',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => ref
                          .read(selectedReportMonthProvider.notifier)
                          .previousMonth(),
                    ),
                    Expanded(
                      child: Text(
                        AppDateUtils.toMonthYear(selectedMonth),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontFamily: 'NotoSansMono',
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right_rounded),
                      tooltip: 'Next Month',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => ref
                          .read(selectedReportMonthProvider.notifier)
                          .nextMonth(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              reportAsync.when(
                loading: () => const SizedBox(
                  height: 240,
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (err, _) => Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Column(
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          color: Colors.red,
                          size: 36,
                        ),
                        const SizedBox(height: 8),
                        Text('Error generating reports: $err'),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: () =>
                              ref.invalidate(financialReportProvider),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
                data: (summary) {
                  return Semantics(
                    label: summary.screenReaderSummary,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // 2. Compact Financial Summary (Income, Expenses, Net Balance)
                        _buildCompactFinancialSummary(
                          context,
                          summary,
                          settings.currencySymbol,
                        ),
                        const SizedBox(height: 14),

                        // 3. Monthly Income vs Expenses Comparison
                        _buildIncomeExpenseCard(
                          context,
                          summary,
                          settings.currencySymbol,
                        ),
                        const SizedBox(height: 14),

                        // 4. Category-Wise Expense Breakdown (Donut Chart)
                        _buildCategoryBreakdownCard(
                          context,
                          summary,
                          settings.currencySymbol,
                        ),
                        const SizedBox(height: 14),

                        // 5. Monthly Spending Trends (Line Chart)
                        _buildSpendingTrendsCard(
                          context,
                          summary,
                          settings.currencySymbol,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Compact, responsive summary showing Income, Expenses, and Net Balance
  /// without text clipping or overflow across 320px–800px screens.
  Widget _buildCompactFinancialSummary(
    BuildContext context,
    FinancialReportSummary summary,
    String currencySymbol,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final income = summary.totalIncome;
    final expense = summary.totalExpense;
    final net = summary.netSavings;
    final isDark = theme.brightness == Brightness.dark;

    final incomeColor = isDark
        ? AppColors.incomeGreenDark
        : AppColors.incomeGreen;
    final expenseColor = isDark
        ? AppColors.nothingRedDark
        : AppColors.nothingRed;
    final netColor = net.isNegative
        ? expenseColor
        : (net.isZero
              ? (isDark
                    ? AppColors.primaryTextDark
                    : AppColors.primaryTextLight)
              : incomeColor);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 340;

            final stats = [
              (
                label: 'INCOME',
                amount: income.format(symbol: currencySymbol),
                color: incomeColor,
              ),
              (
                label: 'EXPENSES',
                amount: expense.format(symbol: currencySymbol),
                color: expenseColor,
              ),
              (
                label: 'NET BALANCE',
                amount: net.format(symbol: currencySymbol),
                color: netColor,
              ),
            ];

            if (isNarrow) {
              return Column(
                children: [
                  for (int i = 0; i < stats.length; i++) ...[
                    if (i > 0)
                      Divider(
                        height: 14,
                        thickness: 0.5,
                        color: colorScheme.outlineVariant.withValues(
                          alpha: 0.35,
                        ),
                      ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          stats[i].label,
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontFamily: 'NotoSansMono',
                            fontSize: 10,
                            letterSpacing: 0.8,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            stats[i].amount,
                            textAlign: TextAlign.end,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontFamily: 'NotoSansMono',
                              fontWeight: FontWeight.w700,
                              color: stats[i].color,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              );
            }

            return Row(
              children: [
                for (int i = 0; i < stats.length; i++) ...[
                  if (i > 0)
                    Container(
                      height: 32,
                      width: 1,
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      color: colorScheme.outlineVariant.withValues(alpha: 0.35),
                    ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          stats[i].label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontFamily: 'NotoSansMono',
                            fontSize: 9.5,
                            letterSpacing: 0.6,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 3),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            stats[i].amount,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontFamily: 'NotoSansMono',
                              fontWeight: FontWeight.w800,
                              color: stats[i].color,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildIncomeExpenseCard(
    BuildContext context,
    FinancialReportSummary summary,
    String currencySymbol,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final income = summary.totalIncome;
    final expense = summary.totalExpense;

    final incomeColor = isDark
        ? AppColors.incomeGreenDark
        : AppColors.incomeGreen;
    final expenseColor = isDark
        ? AppColors.nothingRedDark
        : AppColors.nothingRed;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Income vs. Expenses',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (summary.savingsRate > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: incomeColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: incomeColor.withValues(alpha: 0.4),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      '${summary.savingsRate.toStringAsFixed(1)}% Saved',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontFamily: 'NotoSansMono',
                        fontWeight: FontWeight.w700,
                        color: incomeColor,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),

            if (summary.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'No transaction activity for this month.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              )
            else ...[
              SizedBox(
                height: 140,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY:
                        ((income.cents > expense.cents
                                    ? (income.cents / 100)
                                    : (expense.cents / 100)) *
                                1.25)
                            .clamp(10.0, double.infinity),
                    barTouchData: BarTouchData(
                      enabled: true,
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          final label = groupIndex == 0 ? 'Income' : 'Expense';
                          final amount = Money((rod.toY * 100).toInt())
                              .format(symbol: currencySymbol);
                          return BarTooltipItem(
                            '$label\n$amount',
                            const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          );
                        },
                      ),
                    ),
                    titlesData: FlTitlesData(
                      show: true,
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (val, meta) {
                            final text = val.toInt() == 0
                                ? 'Income'
                                : 'Expense';
                            return Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                text,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontFamily: 'NotoSansMono',
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      leftTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                    ),
                    gridData: const FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                    barGroups: [
                      BarChartGroupData(
                        x: 0,
                        barRods: [
                          BarChartRodData(
                            toY: income.cents / 100.0,
                            color: incomeColor,
                            width: 28,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(4),
                            ),
                          ),
                        ],
                      ),
                      BarChartGroupData(
                        x: 1,
                        barRods: [
                          BarChartRodData(
                            toY: expense.cents / 100.0,
                            color: expenseColor,
                            width: 28,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(4),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryBreakdownCard(
    BuildContext context,
    FinancialReportSummary summary,
    String currencySymbol,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final categories = summary.categoryBreakdown;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Expense Breakdown by Category',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),

            if (categories.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'No expenses recorded for this month.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              )
            else ...[
              // Pie Chart
              SizedBox(
                height: 180,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 42,
                    sections: categories.map((cat) {
                      return PieChartSectionData(
                        value: cat.amount.cents.toDouble(),
                        color: Color(cat.categoryColor),
                        title: cat.percentage >= 8
                            ? '${cat.percentage.toStringAsFixed(0)}%'
                            : '',
                        radius: 46,
                        titleStyle: const TextStyle(
                          fontFamily: 'NotoSansMono',
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Category Legend & Breakdown List
              ...categories.map((cat) {
                final catColor = Color(cat.categoryColor);
                final iconData = CategoryIconHelper.getIcon(cat.categoryIcon);
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 12,
                        backgroundColor: catColor.withValues(alpha: 0.2),
                        child: Icon(iconData, size: 12, color: catColor),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              cat.categoryName,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '${cat.percentage.toStringAsFixed(1)}%',
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontFamily: 'NotoSansMono',
                                color: colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Text(
                            cat.amount.format(symbol: currencySymbol),
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontFamily: 'NotoSansMono',
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSpendingTrendsCard(
    BuildContext context,
    FinancialReportSummary summary,
    String currencySymbol,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final trends = summary.spendingTrends;

    if (trends.isEmpty) return const SizedBox.shrink();

    double maxExpense = 0.0;
    for (final t in trends) {
      final v = t.expenseAmount.cents / 100.0;
      if (v > maxExpense) maxExpense = v;
    }
    if (maxExpense == 0) maxExpense = 100.0;

    final spots = <FlSpot>[];
    for (int i = 0; i < trends.length; i++) {
      spots.add(FlSpot(i.toDouble(), trends[i].expenseAmount.cents / 100.0));
    }

    final trendColor = isDark ? AppColors.nothingRedDark : AppColors.nothingRed;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Spending Trend (Last 6 Months)',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.trending_up_rounded, color: trendColor, size: 20),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 150,
              child: LineChart(
                LineChartData(
                  minX: 0,
                  maxX: (trends.length - 1).toDouble(),
                  minY: 0,
                  maxY: maxExpense * 1.25,
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((spot) {
                          final idx = spot.x.round();
                          final label = idx >= 0 && idx < trends.length
                              ? trends[idx].label
                              : '';
                          final amount = Money((spot.y * 100).toInt())
                              .format(symbol: currencySymbol);
                          return LineTooltipItem(
                            '$label\n$amount',
                            const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          );
                        }).toList();
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        interval: 1.0,
                        getTitlesWidget: (val, meta) {
                          final idx = val.round();
                          // Prevent duplicate labels at non-integer tick intervals (e.g. 0.5, 1.5)
                          if ((val - idx).abs() > 0.05) {
                            return const SizedBox.shrink();
                          }
                          if (idx >= 0 && idx < trends.length) {
                            return SideTitleWidget(
                              meta: meta,
                              space: 6,
                              child: Text(
                                trends[idx].label,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontFamily: 'NotoSansMono',
                                  fontSize: 10,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: trendColor,
                      barWidth: 2.5,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: true),
                      belowBarData: BarAreaData(
                        show: true,
                        color: trendColor.withValues(alpha: 0.12),
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
