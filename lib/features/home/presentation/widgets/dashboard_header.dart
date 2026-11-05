import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/widgets/nothing_widgets.dart';

/// Nothing OS-Inspired Minimalist Dashboard Header.
/// Features geometric monochrome brand identity, active Nothing Red LED dot,
/// and monospaced system timestamp.
class DashboardHeader extends StatelessWidget {
  final DateTime date;

  const DashboardHeader({super.key, required this.date});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final dateString = AppDateUtils.toDisplayDate(date);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header Brand Row
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
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
                child: Center(
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.nothingRedDark
                          : AppColors.nothingRed,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Mind & Money',
                  style: TextStyle(
                    fontFamily: 'NotoSansMono',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Monospaced System Date
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.circle,
                size: 6,
                color: isDark
                    ? AppColors.nothingRedDark
                    : AppColors.nothingRed,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  dateString.toUpperCase(),
                  style: TextStyle(
                    fontFamily: 'NotoSansMono',
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.6,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const NothingDivider(verticalPadding: 8),
        ],
      ),
    );
  }
}
