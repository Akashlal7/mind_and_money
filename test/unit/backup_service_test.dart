import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mind_and_money/core/database/app_database.dart';
import 'package:mind_and_money/core/database/tables.dart';
import 'package:mind_and_money/core/services/backup_service.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late AppDatabase appDatabase;
  late Database rawDb;
  late BackupService backupService;
  late String testDbPath;

  setUp(() async {
    final tempDir = await Directory.systemTemp.createTemp('backup_test_');
    testDbPath = p.join(tempDir.path, 'backup_test.db');

    rawDb = await databaseFactoryFfi.openDatabase(
      testDbPath,
      options: OpenDatabaseOptions(
        version: 4,
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
          await batch.commit();
        },
      ),
    );

    appDatabase = AppDatabase();
    appDatabase.setDatabaseForTesting(rawDb);
    backupService = BackupService(appDatabase);
  });

  tearDown(() async {
    await rawDb.close();
    try {
      final file = File(testDbPath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  });

  group('BackupService Tests', () {
    test(
      'Exports all tables into formatted JSON with schema version 1.0',
      () async {
        // Seed category and habit
        await rawDb.insert(DbTables.categories, {
          'id': 'cat_bk_1',
          'name': 'Groceries',
          'icon': 'shopping_basket',
          'color': 0xFF81C784,
          'type': 'expense',
          'is_default': 1,
          'created_at': DateTime.now().toIso8601String(),
        });
        await rawDb.insert(DbTables.habits, {
          'id': 'hab_bk_1',
          'name': 'Drink Water',
          'schedule_type': 'daily',
          'is_archived': 0,
          'created_at': DateTime.now().toIso8601String(),
        });

        final jsonOutput = await backupService.exportBackupToJson();
        expect(jsonOutput, isNotEmpty);

        final decoded = jsonDecode(jsonOutput) as Map<String, dynamic>;
        expect(decoded['app'], 'Mind & Money');
        expect(decoded['format_version'], '1.0');
        expect(decoded.containsKey('exported_at'), isTrue);

        final tables = decoded['tables'] as Map<String, dynamic>;
        final categories = tables[DbTables.categories] as List;
        final habits = tables[DbTables.habits] as List;

        expect(categories.any((c) => c['id'] == 'cat_bk_1'), isTrue);
        expect(habits.any((h) => h['id'] == 'hab_bk_1'), isTrue);
      },
    );

    test('Restores tables successfully within atomic transaction', () async {
      final backupPayload = jsonEncode({
        'app': 'Mind & Money',
        'format_version': '1.0',
        'exported_at': DateTime.now().toIso8601String(),
        'tables': {
          DbTables.categories: [
            {
              'id': 'cat_restored',
              'name': 'Restored Category',
              'icon': 'category',
              'color': 0xFF123456,
              'type': 'expense',
              'is_default': 0,
              'created_at': '2026-10-20T10:00:00.000',
            },
          ],
          DbTables.habits: [
            {
              'id': 'hab_restored',
              'name': 'Restored Habit',
              'schedule_type': 'daily',
              'is_archived': 0,
              'created_at': '2026-10-20T10:00:00.000',
            },
          ],
          DbTables.habitCompletions: [
            {
              'id': 'comp_restored',
              'habit_id': 'hab_restored',
              'completion_date': '2026-10-20',
              'completed_at': '2026-10-20T10:30:00.000',
            },
          ],
        },
      });

      final result = await backupService.restoreBackupFromJson(backupPayload);
      expect(result.success, isTrue);
      expect(result.itemsRestored, 3);

      final catQuery = await rawDb.query(
        DbTables.categories,
        where: 'id = ?',
        whereArgs: ['cat_restored'],
      );
      expect(catQuery.length, 1);
      expect(catQuery.first['name'], 'Restored Category');

      final habQuery = await rawDb.query(
        DbTables.habits,
        where: 'id = ?',
        whereArgs: ['hab_restored'],
      );
      expect(habQuery.length, 1);
      expect(habQuery.first['name'], 'Restored Habit');
    });

    test(
      'Invalid JSON or missing format_version returns safe error result',
      () async {
        // Empty string
        final emptyResult = await backupService.restoreBackupFromJson('');
        expect(emptyResult.success, isFalse);
        expect(emptyResult.message, contains('empty'));

        // Malformed JSON
        final malformedResult = await backupService.restoreBackupFromJson(
          '{not_valid_json',
        );
        expect(malformedResult.success, isFalse);
        expect(malformedResult.message, contains('Malformed JSON'));

        // Missing format_version
        final missingVersionResult = await backupService.restoreBackupFromJson(
          jsonEncode({'app': 'Mind & Money', 'tables': {}}),
        );
        expect(missingVersionResult.success, isFalse);
        expect(
          missingVersionResult.message,
          contains('Missing format_version'),
        );
      },
    );

    test('validateBackup returns valid metadata and table counts', () {
      final validJson = jsonEncode({
        'app': 'Mind & Money',
        'format_version': '1.0',
        'exported_at': '2026-10-26T12:00:00Z',
        'tables': {
          DbTables.categories: [
            {'id': 'cat_1'},
            {'id': 'cat_2'},
          ],
          DbTables.transactions: [
            {'id': 'tx_1'},
          ],
        },
      });

      final validation = backupService.validateBackup(validJson);
      expect(validation.isValid, isTrue);
      expect(validation.formatVersion, '1.0');
      expect(validation.exportedAt, '2026-10-26T12:00:00Z');
      expect(validation.tableCounts[DbTables.categories], 2);
      expect(validation.tableCounts[DbTables.transactions], 1);
      expect(validation.totalRecords, 3);
    });
  });
}
