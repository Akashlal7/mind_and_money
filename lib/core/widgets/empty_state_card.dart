import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Mind & Money — Nothing OS Minimalist Empty State Card.
/// Minimal monochrome container, wireframe border, and geometric typography.
class EmptyStateCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyStateCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 26),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.secondarySurfaceDark
                      : AppColors.secondarySurfaceLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark
                        ? AppColors.borderDividerDark
                        : AppColors.borderDividerLight,
                    width: 1.0,
                  ),
                ),
                child: Icon(
                  icon,
                  size: 22,
                  color: isDark
                      ? AppColors.secondaryTextDark
                      : AppColors.secondaryTextLight,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                description,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: onAction,
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: Text(
                    actionLabel!,
                    style: const TextStyle(
                      fontFamily: 'NotoSansMono',
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      fontSize: 11,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(88, 40),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
