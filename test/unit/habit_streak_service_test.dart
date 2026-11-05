import 'package:flutter_test/flutter_test.dart';
import 'package:mind_and_money/features/habits/models/habit.dart';
import 'package:mind_and_money/features/habits/services/habit_streak_service.dart';

void main() {
  group('HabitStreakService Tests', () {
    const service = HabitStreakService();

    test('Daily habit: calculates current streak, longest streak, and completion rate', () {
      final habit = Habit(
        id: 'hab_daily_1',
        name: 'Drink Water',
        scheduleType: 'daily',
        createdAt: DateTime(2026, 10, 20),
      );

      // Completed Oct 20, 21, 22, 23 (4 days)
      // Missed Oct 24
      // Completed Oct 25, 26, 27 (3 days)
      // As of Oct 27
      final completionDates = {
        '2026-10-20',
        '2026-10-21',
        '2026-10-22',
        '2026-10-23',
        '2026-10-25',
        '2026-10-26',
        '2026-10-27',
      };

      final stats = service.calculateStats(
        habit: habit,
        completionDates: completionDates,
        asOfDate: DateTime(2026, 10, 27),
      );

      expect(stats.totalScheduledDays, 8); // Oct 20..27 = 8 days
      expect(stats.totalCompletions, 7);
      expect(stats.longestStreak, 4); // Oct 20..23
      expect(stats.currentStreak, 3); // Oct 25..27
      expect(stats.completionPercentage, 88); // 7/8 = 87.5% -> 88%
    });

    test('Selected weekdays habit: unscheduled days do NOT break streak', () {
      // Habit scheduled only on Mon (1), Wed (3), Fri (5)
      // Oct 19, 2026 = Monday (1)
      // Oct 20 = Tuesday (2) - unscheduled
      // Oct 21 = Wednesday (3)
      // Oct 22 = Thursday (4) - unscheduled
      // Oct 23 = Friday (5)
      final habit = Habit(
        id: 'hab_mwf',
        name: 'Gym',
        scheduleType: 'weekdays',
        scheduleDays: '1,3,5',
        createdAt: DateTime(2026, 10, 19),
      );

      // User completed Mon Oct 19 and Wed Oct 21
      final completionDates = {'2026-10-19', '2026-10-21'};

      // As of Thursday Oct 22 (unscheduled day)
      final statsOnThursday = service.calculateStats(
        habit: habit,
        completionDates: completionDates,
        asOfDate: DateTime(2026, 10, 22),
      );

      // Thursday is unscheduled, so it does not break streak!
      // Scheduled days were Mon & Wed, both completed.
      expect(statsOnThursday.totalScheduledDays, 2);
      expect(statsOnThursday.currentStreak, 2);
      expect(statsOnThursday.longestStreak, 2);
    });

    test('Current streak grace period: today scheduled but not yet completed preserves streak', () {
      final habit = Habit(
        id: 'hab_grace',
        name: 'Meditate',
        scheduleType: 'daily',
        createdAt: DateTime(2026, 10, 20),
      );

      // Completed Oct 20, 21, 22.
      // Today is Oct 23 (morning), user hasn't logged yet.
      final completionDates = {'2026-10-20', '2026-10-21', '2026-10-22'};

      final stats = service.calculateStats(
        habit: habit,
        completionDates: completionDates,
        asOfDate: DateTime(2026, 10, 23),
      );

      // Preserves 3-day streak from yesterday because today has not ended yet
      expect(stats.currentStreak, 3);
      expect(stats.longestStreak, 3);

      // When user completes today (Oct 23):
      final completedTodayDates = {...completionDates, '2026-10-23'};
      final updatedStats = service.calculateStats(
        habit: habit,
        completionDates: completedTodayDates,
        asOfDate: DateTime(2026, 10, 23),
      );
      expect(updatedStats.currentStreak, 4);
    });

    test(
      'Missed scheduled day breaks current streak to 0 once day has passed',
      () {
        final habit = Habit(
          id: 'hab_missed',
          name: 'Reading',
          scheduleType: 'daily',
          createdAt: DateTime(2026, 10, 20),
        );

        // Completed Oct 20, 21.
        // Missed Oct 22.
        // Today is Oct 23 (not yet completed).
        final completionDates = {'2026-10-20', '2026-10-21'};

        final stats = service.calculateStats(
          habit: habit,
          completionDates: completionDates,
          asOfDate: DateTime(2026, 10, 23),
        );

        // Because Oct 22 was completely missed, current streak is 0
        expect(stats.currentStreak, 0);
        expect(stats.longestStreak, 2);
      },
    );

    test('Future dates never count as completed or missed', () {
      final habit = Habit(
        id: 'hab_future',
        name: 'Walk',
        scheduleType: 'daily',
        createdAt: DateTime(2026, 10, 25),
      );

      // If evaluated for a date prior to creation
      final statsPrior = service.calculateStats(
        habit: habit,
        completionDates: {},
        asOfDate: DateTime(2026, 10, 20),
      );
      expect(statsPrior.totalScheduledDays, 0);
      expect(statsPrior.currentStreak, 0);
    });

    test('Normalized local date format matches YYYY-MM-DD exactly', () {
      final dt = DateTime(2026, 5, 4, 18, 30, 45);
      final normalized = HabitStreakService.normalizeDate(dt);
      expect(normalized, '2026-05-04');

      final parsed = HabitStreakService.parseNormalizedDate(normalized);
      expect(parsed.year, 2026);
      expect(parsed.month, 5);
      expect(parsed.day, 4);
    });
  });
}
