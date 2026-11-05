import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'tables.dart';

/// Database service managing SQLite database lifecycle, schema initialization,
/// migrations, and foreign key enforcement.
class AppDatabase {
  static const String _databaseName = 'mind_and_money.db';
  static const int _databaseVersion = 4;

  Database? _db;

  /// Returns the active SQLite database instance, opening it if not already opened.
  Future<Database> get database async {
    if (_db != null && _db!.isOpen) {
      return _db!;
    }
    _db = await _initDatabase();
    return _db!;
  }

  /// Explicitly allows injecting an already opened Database (useful for in-memory unit tests).
  void setDatabaseForTesting(Database db) {
    _db = db;
  }

  Future<Database> _initDatabase() async {
    // Ensure SQLite FFI is initialized on Linux, macOS, and Windows
    if (!kIsWeb &&
        (Platform.isLinux || Platform.isWindows || Platform.isMacOS)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, _databaseName);

    return await openDatabase(
      path,
      version: _databaseVersion,
      onConfigure: _onConfigure,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// Ensure foreign keys are enforced in SQLite
  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON;');
  }

  /// Creates all core tables and populates default categories
  Future<void> _onCreate(Database db, int version) async {
    final batch = db.batch();

    // Tables
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

    // Indexes
    for (final indexSql in DbTables.createIndexes) {
      batch.execute(indexSql);
    }

    // Default categories seed
    for (final cat in DbTables.defaultCategories) {
      batch.insert(
        DbTables.categories,
        cat,
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }

    // Initial metadata
    batch.insert(DbTables.appMetadata, {
      'key': 'schema_version',
      'value': version.toString(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    batch.insert(DbTables.appMetadata, {
      'key': 'installed_at',
      'value': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.ignore);

    await batch.commit(noResult: true);
  }

  /// Migration framework hook for database versions
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Phase 3 performance indexes for budgets and savings contributions
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

    if (oldVersion < 3) {
      // Phase 4: Mental Wellness migrations
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

      // Create new tables
      await db.execute(DbTables.createBreathingSessionsTable);
      await db.execute(DbTables.createSpendingReflectionsTable);

      // Create new indexes
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

    if (oldVersion < 4) {
      // Phase 5: Habits updated_at and reminder_time columns
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
  }

  /// Helper to run operations within an atomic SQLite transaction
  Future<T> transaction<T>(Future<T> Function(Transaction txn) action) async {
    final db = await database;
    return await db.transaction(action);
  }

  /// Closes the database connection
  Future<void> close() async {
    if (_db != null && _db!.isOpen) {
      await _db!.close();
      _db = null;
    }
  }

  /// Deletes the entire database file from the device (used for user-confirmed clear data)
  Future<void> deleteDatabaseFile() async {
    await close();
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, _databaseName);
    await deleteDatabase(path);
  }
}
