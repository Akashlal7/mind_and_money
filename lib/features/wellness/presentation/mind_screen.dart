import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/responsive_layout.dart';
import '../../../core/theme/app_colors.dart';
import '../../home/providers/home_providers.dart';
import 'breathing/breathing_exercise_screen.dart';
import 'insights/wellness_insights_view.dart';
import 'journal/journal_editor_screen.dart';
import 'journal/journal_list_view.dart';
import 'mood/mood_check_in_sheet.dart';
import 'mood/mood_history_view.dart';
import 'prompts/gratitude_prompts.dart';

class MindScreen extends ConsumerStatefulWidget {
  const MindScreen({super.key});

  @override
  ConsumerState<MindScreen> createState() => _MindScreenState();
}

class _MindScreenState extends ConsumerState<MindScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late String _currentGratitudePrompt;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _currentGratitudePrompt = GratitudePrompts.promptForDay(DateTime.now());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _shufflePrompt() {
    final curIdx = GratitudePrompts.prompts.indexOf(_currentGratitudePrompt);
    final nextIdx = (curIdx + 1) % GratitudePrompts.prompts.length;
    setState(() {
      _currentGratitudePrompt = GratitudePrompts.prompts[nextIdx];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mental Wellness'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(icon: Icon(Icons.today_rounded), text: 'Today'),
            Tab(icon: Icon(Icons.history_rounded), text: 'Mood History'),
            Tab(icon: Icon(Icons.book_outlined), text: 'Journal'),
            Tab(icon: Icon(Icons.air_rounded), text: 'Breathing'),
            Tab(icon: Icon(Icons.insights_rounded), text: 'Insights'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTodayTab(context),
          const ResponsiveContentWrapper(child: MoodHistoryView()),
          const ResponsiveContentWrapper(child: JournalListView()),
          const BreathingExerciseScreen(showAppBar: false),
          const ResponsiveContentWrapper(child: WellnessInsightsView()),
        ],
      ),
    );
  }

  Widget _buildTodayTab(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final homeSummaryAsync = ref.watch(homeSummaryProvider);
    final todayMood = homeSummaryAsync.value?.todayMood;

    return ResponsiveContentWrapper(
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        children: [
          // 1. Mood Check-In Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AppColors.tealContainer,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.spa_rounded,
                                size: 18,
                                color: AppColors.onTealContainer,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                "Today's Mood",
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () {
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
                        child: Text(
                          todayMood == null ? 'Check in' : 'Log Again',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (todayMood != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.sageContainer.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.sageContainer,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(
                            todayMood.moodEmoji,
                            style: const TextStyle(fontSize: 32),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Feeling ${todayMood.moodLabel}',
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if (todayMood.tags.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    todayMood.tags.join(' • '),
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                                if (todayMood.note != null &&
                                    todayMood.note!.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    '"${todayMood.note}"',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      fontStyle: FontStyle.italic,
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
                    Text(
                      'You have not recorded how you feel today yet. Checking in regularly builds mindful self-awareness.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.tonalIcon(
                      onPressed: () {
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
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Log Mood Check-in'),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // 2. Gratitude & Reflection Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Icon(
                              Icons.lightbulb_outline_rounded,
                              color: colorScheme.primary,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                'Daily Reflection Prompt',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.shuffle_rounded, size: 20),
                        tooltip: 'Next Prompt',
                        onPressed: _shufflePrompt,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer.withValues(
                        alpha: 0.4,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _currentGratitudePrompt,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      FilledButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (ctx) => JournalEditorScreen(
                                entryType: 'reflection',
                                initialPrompt: _currentGratitudePrompt,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.edit_note_rounded),
                        label: const Text('Reflect on this'),
                      ),
                      TextButton(
                        onPressed: () => _tabController.animateTo(2), // Journal
                        child: const Text('View All'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // 3. Guided Breathing Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.tealContainer,
                    ),
                    child: const Icon(
                      Icons.air_rounded,
                      color: AppColors.onTealContainer,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Guided Breathing Exercise',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Take 2 minutes to restore calm and mental clarity.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  FilledButton.tonal(
                    onPressed: () => _tabController.animateTo(3), // Breathing
                    child: const Text('Breathe'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 4. Privacy Card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.lock_outline_rounded,
                  size: 16,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '100% offline. No accounts, no cloud sync, and zero third-party telemetry.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
