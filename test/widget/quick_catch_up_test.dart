import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mind_and_money/core/theme/app_theme.dart';
import 'package:mind_and_money/features/finance/models/category.dart';
import 'package:mind_and_money/features/finance/models/transaction.dart';
import 'package:mind_and_money/features/finance/presentation/quick_catch_up_sheet.dart';
import 'package:mind_and_money/features/finance/providers/transaction_providers.dart';
import 'package:mind_and_money/features/finance/repositories/transaction_repository.dart';

class FakeTransactionRepository implements TransactionRepository {
  final List<FinancialTransaction> stored = [];

  @override
  Future<void> createTransactions(List<FinancialTransaction> transactions) async {
    stored.addAll(transactions);
  }

  @override
  Future<void> createTransaction(FinancialTransaction transaction) async {
    stored.add(transaction);
  }

  @override
  Future<List<Category>> getCategories({String? type}) async {
    final now = DateTime(2026, 11, 1);
    return [
      Category(
        id: 'cat_food',
        name: 'Food & Dining',
        icon: 'restaurant',
        color: 0xFFE57373,
        type: 'expense',
        createdAt: now,
      ),
      Category(
        id: 'cat_transport',
        name: 'Transport',
        icon: 'directions_car',
        color: 0xFF64B5F6,
        type: 'expense',
        createdAt: now,
      ),
    ];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late FakeTransactionRepository fakeRepo;

  setUp(() {
    fakeRepo = FakeTransactionRepository();
  });

  Widget buildTestWidget({Size viewport = const Size(390, 844)}) {
    return ProviderScope(
      overrides: [
        transactionRepositoryProvider.overrideWithValue(fakeRepo),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: MediaQuery(
          data: MediaQueryData(size: viewport),
          child: const Scaffold(
            body: QuickCatchUpSheet(),
          ),
        ),
      ),
    );
  }

  group('QuickCatchUpSheet Widget Tests', () {
    testWidgets('Renders empty state with 1-tap example chips', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('QUICK CATCH-UP'), findsOneWidget);
      expect(find.text('No items staged yet'), findsOneWidget);
      expect(find.text('+ Coffee 120'), findsOneWidget);
      expect(find.text('+ Uber 350 card'), findsOneWidget);
    });

    testWidgets('Tapping example chip stages transaction and shows commit bar', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Tap the Coffee 120 example chip
      await tester.tap(find.text('+ Coffee 120'));
      await tester.pumpAndSettle();

      expect(find.text('Coffee'), findsOneWidget);
      expect(find.text('1 ITEM STAGED'), findsOneWidget);
      expect(find.text('SAVE ALL (1)'), findsOneWidget);
    });

    testWidgets('Typing one-liner adds item and updates running total', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      final input = find.byType(TextField);
      await tester.enterText(input, 'Metro 40');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(find.text('Metro'), findsOneWidget);
      expect(find.text('1 ITEM STAGED'), findsOneWidget);

      // Add a second item
      await tester.enterText(input, 'Lunch 250');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(find.text('Metro'), findsOneWidget);
      expect(find.text('Lunch'), findsOneWidget);
      expect(find.text('2 ITEMS STAGED'), findsOneWidget);
      expect(find.text('SAVE ALL (2)'), findsOneWidget);
    });

    testWidgets('Deleting staged item removes it and updates count', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('+ Coffee 120'));
      await tester.pumpAndSettle();
      expect(find.text('1 ITEM STAGED'), findsOneWidget);

      // Tap delete
      await tester.tap(find.byIcon(Icons.delete_outline_rounded));
      await tester.pumpAndSettle();

      expect(find.text('No items staged yet'), findsOneWidget);
    });

    testWidgets('Commit button writes all staged items to repository', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('+ Coffee 120'));
      await tester.pumpAndSettle();

      final input = find.byType(TextField);
      await tester.enterText(input, 'Lunch 250');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(fakeRepo.stored, isEmpty);

      // Tap Save All (2)
      await tester.tap(find.text('SAVE ALL (2)'));
      await tester.pumpAndSettle();

      expect(fakeRepo.stored, hasLength(2));
      expect(fakeRepo.stored[0].description, 'Coffee');
      expect(fakeRepo.stored[0].amount.cents, 12000);
      expect(fakeRepo.stored[1].description, 'Lunch');
      expect(fakeRepo.stored[1].amount.cents, 25000);
    });

    testWidgets('Renders on 240x280 smartwatch viewport without overflow', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(240, 280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestWidget(viewport: const Size(240, 280)));
      await tester.pumpAndSettle();

      expect(find.text('QUICK CATCH-UP'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
