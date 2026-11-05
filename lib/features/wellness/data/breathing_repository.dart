import '../../../core/database/app_database.dart';
import '../../../core/database/tables.dart';
import '../models/breathing_session.dart';

class BreathingRepository {
  final AppDatabase _database;

  BreathingRepository(this._database);

  /// Records a completed breathing session
  Future<void> recordSession(BreathingSession session) async {
    final db = await _database.database;
    await db.insert(DbTables.breathingSessions, session.toMap());
  }

  /// Retrieves recent breathing sessions
  Future<List<BreathingSession>> getRecentSessions({int limit = 50}) async {
    final db = await _database.database;
    final results = await db.query(
      DbTables.breathingSessions,
      orderBy: 'completed_at DESC',
      limit: limit,
    );
    return results.map((m) => BreathingSession.fromMap(m)).toList();
  }

  /// Calculates total sessions and total minutes practiced
  Future<({int totalSessions, int totalMinutes})> getBreathingStats() async {
    final db = await _database.database;
    final result = await db.rawQuery('''
      SELECT 
        COUNT(*) as session_count,
        COALESCE(SUM(duration_seconds), 0) as total_seconds
      FROM ${DbTables.breathingSessions}
    ''');

    if (result.isEmpty) return (totalSessions: 0, totalMinutes: 0);

    final count = (result.first['session_count'] as num?)?.toInt() ?? 0;
    final seconds = (result.first['total_seconds'] as num?)?.toInt() ?? 0;

    return (totalSessions: count, totalMinutes: (seconds / 60).round());
  }
}
