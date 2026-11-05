import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/responsive_layout.dart';
import '../../../home/providers/home_providers.dart';
import '../../models/habit.dart';
import '../../providers/habit_providers.dart';
import 'habit_form_sheet.dart';

class HabitDetailSheet extends ConsumerWidget {
  final Habit habit;

  const HabitDetailSheet({super.key, required this.habit});

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Habit?'),
        content: Text(
          'Are you sure you want to delete "${habit.name}"? All historical completion records for this habit will be permanently deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final repo = ref.read(habitRepositoryProvider);
      await repo.deleteHabit(habit.id);

      ref.invalidate(activeHabitsProvider);
      ref.invalidate(archivedHabitsProvider);
      ref.invalidate(todayScheduledHabitsProvider);
      ref.invalidate(todayHabitProgressProvider);
      ref.invalidate(homeSummaryProvider);

      if (context.mounted) {
        Navigator.pop(context); // close sheet
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Habit deleted'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _toggleArchive(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(habitRepositoryProvider);
    final willArchive = !habit.isArchived;

    await repo.archiveHabit(habit.id, willArchive);

    ref.invalidate(activeHabitsProvider);
    ref.invalidate(archivedHabitsProvider);
    ref.invalidate(todayScheduledHabitsProvider);
    ref.invalidate(todayHabitProgressProvider);
    ref.invalidate(homeSummaryProvider);

    if (context.mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            willArchive
                ? 'Habit archived. Historical progress is preserved.'
                : 'Habit restored to active habits.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final statsAsync = ref.watch(habitStatsProvider(habit));
    final habitColor = Color(habit.color ?? 0xFF4CAF50);

    return ResponsiveContentWrapper(
      maxWidth: 600,
      child: SafeArea(
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Header
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: habitColor.withValues(alpha: 0.15),
                      child: Icon(
                        Icons.check_circle_rounded,
                        color: habitColor,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            habit.name,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.schedule_rounded,
                                    size: 14,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    habit.scheduleSummary,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              if (habit.isArchived)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colorScheme.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'Archived',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                if (habit.description != null &&
                    habit.description!.isNotEmpty) ...[
                  Text(
                    habit.description!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Statistics Cards
                statsAsync.when(
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  error: (err, _) => Text('Error loading stats: $err'),
                  data: (stats) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Habit Statistics',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _buildMetricTile(
                                context,
                                label: 'Current Streak',
                                value: '${stats.currentStreak} days',
                                icon: Icons.local_fire_department_rounded,
                                color: const Color(0xFFFF9800),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildMetricTile(
                                context,
                                label: 'Best Streak',
                                value: '${stats.longestStreak} days',
                                icon: Icons.emoji_events_outlined,
                                color: const Color(0xFF4CAF50),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _buildMetricTile(
                                context,
                                label: 'Completions',
                                value: '${stats.totalCompletions} days',
                                icon: Icons.check_circle_outline_rounded,
                                color: const Color(0xFF2196F3),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildMetricTile(
                                context,
                                label: 'Consistency',
                                value: '${stats.completionPercentage}%',
                                icon: Icons.pie_chart_outline_rounded,
                                color: const Color(0xFF9C27B0),
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 24),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: const Text('Edit'),
                        onPressed: () {
                          Navigator.pop(context);
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(20),
                              ),
                            ),
                            builder: (_) => HabitFormSheet(habitToEdit: habit),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: Icon(
                          habit.isArchived
                              ? Icons.unarchive_outlined
                              : Icons.archive_outlined,
                          size: 18,
                        ),
                        label: Text(habit.isArchived ? 'Restore' : 'Archive'),
                        onPressed: () => _toggleArchive(context, ref),
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton.outlined(
                      icon: Icon(
                        Icons.delete_outline_rounded,
                        color: colorScheme.error,
                      ),
                      tooltip: 'Delete Habit',
                      onPressed: () => _confirmDelete(context, ref),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetricTile(
    BuildContext context, {
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
