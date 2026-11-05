import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mind_and_money/core/database/app_database.dart';
import 'package:mind_and_money/core/database/tables.dart';
import 'package:mind_and_money/features/home/providers/home_providers.dart';
import 'package:mind_and_money/features/wellness/data/journal_repository.dart';
import 'package:mind_and_money/features/wellness/data/mood_repository.dart';
import 'package:mind_and_money/features/wellness/models/journal_entry.dart';
import 'package:mind_and_money/features/wellness/models/mood_entry.dart';
import 'package:mind_and_money/features/wellness/presentation/breathing/breathing_exercise_screen.dart';
import 'package:mind_and_money/features/wellness/presentation/insights/wellness_insights_view.dart';
import 'package:mind_and_money/features/wellness/presentation/journal/journal_list_view.dart';
import 'package:mind_and_money/features/wellness/presentation/mind_screen.dart';
import 'package:mind_and_money/features/wellness/presentation/mood/mood_check_in_sheet.dart';
import 'package:mind_and_money/features/wellness/presentation/mood/mood_history_view.dart';
import 'package:mind_and_money/features/wellness/presentation/reflection/spending_reflection_sheet.dart';
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
        version: 3,
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
    await appDatabase.close();
  });

  Widget buildTestableWidget(Widget child) {
    return ProviderScope(
      overrides: [appDatabaseProvider.overrideWithValue(appDatabase)],
      child: MaterialApp(home: child),
    );
  }

  testWidgets('MindScreen renders tabs and Today overview elements', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.runAsync(() async {
      await tester.pumpWidget(buildTestableWidget(const MindScreen()));
      await tester.pump();
      await Future.delayed(const Duration(milliseconds: 150));
      await tester.pump();

      // Verify AppBar and Tab bar
      expect(find.text('Mental Wellness'), findsOneWidget);
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Mood History'), findsOneWidget);
      expect(find.text('Journal'), findsOneWidget);
      expect(find.text('Breathing'), findsOneWidget);
      expect(find.text('Insights'), findsOneWidget);

      // Verify Today tab content
      expect(find.text("Today's Mood"), findsOneWidget);
      expect(find.text('Daily Reflection Prompt'), findsOneWidget);
      expect(find.text('Guided Breathing Exercise'), findsOneWidget);
      expect(find.text('Reflect on this'), findsOneWidget);
    });
  });

  testWidgets(
    'MoodHistoryView renders and displays recorded check-in summary',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.runAsync(() async {
        final now = DateTime.now();
        final monthStr = "${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}";
        final entryDateStr = "$monthStr-15";

        // Seed mood check-in for current month
        final moodRepo = MoodRepository(appDatabase);
        await moodRepo.createMoodEntry(
          MoodEntry(
            id: 'mood_w_1',
            entryDate: entryDateStr,
            entryTime: '09:00:00',
            rating: 5,
            emotionLabels: 'Thriving,Grateful',
            createdAt: now,
          ),
        );

        await tester.pumpWidget(
          buildTestableWidget(const Scaffold(body: MoodHistoryView())),
        );
        await tester.pump();
        await Future.delayed(const Duration(milliseconds: 200));
        await tester.pump();

        expect(find.text(entryDateStr), findsOneWidget);
        expect(find.text('Thriving'), findsAtLeastNWidgets(1));
        expect(find.text('Grateful'), findsOneWidget);
      });
    },
  );

  testWidgets('JournalListView renders search field and filter chips', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.runAsync(() async {
      // Seed reflection and journal entry
      final journalRepo = JournalRepository(appDatabase);
      await journalRepo.createEntry(
        JournalEntry(
          id: 'jrn_test_w',
          title: 'Gratitude Reflection',
          content: 'I had a quiet evening with good tea.',
          entryDate: '2026-10-28',
          entryType: 'reflection',
          prompt: 'What went well today?',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      await tester.pumpWidget(
        buildTestableWidget(const Scaffold(body: JournalListView())),
      );
      await tester.pump();
      await Future.delayed(const Duration(milliseconds: 200));
      await tester.pump();

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Reflections'), findsOneWidget);
      expect(find.text('What went well today?'), findsOneWidget);
      expect(find.text('Write'), findsOneWidget); // FAB
    });
  });

  testWidgets('Breathing tab renders breathing circle and controls', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.runAsync(() async {
      await tester.pumpWidget(
        buildTestableWidget(const Scaffold(body: BreathingExerciseScreen())),
      );
      await tester.pump();
      await Future.delayed(const Duration(milliseconds: 200));
      await tester.pump();

      expect(find.text('Start Breathing Session'), findsOneWidget);
      expect(find.text('Select Breathing Technique'), findsOneWidget);
      expect(find.text('Box Breathing (4-4-4-4)'), findsOneWidget);
    });
  });

  testWidgets('Insights tab renders non-diagnostic disclaimer and metrics', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.runAsync(() async {
      await tester.pumpWidget(
        buildTestableWidget(const Scaffold(body: WellnessInsightsView())),
      );
      await tester.pump();
      await Future.delayed(const Duration(milliseconds: 200));
      await tester.pump();

      expect(find.text('Mood & Emotional State'), findsOneWidget);
      expect(find.text('Mindfulness & Reflections'), findsOneWidget);
      expect(
        find.textContaining(
          'These summaries describe only the entries you have saved locally',
        ),
        findsOneWidget,
      );
    });
  });

  testWidgets('MoodCheckInSheet validates and renders scale options', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.runAsync(() async {
      await tester.pumpWidget(
        buildTestableWidget(const Scaffold(body: MoodCheckInSheet())),
      );
      await tester.pump();
      await Future.delayed(const Duration(milliseconds: 150));
      await tester.pump();

      expect(find.text('How are you feeling right now?'), findsOneWidget);
      expect(find.text('Difficult'), findsOneWidget);
      expect(find.text('Thriving'), findsOneWidget);
      expect(find.text('Emotions & Feelings (Optional)'), findsOneWidget);
      expect(find.text('Save Mood Check-in'), findsOneWidget);
    });
  });

  testWidgets('SpendingReflectionSheet renders gentle, non-judgmental prompt', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.runAsync(() async {
      await tester.pumpWidget(
        buildTestableWidget(
          const Scaffold(
            body: SpendingReflectionSheet(
              transactionId: 'tx_w_test',
              transactionAmount: '₹500',
            ),
          ),
        ),
      );
      await tester.pump();
      await Future.delayed(const Duration(milliseconds: 150));
      await tester.pump();

      expect(find.text('Mindful Spending Reflection'), findsOneWidget);
      expect(
        find.text('Was this purchase planned in advance?'),
        findsOneWidget,
      );
      expect(find.text('Planned'), findsOneWidget);
      expect(find.text('Unplanned'), findsOneWidget);
      expect(find.text('Save Reflection'), findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);
    });
  });
}
