import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mind_and_money/core/theme/app_theme.dart';
import 'package:mind_and_money/features/finance/models/category.dart';
import 'package:mind_and_money/features/finance/models/transaction.dart';
import 'package:mind_and_money/features/finance/presentation/bank_statement_import_sheet.dart';
import 'package:mind_and_money/features/finance/providers/transaction_providers.dart';
import 'package:mind_and_money/features/finance/repositories/transaction_repository.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

class FakeTransactionRepository implements TransactionRepository {
  final List<FinancialTransaction> stored = [];

  @override
  Future<void> createTransactions(
    List<FinancialTransaction> transactions,
  ) async {
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
        id: 'cat_shopping',
        name: 'Shopping',
        icon: 'shopping_bag',
        color: 0xFFFFB74D,
        type: 'expense',
        createdAt: now,
      ),
      Category(
        id: 'cat_salary',
        name: 'Salary',
        icon: 'payments',
        color: 0xFF81C784,
        type: 'income',
        createdAt: now,
      ),
    ];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Uint8List _generateSamplePdfBytes() {
  final document = PdfDocument();
  final page = document.pages.add();

  const sampleStatement = '''
AXIS BANK STATEMENT
01/11/2026 UPI/ZOMATO/49102 450.00
02/11/2026 POS AMAZON SHOPPING 1,299.00
03/11/2026 SALARY CREDIT CORP 45,000.00 CR
''';

  page.graphics.drawString(
    sampleStatement,
    PdfStandardFont(PdfFontFamily.helvetica, 12),
  );

  final bytes = document.saveSync();
  document.dispose();
  return Uint8List.fromList(bytes);
}

void main() {
  late FakeTransactionRepository fakeRepo;

  setUp(() {
    fakeRepo = FakeTransactionRepository();
  });

  Widget buildTestWidget({
    Uint8List? preloadedPdfBytes,
    String? preloadedFileName,
    Size viewport = const Size(390, 844),
  }) {
    return ProviderScope(
      overrides: [
        transactionRepositoryProvider.overrideWithValue(fakeRepo),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: MediaQuery(
          data: MediaQueryData(size: viewport),
          child: Scaffold(
            body: BankStatementImportSheet(
              preloadedPdfBytes: preloadedPdfBytes,
              preloadedFileName: preloadedFileName,
            ),
          ),
        ),
      ),
    );
  }

  group('BankStatementImportSheet Widget Tests', () {
    testWidgets('Renders empty upload prompt with offline compatibility badges', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('BANK STATEMENT PDF'), findsOneWidget);
      expect(find.text('SELECT BANK STATEMENT PDF'), findsOneWidget);
      expect(find.text('BROWSE FILES'), findsOneWidget);
      expect(find.text('OFFLINE COMPATIBILITY'), findsOneWidget);
      expect(find.text('HDFC Bank'), findsOneWidget);
      expect(find.text('State Bank of India'), findsOneWidget);
      expect(find.text('Axis Bank'), findsOneWidget);
    });

    testWidgets('Parses preloaded PDF bytes and renders statement review table', (
      tester,
    ) async {
      final pdfBytes = _generateSamplePdfBytes();

      await tester.pumpWidget(
        buildTestWidget(
          preloadedPdfBytes: pdfBytes,
          preloadedFileName: 'axis_nov_statement.pdf',
        ),
      );
      await tester.pumpAndSettle();

      // Check detected bank and filename
      expect(find.text('AXIS BANK'), findsOneWidget);
      expect(find.text('axis_nov_statement.pdf'), findsOneWidget);

      // Check extracted items
      expect(find.textContaining('Zomato'), findsOneWidget);
      expect(find.textContaining('Amazon'), findsOneWidget);
      expect(find.text('Salary Credit Corp'), findsOneWidget);

      // Check commit bar
      expect(find.text('3 OF 3 SELECTED'), findsOneWidget);
      expect(find.text('IMPORT (3)'), findsOneWidget);
    });

    testWidgets('Batch imports transactions into repository on tap', (
      tester,
    ) async {
      final pdfBytes = _generateSamplePdfBytes();

      await tester.pumpWidget(
        buildTestWidget(
          preloadedPdfBytes: pdfBytes,
          preloadedFileName: 'axis_nov_statement.pdf',
        ),
      );
      await tester.pumpAndSettle();

      // Tap the Import button
      await tester.tap(find.text('IMPORT (3)'));
      await tester.pumpAndSettle();

      expect(fakeRepo.stored, hasLength(3));
      expect(fakeRepo.stored[0].amount.cents, 45000);
      expect(fakeRepo.stored[1].amount.cents, 129900);
      expect(fakeRepo.stored[2].amount.cents, 4500000);
      expect(fakeRepo.stored[2].type, TransactionType.income);
    });

    testWidgets('Supports Wearable screen sizes without layout overflow', (
      tester,
    ) async {
      final pdfBytes = _generateSamplePdfBytes();

      await tester.pumpWidget(
        buildTestWidget(
          preloadedPdfBytes: pdfBytes,
          preloadedFileName: 'stmt.pdf',
          viewport: const Size(200, 200), // Smartwatch screen
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('BANK STATEMENT PDF'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
