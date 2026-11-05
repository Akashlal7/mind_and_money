import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/responsive_layout.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/widgets/financial_amount_text.dart';
import '../../data/home_repository.dart';

/// Mind & Money — Nothing OS Minimalist Financial Summary Card.
/// Displays net balance, monthly income, and monthly expenses with
/// monospaced tabular numerals, geometric outline badges, and wireframe hierarchy.
class FinancialSummaryCard extends StatelessWidget {
  final HomeSummary summary;
  final String currencySymbol;

  const FinancialSummaryCard({
    super.key,
    required this.summary,
    this.currencySymbol = '₹',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final monthName = AppDateUtils.toMonthYear(summary.selectedMonth);

    final netType = summary.netBalance.isNegative
        ? FinancialAmountType.expense
        : (summary.netBalance.isZero
              ? FinancialAmountType.neutral
              : FinancialAmountType.income);

    final isWearable = AppBreakpoints.isWearable(context);
    final cardPadding = isWearable
        ? const EdgeInsets.symmetric(horizontal: 10, vertical: 8)
        : const EdgeInsets.all(16);

    return Card(
      child: Padding(
        padding: cardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row: Minimal Icon Badge + Title + Monospaced Month Tag
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(isWearable ? 4 : 6),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.secondarySurfaceDark
                              : AppColors.secondarySurfaceLight,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isDark
                                ? AppColors.borderDividerDark
                                : AppColors.borderDividerLight,
                            width: 1.0,
                          ),
                        ),
                        child: Icon(
                          Icons.account_balance_wallet_outlined,
                          size: isWearable ? 14 : 16,
                          color: isDark
                              ? AppColors.primaryTextDark
                              : AppColors.primaryTextLight,
                        ),
                      ),
                      SizedBox(width: isWearable ? 6 : 10),
                      Expanded(
                        child: Text(
                          isWearable ? 'Summary' : 'Financial Summary',
                          style: TextStyle(
                            fontSize: isWearable ? 13 : 15,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.1,
                            color: colorScheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.secondarySurfaceDark
                            : AppColors.secondarySurfaceLight,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isDark
                              ? AppColors.borderDividerDark
                              : AppColors.borderDividerLight,
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        (isWearable
                                ? AppDateUtils.toCompactMonthYear(summary.selectedMonth)
                                : monthName)
                            .toUpperCase(),
                        style: TextStyle(
                          fontFamily: 'NotoSansMono',
                          fontSize: 10,
                          color: isDark
                              ? AppColors.secondaryTextDark
                              : AppColors.secondaryTextLight,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Net Balance Wireframe Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.secondarySurfaceDark.withValues(alpha: 0.6)
                    : AppColors.secondarySurfaceLight.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDark
                      ? AppColors.borderDividerDark
                      : AppColors.borderDividerLight,
                  width: 0.8,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.nothingRedDark
                              : AppColors.nothingRed,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Net Balance',
                        style: TextStyle(
                          fontFamily: 'NotoSansMono',
                          color: isDark
                              ? AppColors.secondaryTextDark
                              : AppColors.secondaryTextLight,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  FinancialAmountText(
                    amount: summary.netBalance,
                    currencySymbol: currencySymbol,
                    type: netType,
                    showSign: true,
                    showIcon: true,
                    isLarge: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Income & Expense Breakdown (Responsive Stack on Smartwatches / Narrow Screens)
            LayoutBuilder(
              builder: (context, constraints) {
                final isUltraNarrow = constraints.maxWidth < 300;
                final incomeTile = _buildMetricTile(
                  context,
                  label: 'Total Income',
                  amount: summary.monthlyIncome,
                  type: FinancialAmountType.income,
                  icon: Icons.arrow_downward_rounded,
                  bgColor: isDark
                      ? AppColors.incomeContainerDark
                      : AppColors.incomeContainerLight,
                  iconColor: isDark
                      ? AppColors.incomeGreenDark
                      : AppColors.incomeGreen,
                );
                final expenseTile = _buildMetricTile(
                  context,
                  label: 'Total Expenses',
                  amount: summary.monthlyExpense,
                  type: FinancialAmountType.expense,
                  icon: Icons.arrow_upward_rounded,
                  bgColor: isDark
                      ? AppColors.expenseContainerDark
                      : AppColors.expenseContainerLight,
                  iconColor: isDark
                      ? AppColors.nothingRedDark
                      : AppColors.nothingRed,
                );

                if (isUltraNarrow) {
                  return Column(
                    children: [
                      incomeTile,
                      const SizedBox(height: 8),
                      expenseTile,
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: incomeTile),
                    const SizedBox(width: 10),
                    Expanded(child: expenseTile),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricTile(
    BuildContext context, {
    required String label,
    required dynamic amount,
    required FinancialAmountType type,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.primarySurfaceDark
            : AppColors.primarySurfaceLight,
        border: Border.all(
          color: isDark
              ? AppColors.borderDividerDark
              : AppColors.borderDividerLight,
          width: 0.8,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
            child: Icon(icon, size: 13, color: iconColor),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'NotoSansMono',
                    color: isDark
                        ? AppColors.secondaryTextDark
                        : AppColors.secondaryTextLight,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                FinancialAmountText(
                  amount: amount,
                  currencySymbol: currencySymbol,
                  type: type,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontFamily: 'NotoSansMono',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
