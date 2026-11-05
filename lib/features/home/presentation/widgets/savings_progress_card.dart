import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/responsive_layout.dart';
import '../../../../core/utils/money.dart';
import '../../data/home_repository.dart';

/// Mind & Money — Nothing OS Minimalist Savings Progress Card.
/// Dedicated Dashboard card for tracking overall savings goals progress
/// with monospaced metrics, geometric outline badges, and high-contrast indicators.
class SavingsProgressCard extends StatelessWidget {
  final HomeSummary summary;
  final String currencySymbol;
  final VoidCallback onViewSavings;

  const SavingsProgressCard({
    super.key,
    required this.summary,
    this.currencySymbol = '₹',
    required this.onViewSavings,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final hasGoals = summary.hasSavingsGoals;
    final saved = Money(summary.totalSavedCents);
    final target = Money(summary.totalSavingsTargetCents);
    final progressFraction = hasGoals && summary.totalSavingsTargetCents > 0
        ? (summary.totalSavedCents / summary.totalSavingsTargetCents).clamp(
            0.0,
            1.0,
          )
        : 0.0;
    final percentage = (progressFraction * 100).round();

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
                          Icons.savings_outlined,
                          size: isWearable ? 14 : 16,
                          color: isDark
                              ? AppColors.primaryTextDark
                              : AppColors.primaryTextLight,
                        ),
                      ),
                      SizedBox(width: isWearable ? 6 : 10),
                      Expanded(
                        child: Text(
                          isWearable ? 'Savings' : 'Savings Goals',
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
                      onPressed: onViewSavings,
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
                      child: Text(hasGoals ? 'DETAILS' : 'NEW GOAL'),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            if (hasGoals) ...[
              // Savings Stats (Adaptive Row/Column for Smartwatches & Large Amounts)
              LayoutBuilder(
                builder: (context, constraints) {
                  final isUltraNarrow = constraints.maxWidth < 280;

                  final savedSection = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'TOTAL SAVED',
                        style: TextStyle(
                          fontFamily: 'NotoSansMono',
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppColors.secondaryTextDark
                              : AppColors.secondaryTextLight,
                          letterSpacing: 0.4,
                        ),
                      ),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          saved.format(symbol: currencySymbol),
                          style: TextStyle(
                            fontFamily: 'NotoSansMono',
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: isDark
                                ? AppColors.incomeGreenDark
                                : AppColors.incomeGreen,
                          ),
                          maxLines: 1,
                        ),
                      ),
                    ],
                  );

                  final targetSection = Column(
                    crossAxisAlignment: isUltraNarrow
                        ? CrossAxisAlignment.start
                        : CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: isUltraNarrow
                            ? Alignment.centerLeft
                            : Alignment.centerRight,
                        child: Text(
                          'TARGET: ${target.format(symbol: currencySymbol)}',
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
                        '$percentage% Funded',
                        style: TextStyle(
                          fontFamily: 'NotoSansMono',
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? AppColors.primaryTextDark
                              : AppColors.primaryTextLight,
                        ),
                      ),
                    ],
                  );

                  if (isUltraNarrow) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        savedSection,
                        const SizedBox(height: 8),
                        targetSection,
                      ],
                    );
                  }

                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Flexible(child: savedSection),
                      const SizedBox(width: 12),
                      Flexible(child: targetSection),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),

              // Progress Bar
              Semantics(
                label: 'Savings goals are $percentage percent funded',
                value: '$percentage%',
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: progressFraction,
                    minHeight: 6,
                    backgroundColor: isDark
                        ? AppColors.secondarySurfaceDark
                        : AppColors.secondarySurfaceLight,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isDark
                          ? AppColors.incomeGreenDark
                          : AppColors.incomeGreen,
                    ),
                  ),
                ),
              ),
            ] else ...[
              // Empty State
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
                      Icons.flag_outlined,
                      size: 18,
                      color: isDark
                          ? AppColors.secondaryTextDark
                          : AppColors.secondaryTextLight,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Set target savings goals for vacations, emergencies, or milestones.',
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
