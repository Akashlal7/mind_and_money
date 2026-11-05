import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:mind_and_money/core/database/app_database.dart';
import 'package:mind_and_money/core/database/tables.dart';
import 'package:mind_and_money/core/utils/money.dart';
import 'package:mind_and_money/features/finance/models/budget.dart';
import 'package:mind_and_money/features/finance/models/savings_goal.dart';
import 'package:mind_and_money/features/finance/models/transaction.dart';
import 'package:mind_and_money/features/finance/presentation/budgets_view.dart';
import 'package:mind_and_money/features/finance/presentation/money_screen.dart';
import 'package:mind_and_money/features/finance/presentation/reports_view.dart';
import 'package:mind_and_money/features/finance/presentation/savings_view.dart';
import 'package:mind_and_money/features/finance/repositories/budget_repository.dart';
import 'package:mind_and_money/features/finance/repositories/savings_repository.dart';
import 'package:mind_and_money/features/finance/repositories/transaction_repository.dart';
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
        version: 2,
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
          for (final cat in DbTables.defaultCategories) {
            batch.insert(DbTables.categories, cat);
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

  testWidgets(
    'BudgetsView renders empty state and active overall budget card',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.runAsync(() async {
        final bgtRepo = BudgetRepository(appDatabase);
        final now = DateTime.now();
        final monthStr = '${now.year}-${now.month.toString().padLeft(2, '0')}';

        // Insert an overall budget
        await bgtRepo.saveBudget(
          Budget(
            id: 'bgt_widget_overall',
            categoryId: null,
            amount: const Money(1500000), // ₹15,000
            monthYear: monthStr,
            createdAt: now,
            updatedAt: now,
          ),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [appDatabaseProvider.overrideWithValue(appDatabase)],
            child: const MaterialApp(home: BudgetsView()),
          ),
        );

        await tester.pump();
        await Future.delayed(const Duration(milliseconds: 150));
        await tester.pump();

        expect(find.text('Overall Monthly Limit'), findsOneWidget);
        expect(find.text('Set Budget'), findsOneWidget);
      });
    },
  );

  testWidgets(
    'SavingsView renders cumulative portfolio banner and goal cards',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.runAsync(() async {
        final savingsRepo = SavingsRepository(appDatabase);
        await savingsRepo.createSavingsGoal(
          SavingsGoal(
            id: 'goal_trip',
            name: 'Mountain Trek',
            targetAmount: const Money(2000000), // ₹20,000
            currentAmount: const Money.zero(),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          initialDeposit: const Money(500000), // ₹5,000
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [appDatabaseProvider.overrideWithValue(appDatabase)],
            child: const MaterialApp(home: SavingsView()),
          ),
        );

        await tester.pump();
        await Future.delayed(const Duration(milliseconds: 150));
        await tester.pump();

        expect(find.text('Total Savings Portfolio'), findsOneWidget);
        expect(find.text('Mountain Trek'), findsOneWidget);
        expect(find.text('New Goal'), findsOneWidget);
      });
    },
  );

  testWidgets('ReportsView renders Income vs Expenses and Category sections', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.runAsync(() async {
      final transRepo = TransactionRepository(appDatabase);
      final now = DateTime.now();

      await transRepo.createTransaction(
        FinancialTransaction(
          id: 'tx_rep_inc',
          amount: const Money(4000000),
          type: TransactionType.income,
          categoryId: 'cat_salary',
          transactionDate: now,
          createdAt: now,
          updatedAt: now,
        ),
      );

      await transRepo.createTransaction(
        FinancialTransaction(
          id: 'tx_rep_exp',
          amount: const Money(1500000),
          type: TransactionType.expense,
          categoryId: 'cat_groceries',
          transactionDate: now,
          createdAt: now,
          updatedAt: now,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [appDatabaseProvider.overrideWithValue(appDatabase)],
          child: const MaterialApp(home: ReportsView()),
        ),
      );

      await tester.pump();
      await Future.delayed(const Duration(milliseconds: 200));
      await tester.pump();

      expect(find.text('Income vs. Expenses'), findsOneWidget);
      expect(find.text('Expense Breakdown by Category'), findsOneWidget);
      expect(find.text('Spending Trend (Last 6 Months)'), findsOneWidget);

      // Verify X-axis trend month labels are rendered exactly once without duplicate smearing
      final currentMonthLabel = DateFormat('MMM yy').format(now);
      expect(find.text(currentMonthLabel), findsOneWidget);
    });
  });

  testWidgets(
    'MoneyScreen TabBar is scrollable and displays full "Transactions" label without clipping',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.runAsync(() async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [appDatabaseProvider.overrideWithValue(appDatabase)],
            child: const MaterialApp(home: MoneyScreen()),
          ),
        );
        await tester.pump();
        await Future.delayed(const Duration(milliseconds: 300));
        await tester.pump();

        final tabBarFinder = find.byType(TabBar);
        expect(tabBarFinder, findsOneWidget);
        final tabBar = tester.widget<TabBar>(tabBarFinder);
        expect(tabBar.isScrollable, isTrue);
        expect(tabBar.tabAlignment, TabAlignment.start);
        expect(find.text('Transactions'), findsOneWidget);
        expect(find.text('Budgets'), findsOneWidget);
        expect(find.text('Savings'), findsOneWidget);
        expect(find.text('Reports'), findsOneWidget);
      });
    },
  );
}
