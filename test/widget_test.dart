import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mind_and_money/app.dart';
import 'package:mind_and_money/core/utils/money.dart';
import 'package:mind_and_money/features/home/data/home_repository.dart';
import 'package:mind_and_money/features/home/providers/home_providers.dart';

void main() {
  testWidgets('Renders Mind & Money navigation and empty dashboard state', (
    WidgetTester tester,
  ) async {
    // Set standard phone viewport size so dashboard cards fit comfortably
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final mockSummary = HomeSummary(
      selectedMonth: DateTime(2026, 10, 26),
      monthlyIncome: const Money(0),
      monthlyExpense: const Money(0),
      netBalance: const Money(0),
      totalSavingsTargetCents: 0,
      totalSavedCents: 0,
      todayHabits: const [],
      completedHabitsCount: 0,
      totalHabitsCount: 0,
      insightMessage: 'Welcome to Mind & Money. Start tracking your expenses and daily reflections.',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          homeSummaryProvider.overrideWith((ref) async => mockSummary),
        ],
        child: const MindAndMoneyApp(),
      ),
    );

    // Pump to resolve future and render widgets
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Verify 5 navigation destinations exist
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Money'), findsOneWidget);
    expect(find.text('Mind'), findsOneWidget);
    expect(find.text('Habits'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);

    // Verify Home Dashboard elements
    expect(find.text('Mind & Money'), findsOneWidget);
    expect(find.text('Financial Summary'), findsOneWidget);
    expect(find.text('Net Balance'), findsOneWidget);
    expect(
      find.text('₹0.00'),
      findsNWidgets(3),
    ); // Net balance, Income, Expense
    expect(find.text('Add Expense'), findsOneWidget);
    expect(find.text('Add Income'), findsOneWidget);
    expect(find.text('Transactions'), findsOneWidget);
    expect(find.text('Budgets'), findsOneWidget);
    expect(find.text('Mental Wellness'), findsOneWidget);
    expect(find.text("Today's Habits"), findsOneWidget);
    expect(find.text('Daily Insight'), findsOneWidget);

    // Test Navigation to Settings tab
    await tester.tap(find.text('Settings'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Default Currency'), findsOneWidget);
    expect(find.text('Theme Mode'), findsOneWidget);
    expect(find.text('100% Offline & Private'), findsOneWidget);
  });
}
