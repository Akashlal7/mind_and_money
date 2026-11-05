import 'package:flutter_test/flutter_test.dart';
import 'package:mind_and_money/core/database/app_database.dart';
import 'package:mind_and_money/core/database/tables.dart';
import 'package:mind_and_money/features/home/data/home_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('SQLite Database & Schema Tests', () {
    late AppDatabase appDatabase;
    late Database rawDb;

    setUp(() async {
      appDatabase = AppDatabase();
      // Open fresh in-memory database for testing
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
    });

    tearDown(() async {
      await rawDb.close();
    });

    test('seeds default categories correctly', () async {
      final categories = await rawDb.query(DbTables.categories);
      expect(categories.length, 14);

      final foodCat = categories.firstWhere((c) => c['id'] == 'cat_food');
      expect(foodCat['name'], 'Food & Dining');
      expect(foodCat['type'], 'expense');

      final salaryCat = categories.firstWhere((c) => c['id'] == 'cat_salary');
      expect(salaryCat['name'], 'Salary');
      expect(salaryCat['type'], 'income');
    });

    test('enforces foreign key constraints on transactions', () async {
      // Inserting with invalid category_id should throw DatabaseException
      expect(
        () async => await rawDb.insert(DbTables.transactions, {
          'id': 'tx_1',
          'amount_cents': 5000,
          'type': 'expense',
          'category_id': 'invalid_nonexistent_cat',
          'transaction_date': DateTime.now().toIso8601String(),
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        }),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('inserts transaction and calculates HomeRepository metrics', () async {
      final repo = HomeRepository(appDatabase);

      // Verify empty dashboard returns zero totals
      final initialSummary = await repo.getHomeSummary();
      expect(initialSummary.monthlyIncome.cents, 0);
      expect(initialSummary.monthlyExpense.cents, 0);
      expect(initialSummary.netBalance.cents, 0);
      expect(initialSummary.todayMood, isNull);

      // Insert income
      await rawDb.insert(DbTables.transactions, {
        'id': 'tx_salary',
        'amount_cents': 7500000, // ₹75,000.00
        'type': 'income',
        'category_id': 'cat_salary',
        'transaction_date': DateTime.now().toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      // Insert expense
      await rawDb.insert(DbTables.transactions, {
        'id': 'tx_groceries',
        'amount_cents': 350000, // ₹3,500.00
        'type': 'expense',
        'category_id': 'cat_groceries',
        'transaction_date': DateTime.now().toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      final updatedSummary = await repo.getHomeSummary();
      expect(updatedSummary.monthlyIncome.cents, 7500000);
      expect(updatedSummary.monthlyExpense.cents, 350000);
      expect(updatedSummary.netBalance.cents, 7150000);
      expect(updatedSummary.hasTransactions, isTrue);
    });

    test('records quick mood and reflects in HomeRepository', () async {
      final repo = HomeRepository(appDatabase);

      await repo.recordQuickMood(4, 'Feeling calm and productive');
      final summary = await repo.getHomeSummary();

      expect(summary.todayMood, isNotNull);
      expect(summary.todayMood!.rating, 4);
      expect(summary.todayMood!.moodLabel, 'Good');
      expect(summary.todayMood!.note, 'Feeling calm and productive');
    });

    test('toggles habit completion without duplicate records', () async {
      final repo = HomeRepository(appDatabase);
      const habitId = 'habit_breathing';

      // Insert a habit
      await rawDb.insert(DbTables.habits, {
        'id': habitId,
        'name': 'Take a mindful breath',
        'schedule_type': 'daily',
        'created_at': DateTime.now().toIso8601String(),
      });

      final todayStr = DateTime.now().toIso8601String().substring(0, 10);

      // Toggle ON
      await repo.toggleHabitCompletion(habitId, todayStr);
      var summary = await repo.getHomeSummary();
      expect(summary.completedHabitsCount, 1);
      expect(summary.todayHabits.first.isCompletedToday, isTrue);

      // Toggle OFF
      await repo.toggleHabitCompletion(habitId, todayStr);
      summary = await repo.getHomeSummary();
      expect(summary.completedHabitsCount, 0);
      expect(summary.todayHabits.first.isCompletedToday, isFalse);
    });
  });
}
