import 'package:intl/intl.dart';

/// Utilities for working with dates, month ranges, and standard ISO formats.
class AppDateUtils {
  AppDateUtils._();

  static final DateFormat _isoDate = DateFormat('yyyy-MM-dd');
  static final DateFormat _isoMonth = DateFormat('yyyy-MM');
  static final DateFormat _displayDate = DateFormat('EEEE, d MMMM yyyy');
  static final DateFormat _shortDate = DateFormat('d MMM yyyy');
  static final DateFormat _monthYear = DateFormat('MMMM yyyy');
  static final DateFormat _compactMonthYear = DateFormat('MMM yy');
  static final DateFormat _timeFormat = DateFormat('hh:mm a');

  /// Formats DateTime to YYYY-MM-DD
  static String toIsoDate(DateTime date) => _isoDate.format(date);

  /// Formats DateTime to YYYY-MM
  static String toIsoMonth(DateTime date) => _isoMonth.format(date);

  /// Formats DateTime to "Monday, 26 October 2026"
  static String toDisplayDate(DateTime date) => _displayDate.format(date);

  /// Formats DateTime to "26 Oct 2026"
  static String toShortDate(DateTime date) => _shortDate.format(date);

  /// Formats DateTime to "October 2026"
  static String toMonthYear(DateTime date) => _monthYear.format(date);

  /// Formats DateTime to "Oct 26"
  static String toCompactMonthYear(DateTime date) => _compactMonthYear.format(date);

  /// Formats DateTime to "03:45 PM"
  static String toDisplayTime(DateTime date) => _timeFormat.format(date);

  /// Returns start of day: YYYY-MM-DD 00:00:00.000
  static DateTime startOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  /// Returns end of day: YYYY-MM-DD 23:59:59.999
  static DateTime endOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day, 23, 59, 59, 999);
  }

  /// Returns the start of the month: YYYY-MM-01 00:00:00.000
  static DateTime startOfMonth(DateTime date) {
    return DateTime(date.year, date.month, 1);
  }

  /// Returns the end of the month: last day of month 23:59:59.999
  static DateTime endOfMonth(DateTime date) {
    return DateTime(date.year, date.month + 1, 0, 23, 59, 59, 999);
  }

  /// Returns a friendly greeting based on the hour of the day
  static String getGreeting([DateTime? date]) {
    final hour = (date ?? DateTime.now()).hour;
    if (hour < 12) {
      return 'Good morning';
    } else if (hour < 17) {
      return 'Good afternoon';
    } else {
      return 'Good evening';
    }
  }

  /// Returns true if two dates represent the same calendar day
  static bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
