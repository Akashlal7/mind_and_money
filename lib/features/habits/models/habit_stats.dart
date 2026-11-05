/// Aggregated streak and completion statistics for a habit
class HabitStats {
  final String habitId;
  final int currentStreak;
  final int longestStreak;
  final int totalCompletions;
  final int totalScheduledDays;
  final double completionRate; // 0.0 to 1.0

  const HabitStats({
    required this.habitId,
    required this.currentStreak,
    required this.longestStreak,
    required this.totalCompletions,
    required this.totalScheduledDays,
    required this.completionRate,
  });

  /// Factory for an empty/initial stats object
  factory HabitStats.empty(String habitId) {
    return HabitStats(
      habitId: habitId,
      currentStreak: 0,
      longestStreak: 0,
      totalCompletions: 0,
      totalScheduledDays: 0,
      completionRate: 0.0,
    );
  }

  int get completionPercentage => (completionRate * 100).round();
}
