import 'package:flutter_test/flutter_test.dart';
import 'package:mind_and_money/features/finance/models/transaction.dart';
import 'package:mind_and_money/features/finance/providers/transaction_providers.dart';
import 'package:mind_and_money/features/finance/repositories/transaction_repository.dart';

void main() {
  group('TransactionFilterState Tests', () {
    test('calculates effective start and end dates for This Month preset', () {
      const state = TransactionFilterState(preset: DateRangePreset.thisMonth);
      final start = state.effectiveStartDate;
      final end = state.effectiveEndDate;

      final now = DateTime.now();
      expect(start, isNotNull);
      expect(start!.year, now.year);
      expect(start.month, now.month);
      expect(start.day, 1);

      expect(end, isNotNull);
      expect(end!.year, now.year);
      expect(end.month, now.month);
      expect(end.hour, 23);
      expect(end.minute, 59);
    });

    test('calculates effective start and end dates for Today preset', () {
      const state = TransactionFilterState(preset: DateRangePreset.today);
      final start = state.effectiveStartDate;
      final end = state.effectiveEndDate;

      final now = DateTime.now();
      expect(start!.day, now.day);
      expect(start.hour, 0);

      expect(end!.day, now.day);
      expect(end.hour, 23);
    });

    test('allTime preset returns null dates to fetch entire history', () {
      const state = TransactionFilterState(preset: DateRangePreset.allTime);
      expect(state.effectiveStartDate, isNull);
      expect(state.effectiveEndDate, isNull);
    });

    test('custom preset returns user selected custom dates', () {
      final customStart = DateTime(2026, 5, 1);
      final customEnd = DateTime(2026, 6, 30);

      final state = TransactionFilterState(
        preset: DateRangePreset.custom,
        customStartDate: customStart,
        customEndDate: customEnd,
      );

      expect(state.effectiveStartDate, customStart);
      expect(state.effectiveEndDate, customEnd);
    });

    test('copyWith updates fields and allows clearing filters', () {
      var state = const TransactionFilterState();
      state = state.copyWith(
        type: TransactionType.expense,
        categoryId: 'cat_food',
        searchQuery: 'dinner',
        sortOrder: TransactionSortOrder.amountDesc,
      );

      expect(state.type, TransactionType.expense);
      expect(state.categoryId, 'cat_food');
      expect(state.searchQuery, 'dinner');
      expect(state.sortOrder, TransactionSortOrder.amountDesc);

      // Clear filters
      state = state.copyWith(clearType: true, clearCategory: true);
      expect(state.type, isNull);
      expect(state.categoryId, isNull);
    });
  });
}
