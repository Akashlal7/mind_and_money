import '../models/habit.dart';
import '../models/habit_stats.dart';

/// Pure, deterministic calculation service for habit schedules, streaks, and completion rates.
class HabitStreakService {
  const HabitStreakService();

  /// Formats a DateTime into a normalized local calendar date string (YYYY-MM-DD).
  static String normalizeDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  /// Parses an ISO date string (YYYY-MM-DD) into a local DateTime at midnight.
  static DateTime parseNormalizedDate(String dateStr) {
    final parts = dateStr.split('-');
    return DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }

  /// Truncates a DateTime to midnight in local time.
  static DateTime toDateOnly(DateTime dt) {
    return DateTime(dt.year, dt.month, dt.day);
  }

  /// Calculates complete habit statistics up to the given `asOfDate`.
  ///
  /// - `habit`: The habit definition.
  /// - `completionDates`: Set of normalized 'YYYY-MM-DD' strings on which the habit was completed.
  /// - `asOfDate`: The target date for the evaluation (defaults to today).
  HabitStats calculateStats({
    required Habit habit,
    required Set<String> completionDates,
    required DateTime asOfDate,
  }) {
    final targetDate = toDateOnly(asOfDate);
    final startDate = toDateOnly(habit.createdAt);

    if (targetDate.isBefore(startDate)) {
      return HabitStats.empty(habit.id);
    }

    // 1. Collect all scheduled calendar dates between startDate and targetDate inclusive
    final List<DateTime> scheduledDays = [];
    DateTime cursor = startDate;
    while (!cursor.isAfter(targetDate)) {
      if (habit.isScheduledForWeekday(cursor.weekday)) {
        scheduledDays.add(cursor);
      }
      cursor = cursor.add(const Duration(days: 1));
    }

    final totalScheduledDays = scheduledDays.length;
    if (totalScheduledDays == 0) {
      return HabitStats.empty(habit.id);
    }

    // 2. Count total completions and find longest streak
    int totalCompletions = 0;
    int currentRun = 0;
    int longestStreak = 0;

    for (final date in scheduledDays) {
      final dateKey = normalizeDate(date);
      if (completionDates.contains(dateKey)) {
        totalCompletions++;
        currentRun++;
        if (currentRun > longestStreak) {
          longestStreak = currentRun;
        }
      } else {
        currentRun = 0;
      }
    }

    // 3. Calculate current streak
    // Streak rules:
    // - Only scheduled days count.
    // - Unscheduled weekdays never break a streak.
    // - If targetDate is a scheduled day:
    //     - If completed today -> streak includes today and counts consecutive previous scheduled days.
    //     - If NOT completed today -> streak evaluates from the most recent scheduled day before today.
    // - If targetDate is NOT a scheduled day:
    //     - Streak evaluates from the most recent scheduled day before today.
    int currentStreak = 0;
    final isTargetScheduled = habit.isScheduledForWeekday(targetDate.weekday);
    final isTargetCompleted = completionDates.contains(
      normalizeDate(targetDate),
    );

    int startIndex;
    if (isTargetScheduled && isTargetCompleted) {
      // Today is scheduled and completed; count backwards starting from today
      startIndex = scheduledDays.length - 1;
    } else if (isTargetScheduled && !isTargetCompleted) {
      // Today is scheduled but not yet completed; grace period evaluates from previous scheduled day
      startIndex = scheduledDays.length - 2;
    } else {
      // Today is unscheduled; evaluate from most recent scheduled day
      startIndex = scheduledDays.length - 1;
    }

    for (int i = startIndex; i >= 0; i--) {
      final dateKey = normalizeDate(scheduledDays[i]);
      if (completionDates.contains(dateKey)) {
        currentStreak++;
      } else {
        break;
      }
    }

    final completionRate = totalScheduledDays > 0
        ? (totalCompletions / totalScheduledDays).clamp(0.0, 1.0)
        : 0.0;

    return HabitStats(
      habitId: habit.id,
      currentStreak: currentStreak,
      longestStreak: longestStreak,
      totalCompletions: totalCompletions,
      totalScheduledDays: totalScheduledDays,
      completionRate: completionRate,
    );
  }

  /// Returns completion rates and metrics for a specific window of days (e.g. past 7, 30, or custom range).
  double calculateCompletionRateForRange({
    required Habit habit,
    required Set<String> completionDates,
    required DateTime fromDate,
    required DateTime toDate,
  }) {
    final start = toDateOnly(fromDate);
    final end = toDateOnly(toDate);

    int scheduled = 0;
    int completed = 0;

    DateTime cursor = start;
    while (!cursor.isAfter(end)) {
      if (habit.isScheduledForWeekday(cursor.weekday)) {
        scheduled++;
        if (completionDates.contains(normalizeDate(cursor))) {
          completed++;
        }
      }
      cursor = cursor.add(const Duration(days: 1));
    }

    return scheduled > 0 ? (completed / scheduled).clamp(0.0, 1.0) : 0.0;
  }
}
