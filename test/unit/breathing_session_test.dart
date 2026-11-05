import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mind_and_money/core/database/app_database.dart';
import 'package:mind_and_money/core/database/tables.dart';
import 'package:mind_and_money/features/wellness/data/breathing_repository.dart';
import 'package:mind_and_money/features/wellness/models/breathing_session.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late AppDatabase database;
  late BreathingRepository repository;
  late String testDbPath;
  late Database rawDb;

  setUp(() async {
    final tempDir = await Directory.systemTemp.createTemp(
      'breathing_repo_test_',
    );
    testDbPath = p.join(tempDir.path, 'breathing_test.db');

    rawDb = await databaseFactoryFfi.openDatabase(
      testDbPath,
      options: OpenDatabaseOptions(
        version: 3,
        onCreate: (db, version) async {
          final batch = db.batch();
          batch.execute(DbTables.createBreathingSessionsTable);
          batch.execute(
            'CREATE INDEX idx_breathing_date ON ${DbTables.breathingSessions} (completed_at);',
          );
          await batch.commit();
        },
      ),
    );

    database = AppDatabase();
    database.setDatabaseForTesting(rawDb);
    repository = BreathingRepository(database);
  });

  tearDown(() async {
    await database.close();
    final file = File(testDbPath);
    if (await file.exists()) {
      await file.delete();
    }
  });

  group('BreathingRepository Tests', () {
    test(
      'Records completed breathing session and retrieves recent list',
      () async {
        final now = DateTime.now();
        final session = BreathingSession(
          id: 'brth_1',
          technique: 'box',
          durationSeconds: 120, // 2 minutes
          completedAt: now,
          cyclesCompleted: 4,
        );

        await repository.recordSession(session);

        final list = await repository.getRecentSessions();
        expect(list.length, 1);
        expect(list.first.technique, 'box');
        expect(list.first.techniqueTitle, 'Box Breathing (4-4-4-4)');
        expect(list.first.durationSeconds, 120);
        expect(list.first.cyclesCompleted, 4);
      },
    );

    test('Calculates total completed sessions and total minutes practiced accurately', () async {
      final now = DateTime.now();

      await repository.recordSession(
        BreathingSession(
          id: 'brth_a',
          technique: 'box',
          durationSeconds: 120, // 2 mins
          completedAt: now,
          cyclesCompleted: 4,
        ),
      );

      await repository.recordSession(
        BreathingSession(
          id: 'brth_b',
          technique: '478',
          durationSeconds: 180, // 3 mins
          completedAt: now,
          cyclesCompleted: 3,
        ),
      );

      final stats = await repository.getBreathingStats();
      expect(stats.totalSessions, 2);
      // (120 + 180) / 60 = 5 minutes
      expect(stats.totalMinutes, 5);
    });
  });
}
