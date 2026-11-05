import '../../../core/database/app_database.dart';
import '../../../core/database/tables.dart';
import '../models/mood_entry.dart';

/// Aggregated daily summary when one or more mood check-ins exist for a given date
class DailyMoodSummary {
  final String date; // YYYY-MM-DD
  final double averageRating;
  final int totalEntries;
  final MoodEntry latestEntry;
  final List<MoodEntry> entries;

  const DailyMoodSummary({
    required this.date,
    required this.averageRating,
    required this.totalEntries,
    required this.latestEntry,
    required this.entries,
  });
}

/// Statistics and distributions for weekly and monthly mood summaries
class MoodPeriodSummary {
  final int totalCheckIns;
  final double averageRating;
  final int mostFrequentRating;
  final Map<int, int> ratingDistribution; // 1 to 5 -> count
  final List<MapEntry<String, int>> topTags;

  const MoodPeriodSummary({
    required this.totalCheckIns,
    required this.averageRating,
    required this.mostFrequentRating,
    required this.ratingDistribution,
    required this.topTags,
  });
}

class MoodRepository {
  final AppDatabase _database;

  MoodRepository(this._database);

  /// Inserts a new mood check-in. Multiple entries on the same day are supported.
  Future<void> createMoodEntry(MoodEntry entry) async {
    final db = await _database.database;
    await db.insert(DbTables.moodEntries, entry.toMap());
  }

  /// Updates an existing mood check-in
  Future<void> updateMoodEntry(MoodEntry entry) async {
    final db = await _database.database;
    await db.update(
      DbTables.moodEntries,
      entry.toMap(),
      where: 'id = ?',
      whereArgs: [entry.id],
    );
  }

  /// Deletes a mood check-in
  Future<void> deleteMoodEntry(String id) async {
    final db = await _database.database;
    await db.delete(DbTables.moodEntries, where: 'id = ?', whereArgs: [id]);
  }

  /// Fetches a single mood check-in by ID
  Future<MoodEntry?> getMoodById(String id) async {
    final db = await _database.database;
    final results = await db.query(
      DbTables.moodEntries,
      where: 'id = ?',
      whereArgs: [id],
    );
    if (results.isEmpty) return null;
    return MoodEntry.fromMap(results.first);
  }

  /// Gets all mood entries for a specific calendar day (YYYY-MM-DD)
  Future<List<MoodEntry>> getEntriesForDate(String isoDate) async {
    final db = await _database.database;
    final results = await db.query(
      DbTables.moodEntries,
      where: 'entry_date = ?',
      whereArgs: [isoDate],
      orderBy: 'entry_time ASC',
    );
    return results.map((m) => MoodEntry.fromMap(m)).toList();
  }

  /// Gets mood entries in chronological order (most recent first)
  Future<List<MoodEntry>> getRecentEntries({int limit = 100}) async {
    final db = await _database.database;
    final results = await db.query(
      DbTables.moodEntries,
      orderBy: 'entry_date DESC, entry_time DESC',
      limit: limit,
    );
    return results.map((m) => MoodEntry.fromMap(m)).toList();
  }

  /// Gets mood entries for a month formatted as YYYY-MM
  Future<List<MoodEntry>> getEntriesForMonth(String monthYear) async {
    final db = await _database.database;
    final results = await db.query(
      DbTables.moodEntries,
      where: 'entry_date LIKE ?',
      whereArgs: ['$monthYear%'],
      orderBy: 'entry_date DESC, entry_time DESC',
    );
    return results.map((m) => MoodEntry.fromMap(m)).toList();
  }

  /// Aggregates all check-ins for a month into daily summaries without discarding any entry
  Future<List<DailyMoodSummary>> getDailySummariesForMonth(
    String monthYear,
  ) async {
    final entries = await getEntriesForMonth(monthYear);
    if (entries.isEmpty) return [];

    // Group by entryDate
    final grouped = <String, List<MoodEntry>>{};
    for (final entry in entries) {
      grouped.putIfAbsent(entry.entryDate, () => []).add(entry);
    }

    final summaries = <DailyMoodSummary>[];
    for (final date in grouped.keys) {
      final dayEntries = grouped[date]!;
      // Sort day entries ascending by time
      dayEntries.sort((a, b) => a.entryTime.compareTo(b.entryTime));
      final avg =
          dayEntries.map((e) => e.rating).reduce((a, b) => a + b) /
          dayEntries.length;
      summaries.add(
        DailyMoodSummary(
          date: date,
          averageRating: double.parse(avg.toStringAsFixed(1)),
          totalEntries: dayEntries.length,
          latestEntry: dayEntries.last,
          entries: dayEntries,
        ),
      );
    }

    // Sort descending by date
    summaries.sort((a, b) => b.date.compareTo(a.date));
    return summaries;
  }

  /// Computes summary statistics over the last [days] days
  Future<MoodPeriodSummary> getPeriodSummary({int days = 7}) async {
    final db = await _database.database;
    final cutoff = DateTime.now().subtract(Duration(days: days));
    final cutoffDate =
        "${cutoff.year.toString().padLeft(4, '0')}-${cutoff.month.toString().padLeft(2, '0')}-${cutoff.day.toString().padLeft(2, '0')}";

    final results = await db.query(
      DbTables.moodEntries,
      where: 'entry_date >= ?',
      whereArgs: [cutoffDate],
      orderBy: 'entry_date ASC, entry_time ASC',
    );

    final entries = results.map((m) => MoodEntry.fromMap(m)).toList();
    if (entries.isEmpty) {
      return const MoodPeriodSummary(
        totalCheckIns: 0,
        averageRating: 0.0,
        mostFrequentRating: 0,
        ratingDistribution: {1: 0, 2: 0, 3: 0, 4: 0, 5: 0},
        topTags: [],
      );
    }

    final dist = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
    final tagCounts = <String, int>{};
    int totalRating = 0;

    for (final e in entries) {
      totalRating += e.rating;
      dist[e.rating] = (dist[e.rating] ?? 0) + 1;
      for (final tag in e.tags) {
        tagCounts[tag] = (tagCounts[tag] ?? 0) + 1;
      }
    }

    int maxCount = -1;
    int mostFrequent = 3;
    dist.forEach((rating, count) {
      if (count > maxCount) {
        maxCount = count;
        mostFrequent = rating;
      }
    });

    final sortedTags = tagCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return MoodPeriodSummary(
      totalCheckIns: entries.length,
      averageRating: double.parse(
        (totalRating / entries.length).toStringAsFixed(1),
      ),
      mostFrequentRating: mostFrequent,
      ratingDistribution: dist,
      topTags: sortedTags.take(5).toList(),
    );
  }
}
