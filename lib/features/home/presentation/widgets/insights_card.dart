import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/responsive_layout.dart';

/// Mind & Money — Nothing OS Minimalist Daily Insights Card.
/// Monospaced prompt header, Nothing Red status indicator dot,
/// and geometric wireframe layout.
class InsightsCard extends StatelessWidget {
  final String insightMessage;

  const InsightsCard({super.key, required this.insightMessage});

  @override
  Widget build(BuildContext context) {
    if (insightMessage.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final isWearable = AppBreakpoints.isWearable(context);
    final cardPadding = isWearable
        ? const EdgeInsets.symmetric(horizontal: 10, vertical: 8)
        : const EdgeInsets.all(16);

    return Card(
      child: Padding(
        padding: cardPadding,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.secondarySurfaceDark
                    : AppColors.secondarySurfaceLight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark
                      ? AppColors.borderDividerDark
                      : AppColors.borderDividerLight,
                  width: 1.0,
                ),
              ),
              child: Icon(
                Icons.lightbulb_outline_rounded,
                size: 18,
                color: isDark
                    ? AppColors.primaryTextDark
                    : AppColors.primaryTextLight,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
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
                        'Daily Insight',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.1,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    insightMessage,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
