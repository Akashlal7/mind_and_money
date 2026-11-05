import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mind_and_money/core/database/app_database.dart';
import 'package:mind_and_money/core/database/tables.dart';
import 'package:mind_and_money/features/habits/data/habit_repository.dart';
import 'package:mind_and_money/features/habits/models/habit.dart';
import 'package:mind_and_money/features/habits/presentation/habits_screen.dart';
import 'package:mind_and_money/features/home/providers/home_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    SharedPreferences.setMockInitialValues({});
  });

  late AppDatabase appDatabase;
  late Database rawDb;

  setUp(() async {
    appDatabase = AppDatabase();
    rawDb = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
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
          for (final idx in DbTables.createIndexes) {
            batch.execute(idx);
          }
          await batch.commit();
        },
      ),
    );
    appDatabase.setDatabaseForTesting(rawDb);
  });

  tearDown(() async {
    await rawDb.close();
  });

  Widget buildTestableWidget(Widget child) {
    return ProviderScope(
      overrides: [appDatabaseProvider.overrideWithValue(appDatabase)],
      child: MaterialApp(home: child),
    );
  }

  testWidgets(
    'HabitsScreen renders tabs and empty state when no habits exist',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.runAsync(() async {
        await tester.pumpWidget(buildTestableWidget(const HabitsScreen()));
        await tester.pump();
        await Future.delayed(const Duration(milliseconds: 150));
        await tester.pump();

        expect(find.text('Habits & Consistency'), findsOneWidget);
        expect(find.text('Today'), findsOneWidget);
        expect(find.text('All Active'), findsOneWidget);
        expect(find.text('Insights'), findsOneWidget);
        expect(find.text('Archived'), findsOneWidget);
        expect(find.text('No habits due today'), findsOneWidget);
        expect(find.text('New Habit'), findsOneWidget); // FAB
      });
    },
  );

  testWidgets('HabitsScreen displays seeded habit and toggles completion', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.runAsync(() async {
      final repo = HabitRepository(appDatabase);
      await repo.createHabit(
        Habit(
          id: 'hab_w_1',
          name: 'Read Financial News',
          scheduleType: 'daily',
          createdAt: DateTime.now(),
        ),
      );

      await tester.pumpWidget(buildTestableWidget(const HabitsScreen()));
      await tester.pump();
      await Future.delayed(const Duration(milliseconds: 150));
      await tester.pump();

      expect(find.text('Read Financial News'), findsOneWidget);
      expect(find.text('Every day'), findsOneWidget);
      expect(find.byIcon(Icons.radio_button_unchecked_rounded), findsOneWidget);

      // Tap completion button
      await tester.tap(find.byIcon(Icons.radio_button_unchecked_rounded));
      await tester.pump();
      await Future.delayed(const Duration(milliseconds: 250));
      await tester.pump();

      expect(find.byIcon(Icons.check_circle_rounded), findsAtLeastNWidgets(1));
    });
  });
}
