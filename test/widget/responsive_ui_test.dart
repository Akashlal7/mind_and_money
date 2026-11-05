import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mind_and_money/core/theme/app_theme.dart';
import 'package:mind_and_money/core/utils/money.dart';
import 'package:mind_and_money/core/widgets/financial_amount_text.dart';
import 'package:mind_and_money/features/finance/models/report_data.dart';
import 'package:mind_and_money/features/finance/presentation/reports_view.dart';
import 'package:mind_and_money/features/finance/providers/reports_providers.dart';
import 'package:mind_and_money/features/home/data/home_repository.dart';
import 'package:mind_and_money/features/home/presentation/home_screen.dart';
import 'package:mind_and_money/features/home/providers/home_providers.dart';
import 'package:mind_and_money/features/navigation/main_scaffold.dart';
import 'package:mind_and_money/features/wellness/presentation/breathing/breathing_exercise_screen.dart';

void main() {
  final mockSummary = HomeSummary(
    selectedMonth: DateTime(2026, 10, 26),
    monthlyIncome: const Money(4500000), // ₹45,000.00
    monthlyExpense: const Money(2350050), // ₹23,500.50
    netBalance: const Money(2149950), // ₹21,499.50
    totalSavingsTargetCents: 10000000, // ₹1,00,000.00
    totalSavedCents: 4500000, // ₹45,000.00
    todayHabits: const [],
    completedHabitsCount: 0,
    totalHabitsCount: 2,
    insightMessage:
        'Your savings rate this month is 48%, exceeding your baseline.',
  );

  final mockReportSummary = FinancialReportSummary(
    periodStart: DateTime(2026, 10, 1),
    periodEnd: DateTime(2026, 10, 31),
    totalIncome: const Money(5000000), // ₹50,000.00
    totalExpense: const Money(3200000), // ₹32,000.00
    categoryBreakdown: const [
      CategoryExpenseBreakdown(
        categoryId: 'cat_groceries',
        categoryName: 'Groceries & Dining',
        categoryIcon: 'restaurant',
        categoryColor: 0xFF2E7D32,
        amount: Money(2000000),
        percentage: 62.5,
      ),
      CategoryExpenseBreakdown(
        categoryId: 'cat_transport',
        categoryName: 'Transport & Fuel',
        categoryIcon: 'directions_car',
        categoryColor: 0xFF1976D2,
        amount: Money(1200000),
        percentage: 37.5,
      ),
    ],
    spendingTrends: const [
      SpendingTrendPoint(
        monthYear: '2026-05',
        label: 'May 26',
        expenseAmount: Money(2800000),
        incomeAmount: Money(4500000),
      ),
      SpendingTrendPoint(
        monthYear: '2026-06',
        label: 'Jun 26',
        expenseAmount: Money(3000000),
        incomeAmount: Money(4500000),
      ),
      SpendingTrendPoint(
        monthYear: '2026-07',
        label: 'Jul 26',
        expenseAmount: Money(2900000),
        incomeAmount: Money(4800000),
      ),
      SpendingTrendPoint(
        monthYear: '2026-08',
        label: 'Aug 26',
        expenseAmount: Money(3100000),
        incomeAmount: Money(5000000),
      ),
      SpendingTrendPoint(
        monthYear: '2026-09',
        label: 'Sep 26',
        expenseAmount: Money(3300000),
        incomeAmount: Money(5000000),
      ),
      SpendingTrendPoint(
        monthYear: '2026-10',
        label: 'Oct 26',
        expenseAmount: Money(3200000),
        incomeAmount: Money(5000000),
      ),
    ],
    budgetUtilizations: const [],
  );

  Widget createTestApp({
    ThemeMode themeMode = ThemeMode.light,
    TextScaler? textScaler,
    Size viewport = const Size(390, 844),
    HomeSummary? homeSummary,
  }) {
    return ProviderScope(
      overrides: [
        homeSummaryProvider.overrideWith((ref) async => homeSummary ?? mockSummary),
        financialReportProvider.overrideWith((ref) async => mockReportSummary),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: themeMode,
        home: MediaQuery(
          data: MediaQueryData(
            size: viewport,
            textScaler: textScaler ?? TextScaler.noScaling,
          ),
          child: const MainScaffold(),
        ),
      ),
    );
  }

  group('Adaptive Navigation & Breakpoints Tests', () {
    testWidgets(
      'Renders Bottom NavigationBar on screen width < 600px (360px)',
      (tester) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(createTestApp(viewport: const Size(360, 800)));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.byType(NavigationBar), findsOneWidget);
        expect(find.byType(NavigationRail), findsNothing);
      },
    );

    testWidgets(
      'Switches to NavigationRail on expanded width >= 600px (600px)',
      (tester) async {
        tester.view.physicalSize = const Size(600, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(createTestApp(viewport: const Size(600, 900)));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.byType(NavigationRail), findsOneWidget);
        expect(find.byType(NavigationBar), findsNothing);
      },
    );

    testWidgets('NavigationRail persists on large tablet width 800px', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createTestApp(viewport: const Size(800, 1200)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
    });
  });

  group('Responsive Viewport Width Tests without RenderFlex Overflows', () {
    final widthsToTest = [
      240.0,
      280.0,
      320.0,
      360.0,
      375.0,
      390.0,
      430.0,
      600.0,
      800.0,
    ];

    for (final width in widthsToTest) {
      testWidgets('Renders Home Dashboard at width $width without overflow', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(createTestApp(viewport: Size(width, 900)));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        final err = tester.takeException();
        expect(find.byType(HomeScreen), findsOneWidget);
        expect(err, isNull);
      });

      testWidgets('Renders ReportsView at width $width without overflow', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              financialReportProvider.overrideWith(
                (ref) async => mockReportSummary,
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: MediaQuery(
                data: MediaQueryData(size: Size(width, 900)),
                child: const Scaffold(body: ReportsView()),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        final err = tester.takeException();
        expect(find.byType(ReportsView), findsOneWidget);
        expect(err, isNull);
      });

      testWidgets(
        'Renders BreathingExerciseScreen at width $width without overflow',
        (tester) async {
          tester.view.physicalSize = Size(width, 900);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });

          await tester.pumpWidget(
            ProviderScope(
              child: MaterialApp(
                theme: AppTheme.lightTheme,
                home: MediaQuery(
                  data: MediaQueryData(size: Size(width, 900)),
                  child: const Scaffold(
                    body: BreathingExerciseScreen(showAppBar: false),
                  ),
                ),
              ),
            ),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));

          final err = tester.takeException();
          expect(find.byType(BreathingExerciseScreen), findsOneWidget);
          expect(err, isNull);
        },
      );
    }
  });

  group('Compact Screen Heights & Breathing Center Tests', () {
    testWidgets(
      'BreathingExerciseScreen renders cleanly on short viewport (width 320, height 600)',
      (tester) async {
        tester.view.physicalSize = const Size(320, 600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: const MediaQuery(
                data: MediaQueryData(size: Size(320, 600)),
                child: Scaffold(
                  body: BreathingExerciseScreen(showAppBar: false),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.byType(BreathingExerciseScreen), findsOneWidget);
        final exception = tester.takeException();
        if (exception != null) {
          // ignore: avoid_print
          print('DEBUG OVERFLOW DETAILS:\n$exception');
          if (exception is FlutterError) {
            for (final d in exception.diagnostics) {
              // ignore: avoid_print
              print('DIAGNOSTIC: ${d.value}');
            }
          }
        }
        expect(exception, isNull);
      },
    );
  });

  group('Large Text Scale (1.3x) & Accessibility Tests', () {
    testWidgets(
      'Renders Home Dashboard at 1.3x text scale without RenderFlex error',
      (tester) async {
        tester.view.physicalSize = const Size(360, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          createTestApp(
            viewport: const Size(360, 900),
            textScaler: const TextScaler.linear(1.3),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.byType(HomeScreen), findsOneWidget);
        final exception = tester.takeException();
        if (exception != null) {
          // ignore: avoid_print
          print('DEBUG OVERFLOW DETAILS:\n$exception');
          if (exception is FlutterError) {
            for (final d in exception.diagnostics) {
              // ignore: avoid_print
              print('DIAGNOSTIC: ${d.value}');
            }
          }
        }
        expect(exception, isNull);
      },
    );

    testWidgets(
      'Renders ReportsView at 1.3x text scale on narrow width without error',
      (tester) async {
        tester.view.physicalSize = const Size(320, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              financialReportProvider.overrideWith(
                (ref) async => mockReportSummary,
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: const MediaQuery(
                data: MediaQueryData(
                  size: Size(320, 800),
                  textScaler: TextScaler.linear(1.3),
                ),
                child: Scaffold(body: ReportsView()),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.byType(ReportsView), findsOneWidget);
        final exception = tester.takeException();
        if (exception != null) {
          // ignore: avoid_print
          print('DEBUG OVERFLOW DETAILS:\n$exception');
          if (exception is FlutterError) {
            for (final d in exception.diagnostics) {
              // ignore: avoid_print
              print('DIAGNOSTIC: ${d.value}');
            }
          }
        }
        expect(exception, isNull);
      },
    );

    testWidgets(
      'Renders BreathingExerciseScreen at 1.3x text scale without error',
      (tester) async {
        tester.view.physicalSize = const Size(320, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: const MediaQuery(
                data: MediaQueryData(
                  size: Size(320, 800),
                  textScaler: TextScaler.linear(1.3),
                ),
                child: Scaffold(
                  body: BreathingExerciseScreen(showAppBar: false),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.byType(BreathingExerciseScreen), findsOneWidget);
        final exception = tester.takeException();
        if (exception != null) {
          // ignore: avoid_print
          print('DEBUG OVERFLOW DETAILS:\n$exception');
          if (exception is FlutterError) {
            for (final d in exception.diagnostics) {
              // ignore: avoid_print
              print('DIAGNOSTIC: ${d.value}');
            }
          }
        }
        expect(exception, isNull);
      },
    );

    testWidgets(
      'FinancialAmountText renders direction icon and accessible semantics',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: FinancialAmountText(
                amount: const Money(1500000), // ₹15,000.00
                currencySymbol: '₹',
                type: FinancialAmountType.income,
                showIcon: true,
                showSign: true,
              ),
            ),
          ),
        );

        expect(find.byIcon(Icons.arrow_downward_rounded), findsOneWidget);
        expect(find.text('+₹15,000.00'), findsOneWidget);
        expect(
          find.byWidgetPredicate(
            (w) =>
                w is Semantics && w.properties.label == 'Income: +₹15,000.00',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'FinancialAmountText handles large currency values without clipping',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 120, // narrow container
                child: FinancialAmountText(
                  amount: const Money(-987654321), // -₹9,876,543.21
                  currencySymbol: '₹',
                  type: FinancialAmountType.expense,
                  showIcon: true,
                  showSign: true,
                ),
              ),
            ),
          ),
        );

        expect(find.byIcon(Icons.arrow_upward_rounded), findsOneWidget);
        expect(find.text('-₹9,876,543.21'), findsOneWidget);
        expect(
          find.byWidgetPredicate(
            (w) =>
                w is Semantics &&
                w.properties.label == 'Expense: -₹9,876,543.21',
          ),
          findsOneWidget,
        );
        final exception = tester.takeException();
        if (exception != null) {
          // ignore: avoid_print
          print('DEBUG OVERFLOW DETAILS:\n$exception');
          if (exception is FlutterError) {
            for (final d in exception.diagnostics) {
              // ignore: avoid_print
              print('DIAGNOSTIC: ${d.value}');
            }
          }
        }
        expect(exception, isNull);
      },
    );
  });

  group('Dark Theme Integration Tests', () {
    testWidgets('Renders Home Dashboard in Dark Theme cleanly', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        createTestApp(
          themeMode: ThemeMode.dark,
          viewport: const Size(390, 844),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Renders ReportsView in Dark Theme cleanly', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            financialReportProvider.overrideWith(
              (ref) async => mockReportSummary,
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: ThemeMode.dark,
            home: const Scaffold(body: ReportsView()),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(ReportsView), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Smartwatch Viewport & Extreme Length Amounts/Text Tests', () {
    testWidgets(
      'MainScaffold renders wearable-optimized bottom nav without overflow on 240x280',
      (tester) async {
        tester.view.physicalSize = const Size(240, 280);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(createTestApp(viewport: const Size(240, 280)));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(tester.takeException(), isNull);
        expect(find.byType(NavigationBar), findsOneWidget);
      },
    );

    testWidgets(
      'FinancialAmountText scales down trillions without clipping or overflow',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 80, // ultra-narrow smartwatch container
                child: FinancialAmountText(
                  amount: Money(999999999999), // ₹9,999,999,999.99
                  currencySymbol: '₹',
                  type: FinancialAmountType.income,
                  showIcon: true,
                  showSign: true,
                ),
              ),
            ),
          ),
        );

        expect(find.byType(FittedBox), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'HomeScreen renders with unlimited letter lengths on 240x280 smartwatch',
      (tester) async {
        tester.view.physicalSize = const Size(240, 280);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final hugeSummary = HomeSummary(
          selectedMonth: DateTime(2026, 11, 5),
          monthlyIncome: const Money(100000000000), // ₹1,00,00,00,000.00
          monthlyExpense: const Money(90000000000), // ₹90,00,00,000.00
          netBalance: const Money(10000000000), // ₹10,00,00,000.00
          monthlyBudget: const Money(95000000000),
          remainingBudget: const Money(5000000000),
          budgetUsedFraction: 0.947,
          totalSavingsTargetCents: 500000000000,
          totalSavedCents: 250000000000,
          todayHabits: const [],
          completedHabitsCount: 0,
          totalHabitsCount: 0,
          insightMessage:
              'This is an exceptionally long, unbounded analytical insight observation message to stress test extreme textual length on ultra-compact displays without RenderFlex overflows.',
        );

        await tester.pumpWidget(
          createTestApp(
            viewport: const Size(240, 280),
            homeSummary: hugeSummary,
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.byType(HomeScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
