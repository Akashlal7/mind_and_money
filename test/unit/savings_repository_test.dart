import 'package:flutter_test/flutter_test.dart';
import 'package:mind_and_money/core/database/app_database.dart';
import 'package:mind_and_money/core/database/tables.dart';
import 'package:mind_and_money/core/utils/money.dart';
import 'package:mind_and_money/features/finance/models/savings_goal.dart';
import 'package:mind_and_money/features/finance/repositories/savings_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late AppDatabase appDatabase;
  late Database rawDb;
  late SavingsRepository savingsRepo;

  setUp(() async {
    appDatabase = AppDatabase();
    rawDb = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 2,
        onConfigure: (db) async =>
            await db.execute('PRAGMA foreign_keys = ON;'),
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
          await batch.commit();
        },
      ),
    );
    appDatabase.setDatabaseForTesting(rawDb);
    savingsRepo = SavingsRepository(appDatabase);
  });

  tearDown(() async {
    await rawDb.close();
  });

  group('SavingsRepository Goal & Contribution Tests', () {
    test(
      'Creates a goal with initial deposit and validates target calculation',
      () async {
        final goal = SavingsGoal(
          id: 'goal_emergency',
          name: 'Emergency Fund',
          targetAmount: const Money(1000000), // ₹10,000
          currentAmount: const Money.zero(),
          targetDate: DateTime(2027, 1, 1),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await savingsRepo.createSavingsGoal(
          goal,
          initialDeposit: const Money(200000), // ₹2,000 initial
          initialNote: 'Starting fund',
        );

        final retrieved = await savingsRepo.getSavingsGoalById(
          'goal_emergency',
        );
        expect(retrieved, isNotNull);
        expect(retrieved!.currentAmount.cents, 200000);
        expect(retrieved.remainingAmount.cents, 800000);
        expect(retrieved.percentage, 20);
        expect(retrieved.isCompleted, isFalse);

        final history = await savingsRepo.getContributions('goal_emergency');
        expect(history.length, 1);
        expect(history.first.amount.cents, 200000);
        expect(history.first.isContribution, isTrue);
        expect(history.first.isWithdrawal, isFalse);
      },
    );

    test(
      'Adding contribution increments balance and reaches completion status',
      () async {
        final goal = SavingsGoal(
          id: 'goal_trip',
          name: 'Goa Trip',
          targetAmount: const Money(500000), // ₹5,000
          currentAmount: const Money.zero(),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await savingsRepo.createSavingsGoal(goal);

        // Add ₹3,000 contribution
        await savingsRepo.addContribution(
          goalId: 'goal_trip',
          amount: const Money(300000),
          date: DateTime.now(),
          note: 'Saved from freelance work',
        );

        var updated = await savingsRepo.getSavingsGoalById('goal_trip');
        expect(updated!.currentAmount.cents, 300000);
        expect(updated.percentage, 60);
        expect(updated.isCompleted, isFalse);

        // Add another ₹2,500 contribution (total ₹5,500, meets/exceeds target)
        await savingsRepo.addContribution(
          goalId: 'goal_trip',
          amount: const Money(250000),
          date: DateTime.now(),
          note: 'Final milestone',
        );

        updated = await savingsRepo.getSavingsGoalById('goal_trip');
        expect(updated!.currentAmount.cents, 550000);
        expect(updated.percentage, 100);
        expect(updated.remainingAmount.cents, 0); // 0 remaining when exceeded
        expect(updated.isCompleted, isTrue);

        final history = await savingsRepo.getContributions('goal_trip');
        expect(history.length, 2);
      },
    );

    test('Recording withdrawal deducts balance properly', () async {
      final goal = SavingsGoal(
        id: 'goal_laptop',
        name: 'New Laptop',
        targetAmount: const Money(8000000), // ₹80,000
        currentAmount: const Money.zero(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await savingsRepo.createSavingsGoal(
        goal,
        initialDeposit: const Money(3000000), // ₹30,000
      );

      // Withdraw ₹10,000
      await savingsRepo.recordWithdrawal(
        goalId: 'goal_laptop',
        amount: const Money(1000000),
        date: DateTime.now(),
        note: 'Emergency repair deduction',
      );

      final updated = await savingsRepo.getSavingsGoalById('goal_laptop');
      expect(
        updated!.currentAmount.cents,
        2000000,
      ); // 30,000 - 10,000 = ₹20,000
      expect(updated.remainingAmount.cents, 6000000);

      final history = await savingsRepo.getContributions('goal_laptop');
      expect(history.length, 2);
      expect(history.first.amount.cents, -1000000); // Newest first
      expect(history.first.isWithdrawal, isTrue);
      expect(history.first.isContribution, isFalse);
    });

    test('Withdrawal exceeding current balance throws InvalidSavingsBalanceException', () async {
      final goal = SavingsGoal(
        id: 'goal_small',
        name: 'Small Goal',
        targetAmount: const Money(200000), // ₹2,000
        currentAmount: const Money.zero(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await savingsRepo.createSavingsGoal(
        goal,
        initialDeposit: const Money(50000), // ₹500
      );

      // Attempt to withdraw ₹600 (exceeds balance of ₹500)
      expect(
        () => savingsRepo.recordWithdrawal(
          goalId: 'goal_small',
          amount: const Money(60000),
          date: DateTime.now(),
        ),
        throwsA(isA<InvalidSavingsBalanceException>()),
      );

      // Balance must remain unchanged at ₹500
      final check = await savingsRepo.getSavingsGoalById('goal_small');
      expect(check!.currentAmount.cents, 50000);
    });

    test('Zero or negative amounts throw ArgumentError', () async {
      final goal = SavingsGoal(
        id: 'goal_arg',
        name: 'Argument Check',
        targetAmount: const Money(100000),
        currentAmount: const Money.zero(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await savingsRepo.createSavingsGoal(goal);

      // Zero deposit
      expect(
        () => savingsRepo.addContribution(
          goalId: 'goal_arg',
          amount: const Money.zero(),
          date: DateTime.now(),
        ),
        throwsArgumentError,
      );

      // Negative deposit
      expect(
        () => savingsRepo.addContribution(
          goalId: 'goal_arg',
          amount: const Money(-5000),
          date: DateTime.now(),
        ),
        throwsArgumentError,
      );

      // Zero withdrawal
      expect(
        () => savingsRepo.recordWithdrawal(
          goalId: 'goal_arg',
          amount: const Money.zero(),
          date: DateTime.now(),
        ),
        throwsArgumentError,
      );
    });

    test('Deleting goal cascades and removes contribution history', () async {
      final goal = SavingsGoal(
        id: 'goal_delete',
        name: 'Temporary Goal',
        targetAmount: const Money(500000),
        currentAmount: const Money.zero(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await savingsRepo.createSavingsGoal(
        goal,
        initialDeposit: const Money(100000),
      );

      expect((await savingsRepo.getContributions('goal_delete')).length, 1);

      await savingsRepo.deleteSavingsGoal('goal_delete');

      expect(await savingsRepo.getSavingsGoalById('goal_delete'), isNull);
      expect(
        (await savingsRepo.getContributions('goal_delete')).isEmpty,
        isTrue,
      );
    });
  });
}
