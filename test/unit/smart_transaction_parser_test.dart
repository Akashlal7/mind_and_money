import 'package:flutter_test/flutter_test.dart';
import 'package:mind_and_money/features/finance/models/transaction.dart';
import 'package:mind_and_money/features/finance/services/smart_transaction_parser.dart';

void main() {
  final referenceDate = DateTime(2026, 11, 5, 14, 30);

  group('SmartTransactionParser — Bank SMS Parsing', () {
    test('Parses standard UPI debit SMS alert with merchant and amount', () {
      const sms =
          'A/c *4912 debited for Rs 340.00 on 04-Nov-26 by UPI to Starbucks ref 892019. Bal: Rs 14,200.00';

      final results = SmartTransactionParser.parse(
        sms,
        fallbackDate: referenceDate,
      );

      expect(results, hasLength(1));
      final draft = results.first;
      expect(draft.amount.cents, 34000); // Rs 340.00
      expect(draft.type, TransactionType.expense);
      expect(draft.paymentMethod, 'upi');
      expect(draft.categoryId, 'cat_food');
      expect(draft.description, contains('Starbucks'));
      expect(draft.date.day, 4);
      expect(draft.date.month, 11);
    });

    test('Parses Credit Card spend alert with merchant and INR amount', () {
      const sms =
          'INR 1,499.00 spent on your Credit Card ending in 4102 at Amazon India on 02-Nov-26. Avl Lmt: INR 45,000.00';

      final results = SmartTransactionParser.parse(
        sms,
        fallbackDate: referenceDate,
      );

      expect(results, hasLength(1));
      final draft = results.first;
      expect(draft.amount.cents, 149900); // Rs 1,499.00
      expect(draft.type, TransactionType.expense);
      expect(draft.paymentMethod, 'credit_card');
      expect(draft.categoryId, 'cat_shopping');
      expect(draft.description, contains('Amazon'));
    });

    test('Parses Bank Salary credit alert', () {
      const sms =
          'Your A/c *8921 is credited with Rs 65,000.00 on 01-Nov-26 by Salary transfer from Employer Ltd.';

      final results = SmartTransactionParser.parse(
        sms,
        fallbackDate: referenceDate,
      );

      expect(results, hasLength(1));
      final draft = results.first;
      expect(draft.amount.cents, 6500000); // Rs 65,000.00
      expect(draft.type, TransactionType.income);
      expect(draft.categoryId, 'cat_salary');
      expect(draft.paymentMethod, 'bank_transfer');
    });
  });

  group('SmartTransactionParser — One-Liner Quick Entry', () {
    test('Parses simple "Coffee 120" with default date and cash', () {
      final results = SmartTransactionParser.parse(
        'Coffee 120',
        fallbackDate: referenceDate,
      );

      expect(results, hasLength(1));
      final draft = results.first;
      expect(draft.amount.cents, 12000); // 120.00
      expect(draft.description, 'Coffee');
      expect(draft.categoryId, 'cat_food');
      expect(draft.paymentMethod, 'cash');
      expect(draft.date.day, referenceDate.day);
    });

    test('Parses "Uber 350 card yesterday" with relative date and card payment', () {
      final results = SmartTransactionParser.parse(
        'Uber 350 card yesterday',
        fallbackDate: referenceDate,
      );

      expect(results, hasLength(1));
      final draft = results.first;
      expect(draft.amount.cents, 35000);
      expect(draft.description, 'Uber');
      expect(draft.categoryId, 'cat_transport');
      expect(draft.paymentMethod, 'card');
      expect(draft.date.day, referenceDate.day - 1);
    });

    test('Parses "Groceries 1500 blinkit upi"', () {
      final results = SmartTransactionParser.parse(
        'Groceries 1500 blinkit upi',
        fallbackDate: referenceDate,
      );

      expect(results, hasLength(1));
      final draft = results.first;
      expect(draft.amount.cents, 150000);
      expect(draft.categoryId, 'cat_groceries');
      expect(draft.paymentMethod, 'upi');
    });
  });

  group('SmartTransactionParser — Batch Multi-line Parsing', () {
    test('Parses multiple quick lines in single paste', () {
      const multiline = '''
Coffee 120
Metro 40
Lunch 250
''';

      final results = SmartTransactionParser.parse(
        multiline,
        fallbackDate: referenceDate,
      );

      expect(results, hasLength(3));
      expect(results[0].amount.cents, 12000);
      expect(results[0].description, 'Coffee');
      expect(results[1].amount.cents, 4000);
      expect(results[1].description, 'Metro');
      expect(results[2].amount.cents, 25000);
      expect(results[2].description, 'Lunch');
    });

    test('Parses multiple bank SMS pasted together separated by blank lines', () {
      const multiSms = '''
A/c *4912 debited for Rs 120.00 on 04-Nov-26 by UPI to Chai Point ref 1122.

INR 850.00 spent on your Credit Card ending in 4102 at Swiggy on 04-Nov-26.
''';

      final results = SmartTransactionParser.parse(
        multiSms,
        fallbackDate: referenceDate,
      );

      expect(results, hasLength(2));
      expect(results[0].amount.cents, 12000);
      expect(results[0].paymentMethod, 'upi');
      expect(results[1].amount.cents, 85000);
      expect(results[1].paymentMethod, 'credit_card');
    });
  });
}

