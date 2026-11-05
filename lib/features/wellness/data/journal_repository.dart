import '../../../core/database/app_database.dart';
import '../../../core/database/tables.dart';
import '../models/journal_entry.dart';

class JournalRepository {
  final AppDatabase _database;

  JournalRepository(this._database);

  /// Inserts a new journal or reflection entry into SQLite
  Future<void> createEntry(JournalEntry entry) async {
    final db = await _database.database;
    await db.insert(DbTables.journalEntries, entry.toMap());
  }

  /// Updates an existing journal or reflection entry
  Future<void> updateEntry(JournalEntry entry) async {
    final db = await _database.database;
    await db.update(
      DbTables.journalEntries,
      entry.toMap(),
      where: 'id = ?',
      whereArgs: [entry.id],
    );
  }

  /// Deletes a journal or reflection entry
  Future<void> deleteEntry(String id) async {
    final db = await _database.database;
    await db.delete(DbTables.journalEntries, where: 'id = ?', whereArgs: [id]);
  }

  /// Retrieves a specific entry by its ID
  Future<JournalEntry?> getEntryById(String id) async {
    final db = await _database.database;
    final results = await db.query(
      DbTables.journalEntries,
      where: 'id = ?',
      whereArgs: [id],
    );
    if (results.isEmpty) return null;
    return JournalEntry.fromMap(results.first);
  }

  /// Retrieves entries with optional search query and entryType filter ('journal' or 'reflection')
  Future<List<JournalEntry>> getEntries({
    String? query,
    String? entryType,
    int limit = 100,
  }) async {
    final db = await _database.database;

    final conditions = <String>[];
    final args = <dynamic>[];

    if (entryType != null && entryType.isNotEmpty) {
      conditions.add('entry_type = ?');
      args.add(entryType);
    }

    if (query != null && query.trim().isNotEmpty) {
      conditions.add('(title LIKE ? OR content LIKE ? OR prompt LIKE ?)');
      final term = '%${query.trim()}%';
      args.addAll([term, term, term]);
    }

    final whereClause = conditions.isNotEmpty ? conditions.join(' AND ') : null;

    final results = await db.query(
      DbTables.journalEntries,
      where: whereClause,
      whereArgs: args.isNotEmpty ? args : null,
      orderBy: 'created_at DESC',
      limit: limit,
    );

    return results.map((m) => JournalEntry.fromMap(m)).toList();
  }

  /// Returns total count of journal and reflection entries
  Future<int> getTotalEntriesCount({String? entryType}) async {
    final db = await _database.database;
    final where = entryType != null ? 'WHERE entry_type = ?' : '';
    final args = entryType != null ? [entryType] : null;

    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM ${DbTables.journalEntries} $where',
      args,
    );
    return (result.first['count'] as num?)?.toInt() ?? 0;
  }
}
