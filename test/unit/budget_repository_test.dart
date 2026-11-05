import 'package:flutter_test/flutter_test.dart';
import 'package:mind_and_money/core/database/app_database.dart';
import 'package:mind_and_money/core/database/tables.dart';
import 'package:mind_and_money/core/utils/money.dart';
import 'package:mind_and_money/features/finance/models/budget.dart';
import 'package:mind_and_money/features/finance/models/transaction.dart';
import 'package:mind_and_money/features/finance/repositories/budget_repository.dart';
import 'package:mind_and_money/features/finance/repositories/transaction_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late AppDatabase appDatabase;
  late Database rawDb;
  late BudgetRepository budgetRepo;
  late TransactionRepository transRepo;

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
    budgetRepo = BudgetRepository(appDatabase);
    transRepo = TransactionRepository(appDatabase);
  });

  tearDown(() async {
    await rawDb.close();
  });

  group('BudgetRepository Monthly & Category Spending Tests', () {
    test(
      'Calculates overall and category-specific budget spending accurately',
      () async {
        const monthStr = '2026-10';

        // 1. Create an overall budget of ₹20,000 (2000000 cents)
        await budgetRepo.saveBudget(
          Budget(
            id: 'bgt_overall',
            categoryId: null,
            amount: const Money(2000000),
            monthYear: monthStr,
            createdAt: DateTime(2026, 10, 1),
            updatedAt: DateTime(2026, 10, 1),
          ),
        );

        // 2. Create a Food category budget of ₹5,000 (500000 cents)
        await budgetRepo.saveBudget(
          Budget(
            id: 'bgt_food',
            categoryId: 'cat_food',
            amount: const Money(500000),
            monthYear: monthStr,
            createdAt: DateTime(2026, 10, 1),
            updatedAt: DateTime(2026, 10, 1),
          ),
        );

        // 3. Add expense transactions in October 2026
        await transRepo.createTransaction(
          FinancialTransaction(
            id: 'tx_1',
            amount: const Money(200000), // ₹2,000 on Food
            type: TransactionType.expense,
            categoryId: 'cat_food',
            transactionDate: DateTime(2026, 10, 15, 12, 0),
            createdAt: DateTime(2026, 10, 15),
            updatedAt: DateTime(2026, 10, 15),
          ),
        );

        await transRepo.createTransaction(
          FinancialTransaction(
            id: 'tx_2',
            amount: const Money(300000), // ₹3,000 on Transport
            type: TransactionType.expense,
            categoryId: 'cat_transport',
            transactionDate: DateTime(2026, 10, 18, 14, 0),
            createdAt: DateTime(2026, 10, 18),
            updatedAt: DateTime(2026, 10, 18),
          ),
        );

        // 4. Add an income transaction of ₹50,000 (must NOT be counted toward spending)
        await transRepo.createTransaction(
          FinancialTransaction(
            id: 'tx_income',
            amount: const Money(5000000),
            type: TransactionType.income,
            categoryId: 'cat_salary',
            transactionDate: DateTime(2026, 10, 5, 10, 0),
            createdAt: DateTime(2026, 10, 5),
            updatedAt: DateTime(2026, 10, 5),
          ),
        );

        final budgets = await budgetRepo.getBudgetsForMonth(monthStr);
        expect(budgets.length, 2);

        // Verify Overall Budget
        final overall = budgets.firstWhere((b) => b.budget.isOverall);
        expect(overall.budget.amount.cents, 2000000);
        expect(overall.spent.cents, 500000); // 2000 + 3000 = ₹5,000
        expect(overall.remaining.cents, 1500000); // ₹15,000 left
        expect(overall.percentageUsed, 25);
        expect(overall.isOverBudget, isFalse);
        expect(overall.isNearLimit, isFalse);

        // Verify Food Category Budget
        final food = budgets.firstWhere(
          (b) => b.budget.categoryId == 'cat_food',
        );
        expect(food.budget.amount.cents, 500000);
        expect(food.spent.cents, 200000); // Only Food expense counted
        expect(food.remaining.cents, 300000);
        expect(food.percentageUsed, 40);
      },
    );

    test(
      'Transactions crossing month boundaries are strictly filtered by month',
      () async {
        const monthStr = '2026-10';

        await budgetRepo.saveBudget(
          Budget(
            id: 'bgt_overall',
            categoryId: null,
            amount: const Money(1000000), // ₹10,000
            monthYear: monthStr,
            createdAt: DateTime(2026, 10, 1),
            updatedAt: DateTime(2026, 10, 1),
          ),
        );

        // September 30 (previous month, 23:59:59)
        await transRepo.createTransaction(
          FinancialTransaction(
            id: 'tx_sep',
            amount: const Money(400000),
            type: TransactionType.expense,
            categoryId: 'cat_food',
            transactionDate: DateTime(2026, 9, 30, 23, 59, 59),
            createdAt: DateTime(2026, 9, 30),
            updatedAt: DateTime(2026, 9, 30),
          ),
        );

        // October 1 (current month, 00:00:00)
        await transRepo.createTransaction(
          FinancialTransaction(
            id: 'tx_oct',
            amount: const Money(250000),
            type: TransactionType.expense,
            categoryId: 'cat_food',
            transactionDate: DateTime(2026, 10, 1, 0, 0, 0),
            createdAt: DateTime(2026, 10, 1),
            updatedAt: DateTime(2026, 10, 1),
          ),
        );

        // November 1 (next month, 00:00:00)
        await transRepo.createTransaction(
          FinancialTransaction(
            id: 'tx_nov',
            amount: const Money(300000),
            type: TransactionType.expense,
            categoryId: 'cat_food',
            transactionDate: DateTime(2026, 11, 1, 0, 0, 0),
            createdAt: DateTime(2026, 11, 1),
            updatedAt: DateTime(2026, 11, 1),
          ),
        );

        final overall = await budgetRepo.getOverallBudget(monthStr);
        expect(overall, isNotNull);
        // Only the October 1 transaction should be counted
        expect(overall!.spent.cents, 250000);
        expect(overall.remaining.cents, 750000);
      },
    );

    test('Adding, editing, and deleting transactions recalculates budget spending immediately', () async {
      const monthStr = '2026-10';

      await budgetRepo.saveBudget(
        Budget(
          id: 'bgt_food',
          categoryId: 'cat_food',
          amount: const Money(500000), // ₹5,000
          monthYear: monthStr,
          createdAt: DateTime(2026, 10, 1),
          updatedAt: DateTime(2026, 10, 1),
        ),
      );

      // Initial transaction: ₹2,000
      final tx = FinancialTransaction(
        id: 'tx_dynamic',
        amount: const Money(200000),
        type: TransactionType.expense,
        categoryId: 'cat_food',
        transactionDate: DateTime(2026, 10, 10),
        createdAt: DateTime(2026, 10, 10),
        updatedAt: DateTime(2026, 10, 10),
      );
      await transRepo.createTransaction(tx);

      var budgets = await budgetRepo.getBudgetsForMonth(monthStr);
      expect(budgets.first.spent.cents, 200000);

      // Edit transaction amount to ₹4,500 (approaching limit > 80%)
      await transRepo.updateTransaction(
        tx.copyWith(amount: const Money(450000)),
      );

      budgets = await budgetRepo.getBudgetsForMonth(monthStr);
      expect(budgets.first.spent.cents, 450000);
      expect(budgets.first.isNearLimit, isTrue);
      expect(budgets.first.isOverBudget, isFalse);

      // Delete transaction
      await transRepo.deleteTransaction(tx.id);

      budgets = await budgetRepo.getBudgetsForMonth(monthStr);
      expect(budgets.first.spent.cents, 0);
      expect(budgets.first.remaining.cents, 500000);
    });

    test(
      'Warning states trigger accurately on near-limit and over-budget',
      () async {
        const monthStr = '2026-10';

        final budget = Budget(
          id: 'bgt_test',
          categoryId: 'cat_food',
          amount: const Money(100000), // ₹1,000
          monthYear: monthStr,
          createdAt: DateTime(2026, 10, 1),
          updatedAt: DateTime(2026, 10, 1),
        );

        // 75% used: Normal
        final normalStatus = BudgetStatus(
          budget: budget,
          spent: const Money(75000),
        );
        expect(normalStatus.isNearLimit, isFalse);
        expect(normalStatus.isOverBudget, isFalse);

        // 85% used: Near limit warning
        final warningStatus = BudgetStatus(
          budget: budget,
          spent: const Money(85000),
        );
        expect(warningStatus.isNearLimit, isTrue);
        expect(warningStatus.isOverBudget, isFalse);

        // 110% used: Over budget warning
        final overStatus = BudgetStatus(
          budget: budget,
          spent: const Money(110000),
        );
        expect(overStatus.isOverBudget, isTrue);
        expect(overStatus.isNearLimit, isFalse);
        expect(overStatus.remaining.isNegative, isTrue);
      },
    );

    test('Copying budgets from previous month creates or updates destination month records', () async {
      // Set up September budgets
      await budgetRepo.saveBudget(
        Budget(
          id: 'bgt_sep_overall',
          categoryId: null,
          amount: const Money(2500000),
          monthYear: '2026-09',
          createdAt: DateTime(2026, 9, 1),
          updatedAt: DateTime(2026, 9, 1),
        ),
      );
      await budgetRepo.saveBudget(
        Budget(
          id: 'bgt_sep_food',
          categoryId: 'cat_food',
          amount: const Money(600000),
          monthYear: '2026-09',
          createdAt: DateTime(2026, 9, 1),
          updatedAt: DateTime(2026, 9, 1),
        ),
      );

      // October initially has zero budgets
      var octBudgets = await budgetRepo.getBudgetsForMonth('2026-10');
      expect(octBudgets.isEmpty, isTrue);

      // Copy from September into October
      final copied = await budgetRepo.copyBudgets(
        fromMonthYear: '2026-09',
        toMonthYear: '2026-10',
      );
      expect(copied, 2);

      octBudgets = await budgetRepo.getBudgetsForMonth('2026-10');
      expect(octBudgets.length, 2);
      expect(
        octBudgets.any(
          (b) => b.budget.isOverall && b.budget.amount.cents == 2500000,
        ),
        isTrue,
      );
      expect(
        octBudgets.any(
          (b) =>
              b.budget.categoryId == 'cat_food' &&
              b.budget.amount.cents == 600000,
        ),
        isTrue,
      );
    });
  });
}
