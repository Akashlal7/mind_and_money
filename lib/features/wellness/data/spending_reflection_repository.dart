import '../../../core/database/app_database.dart';
import '../../../core/database/tables.dart';
import '../models/spending_reflection.dart';

class SpendingReflectionSummary {
  final int totalReflections;
  final int plannedCount;
  final int unplannedCount;
  final Map<String, int> natureCounts; // 'necessary', 'optional', 'impulsive'
  final Map<String, int> feelingCounts;

  const SpendingReflectionSummary({
    required this.totalReflections,
    required this.plannedCount,
    required this.unplannedCount,
    required this.natureCounts,
    required this.feelingCounts,
  });
}

class SpendingReflectionRepository {
  final AppDatabase _database;

  SpendingReflectionRepository(this._database);

  /// Saves a new spending reflection linked to a transaction
  Future<void> createReflection(SpendingReflection reflection) async {
    final db = await _database.database;
    await db.insert(DbTables.spendingReflections, reflection.toMap());
  }

  /// Updates an existing spending reflection
  Future<void> updateReflection(SpendingReflection reflection) async {
    final db = await _database.database;
    await db.update(
      DbTables.spendingReflections,
      reflection.toMap(),
      where: 'id = ?',
      whereArgs: [reflection.id],
    );
  }

  /// Deletes a reflection by its ID
  Future<void> deleteReflection(String id) async {
    final db = await _database.database;
    await db.delete(
      DbTables.spendingReflections,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Deletes a reflection linked to a specific transaction ID
  Future<void> deleteByTransactionId(String transactionId) async {
    final db = await _database.database;
    await db.delete(
      DbTables.spendingReflections,
      where: 'transaction_id = ?',
      whereArgs: [transactionId],
    );
  }

  /// Retrieves the reflection linked to a specific transaction, if one exists
  Future<SpendingReflection?> getReflectionForTransaction(
    String transactionId,
  ) async {
    final db = await _database.database;
    final results = await db.query(
      DbTables.spendingReflections,
      where: 'transaction_id = ?',
      whereArgs: [transactionId],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return SpendingReflection.fromMap(results.first);
  }

  /// Retrieves all reflections in descending order
  Future<List<SpendingReflection>> getAllReflections({int limit = 100}) async {
    final db = await _database.database;
    final results = await db.query(
      DbTables.spendingReflections,
      orderBy: 'created_at DESC',
      limit: limit,
    );
    return results.map((m) => SpendingReflection.fromMap(m)).toList();
  }

  /// Aggregates non-judgmental spending reflection summary metrics
  Future<SpendingReflectionSummary> getSummary() async {
    final reflections = await getAllReflections(limit: 500);

    int planned = 0;
    int unplanned = 0;
    final natureMap = <String, int>{};
    final feelingMap = <String, int>{};

    for (final r in reflections) {
      if (r.wasPlanned) {
        planned++;
      } else {
        unplanned++;
      }
      natureMap[r.spendingNature] = (natureMap[r.spendingNature] ?? 0) + 1;
      feelingMap[r.feeling] = (feelingMap[r.feeling] ?? 0) + 1;
    }

    return SpendingReflectionSummary(
      totalReflections: reflections.length,
      plannedCount: planned,
      unplannedCount: unplanned,
      natureCounts: natureMap,
      feelingCounts: feelingMap,
    );
  }
}
