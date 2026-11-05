import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/tables.dart';
import '../models/habit.dart';
import '../models/habit_completion.dart';
import '../models/habit_stats.dart';
import '../services/habit_streak_service.dart';

/// Repository for persistent habit management and completion tracking in SQLite.
class HabitRepository {
  final AppDatabase _database;
  final HabitStreakService _streakService;

  HabitRepository(
    this._database, [
    this._streakService = const HabitStreakService(),
  ]);

  /// Creates a new habit definition
  Future<void> createHabit(Habit habit) async {
    final db = await _database.database;
    await db.insert(
      DbTables.habits,
      habit.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Updates an existing habit definition
  Future<void> updateHabit(Habit habit) async {
    final db = await _database.database;
    final updatedHabit = habit.copyWith(updatedAt: DateTime.now());
    await db.update(
      DbTables.habits,
      updatedHabit.toMap(),
      where: 'id = ?',
      whereArgs: [habit.id],
    );
  }

  /// Archives or restores a habit without modifying historical completion records
  Future<void> archiveHabit(String id, bool archive) async {
    final db = await _database.database;
    await db.update(
      DbTables.habits,
      {
        'is_archived': archive ? 1 : 0,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Permanently deletes a habit and its historical completion records
  Future<void> deleteHabit(String id) async {
    final db = await _database.database;
    await db.transaction((txn) async {
      await txn.delete(
        DbTables.habitCompletions,
        where: 'habit_id = ?',
        whereArgs: [id],
      );
      await txn.delete(DbTables.habits, where: 'id = ?', whereArgs: [id]);
    });
  }

  /// Fetches a single habit by ID
  Future<Habit?> getHabitById(String id, {String? targetDateStr}) async {
    final db = await _database.database;
    final results = await db.query(
      DbTables.habits,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (results.isEmpty) return null;

    final dateKey =
        targetDateStr ?? HabitStreakService.normalizeDate(DateTime.now());
    final completionResults = await db.query(
      DbTables.habitCompletions,
      where: 'habit_id = ? AND completion_date = ?',
      whereArgs: [id, dateKey],
      limit: 1,
    );

    return Habit.fromMap(
      results.first,
      isCompletedToday: completionResults.isNotEmpty,
    );
  }

  /// Fetches all active (or all including archived) habits with completion state for [targetDate]
  Future<List<Habit>> getHabits({
    bool includeArchived = false,
    DateTime? targetDate,
  }) async {
    final db = await _database.database;
    final date = targetDate ?? DateTime.now();
    final dateKey = HabitStreakService.normalizeDate(date);

    final whereClause = includeArchived ? null : 'is_archived = 0';
    final rows = await db.query(
      DbTables.habits,
      where: whereClause,
      orderBy: 'created_at ASC',
    );

    final completionRows = await db.query(
      DbTables.habitCompletions,
      where: 'completion_date = ?',
      whereArgs: [dateKey],
    );
    final completedHabitIds = completionRows
        .map((r) => r['habit_id'] as String)
        .toSet();

    return rows.map((r) {
      final id = r['id'] as String;
      return Habit.fromMap(r, isCompletedToday: completedHabitIds.contains(id));
    }).toList();
  }

  /// Returns only active habits that are scheduled for the given calendar date
  Future<List<Habit>> getScheduledHabitsForDate(DateTime date) async {
    final allActive = await getHabits(includeArchived: false, targetDate: date);
    return allActive.where((h) => h.isScheduledForDate(date)).toList();
  }

  /// Marks a habit as completed for a given normalized calendar date (YYYY-MM-DD)
  Future<void> completeHabit(String habitId, String dateStr) async {
    final db = await _database.database;
    final now = DateTime.now();
    await db.insert(DbTables.habitCompletions, {
      'id': 'comp_${now.microsecondsSinceEpoch}_$habitId',
      'habit_id': habitId,
      'completion_date': dateStr,
      'completed_at': now.toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  /// Removes a completion record for a specific habit and date without deleting other history
  Future<void> undoCompletion(String habitId, String dateStr) async {
    final db = await _database.database;
    await db.delete(
      DbTables.habitCompletions,
      where: 'habit_id = ? AND completion_date = ?',
      whereArgs: [habitId, dateStr],
    );
  }

  /// Toggles completion status for a habit on a normalized date. Returns the new completed state.
  Future<bool> toggleCompletion(String habitId, String dateStr) async {
    final db = await _database.database;
    final existing = await db.query(
      DbTables.habitCompletions,
      where: 'habit_id = ? AND completion_date = ?',
      whereArgs: [habitId, dateStr],
      limit: 1,
    );

    if (existing.isNotEmpty) {
      await undoCompletion(habitId, dateStr);
      return false;
    } else {
      await completeHabit(habitId, dateStr);
      return true;
    }
  }

  /// Fetches all completion records for a specific habit
  Future<List<HabitCompletion>> getCompletionsForHabit(
    String habitId, {
    DateTime? from,
    DateTime? to,
  }) async {
    final db = await _database.database;
    String? where = 'habit_id = ?';
    List<dynamic> args = [habitId];

    if (from != null && to != null) {
      where += ' AND completion_date >= ? AND completion_date <= ?';
      args.addAll([
        HabitStreakService.normalizeDate(from),
        HabitStreakService.normalizeDate(to),
      ]);
    }

    final rows = await db.query(
      DbTables.habitCompletions,
      where: where,
      whereArgs: args,
      orderBy: 'completion_date ASC',
    );

    return rows.map(HabitCompletion.fromMap).toList();
  }

  /// Returns the set of all normalized completion date strings for a habit
  Future<Set<String>> getAllCompletionDatesForHabit(String habitId) async {
    final db = await _database.database;
    final rows = await db.query(
      DbTables.habitCompletions,
      columns: ['completion_date'],
      where: 'habit_id = ?',
      whereArgs: [habitId],
    );
    return rows.map((r) => r['completion_date'] as String).toSet();
  }

  /// Calculates deterministic statistics and streaks for a habit
  Future<HabitStats> getHabitStats(Habit habit, {DateTime? asOfDate}) async {
    final completionDates = await getAllCompletionDatesForHabit(habit.id);
    return _streakService.calculateStats(
      habit: habit,
      completionDates: completionDates,
      asOfDate: asOfDate ?? DateTime.now(),
    );
  }

  /// Fetches daily summary metrics for a given date
  Future<({int scheduledCount, int completedCount, double completionRate})>
  getDailyProgress(DateTime date) async {
    final scheduled = await getScheduledHabitsForDate(date);
    final completed = scheduled.where((h) => h.isCompletedToday).length;
    final total = scheduled.length;
    final rate = total > 0 ? (completed / total).clamp(0.0, 1.0) : 0.0;
    return (
      scheduledCount: total,
      completedCount: completed,
      completionRate: rate,
    );
  }
}
