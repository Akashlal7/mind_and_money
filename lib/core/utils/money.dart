import 'package:intl/intl.dart';

/// Represents a monetary value using integer minor units (cents / paise)
/// to prevent IEEE-754 floating-point inaccuracies.
class Money implements Comparable<Money> {
  final int cents;

  const Money(this.cents);

  const Money.zero() : cents = 0;

  /// Creates a Money instance from a double amount (e.g. 12.50 -> 1250 cents)
  factory Money.fromDouble(double amount) {
    return Money((amount * 100).round());
  }

  /// Parses a string representation like "123.45" or "100" into a Money instance.
  /// Throws FormatException if invalid.
  factory Money.parse(String text) {
    final cleaned = text.trim().replaceAll(',', '');
    final parsed = double.tryParse(cleaned);
    if (parsed == null) {
      throw FormatException('Invalid currency amount: "$text"');
    }
    return Money.fromDouble(parsed);
  }

  /// Safe parse that returns null if invalid.
  static Money? tryParse(String? text) {
    if (text == null || text.trim().isEmpty) return null;
    try {
      return Money.parse(text);
    } catch (_) {
      return null;
    }
  }

  /// Alias for tryParse
  static Money? tryParseAmount(String? text) => tryParse(text);

  /// Returns the amount as double (e.g. 1250 -> 12.50)
  double toDouble() => cents / 100.0;

  Money operator +(Money other) => Money(cents + other.cents);
  Money operator -(Money other) => Money(cents - other.cents);
  Money operator -() => Money(-cents);
  Money operator *(num factor) => Money((cents * factor).round());

  bool operator <(Money other) => cents < other.cents;
  bool operator <=(Money other) => cents <= other.cents;
  bool operator >(Money other) => cents > other.cents;
  bool operator >=(Money other) => cents >= other.cents;

  bool get isNegative => cents < 0;
  bool get isZero => cents == 0;
  bool get isPositive => cents > 0;

  Money abs() => Money(cents.abs());

  @override
  int compareTo(Money other) => cents.compareTo(other.cents);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Money &&
          runtimeType == other.runtimeType &&
          cents == other.cents;

  @override
  int get hashCode => cents.hashCode;

  /// Formats the money with a currency symbol (defaults to Indian Rupee ₹)
  String format({String symbol = '₹', bool includeSign = false}) {
    final formatter = NumberFormat('#,##0.00', 'en_IN');
    final absFormatted = formatter.format(abs().toDouble());
    if (isNegative) {
      return '-$symbol$absFormatted';
    }
    if (includeSign && isPositive) {
      return '+$symbol$absFormatted';
    }
    return '$symbol$absFormatted';
  }

  /// Convenience getter for standard formatted string
  String get formatted => format();

  @override
  String toString() => format();
}
