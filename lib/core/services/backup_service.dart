import 'dart:convert';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../database/app_database.dart';
import '../database/tables.dart';

/// Validation result for incoming JSON backup payloads.
class BackupValidationResult {
  final bool isValid;
  final String? errorMessage;
  final String? formatVersion;
  final String? exportedAt;
  final Map<String, int> tableCounts;

  const BackupValidationResult({
    required this.isValid,
    this.errorMessage,
    this.formatVersion,
    this.exportedAt,
    this.tableCounts = const {},
  });

  int get totalRecords =>
      tableCounts.values.fold(0, (sum, count) => sum + count);
}

/// Service responsible for offline JSON backup and restore with schema versioning,
/// data integrity validation, and transactional restores.
class BackupService {
  final AppDatabase _database;

  static const String currentFormatVersion = '1.0';

  const BackupService(this._database);

  /// Exports all application tables into a formatted JSON string.
  Future<String> exportBackupToJson() async {
    final db = await _database.database;

    final categories = await db.query(DbTables.categories);
    final transactions = await db.query(DbTables.transactions);
    final budgets = await db.query(DbTables.budgets);
    final savingsGoals = await db.query(DbTables.savingsGoals);
    final savingsContributions = await db.query(DbTables.savingsContributions);
    final moodEntries = await db.query(DbTables.moodEntries);
    final journalEntries = await db.query(DbTables.journalEntries);
    final breathingSessions = await db.query(DbTables.breathingSessions);
    final spendingReflections = await db.query(DbTables.spendingReflections);
    final habits = await db.query(DbTables.habits);
    final habitCompletions = await db.query(DbTables.habitCompletions);
    final metadata = await db.query(DbTables.appMetadata);

    final payload = <String, dynamic>{
      'app': 'Mind & Money',
      'format_version': currentFormatVersion,
      'exported_at': DateTime.now().toIso8601String(),
      'tables': {
        DbTables.categories: categories,
        DbTables.transactions: transactions,
        DbTables.budgets: budgets,
        DbTables.savingsGoals: savingsGoals,
        DbTables.savingsContributions: savingsContributions,
        DbTables.moodEntries: moodEntries,
        DbTables.journalEntries: journalEntries,
        DbTables.breathingSessions: breathingSessions,
        DbTables.spendingReflections: spendingReflections,
        DbTables.habits: habits,
        DbTables.habitCompletions: habitCompletions,
        DbTables.appMetadata: metadata,
      },
    };

    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  /// Pre-validates a backup JSON string before attempting any database operations.
  BackupValidationResult validateBackup(String jsonString) {
    if (jsonString.trim().isEmpty) {
      return const BackupValidationResult(
        isValid: false,
        errorMessage: 'Backup content is empty.',
      );
    }

    Map<String, dynamic> data;
    try {
      final decoded = jsonDecode(jsonString);
      if (decoded is! Map<String, dynamic>) {
        return const BackupValidationResult(
          isValid: false,
          errorMessage: 'Invalid backup structure. Expected JSON object.',
        );
      }
      data = decoded;
    } catch (e) {
      return BackupValidationResult(
        isValid: false,
        errorMessage: 'Malformed JSON payload: $e',
      );
    }

    final formatVersion = data['format_version'] as String?;
    if (formatVersion == null || formatVersion.isEmpty) {
      return const BackupValidationResult(
        isValid: false,
        errorMessage: 'Unsupported backup: Missing format_version.',
      );
    }

    final tables = data['tables'];
    if (tables is! Map<String, dynamic>) {
      return const BackupValidationResult(
        isValid: false,
        errorMessage: 'Invalid backup: "tables" mapping not found.',
      );
    }

    final counts = <String, int>{};
    for (final entry in tables.entries) {
      if (entry.value is List) {
        counts[entry.key] = (entry.value as List).length;
      }
    }

    return BackupValidationResult(
      isValid: true,
      formatVersion: formatVersion,
      exportedAt: data['exported_at'] as String?,
      tableCounts: counts,
    );
  }

  /// Restores records from a JSON string inside an atomic SQLite transaction.
  /// Validates format version and table payloads before running.
  Future<({bool success, String message, int itemsRestored})>
  restoreBackupFromJson(String jsonString) async {
    final validation = validateBackup(jsonString);
    if (!validation.isValid) {
      return (
        success: false,
        message: validation.errorMessage ?? 'Invalid backup file.',
        itemsRestored: 0,
      );
    }

    final decoded = jsonDecode(jsonString) as Map<String, dynamic>;
    final tables = decoded['tables'] as Map<String, dynamic>;

    final db = await _database.database;
    int restoredCount = 0;

    try {
      await db.transaction((txn) async {
        // Restore table helper
        Future<void> restoreTable(
          String tableName,
          ConflictAlgorithm algorithm,
        ) async {
          final rows = tables[tableName];
          if (rows is List) {
            for (final row in rows) {
              if (row is Map<String, dynamic>) {
                await txn.insert(tableName, row, conflictAlgorithm: algorithm);
                restoredCount++;
              }
            }
          }
        }

        // Ordered restore respecting foreign keys:
        // 1. Categories
        await restoreTable(DbTables.categories, ConflictAlgorithm.replace);
        // 2. Transactions
        await restoreTable(DbTables.transactions, ConflictAlgorithm.replace);
        // 3. Budgets
        await restoreTable(DbTables.budgets, ConflictAlgorithm.replace);
        // 4. Savings Goals & Contributions
        await restoreTable(DbTables.savingsGoals, ConflictAlgorithm.replace);
        await restoreTable(
          DbTables.savingsContributions,
          ConflictAlgorithm.replace,
        );
        // 5. Wellness: Moods, Journals, Breathing, Spending Reflections
        await restoreTable(DbTables.moodEntries, ConflictAlgorithm.replace);
        await restoreTable(DbTables.journalEntries, ConflictAlgorithm.replace);
        await restoreTable(
          DbTables.breathingSessions,
          ConflictAlgorithm.replace,
        );
        await restoreTable(
          DbTables.spendingReflections,
          ConflictAlgorithm.replace,
        );
        // 6. Habits & Habit Completions
        await restoreTable(DbTables.habits, ConflictAlgorithm.replace);
        await restoreTable(
          DbTables.habitCompletions,
          ConflictAlgorithm.replace,
        );
        // 7. Metadata
        await restoreTable(DbTables.appMetadata, ConflictAlgorithm.replace);
      });

      return (
        success: true,
        message: 'Successfully restored $restoredCount records.',
        itemsRestored: restoredCount,
      );
    } catch (e) {
      return (
        success: false,
        message: 'Failed to restore database: $e',
        itemsRestored: 0,
      );
    }
  }
}
