import 'package:flutter_test/flutter_test.dart';
import 'package:mind_and_money/core/utils/date_utils.dart';

void main() {
  group('AppDateUtils Tests', () {
    test('calculates correct start of month', () {
      final date = DateTime(2026, 10, 26, 14, 30);
      final start = AppDateUtils.startOfMonth(date);

      expect(start.year, 2026);
      expect(start.month, 10);
      expect(start.day, 1);
      expect(start.hour, 0);
      expect(start.minute, 0);
    });

    test('calculates correct end of month for leap and non-leap years', () {
      final dateFeb2024 = DateTime(2024, 2, 10); // Leap year
      final endFeb2024 = AppDateUtils.endOfMonth(dateFeb2024);
      expect(endFeb2024.day, 29);

      final dateOct2026 = DateTime(2026, 10, 15);
      final endOct2026 = AppDateUtils.endOfMonth(dateOct2026);
      expect(endOct2026.day, 31);
    });

    test('formats ISO strings correctly', () {
      final date = DateTime(2026, 10, 26);
      expect(AppDateUtils.toIsoDate(date), '2026-10-26');
      expect(AppDateUtils.toIsoMonth(date), '2026-10');
      expect(AppDateUtils.toMonthYear(date), 'October 2026');
    });

    test('returns appropriate daytime greeting', () {
      final morning = DateTime(2026, 10, 26, 9, 0);
      final afternoon = DateTime(2026, 10, 26, 14, 0);
      final evening = DateTime(2026, 10, 26, 20, 0);

      expect(AppDateUtils.getGreeting(morning), 'Good morning');
      expect(AppDateUtils.getGreeting(afternoon), 'Good afternoon');
      expect(AppDateUtils.getGreeting(evening), 'Good evening');
    });
  });
}
