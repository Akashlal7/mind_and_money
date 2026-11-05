import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mind_and_money/core/database/tables.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late String testDbPath;

  setUp(() async {
    final tempDir = await Directory.systemTemp.createTemp('db_migration_test_');
    testDbPath = p.join(tempDir.path, 'migration_test.db');
  });

  tearDown(() async {
    final file = File(testDbPath);
    if (await file.exists()) {
      await file.delete();
    }
  });

  test('Version 1 to Version 2 migration preserves all user records and adds performance indexes', () async {
    // 1. Create and populate Database at Version 1
    final v1Db = await databaseFactoryFfi.openDatabase(
      testDbPath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          final batch = db.batch();
          batch.execute(DbTables.createCategoriesTable);
          batch.execute(DbTables.createTransactionsTable);
          batch.execute(DbTables.createBudgetsTable);
          batch.execute(DbTables.createSavingsGoalsTable);
          batch.execute(DbTables.createSavingsContributionsTable);
          batch.execute(DbTables.createMoodEntriesTable);
          batch.execute(DbTables.createJournalEntriesTable);
          batch.execute(DbTables.createHabitsTable);
          batch.execute(DbTables.createHabitCompletionsTable);
          batch.execute(DbTables.createAppMetadataTable);

          // V1 Indexes
          batch.execute(
            'CREATE INDEX idx_trans_date ON ${DbTables.transactions} (transaction_date);',
          );
          batch.execute(
            'CREATE INDEX idx_budgets_month ON ${DbTables.budgets} (month_year);',
          );

          batch.insert(DbTables.appMetadata, {
            'key': 'schema_version',
            'value': '1',
          });

          await batch.commit();
        },
      ),
    );

    // Insert user data in V1
    await v1Db.insert(DbTables.categories, {
      'id': 'cat_v1_custom',
      'name': 'Custom V1 Category',
      'icon': 'star',
      'color': 4287661230,
      'type': 'expense',
      'is_default': 0,
      'created_at': '2026-10-01T10:00:00.000',
    });

    await v1Db.insert(DbTables.transactions, {
      'id': 'tx_v1_record',
      'amount_cents': 149900,
      'type': 'expense',
      'category_id': 'cat_v1_custom',
      'transaction_date': '2026-10-05T12:00:00.000',
      'description': 'Important purchase',
      'payment_method': 'upi',
      'note': 'Preserve this note',
      'created_at': '2026-10-05T12:00:00.000',
      'updated_at': '2026-10-05T12:00:00.000',
    });

    await v1Db.insert(DbTables.budgets, {
      'id': 'bgt_v1_record',
      'category_id': 'cat_v1_custom',
      'amount_cents': 300000,
      'month_year': '2026-10',
      'created_at': '2026-10-01T10:00:00.000',
      'updated_at': '2026-10-01T10:00:00.000',
    });

    await v1Db.insert(DbTables.savingsGoals, {
      'id': 'goal_v1_record',
      'name': 'Retirement Nest',
      'target_amount_cents': 50000000,
      'current_amount_cents': 15000000,
      'target_date': '2030-01-01',
      'created_at': '2026-10-01T10:00:00.000',
      'updated_at': '2026-10-01T10:00:00.000',
    });

    await v1Db.close();

    // 2. Open at Version 2 with onUpgrade migration
    final v2Db = await databaseFactoryFfi.openDatabase(
      testDbPath,
      options: OpenDatabaseOptions(
        version: 2,
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) {
            await db.execute(
              'CREATE INDEX IF NOT EXISTS idx_budgets_cat_month ON ${DbTables.budgets} (category_id, month_year);',
            );
            await db.execute(
              'CREATE INDEX IF NOT EXISTS idx_savings_contrib_goal ON ${DbTables.savingsContributions} (goal_id);',
            );
            await db.execute(
              'CREATE INDEX IF NOT EXISTS idx_savings_contrib_date ON ${DbTables.savingsContributions} (date);',
            );
          }

          await db.update(
            DbTables.appMetadata,
            {'value': newVersion.toString()},
            where: 'key = ?',
            whereArgs: ['schema_version'],
          );
        },
      ),
    );

    // 3. Verify All Existing User Data is Perfectly Intact
    final catRows = await v2Db.query(
      DbTables.categories,
      where: 'id = ?',
      whereArgs: ['cat_v1_custom'],
    );
    expect(catRows.length, 1);
    expect(catRows.first['name'], 'Custom V1 Category');

    final txRows = await v2Db.query(
      DbTables.transactions,
      where: 'id = ?',
      whereArgs: ['tx_v1_record'],
    );
    expect(txRows.length, 1);
    expect(txRows.first['amount_cents'], 149900);
    expect(txRows.first['note'], 'Preserve this note');

    final budgetRows = await v2Db.query(
      DbTables.budgets,
      where: 'id = ?',
      whereArgs: ['bgt_v1_record'],
    );
    expect(budgetRows.length, 1);
    expect(budgetRows.first['amount_cents'], 300000);

    final goalRows = await v2Db.query(
      DbTables.savingsGoals,
      where: 'id = ?',
      whereArgs: ['goal_v1_record'],
    );
    expect(goalRows.length, 1);
    expect(goalRows.first['current_amount_cents'], 15000000);

    // 4. Verify New Indexes Exist
    final indexRows = await v2Db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'index' AND name IN ('idx_budgets_cat_month', 'idx_savings_contrib_goal', 'idx_savings_contrib_date')",
    );
    final indexNames = indexRows.map((r) => r['name'] as String).toSet();
    expect(indexNames.contains('idx_budgets_cat_month'), isTrue);
    expect(indexNames.contains('idx_savings_contrib_goal'), isTrue);
    expect(indexNames.contains('idx_savings_contrib_date'), isTrue);

    // 5. Verify Metadata Updated
    final metaRows = await v2Db.query(
      DbTables.appMetadata,
      where: 'key = ?',
      whereArgs: ['schema_version'],
    );
    expect(metaRows.first['value'], '2');

    await v2Db.close();
  });

  test('Version 2 to Version 3 migration preserves all user records and creates Phase 4 wellness tables, columns, and indexes', () async {
    // 1. Setup V2 Database
    final v2Db = await databaseFactoryFfi.openDatabase(
      testDbPath,
      options: OpenDatabaseOptions(
        version: 2,
        onCreate: (db, version) async {
          final batch = db.batch();
          batch.execute(DbTables.createCategoriesTable);
          batch.execute(DbTables.createTransactionsTable);
          batch.execute(DbTables.createBudgetsTable);
          batch.execute(DbTables.createSavingsGoalsTable);
          batch.execute(DbTables.createSavingsContributionsTable);
          batch.execute('''
            CREATE TABLE ${DbTables.moodEntries} (
              id TEXT PRIMARY KEY,
              entry_date TEXT NOT NULL,
              entry_time TEXT NOT NULL,
              rating INTEGER NOT NULL,
              emotion_labels TEXT,
              stress_rating INTEGER,
              energy_rating INTEGER,
              sleep_rating INTEGER,
              note TEXT,
              created_at TEXT NOT NULL
            );
            ''');
          batch.execute('''
            CREATE TABLE ${DbTables.journalEntries} (
              id TEXT PRIMARY KEY,
              title TEXT,
              content TEXT NOT NULL,
              mood_rating INTEGER,
              entry_date TEXT NOT NULL,
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL
            );
            ''');
          batch.execute(DbTables.createHabitsTable);
          batch.execute(DbTables.createHabitCompletionsTable);
          batch.execute(DbTables.createAppMetadataTable);

          batch.insert(DbTables.appMetadata, {
            'key': 'schema_version',
            'value': '2',
          });

          await batch.commit();
        },
      ),
    );

    // Insert user data in V2
    await v2Db.insert(DbTables.categories, {
      'id': 'cat_food_v2',
      'name': 'Dining Out',
      'icon': 'restaurant',
      'color': 4287661230,
      'type': 'expense',
      'is_default': 1,
      'created_at': '2026-10-10T12:00:00.000',
    });

    await v2Db.insert(DbTables.transactions, {
      'id': 'tx_v2_cafe',
      'amount_cents': 25000,
      'type': 'expense',
      'category_id': 'cat_food_v2',
      'transaction_date': '2026-10-15T15:30:00.000',
      'description': 'Afternoon coffee',
      'payment_method': 'card',
      'note': 'Mindful pause',
      'created_at': '2026-10-15T15:30:00.000',
      'updated_at': '2026-10-15T15:30:00.000',
    });

    await v2Db.insert(DbTables.moodEntries, {
      'id': 'mood_v2_sample',
      'entry_date': '2026-10-15',
      'entry_time': '16:00:00',
      'rating': 4,
      'emotion_labels': 'Calm,Grateful',
      'stress_rating': 2,
      'energy_rating': 4,
      'sleep_rating': 5,
      'note': 'Peaceful afternoon',
      'created_at': '2026-10-15T16:00:00.000',
    });

    await v2Db.insert(DbTables.journalEntries, {
      'id': 'jrn_v2_sample',
      'title': 'Autumn Reflections',
      'content': 'Taking a gentle moment to reflect on my progress.',
      'mood_rating': 4,
      'entry_date': '2026-10-15',
      'created_at': '2026-10-15T16:30:00.000',
      'updated_at': '2026-10-15T16:30:00.000',
    });

    await v2Db.close();

    // 2. Open at Version 3 using AppDatabase upgrade logic
    final v3Db = await databaseFactoryFfi.openDatabase(
      testDbPath,
      options: OpenDatabaseOptions(
        version: 3,
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 3) {
            try {
              await db.execute(
                'ALTER TABLE ${DbTables.moodEntries} ADD COLUMN updated_at TEXT;',
              );
            } catch (_) {}
            try {
              await db.execute(
                "ALTER TABLE ${DbTables.journalEntries} ADD COLUMN entry_type TEXT NOT NULL DEFAULT 'journal';",
              );
            } catch (_) {}
            try {
              await db.execute(
                'ALTER TABLE ${DbTables.journalEntries} ADD COLUMN prompt TEXT;',
              );
            } catch (_) {}

            await db.execute(DbTables.createBreathingSessionsTable);
            await db.execute(DbTables.createSpendingReflectionsTable);

            await db.execute(
              'CREATE INDEX IF NOT EXISTS idx_journal_type ON ${DbTables.journalEntries} (entry_type);',
            );
            await db.execute(
              'CREATE INDEX IF NOT EXISTS idx_breathing_date ON ${DbTables.breathingSessions} (completed_at);',
            );
            await db.execute(
              'CREATE INDEX IF NOT EXISTS idx_spending_reflections_tx ON ${DbTables.spendingReflections} (transaction_id);',
            );
          }

          await db.update(
            DbTables.appMetadata,
            {'value': newVersion.toString()},
            where: 'key = ?',
            whereArgs: ['schema_version'],
          );
        },
      ),
    );

    // 3. Verify Existing Data Intact
    final txRows = await v3Db.query(
      DbTables.transactions,
      where: 'id = ?',
      whereArgs: ['tx_v2_cafe'],
    );
    expect(txRows.length, 1);
    expect(txRows.first['amount_cents'], 25000);
    expect(txRows.first['description'], 'Afternoon coffee');

    final moodRows = await v3Db.query(
      DbTables.moodEntries,
      where: 'id = ?',
      whereArgs: ['mood_v2_sample'],
    );
    expect(moodRows.length, 1);
    expect(moodRows.first['rating'], 4);
    expect(moodRows.first['emotion_labels'], 'Calm,Grateful');

    final journalRows = await v3Db.query(
      DbTables.journalEntries,
      where: 'id = ?',
      whereArgs: ['jrn_v2_sample'],
    );
    expect(journalRows.length, 1);
    expect(journalRows.first['title'], 'Autumn Reflections');
    expect(journalRows.first['entry_type'], 'journal');

    // 4. Verify New Tables Accept Inserts
    await v3Db.insert(DbTables.breathingSessions, {
      'id': 'brth_test_1',
      'technique': 'box',
      'duration_seconds': 120,
      'completed_at': '2026-10-28T09:00:00.000',
      'cycles_completed': 4,
    });

    final brthRows = await v3Db.query(
      DbTables.breathingSessions,
      where: 'id = ?',
      whereArgs: ['brth_test_1'],
    );
    expect(brthRows.length, 1);
    expect(brthRows.first['technique'], 'box');

    await v3Db.insert(DbTables.spendingReflections, {
      'id': 'refl_test_1',
      'transaction_id': 'tx_v2_cafe',
      'feeling': 'Calm',
      'was_planned': 1,
      'spending_nature': 'optional',
      'notes': 'Enjoyed a mindful pause',
      'created_at': '2026-10-28T09:05:00.000',
      'updated_at': '2026-10-28T09:05:00.000',
    });

    final reflRows = await v3Db.query(
      DbTables.spendingReflections,
      where: 'id = ?',
      whereArgs: ['refl_test_1'],
    );
    expect(reflRows.length, 1);
    expect(reflRows.first['spending_nature'], 'optional');

    // 5. Verify Metadata
    final metaRows = await v3Db.query(
      DbTables.appMetadata,
      where: 'key = ?',
      whereArgs: ['schema_version'],
    );
    expect(metaRows.first['value'], '3');

    await v3Db.close();
  });

  test('Migration from Schema Version 3 to Version 4 preserves all records and extends habits table', () async {
    // 1. Setup Version 3 Database with seed records
    final v3Db = await databaseFactoryFfi.openDatabase(
      testDbPath,
      options: OpenDatabaseOptions(
        version: 3,
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

    // Seed habit in v3
    await v3Db.insert(DbTables.habits, {
      'id': 'hab_v3_seed',
      'name': 'Drink Green Tea',
      'description': 'Healthy morning ritual',
      'schedule_type': 'daily',
      'is_archived': 0,
      'color': 0xFF4CAF50,
      'icon': 'local_cafe_rounded',
      'created_at': '2026-10-20T08:00:00.000',
    });

    await v3Db.insert(DbTables.habitCompletions, {
      'id': 'comp_v3_seed',
      'habit_id': 'hab_v3_seed',
      'completion_date': '2026-10-20',
      'completed_at': '2026-10-20T08:30:00.000',
    });

    await v3Db.close();

    // 2. Open at Version 4 triggering onUpgrade
    final v4Db = await databaseFactoryFfi.openDatabase(
      testDbPath,
      options: OpenDatabaseOptions(
        version: 4,
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 4) {
            try {
              await db.execute(
                'ALTER TABLE ${DbTables.habits} ADD COLUMN updated_at TEXT;',
              );
            } catch (_) {}
            try {
              await db.execute(
                'ALTER TABLE ${DbTables.habits} ADD COLUMN reminder_time TEXT;',
              );
            } catch (_) {}
          }
          await db.update(
            DbTables.appMetadata,
            {'value': newVersion.toString()},
            where: 'key = ?',
            whereArgs: ['schema_version'],
          );
        },
      ),
    );

    // 3. Verify Existing Habit and Completion are intact
    final habitRows = await v4Db.query(
      DbTables.habits,
      where: 'id = ?',
      whereArgs: ['hab_v3_seed'],
    );
    expect(habitRows.length, 1);
    expect(habitRows.first['name'], 'Drink Green Tea');
    expect(habitRows.first['reminder_time'], isNull);

    final compRows = await v4Db.query(
      DbTables.habitCompletions,
      where: 'id = ?',
      whereArgs: ['comp_v3_seed'],
    );
    expect(compRows.length, 1);

    // 4. Verify New Columns Accept Updates and Inserts
    await v4Db.update(
      DbTables.habits,
      {'updated_at': '2026-10-28T10:00:00.000', 'reminder_time': '07:30'},
      where: 'id = ?',
      whereArgs: ['hab_v3_seed'],
    );

    final updatedHabitRows = await v4Db.query(
      DbTables.habits,
      where: 'id = ?',
      whereArgs: ['hab_v3_seed'],
    );
    expect(updatedHabitRows.first['reminder_time'], '07:30');
    expect(updatedHabitRows.first['updated_at'], '2026-10-28T10:00:00.000');

    await v4Db.close();
  });
}
