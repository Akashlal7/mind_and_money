import '../../../core/database/app_database.dart';
import '../../../core/database/tables.dart';
import '../../../core/utils/money.dart';
import '../models/savings_contribution.dart';
import '../models/savings_goal.dart';

/// Exception thrown when a savings operation violates domain constraints,
/// such as withdrawing more than the available goal balance.
class InvalidSavingsBalanceException implements Exception {
  final String message;
  const InvalidSavingsBalanceException(this.message);

  @override
  String toString() => 'InvalidSavingsBalanceException: $message';
}

/// Repository responsible for savings goals and contribution/withdrawal records in SQLite.
class SavingsRepository {
  final AppDatabase _database;

  SavingsRepository(this._database);

  /// Retrieves all savings goals ordered newest first.
  Future<List<SavingsGoal>> getSavingsGoals() async {
    final db = await _database.database;
    final rows = await db.query(
      DbTables.savingsGoals,
      orderBy: 'created_at DESC',
    );

    return rows.map((r) => SavingsGoal.fromMap(r)).toList();
  }

  /// Retrieves a single savings goal by its ID.
  Future<SavingsGoal?> getSavingsGoalById(String id) async {
    final db = await _database.database;
    final rows = await db.query(
      DbTables.savingsGoals,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (rows.isEmpty) return null;
    return SavingsGoal.fromMap(rows.first);
  }

  /// Creates a new savings goal with optional initial deposit.
  Future<void> createSavingsGoal(
    SavingsGoal goal, {
    Money? initialDeposit,
    String? initialNote,
  }) async {
    if (!goal.targetAmount.isPositive) {
      throw ArgumentError(
        'Savings goal target amount must be greater than zero.',
      );
    }

    final db = await _database.database;
    final now = DateTime.now();

    await db.transaction((txn) async {
      int initialCents = 0;
      if (initialDeposit != null && initialDeposit.isPositive) {
        initialCents = initialDeposit.cents;
      }

      final goalWithInitial = goal.copyWith(
        currentAmount: Money(initialCents),
        createdAt: now,
        updatedAt: now,
      );

      await txn.insert(DbTables.savingsGoals, goalWithInitial.toMap());

      if (initialCents > 0) {
        final contrib = SavingsContribution(
          id: 'sc_${now.microsecondsSinceEpoch}',
          goalId: goal.id,
          amount: Money(initialCents),
          date: now,
          note: initialNote ?? 'Initial contribution',
          createdAt: now,
        );
        await txn.insert(DbTables.savingsContributions, contrib.toMap());
      }
    });
  }

  /// Updates basic details of an existing goal (name, target, target date).
  Future<void> updateSavingsGoal(SavingsGoal goal) async {
    if (!goal.targetAmount.isPositive) {
      throw ArgumentError('Target amount must be positive.');
    }

    final db = await _database.database;
    final now = DateTime.now();

    await db.update(
      DbTables.savingsGoals,
      {
        'name': goal.name,
        'target_amount_cents': goal.targetAmount.cents,
        'target_date': goal.targetDate?.toIso8601String(),
        'updated_at': now.toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [goal.id],
    );
  }

  /// Deletes a savings goal and its associated contributions.
  Future<void> deleteSavingsGoal(String goalId) async {
    final db = await _database.database;
    await db.transaction((txn) async {
      await txn.delete(
        DbTables.savingsContributions,
        where: 'goal_id = ?',
        whereArgs: [goalId],
      );
      await txn.delete(
        DbTables.savingsGoals,
        where: 'id = ?',
        whereArgs: [goalId],
      );
    });
  }

  /// Retrieves contribution and withdrawal history for a specific goal.
  Future<List<SavingsContribution>> getContributions(String goalId) async {
    final db = await _database.database;
    final rows = await db.query(
      DbTables.savingsContributions,
      where: 'goal_id = ?',
      whereArgs: [goalId],
      orderBy: 'date DESC, created_at DESC',
    );

    return rows.map((r) => SavingsContribution.fromMap(r)).toList();
  }

  /// Adds a savings contribution (deposit) to a goal.
  ///
  /// Note: Saving money is a balance transfer/allocation, not an expense transaction.
  Future<void> addContribution({
    required String goalId,
    required Money amount,
    required DateTime date,
    String? note,
  }) async {
    if (!amount.isPositive) {
      throw ArgumentError('Contribution amount must be greater than zero.');
    }

    final db = await _database.database;
    final now = DateTime.now();

    await db.transaction((txn) async {
      final goalRows = await txn.query(
        DbTables.savingsGoals,
        where: 'id = ?',
        whereArgs: [goalId],
      );

      if (goalRows.isEmpty) {
        throw StateError('Savings goal not found: $goalId');
      }

      final currentCents =
          (goalRows.first['current_amount_cents'] as int? ?? 0);
      final newCents = currentCents + amount.cents;

      // 1. Record contribution entry
      final contrib = SavingsContribution(
        id: 'sc_${now.microsecondsSinceEpoch}',
        goalId: goalId,
        amount: amount,
        date: date,
        note: note,
        createdAt: now,
      );

      await txn.insert(DbTables.savingsContributions, contrib.toMap());

      // 2. Update goal's current saved balance
      await txn.update(
        DbTables.savingsGoals,
        {'current_amount_cents': newCents, 'updated_at': now.toIso8601String()},
        where: 'id = ?',
        whereArgs: [goalId],
      );
    });
  }

  /// Records a withdrawal from a goal's saved balance.
  ///
  /// Throws [InvalidSavingsBalanceException] if the withdrawal amount exceeds
  /// the current saved balance of the goal.
  Future<void> recordWithdrawal({
    required String goalId,
    required Money amount,
    required DateTime date,
    String? note,
  }) async {
    if (!amount.isPositive) {
      throw ArgumentError('Withdrawal amount must be greater than zero.');
    }

    final db = await _database.database;
    final now = DateTime.now();

    await db.transaction((txn) async {
      final goalRows = await txn.query(
        DbTables.savingsGoals,
        where: 'id = ?',
        whereArgs: [goalId],
      );

      if (goalRows.isEmpty) {
        throw StateError('Savings goal not found: $goalId');
      }

      final currentCents =
          (goalRows.first['current_amount_cents'] as int? ?? 0);

      if (amount.cents > currentCents) {
        throw InvalidSavingsBalanceException(
          'Withdrawal of ${amount.format()} exceeds current balance of ${Money(currentCents).format()}.',
        );
      }

      final newCents = currentCents - amount.cents;

      // 1. Record withdrawal entry (negative amount)
      final withdrawal = SavingsContribution(
        id: 'sc_${now.microsecondsSinceEpoch}',
        goalId: goalId,
        amount: -amount,
        date: date,
        note: note,
        createdAt: now,
      );

      await txn.insert(DbTables.savingsContributions, withdrawal.toMap());

      // 2. Update goal's current saved balance
      await txn.update(
        DbTables.savingsGoals,
        {'current_amount_cents': newCents, 'updated_at': now.toIso8601String()},
        where: 'id = ?',
        whereArgs: [goalId],
      );
    });
  }
}
