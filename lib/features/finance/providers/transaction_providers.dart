import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../home/providers/home_providers.dart';
import '../models/category.dart';
import '../models/transaction.dart';
import '../repositories/transaction_repository.dart';

enum DateRangePreset {
  thisMonth('This Month'),
  thisWeek('This Week'),
  today('Today'),
  allTime('All Time'),
  custom('Custom');

  final String label;
  const DateRangePreset(this.label);
}

class TransactionFilterState {
  final DateRangePreset preset;
  final DateTime? customStartDate;
  final DateTime? customEndDate;
  final TransactionType? type;
  final String? categoryId;
  final String searchQuery;
  final TransactionSortOrder sortOrder;

  const TransactionFilterState({
    this.preset = DateRangePreset.thisMonth,
    this.customStartDate,
    this.customEndDate,
    this.type,
    this.categoryId,
    this.searchQuery = '',
    this.sortOrder = TransactionSortOrder.dateDesc,
  });

  TransactionFilterState copyWith({
    DateRangePreset? preset,
    DateTime? customStartDate,
    DateTime? customEndDate,
    TransactionType? type,
    bool clearType = false,
    String? categoryId,
    bool clearCategory = false,
    String? searchQuery,
    TransactionSortOrder? sortOrder,
  }) {
    return TransactionFilterState(
      preset: preset ?? this.preset,
      customStartDate: customStartDate ?? this.customStartDate,
      customEndDate: customEndDate ?? this.customEndDate,
      type: clearType ? null : (type ?? this.type),
      categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
      searchQuery: searchQuery ?? this.searchQuery,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  /// Calculates effective start date
  DateTime? get effectiveStartDate {
    final now = DateTime.now();
    switch (preset) {
      case DateRangePreset.today:
        return DateTime(now.year, now.month, now.day, 0, 0, 0);
      case DateRangePreset.thisWeek:
        final weekday = now.weekday; // 1 = Monday
        final monday = now.subtract(Duration(days: weekday - 1));
        return DateTime(monday.year, monday.month, monday.day, 0, 0, 0);
      case DateRangePreset.thisMonth:
        return DateTime(now.year, now.month, 1, 0, 0, 0);
      case DateRangePreset.allTime:
        return null;
      case DateRangePreset.custom:
        return customStartDate;
    }
  }

  /// Calculates effective end date
  DateTime? get effectiveEndDate {
    final now = DateTime.now();
    switch (preset) {
      case DateRangePreset.today:
        return DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
      case DateRangePreset.thisWeek:
        final weekday = now.weekday;
        final sunday = now.add(Duration(days: 7 - weekday));
        return DateTime(sunday.year, sunday.month, sunday.day, 23, 59, 59, 999);
      case DateRangePreset.thisMonth:
        final nextMonth = DateTime(now.year, now.month + 1, 1);
        final lastDay = nextMonth.subtract(const Duration(days: 1));
        return DateTime(
          lastDay.year,
          lastDay.month,
          lastDay.day,
          23,
          59,
          59,
          999,
        );
      case DateRangePreset.allTime:
        return null;
      case DateRangePreset.custom:
        return customEndDate;
    }
  }
}

class TransactionFilterNotifier extends Notifier<TransactionFilterState> {
  @override
  TransactionFilterState build() => const TransactionFilterState();

  void setPreset(DateRangePreset preset) {
    state = state.copyWith(preset: preset);
  }

  void setCustomRange(DateTime start, DateTime end) {
    state = state.copyWith(
      preset: DateRangePreset.custom,
      customStartDate: start,
      customEndDate: end,
    );
  }

  void setType(TransactionType? type) {
    if (type == null) {
      state = state.copyWith(clearType: true);
    } else {
      state = state.copyWith(type: type);
    }
  }

  void setCategory(String? categoryId) {
    if (categoryId == null || categoryId.isEmpty) {
      state = state.copyWith(clearCategory: true);
    } else {
      state = state.copyWith(categoryId: categoryId);
    }
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void setSortOrder(TransactionSortOrder sort) {
    state = state.copyWith(sortOrder: sort);
  }

  void resetFilters() {
    state = const TransactionFilterState();
  }
}

/// Transaction repository provider
final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  final database = ref.watch(appDatabaseProvider);
  return TransactionRepository(database);
});

/// Filter state notifier provider
final transactionFilterProvider =
    NotifierProvider<TransactionFilterNotifier, TransactionFilterState>(
      TransactionFilterNotifier.new,
    );

/// Filtered transactions provider responding to filter changes
final filteredTransactionsProvider =
    FutureProvider.autoDispose<List<FinancialTransaction>>((ref) async {
      final repo = ref.watch(transactionRepositoryProvider);
      final filter = ref.watch(transactionFilterProvider);

      return repo.getTransactions(
        startDate: filter.effectiveStartDate,
        endDate: filter.effectiveEndDate,
        type: filter.type,
        categoryId: filter.categoryId,
        searchQuery: filter.searchQuery,
        sort: filter.sortOrder,
      );
    });

/// Categories provider optionally filtered by type
final categoriesProvider = FutureProvider.autoDispose
    .family<List<Category>, String?>((ref, type) async {
      final repo = ref.watch(transactionRepositoryProvider);
      return repo.getCategories(type: type);
    });

/// Period totals provider (Income, Expense, Net) for current filter date range
final periodTotalsProvider = FutureProvider.autoDispose<PeriodTotals>((
  ref,
) async {
  final repo = ref.watch(transactionRepositoryProvider);
  final filter = ref.watch(transactionFilterProvider);

  return repo.getPeriodTotals(
    startDate: filter.effectiveStartDate,
    endDate: filter.effectiveEndDate,
  );
});

/// Controls active subtab in Money screen: 0: Transactions, 1: Budgets, 2: Savings, 3: Reports
class MoneySubTabNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void setSubTab(int index) => state = index;
}

final moneySubTabProvider = NotifierProvider<MoneySubTabNotifier, int>(
  MoneySubTabNotifier.new,
);
