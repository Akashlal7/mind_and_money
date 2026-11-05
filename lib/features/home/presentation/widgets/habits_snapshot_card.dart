import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/responsive_layout.dart';
import '../../../habits/models/habit.dart';

/// Mind & Money — Nothing OS Minimalist Habits Snapshot Card.
/// Shows daily habit progress bar and geometric check-off controls.
class HabitsSnapshotCard extends StatelessWidget {
  final List<Habit> habits;
  final int completedCount;
  final int totalCount;
  final void Function(Habit) onToggleHabit;
  final VoidCallback onManageHabits;

  const HabitsSnapshotCard({
    super.key,
    required this.habits,
    required this.completedCount,
    required this.totalCount,
    required this.onToggleHabit,
    required this.onManageHabits,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final progress = totalCount > 0
        ? (completedCount / totalCount).clamp(0.0, 1.0)
        : 0.0;
    final percentage = (progress * 100).round();

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
            // Header Row
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
                          Icons.check_circle_outline_rounded,
                          size: isWearable ? 14 : 16,
                          color: isDark
                              ? AppColors.primaryTextDark
                              : AppColors.primaryTextLight,
                        ),
                      ),
                      SizedBox(width: isWearable ? 6 : 10),
                      Expanded(
                        child: Text(
                          isWearable ? 'Habits' : "Today's Habits",
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
                      onPressed: onManageHabits,
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
                      child: Text(totalCount == 0 ? 'ADD HABIT' : 'VIEW ALL'),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            if (totalCount == 0) ...[
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
                      Icons.calendar_today_outlined,
                      size: 20,
                      color: isDark
                          ? AppColors.secondaryTextDark
                          : AppColors.secondaryTextLight,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'No habits scheduled for today',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Build positive daily routines like logging expenses or evening reflection.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: isDark
                                  ? AppColors.secondaryTextDark
                                  : AppColors.secondaryTextLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              // Progress Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$completedCount of $totalCount completed',
                    style: TextStyle(
                      fontFamily: 'NotoSansMono',
                      fontSize: 11,
                      color: isDark
                          ? AppColors.secondaryTextDark
                          : AppColors.secondaryTextLight,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '$percentage%',
                    style: TextStyle(
                      fontFamily: 'NotoSansMono',
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      color: isDark
                          ? AppColors.primaryTextDark
                          : AppColors.primaryTextLight,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Semantics(
                label:
                    'Habits progress: $completedCount of $totalCount completed',
                value: '$percentage%',
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: isDark
                        ? AppColors.secondarySurfaceDark
                        : AppColors.secondarySurfaceLight,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isDark
                          ? AppColors.primaryTextDark
                          : AppColors.primaryTextLight,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Habits Preview List (up to 3 items)
              ...habits.take(3).map((habit) {
                final isDone = habit.isCompletedToday;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: InkWell(
                    onTap: () => onToggleHabit(habit),
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 6,
                        horizontal: 4,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isDone
                                ? Icons.check_box_outlined
                                : Icons.check_box_outline_blank_outlined,
                            color: isDone
                                ? (isDark
                                      ? AppColors.nothingRedDark
                                      : AppColors.nothingRed)
                                : (isDark
                                      ? AppColors.secondaryTextDark
                                      : AppColors.secondaryTextLight),
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              habit.name,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                decoration: isDone
                                    ? TextDecoration.lineThrough
                                    : null,
                                color: isDone
                                    ? (isDark
                                          ? AppColors.secondaryTextDark
                                          : AppColors.secondaryTextLight)
                                    : colorScheme.onSurface,
                                fontWeight: isDone
                                    ? FontWeight.w400
                                    : FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}
