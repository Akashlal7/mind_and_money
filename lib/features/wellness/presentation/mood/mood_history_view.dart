import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/empty_state_card.dart';
import '../../../home/providers/home_providers.dart';
import '../../data/mood_repository.dart';
import '../../models/mood_entry.dart';
import '../../providers/wellness_providers.dart';
import 'mood_check_in_sheet.dart';

class MoodHistoryView extends ConsumerWidget {
  const MoodHistoryView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final selectedMonth = ref.watch(moodMonthProvider);
    final summariesAsync = ref.watch(
      monthlyMoodSummariesProvider(selectedMonth),
    );

    return Column(
      children: [
        // Month Selector Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton.outlined(
                icon: const Icon(Icons.chevron_left_rounded),
                onPressed: () =>
                    ref.read(moodMonthProvider.notifier).previousMonth(),
                tooltip: 'Previous Month',
              ),
              Row(
                children: [
                  Icon(
                    Icons.calendar_month_rounded,
                    size: 18,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _formatMonthTitle(selectedMonth),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              IconButton.outlined(
                icon: const Icon(Icons.chevron_right_rounded),
                onPressed: () =>
                    ref.read(moodMonthProvider.notifier).nextMonth(),
                tooltip: 'Next Month',
              ),
            ],
          ),
        ),

        // History Content
        Expanded(
          child: summariesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(child: Text('Error: $err')),
            data: (dailySummaries) {
              if (dailySummaries.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: EmptyStateCard(
                      icon: Icons.mood_rounded,
                      title: 'No Mood Check-ins',
                      description:
                          'No mood entries recorded for ${_formatMonthTitle(selectedMonth)}.\n\nTake a mindful moment to log how you feel.',
                      actionLabel: 'Check In Now',
                      onAction: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(20),
                            ),
                          ),
                          builder: (ctx) => const MoodCheckInSheet(),
                        );
                      },
                    ),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                itemCount: dailySummaries.length,
                itemBuilder: (context, index) {
                  final daySummary = dailySummaries[index];
                  return _DailySummaryCard(summary: daySummary);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  String _formatMonthTitle(String monthYear) {
    try {
      final parts = monthYear.split('-');
      final year = parts[0];
      final month = int.parse(parts[1]);
      const months = [
        'January',
        'February',
        'March',
        'April',
        'May',
        'June',
        'July',
        'August',
        'September',
        'October',
        'November',
        'December',
      ];
      return '${months[month - 1]} $year';
    } catch (_) {
      return monthYear;
    }
  }
}

class _DailySummaryCard extends ConsumerWidget {
  final DailyMoodSummary summary;

  const _DailySummaryCard({required this.summary});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isMultiple = summary.totalEntries > 1;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Daily Header (Wrap protection for smartwatches and compact displays)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          summary.date,
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (isMultiple)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.tealContainer.withValues(
                              alpha: 0.6,
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${summary.totalEntries} check-ins (Avg ${summary.averageRating})',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: AppColors.onTealContainer,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 16),

            // Entries List for this Day
            ...summary.entries.map((entry) {
              return _MoodEntryTile(
                entry: entry,
                onEdit: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                    ),
                    builder: (ctx) => MoodCheckInSheet(entryToEdit: entry),
                  );
                },
                onDelete: () => _confirmDelete(context, ref, entry),
              );
            }),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, MoodEntry entry) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Mood Entry?'),
        content: const Text(
          'Are you sure you want to permanently delete this mood check-in?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await ref.read(moodRepositoryProvider).deleteMoodEntry(entry.id);
              ref.invalidate(recentMoodEntriesProvider);
              ref.invalidate(moodWeeklySummaryProvider);
              ref.invalidate(moodMonthlySummaryProvider);
              ref.invalidate(homeSummaryProvider);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Mood entry deleted.')),
                );
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _MoodEntryTile extends StatelessWidget {
  final MoodEntry entry;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _MoodEntryTile({
    required this.entry,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(entry.moodEmoji, style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            entry.moodLabel,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _formatTime(entry.entryTime),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded, size: 20),
                  onSelected: (val) {
                    if (val == 'edit') onEdit();
                    if (val == 'delete') onDelete();
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 18),
                          SizedBox(width: 8),
                          Text('Edit'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(
                            Icons.delete_outline,
                            size: 18,
                            color: Colors.red,
                          ),
                          SizedBox(width: 8),
                          Text('Delete', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // Emotion Tags
            if (entry.tags.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: entry.tags.map((t) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.secondaryContainer.withValues(
                        alpha: 0.6,
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      t,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSecondaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],

            // Stress, Energy, Sleep Metrics chips
            if (entry.stressRating != null ||
                entry.energyRating != null ||
                entry.sleepRating != null) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  if (entry.stressRating != null)
                    _buildMetricChip(
                      context,
                      'Stress: ${entry.stressRating}/5',
                      Icons.speed_rounded,
                    ),
                  if (entry.energyRating != null)
                    _buildMetricChip(
                      context,
                      'Energy: ${entry.energyRating}/5',
                      Icons.bolt_rounded,
                    ),
                  if (entry.sleepRating != null)
                    _buildMetricChip(
                      context,
                      'Sleep: ${entry.sleepRating}/5',
                      Icons.bedtime_outlined,
                    ),
                ],
              ),
            ],

            // Note
            if (entry.note != null && entry.note!.trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                entry.note!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontStyle: FontStyle.italic,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMetricChip(BuildContext context, String text, IconData icon) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: colorScheme.primary),
        const SizedBox(width: 4),
        Text(
          text,
          style: theme.textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  String _formatTime(String timeStr) {
    try {
      final parts = timeStr.split(':');
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      final period = hour >= 12 ? 'PM' : 'AM';
      final h12 = hour % 12 == 0 ? 12 : hour % 12;
      return '$h12:${minute.toString().padLeft(2, '0')} $period';
    } catch (_) {
      return timeStr;
    }
  }
}
