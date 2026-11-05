import 'package:flutter_test/flutter_test.dart';
import 'package:mind_and_money/core/database/app_database.dart';
import 'package:mind_and_money/core/database/tables.dart';
import 'package:mind_and_money/core/utils/money.dart';
import 'package:mind_and_money/features/finance/models/budget.dart';
import 'package:mind_and_money/features/finance/models/transaction.dart';
import 'package:mind_and_money/features/finance/repositories/budget_repository.dart';
import 'package:mind_and_money/features/finance/repositories/reports_repository.dart';
import 'package:mind_and_money/features/finance/repositories/transaction_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late AppDatabase appDatabase;
  late Database rawDb;
  late ReportsRepository reportsRepo;
  late TransactionRepository transRepo;
  late BudgetRepository budgetRepo;

  setUp(() async {
    appDatabase = AppDatabase();
    rawDb = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 2,
        onCreate: (db, version) async {
          final batch = db.batch();
          batch.execute(DbTables.createCategoriesTable);
          batch.execute(DbTables.createTransactionsTable);
          batch.execute(DbTables.createBudgetsTable);
          batch.execute(DbTables.createSavingsGoalsTable);
          batch.execute(DbTables.createSavingsContributionsTable);
          batch.execute(DbTables.createMoodEntriesTable);
          batch.execute(DbTables.createJournalEntriesTable);
          batch.execute(DbTables.createBreathingSessionsTable);
          batch.execute(DbTables.createSpendingReflectionsTable);
          batch.execute(DbTables.createHabitsTable);
          batch.execute(DbTables.createHabitCompletionsTable);
          batch.execute(DbTables.createAppMetadataTable);
          for (final idx in DbTables.createIndexes) {
            batch.execute(idx);
          }
          for (final cat in DbTables.defaultCategories) {
            batch.insert(DbTables.categories, cat);
          }
          await batch.commit();
        },
      ),
    );
    appDatabase.setDatabaseForTesting(rawDb);
    reportsRepo = ReportsRepository(appDatabase);
    transRepo = TransactionRepository(appDatabase);
    budgetRepo = BudgetRepository(appDatabase);
  });

  tearDown(() async {
    await rawDb.close();
  });

  group('ReportsRepository Financial Analysis Tests', () {
    test('Calculates totals, category breakdown shares, and savings rates accurately', () async {
      final start = DateTime(2026, 10, 1);
      final end = DateTime(2026, 10, 31, 23, 59, 59);

      // Income: ₹60,000 (6000000 cents)
      await transRepo.createTransaction(
        FinancialTransaction(
          id: 'tx_inc_1',
          amount: const Money(6000000),
          type: TransactionType.income,
          categoryId: 'cat_salary',
          transactionDate: DateTime(2026, 10, 1),
          createdAt: DateTime(2026, 10, 1),
          updatedAt: DateTime(2026, 10, 1),
        ),
      );

      // Expense 1: ₹10,000 (1000000 cents) on Groceries
      await transRepo.createTransaction(
        FinancialTransaction(
          id: 'tx_exp_1',
          amount: const Money(1000000),
          type: TransactionType.expense,
          categoryId: 'cat_groceries',
          transactionDate: DateTime(2026, 10, 10),
          createdAt: DateTime(2026, 10, 10),
          updatedAt: DateTime(2026, 10, 10),
        ),
      );

      // Expense 2: ₹10,000 (1000000 cents) on Transport
      await transRepo.createTransaction(
        FinancialTransaction(
          id: 'tx_exp_2',
          amount: const Money(1000000),
          type: TransactionType.expense,
          categoryId: 'cat_transport',
          transactionDate: DateTime(2026, 10, 12),
          createdAt: DateTime(2026, 10, 12),
          updatedAt: DateTime(2026, 10, 12),
        ),
      );

      // Set a budget of ₹25,000 for October
      await budgetRepo.saveBudget(
        Budget(
          id: 'bgt_oct_overall',
          categoryId: null,
          amount: const Money(2500000),
          monthYear: '2026-10',
          createdAt: DateTime(2026, 10, 1),
          updatedAt: DateTime(2026, 10, 1),
        ),
      );

      final report = await reportsRepo.getFinancialReport(
        startDate: start,
        endDate: end,
      );

      // 1. Verify totals match raw database operations
      expect(report.totalIncome.cents, 6000000);
      expect(report.totalExpense.cents, 2000000);
      expect(report.netSavings.cents, 4000000); // 60,000 - 20,000 = ₹40,000
      expect(
        report.savingsRate,
        closeTo(66.66, 0.1),
      ); // 40,000 / 60,000 = 66.67%
      expect(report.isEmpty, isFalse);

      // 2. Verify Category Breakdown
      expect(report.categoryBreakdown.length, 2);
      final groc = report.categoryBreakdown.firstWhere(
        (c) => c.categoryId == 'cat_groceries',
      );
      expect(groc.amount.cents, 1000000);
      expect(groc.percentage, 50.0);

      final trans = report.categoryBreakdown.firstWhere(
        (c) => c.categoryId == 'cat_transport',
      );
      expect(trans.amount.cents, 1000000);
      expect(trans.percentage, 50.0);

      // 3. Verify Budget Utilization
      expect(report.budgetUtilizations.isNotEmpty, isTrue);
      final overallUtil = report.budgetUtilizations.first;
      expect(overallUtil.budgetAmount.cents, 2500000);
      expect(overallUtil.spentAmount.cents, 2000000);
      expect(overallUtil.percentage, 80); // 20k of 25k is 80%
      expect(overallUtil.isOverBudget, isFalse);

      // 4. Verify Screen Reader Accessible Summary
      expect(
        report.screenReaderSummary,
        contains('Total income is ₹60,000.00'),
      );
      expect(
        report.screenReaderSummary,
        contains('total expense is ₹20,000.00'),
      );
      expect(
        report.screenReaderSummary,
        contains('All active budgets are within limits.'),
      );
    });

    test(
      'Empty period safely returns zero metrics without division by zero',
      () async {
        final start = DateTime(2025, 1, 1);
        final end = DateTime(2025, 1, 31);

        final report = await reportsRepo.getFinancialReport(
          startDate: start,
          endDate: end,
        );

        expect(report.totalIncome.cents, 0);
        expect(report.totalExpense.cents, 0);
        expect(report.netSavings.cents, 0);
        expect(report.savingsRate, 0.0);
        expect(report.categoryBreakdown.isEmpty, isTrue);
        expect(report.isEmpty, isTrue);
        expect(
          report.screenReaderSummary,
          contains('No financial records found'),
        );
      },
    );
  });
}
