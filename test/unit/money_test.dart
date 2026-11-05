import 'package:flutter_test/flutter_test.dart';
import 'package:mind_and_money/core/utils/money.dart';

void main() {
  group('Money Value Object Tests', () {
    test('creates Money from integer cents', () {
      const m = Money(1550);
      expect(m.cents, 1550);
      expect(m.toDouble(), 15.50);
    });

    test('creates Money from double without floating precision loss', () {
      final m = Money.fromDouble(19.99);
      expect(m.cents, 1999);
      expect(m.toDouble(), 19.99);
    });

    test('parses currency strings correctly', () {
      final m1 = Money.parse('123.45');
      expect(m1.cents, 12345);

      final m2 = Money.parse('1,500.00');
      expect(m2.cents, 150000);

      final m3 = Money.tryParse('invalid');
      expect(m3, isNull);
    });

    test('performs exact decimal addition and subtraction', () {
      const a = Money(10050); // 100.50
      const b = Money(4950); // 49.50

      final sum = a + b;
      expect(sum.cents, 15000);
      expect(sum.toDouble(), 150.0);

      final diff = a - b;
      expect(diff.cents, 5100);
      expect(diff.toDouble(), 51.0);
    });

    test('formats currency with default Indian Rupee ₹ symbol', () {
      const m = Money(250000); // 2500.00
      expect(m.format(symbol: '₹'), '₹2,500.00');

      const neg = Money(-7550);
      expect(neg.format(symbol: '₹'), '-₹75.50');
    });

    test('equality and comparison work accurately', () {
      const m1 = Money(1000);
      const m2 = Money(1000);
      const m3 = Money(2000);

      expect(m1, equals(m2));
      expect(m1.compareTo(m3), lessThan(0));
      expect(m3.compareTo(m1), greaterThan(0));
    });
  });
}
