import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mind_and_money/core/database/app_database.dart';
import 'package:mind_and_money/core/database/tables.dart';
import 'package:mind_and_money/core/utils/money.dart';
import 'package:mind_and_money/features/finance/models/transaction.dart';
import 'package:mind_and_money/features/finance/presentation/money_screen.dart';
import 'package:mind_and_money/features/finance/presentation/transaction_form_sheet.dart';
import 'package:mind_and_money/features/finance/repositories/transaction_repository.dart';
import 'package:mind_and_money/features/home/providers/home_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    SharedPreferences.setMockInitialValues({});
  });

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
          batch.execute(DbTables.createBudgetsTable);
          batch.execute(DbTables.createSavingsGoalsTable);
          batch.execute(DbTables.createSavingsContributionsTable);
          batch.execute(DbTables.createMoodEntriesTable);
          batch.execute(DbTables.createJournalEntriesTable);
          batch.execute(DbTables.createHabitsTable);
          batch.execute(DbTables.createHabitCompletionsTable);
          batch.execute(DbTables.createAppMetadataTable);
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

  testWidgets('MoneyScreen displays empty state when no transactions exist', (
    WidgetTester tester,
  ) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appDatabaseProvider.overrideWithValue(appDatabase)],
          child: const MaterialApp(home: MoneyScreen()),
        ),
      );

      await tester.pump();
      await Future.delayed(const Duration(milliseconds: 100));
      await tester.pump();

      expect(find.text('No transactions recorded'), findsOneWidget);
      expect(find.text('Add Transaction'), findsNWidgets(2));
    });
  });

  testWidgets('MoneyScreen displays transactions and calculates totals', (
    WidgetTester tester,
  ) async {
    await tester.runAsync(() async {
      final repo = TransactionRepository(appDatabase);
      await repo.createTransaction(
        FinancialTransaction(
          id: 'tx_coffee',
          amount: const Money(15000), // ₹150.00
          type: TransactionType.expense,
          categoryId: 'cat_food',
          description: 'Morning Coffee',
          paymentMethod: 'upi',
          transactionDate: DateTime.now(),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [appDatabaseProvider.overrideWithValue(appDatabase)],
          child: const MaterialApp(home: MoneyScreen()),
        ),
      );

      await tester.pump();
      await Future.delayed(const Duration(milliseconds: 100));
      await tester.pump();

      expect(find.text('Morning Coffee'), findsOneWidget);
      expect(find.text('-₹150.00'), findsNWidgets(2));
    });
  });

  testWidgets('TransactionFormSheet validates required amount and saves', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.runAsync(() async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appDatabaseProvider.overrideWithValue(appDatabase)],
          child: const MaterialApp(
            home: Scaffold(body: TransactionFormSheet()),
          ),
        ),
      );

      await tester.pump();
      await Future.delayed(const Duration(milliseconds: 100));
      await tester.pump();

      expect(find.text('Record Transaction'), findsOneWidget);

      // Attempt to save empty amount
      final saveBtn = find.text('Save Transaction');
      await tester.tap(saveBtn);
      await tester.pump();
      await Future.delayed(const Duration(milliseconds: 50));
      await tester.pump();

      expect(find.text('Please enter an amount'), findsOneWidget);

      // Enter valid amount and save
      await tester.enterText(find.byType(TextFormField).first, '350.00');
      await tester.enterText(find.byType(TextFormField).at(1), 'Lunch Combo');
      await tester.pump();

      await tester.tap(saveBtn);
      await tester.pump();
      await Future.delayed(const Duration(milliseconds: 200));
      await tester.pump();

      // Verify transaction was written to SQLite
      final repo = TransactionRepository(appDatabase);
      final transactions = await repo.getTransactions();
      expect(transactions.any((t) => t.description == 'Lunch Combo'), isTrue);
    });
  });
}
