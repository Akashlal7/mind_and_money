import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mind_and_money/core/database/app_database.dart';
import 'package:mind_and_money/core/database/tables.dart';
import 'package:mind_and_money/features/habits/data/habit_repository.dart';
import 'package:mind_and_money/features/habits/models/habit.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late AppDatabase appDatabase;
  late Database rawDb;
  late HabitRepository repository;
  late String testDbPath;

  setUp(() async {
    final tempDir = await Directory.systemTemp.createTemp('habit_repo_test_');
    testDbPath = p.join(tempDir.path, 'habit_repo_test.db');

    rawDb = await databaseFactoryFfi.openDatabase(
      testDbPath,
      options: OpenDatabaseOptions(
        version: 4,
        onConfigure: (db) async =>
            await db.execute('PRAGMA foreign_keys = ON;'),
        onCreate: (db, version) async {
          final batch = db.batch();
          batch.execute(DbTables.createHabitsTable);
          batch.execute(DbTables.createHabitCompletionsTable);
          batch.execute(
            'CREATE INDEX idx_habit_comp_date ON ${DbTables.habitCompletions} (completion_date);',
          );
          batch.execute(
            'CREATE INDEX idx_habit_comp_habit ON ${DbTables.habitCompletions} (habit_id);',
          );
          await batch.commit();
        },
      ),
    );

    appDatabase = AppDatabase();
    appDatabase.setDatabaseForTesting(rawDb);
    repository = HabitRepository(appDatabase);
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

  group('HabitRepository Tests', () {
    test('Create, read, update, and archive habit', () async {
      final now = DateTime(2026, 10, 20);
      final habit = Habit(
        id: 'hab_read_1',
        name: 'Read 10 Pages',
        description: 'Read non-fiction book',
        scheduleType: 'daily',
        color: 0xFF2196F3,
        icon: 'book_outlined',
        createdAt: now,
      );

      // Create
      await repository.createHabit(habit);
      final fetched = await repository.getHabitById('hab_read_1');
      expect(fetched, isNotNull);
      expect(fetched!.name, 'Read 10 Pages');
      expect(fetched.isArchived, isFalse);

      // Update
      final updated = fetched.copyWith(
        name: 'Read 20 Pages',
        reminderTime: '21:00',
      );
      await repository.updateHabit(updated);
      final afterUpdate = await repository.getHabitById('hab_read_1');
      expect(afterUpdate!.name, 'Read 20 Pages');
      expect(afterUpdate.reminderTime, '21:00');

      // Archive
      await repository.archiveHabit('hab_read_1', true);
      final activeList = await repository.getHabits(includeArchived: false);
      expect(activeList.any((h) => h.id == 'hab_read_1'), isFalse);

      final fullList = await repository.getHabits(includeArchived: true);
      expect(fullList.any((h) => h.id == 'hab_read_1'), isTrue);

      // Restore
      await repository.archiveHabit('hab_read_1', false);
      final restoredList = await repository.getHabits(includeArchived: false);
      expect(restoredList.any((h) => h.id == 'hab_read_1'), isTrue);
    });

    test('Completion tracking, duplicate prevention, and undo', () async {
      final habit = Habit(
        id: 'hab_comp_1',
        name: 'Morning Stretch',
        scheduleType: 'daily',
        createdAt: DateTime(2026, 10, 20),
      );
      await repository.createHabit(habit);

      // Complete on 2026-10-21
      await repository.completeHabit('hab_comp_1', '2026-10-21');
      var completions = await repository.getCompletionsForHabit('hab_comp_1');
      expect(completions.length, 1);
      expect(completions.first.completionDate, '2026-10-21');

      // Prevent duplicate completion (UNIQUE constraint ignores duplicate without throwing)
      await repository.completeHabit('hab_comp_1', '2026-10-21');
      completions = await repository.getCompletionsForHabit('hab_comp_1');
      expect(completions.length, 1);

      // Complete another date
      await repository.completeHabit('hab_comp_1', '2026-10-22');
      completions = await repository.getCompletionsForHabit('hab_comp_1');
      expect(completions.length, 2);

      // Undo completion for 2026-10-21 without deleting 2026-10-22
      await repository.undoCompletion('hab_comp_1', '2026-10-21');
      completions = await repository.getCompletionsForHabit('hab_comp_1');
      expect(completions.length, 1);
      expect(completions.first.completionDate, '2026-10-22');
    });

    test('Toggle completion status switches correctly', () async {
      final habit = Habit(
        id: 'hab_toggle',
        name: 'Check Budget',
        scheduleType: 'daily',
        createdAt: DateTime(2026, 10, 20),
      );
      await repository.createHabit(habit);

      // Toggle 1: should mark completed -> true
      final res1 = await repository.toggleCompletion(
        'hab_toggle',
        '2026-10-25',
      );
      expect(res1, isTrue);

      var dates = await repository.getAllCompletionDatesForHabit('hab_toggle');
      expect(dates.contains('2026-10-25'), isTrue);

      // Toggle 2: should undo -> false
      final res2 = await repository.toggleCompletion(
        'hab_toggle',
        '2026-10-25',
      );
      expect(res2, isFalse);

      dates = await repository.getAllCompletionDatesForHabit('hab_toggle');
      expect(dates.contains('2026-10-25'), isFalse);
    });

    test(
      'Delete habit cascades and cleanly removes completion history',
      () async {
        final habit = Habit(
          id: 'hab_del',
          name: 'Journal',
          scheduleType: 'daily',
          createdAt: DateTime(2026, 10, 20),
        );
        await repository.createHabit(habit);
        await repository.completeHabit('hab_del', '2026-10-20');
        await repository.completeHabit('hab_del', '2026-10-21');

        // Verify completions exist
        var comps = await repository.getCompletionsForHabit('hab_del');
        expect(comps.length, 2);

        // Delete habit
        await repository.deleteHabit('hab_del');

        final fetched = await repository.getHabitById('hab_del');
        expect(fetched, isNull);

        comps = await repository.getCompletionsForHabit('hab_del');
        expect(comps, isEmpty);
      },
    );

    test('Daily progress calculation returns correct ratio', () async {
      final habit1 = Habit(
        id: 'h_prog_1',
        name: 'Habit 1',
        scheduleType: 'daily',
        createdAt: DateTime(2026, 10, 20),
      );
      final habit2 = Habit(
        id: 'h_prog_2',
        name: 'Habit 2',
        scheduleType: 'daily',
        createdAt: DateTime(2026, 10, 20),
      );
      await repository.createHabit(habit1);
      await repository.createHabit(habit2);

      // Complete habit1 on 2026-10-28
      await repository.completeHabit('h_prog_1', '2026-10-28');

      final progress = await repository.getDailyProgress(
        DateTime(2026, 10, 28),
      );
      expect(progress.scheduledCount, 2);
      expect(progress.completedCount, 1);
      expect(progress.completionRate, 0.5);
    });
  });
}
