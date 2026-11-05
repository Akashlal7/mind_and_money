import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../providers/wellness_providers.dart';

class WellnessInsightsView extends ConsumerWidget {
  const WellnessInsightsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final weeklyMoodAsync = ref.watch(moodWeeklySummaryProvider);
    final breathingStatsAsync = ref.watch(breathingStatsProvider);
    final journalEntriesAsync = ref.watch(journalEntriesProvider);
    final spendingReflectionsAsync = ref.watch(
      spendingReflectionSummaryProvider,
    );

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        // Non-diagnostic Header Banner
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.shield_outlined, size: 18, color: colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'These summaries describe only the entries you have saved locally on this device. They are designed for gentle personal awareness and are not psychological or medical diagnoses.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 1. Mood Check-ins & Balance
        Text(
          'Mood & Emotional State',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: colorScheme.primary,
          ),
        ),
        const SizedBox(height: 8),
        weeklyMoodAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Text('Error: $err'),
          data: (weekly) {
            final hasData = weekly.totalCheckIns > 0;
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Past 7 Days Check-ins',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${weekly.totalCheckIns} recorded',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (!hasData) ...[
                      Text(
                        'No mood check-ins recorded in the last 7 days. Log your mood to see trends over time.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ] else ...[
                      Row(
                        children: [
                          Expanded(
                            child: _buildMetricTile(
                              context,
                              'Average Score',
                              '${weekly.averageRating} / 5',
                              _moodEmoji(weekly.averageRating.round()),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildMetricTile(
                              context,
                              'Most Frequent',
                              _moodLabel(weekly.mostFrequentRating),
                              _moodEmoji(weekly.mostFrequentRating),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Distribution bar
                      Text(
                        'Score Distribution',
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...List.generate(5, (index) {
                        final rating = 5 - index; // 5 down to 1
                        final count = weekly.ratingDistribution[rating] ?? 0;
                        final fraction = weekly.totalCheckIns > 0
                            ? (count / weekly.totalCheckIns)
                            : 0.0;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 24,
                                child: Text(
                                  _moodEmoji(rating),
                                  style: const TextStyle(fontSize: 16),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: fraction,
                                    minHeight: 8,
                                    backgroundColor:
                                        colorScheme.surfaceContainerHighest,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              SizedBox(
                                width: 20,
                                child: Text(
                                  '$count',
                                  textAlign: TextAlign.end,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),

                      if (weekly.topTags.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          'Most Common Feelings:',
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: weekly.topTags.map((t) {
                            return Chip(
                              label: Text('${t.key} (${t.value})'),
                              visualDensity: VisualDensity.compact,
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 16),

        // 2. Mindfulness & Journaling Activity
        Text(
          'Mindfulness & Reflections',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: colorScheme.primary,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            // Breathing stats
            Expanded(
              child: breathingStatsAsync.when(
                loading: () => const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
                error: (e, _) => Card(child: Text('Error: $e')),
                data: (stats) {
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.air_rounded,
                                size: 20,
                                color: AppColors.tealSecondary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Breathing',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            '${stats.totalSessions} sessions',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: AppColors.tealSecondary,
                            ),
                          ),
                          Text(
                            '${stats.totalMinutes} total minutes',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),

            // Journal stats
            Expanded(
              child: journalEntriesAsync.when(
                loading: () => const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
                error: (e, _) => Card(child: Text('Error: $e')),
                data: (entries) {
                  final reflectionsCount = entries
                      .where((e) => e.isReflection)
                      .length;
                  final journalsCount = entries.length - reflectionsCount;

                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.book_outlined,
                                size: 20,
                                color: colorScheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Journaling',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            '${entries.length} entries',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: colorScheme.primary,
                            ),
                          ),
                          Text(
                            '$reflectionsCount reflections • $journalsCount notes',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // 3. Emotional Spending Observations (shown when sufficient data exists)
        Text(
          'Emotional Spending Patterns',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: colorScheme.primary,
          ),
        ),
        const SizedBox(height: 8),
        spendingReflectionsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Text('Error: $err'),
          data: (reflSummary) {
            final hasSufficientData = reflSummary.totalReflections >= 3;

            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Purchase Reflections',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${reflSummary.totalReflections} reflections',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colorScheme.onSecondaryContainer,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (!hasSufficientData) ...[
                      Text(
                        'Record at least 3 optional purchase reflections to see a gentle summary of your spending patterns and feelings.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ] else ...[
                      Row(
                        children: [
                          Expanded(
                            child: _buildMetricTile(
                              context,
                              'Planned Purchases',
                              '${((reflSummary.plannedCount / reflSummary.totalReflections) * 100).round()}%',
                              '📅',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildMetricTile(
                              context,
                              'Unplanned / Quick',
                              '${((reflSummary.unplannedCount / reflSummary.totalReflections) * 100).round()}%',
                              '⚡',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      Text(
                        'Spending Nature Breakdown',
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: reflSummary.natureCounts.entries.map((e) {
                          return Chip(
                            label: Text('${_capitalize(e.key)}: ${e.value}'),
                            visualDensity: VisualDensity.compact,
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 12),

                      if (reflSummary.feelingCounts.isNotEmpty) ...[
                        Text(
                          'Emotions Noted at Purchase:',
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: reflSummary.feelingCounts.entries.map((e) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${e.key} (${e.value})',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildMetricTile(
    BuildContext context,
    String label,
    String value,
    String iconOrEmoji,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(iconOrEmoji, style: const TextStyle(fontSize: 16)),
            ],
          ),
          const SizedBox(height: 4),
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

  String _moodEmoji(int rating) {
    switch (rating) {
      case 1:
        return '😔';
      case 2:
        return '🙁';
      case 3:
        return '😐';
      case 4:
        return '🙂';
      case 5:
        return '😊';
      default:
        return '😐';
    }
  }

  String _moodLabel(int rating) {
    switch (rating) {
      case 1:
        return 'Difficult';
      case 2:
        return 'Low';
      case 3:
        return 'Neutral';
      case 4:
        return 'Good';
      case 5:
        return 'Thriving';
      default:
        return 'Neutral';
    }
  }

  String _capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }
}
