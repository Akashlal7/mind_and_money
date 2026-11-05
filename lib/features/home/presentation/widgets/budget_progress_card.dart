import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/responsive_layout.dart';
import '../../../../core/widgets/financial_amount_text.dart';
import '../../data/home_repository.dart';

/// Mind & Money — Nothing OS Minimalist Budget Progress Card.
/// Features geometric wireframe card, monospaced metrics, and high-contrast
/// linear progress tracking.
class BudgetProgressCard extends StatelessWidget {
  final HomeSummary summary;
  final String currencySymbol;
  final VoidCallback onViewBudgets;

  const BudgetProgressCard({
    super.key,
    required this.summary,
    this.currencySymbol = '₹',
    required this.onViewBudgets,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final hasBudget = summary.hasBudget && summary.budgetUsedFraction != null;
    final usedFraction = hasBudget ? summary.budgetUsedFraction! : 0.0;
    final percentage = (usedFraction * 100).round();
    final isOver = hasBudget && usedFraction > 1.0;
    final isNearLimit = hasBudget && !isOver && usedFraction >= 0.85;

    Color progressColor;
    if (isOver) {
      progressColor = isDark ? AppColors.nothingRedDark : AppColors.nothingRed;
    } else if (isNearLimit) {
      progressColor = isDark
          ? AppColors.warningAmberDark
          : AppColors.warningAmber;
    } else {
      progressColor = isDark
          ? AppColors.primaryTextDark
          : AppColors.primaryTextLight;
    }

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
            // Card Header
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
                          Icons.pie_chart_outline_rounded,
                          size: isWearable ? 14 : 16,
                          color: isDark
                              ? AppColors.primaryTextDark
                              : AppColors.primaryTextLight,
                        ),
                      ),
                      SizedBox(width: isWearable ? 6 : 10),
                      Expanded(
                        child: Text(
                          isWearable ? 'Budget' : 'Monthly Budget',
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
                    child: TextButton(
                      onPressed: onViewBudgets,
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        foregroundColor: isDark
                            ? AppColors.nothingRedDark
                            : AppColors.nothingRed,
                        textStyle: const TextStyle(
                          fontFamily: 'NotoSansMono',
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                          letterSpacing: 0.5,
                        ),
                      ),
                      child: Text(hasBudget ? 'DETAILS' : 'SET BUDGET'),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            if (hasBudget) ...[
              // Budget Numbers (Adaptive Row/Column for Smartwatches & Large Amounts)
              LayoutBuilder(
                builder: (context, constraints) {
                  final isUltraNarrow = constraints.maxWidth < 280;

                  final spentSection = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'SPENT OF ${summary.monthlyBudget!.format(symbol: currencySymbol)}',
                          style: TextStyle(
                            fontFamily: 'NotoSansMono',
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? AppColors.secondaryTextDark
                                : AppColors.secondaryTextLight,
                            letterSpacing: 0.4,
                          ),
                          maxLines: 1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$percentage% Used',
                        style: TextStyle(
                          fontFamily: 'NotoSansMono',
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: progressColor,
                        ),
                      ),
                    ],
                  );

                  Widget? remainingSection;
                  if (summary.remainingBudget != null) {
                    remainingSection = Column(
                      crossAxisAlignment: isUltraNarrow
                          ? CrossAxisAlignment.start
                          : CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          isOver ? 'OVER BUDGET' : 'REMAINING',
                          style: TextStyle(
                            fontFamily: 'NotoSansMono',
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? AppColors.secondaryTextDark
                                : AppColors.secondaryTextLight,
                            letterSpacing: 0.4,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        FinancialAmountText(
                          amount: summary.remainingBudget!,
                          currencySymbol: currencySymbol,
                          type: isOver
                              ? FinancialAmountType.expense
                              : FinancialAmountType.neutral,
                          showSign: isOver,
                          alignment: isUltraNarrow
                              ? Alignment.centerLeft
                              : Alignment.centerRight,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            fontFamily: 'NotoSansMono',
                          ),
                        ),
                      ],
                    );
                  }

                  if (isUltraNarrow) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        spentSection,
                        if (remainingSection != null) ...[
                          const SizedBox(height: 8),
                          remainingSection,
                        ],
                      ],
                    );
                  }

                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Flexible(child: spentSection),
                      if (remainingSection != null) ...[
                        const SizedBox(width: 12),
                        Flexible(child: remainingSection),
                      ],
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),

              // Progress Bar
              Semantics(
                label: 'Monthly budget is $percentage percent utilized',
                value: '$percentage%',
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: usedFraction.clamp(0.0, 1.0),
                    minHeight: 6,
                    backgroundColor: isDark
                        ? AppColors.secondarySurfaceDark
                        : AppColors.secondarySurfaceLight,
                    valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                  ),
                ),
              ),
            ] else ...[
              // Helpful Empty State
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.secondarySurfaceDark.withValues(alpha: 0.5)
                      : AppColors.secondarySurfaceLight.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark
                        ? AppColors.borderDividerDark
                        : AppColors.borderDividerLight,
                    width: 0.8,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 18,
                      color: isDark
                          ? AppColors.secondaryTextDark
                          : AppColors.secondaryTextLight,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'No budget set for this month. Set a target limit to track expenses.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isDark
                              ? AppColors.secondaryTextDark
                              : AppColors.secondaryTextLight,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
