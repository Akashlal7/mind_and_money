import 'package:flutter_test/flutter_test.dart';
import 'package:mind_and_money/core/database/app_database.dart';
import 'package:mind_and_money/core/database/tables.dart';
import 'package:mind_and_money/core/services/csv_service.dart';
import 'package:mind_and_money/core/utils/money.dart';
import 'package:mind_and_money/features/finance/models/transaction.dart';
import 'package:mind_and_money/features/finance/repositories/transaction_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('CsvExportService - RFC 4180 Escaping Unit Tests', () {
    test('escapeCsvField handles null and plain text', () {
      expect(CsvExportService.escapeCsvField(null), equals(''));
      expect(CsvExportService.escapeCsvField(''), equals(''));
      expect(CsvExportService.escapeCsvField('Grocery'), equals('Grocery'));
      expect(CsvExportService.escapeCsvField('150.00'), equals('150.00'));
    });

    test('escapeCsvField quotes fields with commas', () {
      expect(
        CsvExportService.escapeCsvField('Coffee, Tea & Snacks'),
        equals('"Coffee, Tea & Snacks"'),
      );
    });

    test('escapeCsvField quotes and doubles internal quotation marks', () {
      expect(
        CsvExportService.escapeCsvField('Lunch at "The Bistro"'),
        equals('"Lunch at ""The Bistro"""'),
      );
    });

    test('escapeCsvField quotes multiline text with line breaks', () {
      expect(
        CsvExportService.escapeCsvField('Line 1\nLine 2'),
        equals('"Line 1\nLine 2"'),
      );
      expect(
        CsvExportService.escapeCsvField('Line 1\r\nLine 2'),
        equals('"Line 1\r\nLine 2"'),
      );
    });
  });

  group('CsvExportService - Database Export Integration Tests', () {
    late AppDatabase appDatabase;
    late Database rawDb;

    setUp(() async {
      appDatabase = AppDatabase();
      rawDb = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, version) async {
            final batch = db.batch();
            batch.execute(DbTables.createCategoriesTable);
            batch.execute(DbTables.createTransactionsTable);
            for (final cat in DbTables.defaultCategories) {
              batch.insert(DbTables.categories, cat);
            }
            await batch.commit();
          },
        ),
      );
      appDatabase.setDatabaseForTesting(rawDb);
    });

    tearDown(() async {
      await rawDb.close();
    });

    test(
      'Exports empty transactions table with correct RFC 4180 header',
      () async {
        final csvService = CsvExportService(appDatabase);
        final csv = await csvService.exportTransactionsToCsv();

        final lines = csv.trim().split('\n');
        expect(lines.length, equals(1));
        expect(
          lines.first,
          equals(
            'id,date,type,category,amount,payment_method,description,note,created_at',
          ),
        );
      },
    );

    test(
      'Exports transactions with resolved categories and decimal amounts',
      () async {
        final txRepo = TransactionRepository(appDatabase);
        final date = DateTime(2026, 10, 26, 14, 30);

        await txRepo.createTransaction(
          FinancialTransaction(
            id: 'tx_1',
            amount: const Money(250050), // ₹2500.50
            type: TransactionType.expense,
            categoryId: 'cat_food',
            description: 'Team Dinner, "Pizza"',
            paymentMethod: 'credit_card',
            note: 'Work meal\nShared with colleagues',
            transactionDate: date,
            createdAt: date,
            updatedAt: date,
          ),
        );

        final csvService = CsvExportService(appDatabase);
        final csv = await csvService.exportTransactionsToCsv();

        expect(
          csv,
          contains(
            'id,date,type,category,amount,payment_method,description,note,created_at',
          ),
        );
        expect(csv, contains('tx_1'));
        expect(csv, contains('expense'));
        expect(csv, contains('Food & Dining'));
        expect(csv, contains('2500.50'));
        expect(csv, contains('"Team Dinner, ""Pizza"""'));
        expect(csv, contains('"Work meal\nShared with colleagues"'));
        expect(csv, contains('credit_card'));
      },
    );
  });
}
