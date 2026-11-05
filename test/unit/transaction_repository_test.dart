import 'package:flutter_test/flutter_test.dart';
import 'package:mind_and_money/core/database/app_database.dart';
import 'package:mind_and_money/core/database/tables.dart';
import 'package:mind_and_money/core/utils/money.dart';
import 'package:mind_and_money/features/finance/models/category.dart';
import 'package:mind_and_money/features/finance/models/transaction.dart';
import 'package:mind_and_money/features/finance/repositories/transaction_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('TransactionRepository SQLite Tests', () {
    late AppDatabase appDatabase;
    late Database rawDb;
    late TransactionRepository repository;

    setUp(() async {
      appDatabase = AppDatabase();
      rawDb = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 1,
          onConfigure: (db) async {
            await db.execute('PRAGMA foreign_keys = ON;');
          },
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
      repository = TransactionRepository(appDatabase);
    });

    tearDown(() async {
      await rawDb.close();
    });

    test(
      'creates and retrieves a transaction with joined category info',
      () async {
        final tx = FinancialTransaction(
          id: 'tx_coffee_1',
          amount: const Money(45000), // ₹450.00
          type: TransactionType.expense,
          categoryId: 'cat_food',
          transactionDate: DateTime(2026, 10, 26, 10, 30),
          description: 'Morning Cappuccino',
          paymentMethod: 'upi',
          note: 'At Artisan Cafe',
          createdAt: DateTime(2026, 10, 26, 10, 30),
          updatedAt: DateTime(2026, 10, 26, 10, 30),
        );

        await repository.createTransaction(tx);

        final fetched = await repository.getTransactionById('tx_coffee_1');
        expect(fetched, isNotNull);
        expect(fetched!.amount.cents, 45000);
        expect(fetched.description, 'Morning Cappuccino');
        expect(fetched.categoryName, 'Food & Dining');
        expect(fetched.type, TransactionType.expense);
        expect(fetched.paymentMethod, 'upi');
      },
    );

    test('updates an existing transaction accurately', () async {
      final tx = FinancialTransaction(
        id: 'tx_update_test',
        amount: const Money(100000), // ₹1,000.00
        type: TransactionType.expense,
        categoryId: 'cat_shopping',
        transactionDate: DateTime(2026, 10, 26, 12, 0),
        description: 'Books',
        createdAt: DateTime(2026, 10, 26, 12, 0),
        updatedAt: DateTime(2026, 10, 26, 12, 0),
      );
      await repository.createTransaction(tx);

      // Update amount and description
      final updated = FinancialTransaction(
        id: 'tx_update_test',
        amount: const Money(125000), // ₹1,250.00
        type: TransactionType.expense,
        categoryId: 'cat_shopping',
        transactionDate: DateTime(2026, 10, 26, 12, 0),
        description: 'Books & Stationery',
        createdAt: tx.createdAt,
        updatedAt: DateTime.now(),
      );
      await repository.updateTransaction(updated);

      final fetched = await repository.getTransactionById('tx_update_test');
      expect(fetched!.amount.cents, 125000);
      expect(fetched.description, 'Books & Stationery');
    });

    test('deletes a transaction from database', () async {
      final tx = FinancialTransaction(
        id: 'tx_delete_test',
        amount: const Money(5000),
        type: TransactionType.expense,
        categoryId: 'cat_transport',
        transactionDate: DateTime(2026, 10, 26),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await repository.createTransaction(tx);

      var list = await repository.getTransactions();
      expect(list.length, 1);

      await repository.deleteTransaction('tx_delete_test');
      list = await repository.getTransactions();
      expect(list, isEmpty);
    });

    test('filters transactions by type, category, and date range', () async {
      // 1. October expense
      await repository.createTransaction(
        FinancialTransaction(
          id: 't1',
          amount: const Money(20000),
          type: TransactionType.expense,
          categoryId: 'cat_food',
          transactionDate: DateTime(2026, 10, 10),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      // 2. October income
      await repository.createTransaction(
        FinancialTransaction(
          id: 't2',
          amount: const Money(800000),
          type: TransactionType.income,
          categoryId: 'cat_salary',
          transactionDate: DateTime(2026, 10, 1),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      // 3. September expense
      await repository.createTransaction(
        FinancialTransaction(
          id: 't3',
          amount: const Money(30000),
          type: TransactionType.expense,
          categoryId: 'cat_groceries',
          transactionDate: DateTime(2026, 9, 20),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      // Filter by type: income only
      final incomeList = await repository.getTransactions(
        type: TransactionType.income,
      );
      expect(incomeList.length, 1);
      expect(incomeList.first.id, 't2');

      // Filter by category: food only
      final foodList = await repository.getTransactions(categoryId: 'cat_food');
      expect(foodList.length, 1);
      expect(foodList.first.id, 't1');

      // Filter by date range: October only
      final octList = await repository.getTransactions(
        startDate: DateTime(2026, 10, 1),
        endDate: DateTime(2026, 10, 31, 23, 59, 59),
      );
      expect(octList.length, 2);
    });

    test('searches transactions by description or note', () async {
      await repository.createTransaction(
        FinancialTransaction(
          id: 'tx_s1',
          amount: const Money(15000),
          type: TransactionType.expense,
          categoryId: 'cat_groceries',
          description: 'Supermarket weekly fruits',
          transactionDate: DateTime.now(),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      await repository.createTransaction(
        FinancialTransaction(
          id: 'tx_s2',
          amount: const Money(5000),
          type: TransactionType.expense,
          categoryId: 'cat_transport',
          description: 'Metro card reload',
          note: 'Blue line commute',
          transactionDate: DateTime.now(),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      final fruitsResult = await repository.getTransactions(
        searchQuery: 'fruits',
      );
      expect(fruitsResult.length, 1);
      expect(fruitsResult.first.id, 'tx_s1');

      final commuteResult = await repository.getTransactions(
        searchQuery: 'commute',
      );
      expect(commuteResult.length, 1);
      expect(commuteResult.first.id, 'tx_s2');
    });

    test('sorts transactions by date and amount correctly', () async {
      await repository.createTransaction(
        FinancialTransaction(
          id: 'tx_small',
          amount: const Money(1000),
          type: TransactionType.expense,
          categoryId: 'cat_food',
          transactionDate: DateTime(2026, 10, 1),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      await repository.createTransaction(
        FinancialTransaction(
          id: 'tx_large',
          amount: const Money(90000),
          type: TransactionType.expense,
          categoryId: 'cat_food',
          transactionDate: DateTime(2026, 10, 20),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      // Sort amount descending
      final amountDesc = await repository.getTransactions(
        sort: TransactionSortOrder.amountDesc,
      );
      expect(amountDesc.first.id, 'tx_large');
      expect(amountDesc.last.id, 'tx_small');

      // Sort date ascending
      final dateAsc = await repository.getTransactions(
        sort: TransactionSortOrder.dateAsc,
      );
      expect(dateAsc.first.id, 'tx_small');
      expect(dateAsc.last.id, 'tx_large');
    });

    test('calculates accurate period totals', () async {
      await repository.createTransaction(
        FinancialTransaction(
          id: 'i1',
          amount: const Money(500000), // +5000
          type: TransactionType.income,
          categoryId: 'cat_salary',
          transactionDate: DateTime(2026, 10, 15),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      await repository.createTransaction(
        FinancialTransaction(
          id: 'e1',
          amount: const Money(120000), // -1200
          type: TransactionType.expense,
          categoryId: 'cat_food',
          transactionDate: DateTime(2026, 10, 16),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      final totals = await repository.getPeriodTotals(
        startDate: DateTime(2026, 10, 1),
        endDate: DateTime(2026, 10, 31),
      );

      expect(totals.totalIncome.cents, 500000);
      expect(totals.totalExpense.cents, 120000);
      expect(totals.netBalance.cents, 380000);
      expect(totals.transactionCount, 2);
    });

    test('safe category deletion prevents deleting in-use category', () async {
      const customCatId = 'cat_custom_gym';
      await repository.createCategory(
        Category(
          id: customCatId,
          name: 'Gym Membership',
          icon: 'fitness_center',
          color: 0xFF4CAF50,
          type: 'expense',
          createdAt: DateTime.now(),
        ),
      );

      // Delete unused category should succeed
      var deleted = await repository.deleteCategory(customCatId);
      expect(deleted, isTrue);

      // Recreate and add a transaction using it
      await repository.createCategory(
        Category(
          id: customCatId,
          name: 'Gym Membership',
          icon: 'fitness_center',
          color: 0xFF4CAF50,
          type: 'expense',
          createdAt: DateTime.now(),
        ),
      );

      await repository.createTransaction(
        FinancialTransaction(
          id: 'tx_gym',
          amount: const Money(200000),
          type: TransactionType.expense,
          categoryId: customCatId,
          transactionDate: DateTime.now(),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      // Now deleting category must be blocked
      deleted = await repository.deleteCategory(customCatId);
      expect(deleted, isFalse);
    });
  });
}
