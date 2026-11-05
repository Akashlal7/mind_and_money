import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mind_and_money/core/database/app_database.dart';
import 'package:mind_and_money/core/database/tables.dart';
import 'package:mind_and_money/features/wellness/data/mood_repository.dart';
import 'package:mind_and_money/features/wellness/models/mood_entry.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late AppDatabase database;
  late MoodRepository repository;
  late String testDbPath;
  late Database rawDb;

  setUp(() async {
    final tempDir = await Directory.systemTemp.createTemp('mood_repo_test_');
    testDbPath = p.join(tempDir.path, 'mood_test.db');

    rawDb = await databaseFactoryFfi.openDatabase(
      testDbPath,
      options: OpenDatabaseOptions(
        version: 3,
        onCreate: (db, version) async {
          final batch = db.batch();
          batch.execute(DbTables.createMoodEntriesTable);
          batch.execute(
            'CREATE INDEX idx_mood_date ON ${DbTables.moodEntries} (entry_date);',
          );
          await batch.commit();
        },
      ),
    );

    database = AppDatabase();
    database.setDatabaseForTesting(rawDb);
    repository = MoodRepository(database);
  });

  tearDown(() async {
    await database.close();
    final file = File(testDbPath);
    if (await file.exists()) {
      await file.delete();
    }
  });

  group('MoodRepository CRUD & Multiple Daily Check-in Tests', () {
    test('Creates and retrieves a single mood check-in', () async {
      final now = DateTime.now();
      final entry = MoodEntry(
        id: 'mood_1',
        entryDate: '2026-10-28',
        entryTime: '08:30:00',
        rating: 4,
        emotionLabels: 'Grateful,Calm',
        stressRating: 2,
        energyRating: 4,
        sleepRating: 5,
        note: 'Feeling good this morning',
        createdAt: now,
        updatedAt: now,
      );

      await repository.createMoodEntry(entry);

      final fetched = await repository.getMoodById('mood_1');
      expect(fetched, isNotNull);
      expect(fetched!.rating, 4);
      expect(fetched.moodLabel, 'Good');
      expect(fetched.moodEmoji, '🙂');
      expect(fetched.tags, ['Grateful', 'Calm']);
      expect(fetched.stressRating, 2);
    });

    test('Multiple mood check-ins on the same day are all preserved without data loss', () async {
      final date = '2026-10-28';
      final entryMorning = MoodEntry(
        id: 'mood_m',
        entryDate: date,
        entryTime: '08:00:00',
        rating: 2,
        emotionLabels: 'Tired,Anxious',
        note: 'Rough start',
        createdAt: DateTime.now(),
      );
      final entryNoon = MoodEntry(
        id: 'mood_n',
        entryDate: date,
        entryTime: '13:00:00',
        rating: 4,
        emotionLabels: 'Energized',
        note: 'Walk helped',
        createdAt: DateTime.now(),
      );
      final entryEvening = MoodEntry(
        id: 'mood_e',
        entryDate: date,
        entryTime: '21:00:00',
        rating: 3,
        emotionLabels: 'Content,Calm',
        note: 'Wind down',
        createdAt: DateTime.now(),
      );

      await repository.createMoodEntry(entryMorning);
      await repository.createMoodEntry(entryNoon);
      await repository.createMoodEntry(entryEvening);

      // Verify all 3 entries are fetched for this date
      final dayEntries = await repository.getEntriesForDate(date);
      expect(dayEntries.length, 3);
      expect(dayEntries.map((e) => e.id).toList(), [
        'mood_m',
        'mood_n',
        'mood_e',
      ]);

      // Verify daily summary aggregation calculates accurate average
      final summaries = await repository.getDailySummariesForMonth('2026-10');
      expect(summaries.length, 1);
      final todaySummary = summaries.first;
      expect(todaySummary.date, date);
      expect(todaySummary.totalEntries, 3);
      // (2 + 4 + 3) / 3 = 3.0
      expect(todaySummary.averageRating, 3.0);
      expect(todaySummary.latestEntry.id, 'mood_e');
      expect(todaySummary.entries.length, 3);
    });

    test('Period summary computes distributions and top feelings across dates', () async {
      final now = DateTime.now();
      // Insert across multiple recent dates
      final entry1 = MoodEntry(
        id: 'm_1',
        entryDate:
            "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}",
        entryTime: '10:00:00',
        rating: 5,
        emotionLabels: 'Thriving,Grateful',
        createdAt: now,
      );
      final entry2 = MoodEntry(
        id: 'm_2',
        entryDate:
            "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}",
        entryTime: '15:00:00',
        rating: 5,
        emotionLabels: 'Grateful,Calm',
        createdAt: now,
      );

      await repository.createMoodEntry(entry1);
      await repository.createMoodEntry(entry2);

      final summary = await repository.getPeriodSummary(days: 7);
      expect(summary.totalCheckIns, 2);
      expect(summary.averageRating, 5.0);
      expect(summary.mostFrequentRating, 5);
      expect(summary.ratingDistribution[5], 2);
      expect(summary.topTags.first.key, 'Grateful');
      expect(summary.topTags.first.value, 2);
    });

    test('Updates existing mood check-in', () async {
      final entry = MoodEntry(
        id: 'mood_update',
        entryDate: '2026-10-28',
        entryTime: '10:00:00',
        rating: 2,
        note: 'Before coffee',
        createdAt: DateTime.now(),
      );
      await repository.createMoodEntry(entry);

      final updated = entry.copyWith(
        rating: 4,
        note: 'After coffee and reflection',
        updatedAt: DateTime.now(),
      );
      await repository.updateMoodEntry(updated);

      final fetched = await repository.getMoodById('mood_update');
      expect(fetched!.rating, 4);
      expect(fetched.note, 'After coffee and reflection');
      expect(fetched.updatedAt, isNotNull);
    });

    test('Deletes mood check-in cleanly', () async {
      final entry = MoodEntry(
        id: 'mood_del',
        entryDate: '2026-10-28',
        entryTime: '10:00:00',
        rating: 3,
        createdAt: DateTime.now(),
      );
      await repository.createMoodEntry(entry);

      await repository.deleteMoodEntry('mood_del');

      final fetched = await repository.getMoodById('mood_del');
      expect(fetched, isNull);
    });
  });
}
