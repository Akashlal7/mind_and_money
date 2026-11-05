import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/responsive_layout.dart';
import '../../../wellness/models/mood_entry.dart';
import '../../../wellness/presentation/mood/mood_check_in_sheet.dart';
import 'quick_breathing_sheet.dart';

/// Mind & Money — Nothing OS Minimalist Wellness Snapshot Card.
/// Minimal monochrome container, wireframe check-in details, and
/// geometric quick action buttons.
class WellnessSnapshotCard extends StatelessWidget {
  final MoodEntry? todayMood;
  final VoidCallback onOpenJournal;

  const WellnessSnapshotCard({
    super.key,
    required this.todayMood,
    required this.onOpenJournal,
  });

  @override
  Widget build(BuildContext context) {
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
                          Icons.spa_outlined,
                          size: isWearable ? 14 : 16,
                          color: isDark
                              ? AppColors.primaryTextDark
                              : AppColors.primaryTextLight,
                        ),
                      ),
                      SizedBox(width: isWearable ? 6 : 10),
                      Expanded(
                        child: Text(
                          isWearable ? 'Wellness' : 'Mental Wellness',
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
                      onPressed: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(20),
                            ),
                          ),
                          builder: (ctx) =>
                              MoodCheckInSheet(entryToEdit: todayMood),
                        );
                      },
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
                      child: Text(todayMood == null ? 'CHECK IN' : 'UPDATE'),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Today's Mood State
            if (todayMood != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
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
                    Text(
                      todayMood!.moodEmoji,
                      style: const TextStyle(fontSize: 28),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'FEELING ${todayMood!.moodLabel.toUpperCase()}',
                            style: TextStyle(
                              fontFamily: 'NotoSansMono',
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.4,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          if (todayMood!.note != null &&
                              todayMood!.note!.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              '"${todayMood!.note}"',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              Container(
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
                      Icons.sentiment_satisfied_outlined,
                      size: 22,
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
                            'No mood check-in yet today',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'A quick check-in helps ground your emotional spending.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),

            // Quick Wellness Tools (Adaptive Row/Column for Smartwatches)
            LayoutBuilder(
              builder: (context, constraints) {
                final isUltraNarrow = constraints.maxWidth < 280;
                final breatheBtn = OutlinedButton.icon(
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(20),
                        ),
                      ),
                      builder: (ctx) => const QuickBreathingSheet(),
                    );
                  },
                  icon: Icon(
                    Icons.air_rounded,
                    size: 16,
                    color: isDark
                        ? AppColors.primaryTextDark
                        : AppColors.primaryTextLight,
                  ),
                  label: const Text(
                    'BREATHE',
                    style: TextStyle(
                      fontFamily: 'NotoSansMono',
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                      letterSpacing: 0.5,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    visualDensity: VisualDensity.compact,
                  ),
                );

                final journalBtn = OutlinedButton.icon(
                  onPressed: onOpenJournal,
                  icon: Icon(
                    Icons.edit_note_rounded,
                    size: 16,
                    color: isDark
                        ? AppColors.primaryTextDark
                        : AppColors.primaryTextLight,
                  ),
                  label: const Text(
                    'JOURNAL',
                    style: TextStyle(
                      fontFamily: 'NotoSansMono',
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                      letterSpacing: 0.5,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    visualDensity: VisualDensity.compact,
                  ),
                );

                if (isUltraNarrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      breatheBtn,
                      const SizedBox(height: 8),
                      journalBtn,
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: breatheBtn),
                    const SizedBox(width: 10),
                    Expanded(child: journalBtn),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
