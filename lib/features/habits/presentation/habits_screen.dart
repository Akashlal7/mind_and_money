import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/responsive_layout.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/empty_state_card.dart';
import '../../home/providers/home_providers.dart';
import '../../insights/providers/insights_providers.dart';
import '../models/habit.dart';
import '../providers/habit_providers.dart';
import '../services/habit_streak_service.dart';
import 'widgets/habit_detail_sheet.dart';
import 'widgets/habit_form_sheet.dart';

class HabitsScreen extends ConsumerStatefulWidget {
  const HabitsScreen({super.key});

  @override
  ConsumerState<HabitsScreen> createState() => _HabitsScreenState();
}

class _HabitsScreenState extends ConsumerState<HabitsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _openCreateHabitSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const HabitFormSheet(),
    );
  }

  void _openHabitDetailSheet(Habit habit) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => HabitDetailSheet(habit: habit),
    );
  }

  Future<void> _toggleHabit(Habit habit) async {
    final repo = ref.read(habitRepositoryProvider);
    final todayStr = HabitStreakService.normalizeDate(DateTime.now());

    await repo.toggleCompletion(habit.id, todayStr);

    ref.invalidate(activeHabitsProvider);
    ref.invalidate(todayScheduledHabitsProvider);
    ref.invalidate(todayHabitProgressProvider);
    ref.invalidate(homeSummaryProvider);
    ref.invalidate(deterministicInsightsProvider);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Habits & Consistency'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Create Habit',
            onPressed: _openCreateHabitSheet,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(icon: Icon(Icons.today_rounded), text: 'Today'),
            Tab(icon: Icon(Icons.list_alt_rounded), text: 'All Active'),
            Tab(icon: Icon(Icons.insights_rounded), text: 'Insights'),
            Tab(icon: Icon(Icons.archive_outlined), text: 'Archived'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          ResponsiveContentWrapper(child: _buildTodayTab(context)),
          ResponsiveContentWrapper(child: _buildAllActiveTab(context)),
          ResponsiveContentWrapper(child: _buildInsightsTab(context)),
          ResponsiveContentWrapper(child: _buildArchivedTab(context)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateHabitSheet,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Habit'),
      ),
    );
  }

  // -------------------------------------------------------------
  // TAB 1: TODAY'S SCHEDULED HABITS
  // -------------------------------------------------------------
  Widget _buildTodayTab(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final scheduledAsync = ref.watch(todayScheduledHabitsProvider);
    final progressAsync = ref.watch(todayHabitProgressProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(todayScheduledHabitsProvider);
        ref.invalidate(todayHabitProgressProvider);
        await ref.read(todayScheduledHabitsProvider.future);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
        children: [
          // 1. Daily Progress Banner
          progressAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
            data: (prog) {
              final pct = (prog.completionRate * 100).round();
              return Card(
                color: colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.6,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 54,
                            height: 54,
                            child: CircularProgressIndicator(
                              value: prog.completionRate,
                              strokeWidth: 5,
                              backgroundColor:
                                  colorScheme.surfaceContainerHighest,
                              color: prog.completionRate >= 1.0
                                  ? const Color(0xFF4CAF50)
                                  : colorScheme.primary,
                            ),
                          ),
                          Text(
                            '$pct%',
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Today's Progress",
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              prog.scheduledCount == 0
                                  ? 'No habits scheduled for today.'
                                  : '${prog.completedCount} of ${prog.scheduledCount} habits completed',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),

          // 2. Scheduled Habits List
          scheduledAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (err, _) =>
                Center(child: Text('Error loading habits: $err')),
            data: (habits) {
              if (habits.isEmpty) {
                return EmptyStateCard(
                  icon: Icons.checklist_rounded,
                  title: 'No habits due today',
                  description: 'You have no habits scheduled for today. Create daily habits or check "All Active" to view your full routine.',
                  actionLabel: 'Add Habit',
                  onAction: _openCreateHabitSheet,
                );
              }

              return Column(
                children: habits
                    .map((h) => _buildHabitTile(context, h, isTodayView: true))
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // TAB 2: ALL ACTIVE HABITS
  // -------------------------------------------------------------
  Widget _buildAllActiveTab(BuildContext context) {
    final activeAsync = ref.watch(activeHabitsProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(activeHabitsProvider);
        await ref.read(activeHabitsProvider.future);
      },
      child: activeAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (habits) {
          if (habits.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: EmptyStateCard(
                  icon: Icons.repeat_rounded,
                  title: 'No active habits',
                  description: 'Start building small daily habits for your financial clarity and mental peace.',
                  actionLabel: 'Create First Habit',
                  onAction: _openCreateHabitSheet,
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
            itemCount: habits.length,
            itemBuilder: (ctx, i) {
              return _buildHabitTile(ctx, habits[i], isTodayView: false);
            },
          );
        },
      ),
    );
  }

  // -------------------------------------------------------------
  // TAB 3: INSIGHTS & HABIT CONSISTENCY
  // -------------------------------------------------------------
  Widget _buildInsightsTab(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final insightsAsync = ref.watch(deterministicInsightsProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(deterministicInsightsProvider);
        await ref.read(deterministicInsightsProvider.future);
      },
      child: insightsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (insights) {
          if (insights.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: EmptyStateCard(
                  icon: Icons.lightbulb_outline_rounded,
                  title: 'No insights available yet',
                  description: 'Continue recording expenses, mood check-ins, and completing habits. Mind & Money generates evidence-based insights once sufficient local data exists.',
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
            itemCount: insights.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (ctx, i) {
              final insight = insights[i];
              final col = Color(insight.color ?? 0xFF4CAF50);

              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: col.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.auto_awesome_rounded,
                          color: col,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Flexible(
                                  child: Text(
                                    insight.title,
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
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
                                    insight.category.name.toUpperCase(),
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              insight.message,
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
            },
          );
        },
      ),
    );
  }

  // -------------------------------------------------------------
  // TAB 4: ARCHIVED HABITS
  // -------------------------------------------------------------
  Widget _buildArchivedTab(BuildContext context) {
    final archivedAsync = ref.watch(archivedHabitsProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(archivedHabitsProvider);
        await ref.read(archivedHabitsProvider.future);
      },
      child: archivedAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (habits) {
          if (habits.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: EmptyStateCard(
                  icon: Icons.archive_outlined,
                  title: 'No archived habits',
                  description: 'When you archive a habit, it is preserved here without losing its historical completion records.',
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
            itemCount: habits.length,
            itemBuilder: (ctx, i) {
              return _buildHabitTile(ctx, habits[i], isTodayView: false);
            },
          );
        },
      ),
    );
  }

  // -------------------------------------------------------------
  // REUSABLE HABIT TILE
  // -------------------------------------------------------------
  Widget _buildHabitTile(
    BuildContext context,
    Habit habit, {
    required bool isTodayView,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final habitColor = Color(habit.color ?? 0xFF4CAF50);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => _openHabitDetailSheet(habit),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              // Checkbox if today view; colored circle if not
              if (isTodayView)
                Semantics(
                  label: habit.isCompletedToday
                      ? 'Mark ${habit.name} incomplete'
                      : 'Mark ${habit.name} completed',
                  button: true,
                  checked: habit.isCompletedToday,
                  child: InkWell(
                    onTap: () => _toggleHabit(habit),
                    borderRadius: BorderRadius.circular(22),
                    child: Container(
                      constraints: const BoxConstraints(
                        minWidth: 44,
                        minHeight: 44,
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        habit.isCompletedToday
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_unchecked_rounded,
                        size: 26,
                        color: habit.isCompletedToday
                            ? habitColor
                            : colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                )
              else
                CircleAvatar(
                  radius: 16,
                  backgroundColor: habitColor.withValues(alpha: 0.15),
                  child: Icon(
                    Icons.check_circle_rounded,
                    color: habitColor,
                    size: 20,
                  ),
                ),
              const SizedBox(width: 12),

              // Title and schedule
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      habit.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        decoration: isTodayView && habit.isCompletedToday
                            ? TextDecoration.lineThrough
                            : null,
                        color: isTodayView && habit.isCompletedToday
                            ? colorScheme.onSurfaceVariant
                            : null,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      habit.scheduleSummary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

              // Streak / Info Pill (FittedBox protection for large numbers and small screens)
              Consumer(
                builder: (ctx, ref, _) {
                  final statsAsync = ref.watch(habitStatsProvider(habit));
                  final streak = statsAsync.value?.currentStreak ?? 0;

                  final isDark = theme.brightness == Brightness.dark;
                  final streakColor = isDark
                      ? AppColors.warningAmberDark
                      : AppColors.warningAmber;
                  final streakBg = isDark
                      ? AppColors.warningContainerDark
                      : AppColors.warningContainerLight;

                  return Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: streakBg,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.local_fire_department_rounded,
                              size: 14,
                              color: streakColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$streak',
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: streakColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
