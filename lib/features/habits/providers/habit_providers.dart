import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../home/providers/home_providers.dart';
import '../data/habit_repository.dart';
import '../models/habit.dart';
import '../models/habit_completion.dart';
import '../models/habit_stats.dart';

/// Repository provider for HabitRepository
final habitRepositoryProvider = Provider<HabitRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return HabitRepository(db);
});

/// Notifier to manage active filter tab in Habits screen: 'today', 'active', 'archived', 'stats'
class HabitTabFilterNotifier extends Notifier<String> {
  @override
  String build() => 'today';

  void setFilter(String filter) => state = filter;
}

final habitTabFilterProvider = NotifierProvider<HabitTabFilterNotifier, String>(
  HabitTabFilterNotifier.new,
);

/// Provider for active habits with today's completion state
final activeHabitsProvider = FutureProvider.autoDispose<List<Habit>>((
  ref,
) async {
  final repo = ref.watch(habitRepositoryProvider);
  return repo.getHabits(includeArchived: false);
});

/// Provider for archived habits
final archivedHabitsProvider = FutureProvider.autoDispose<List<Habit>>((
  ref,
) async {
  final repo = ref.watch(habitRepositoryProvider);
  final all = await repo.getHabits(includeArchived: true);
  return all.where((h) => h.isArchived).toList();
});

/// Provider for habits scheduled specifically for today
final todayScheduledHabitsProvider = FutureProvider.autoDispose<List<Habit>>((
  ref,
) async {
  final repo = ref.watch(habitRepositoryProvider);
  return repo.getScheduledHabitsForDate(DateTime.now());
});

/// Provider for today's habit completion progress
final todayHabitProgressProvider =
    FutureProvider.autoDispose<
      ({int scheduledCount, int completedCount, double completionRate})
    >((ref) async {
      final repo = ref.watch(habitRepositoryProvider);
      return repo.getDailyProgress(DateTime.now());
    });

/// Provider for a specific habit's calculated statistics and streaks
final habitStatsProvider = FutureProvider.autoDispose.family<HabitStats, Habit>(
  (ref, habit) async {
    final repo = ref.watch(habitRepositoryProvider);
    return repo.getHabitStats(habit);
  },
);

/// Provider for all completion records of a habit
final habitCompletionsProvider = FutureProvider.autoDispose
    .family<List<HabitCompletion>, String>((ref, habitId) async {
      final repo = ref.watch(habitRepositoryProvider);
      return repo.getCompletionsForHabit(habitId);
    });
