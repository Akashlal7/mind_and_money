import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/date_utils.dart';
import '../../home/providers/home_providers.dart';
import '../models/budget.dart';
import '../repositories/budget_repository.dart';

/// Provider exposing the BudgetRepository
final budgetRepositoryProvider = Provider<BudgetRepository>((ref) {
  final database = ref.watch(appDatabaseProvider);
  return BudgetRepository(database);
});

/// Holds the currently selected budget month string in 'YYYY-MM' format.
class BudgetMonthNotifier extends Notifier<String> {
  @override
  String build() {
    return AppDateUtils.toIsoMonth(DateTime.now());
  }

  void setMonth(String monthYear) {
    state = monthYear;
  }

  void setDate(DateTime date) {
    state = AppDateUtils.toIsoMonth(date);
  }
}

final selectedBudgetMonthProvider =
    NotifierProvider<BudgetMonthNotifier, String>(BudgetMonthNotifier.new);

/// List of all distinct months with transactions or budgets
final availableBudgetMonthsProvider = FutureProvider.autoDispose<List<String>>((
  ref,
) async {
  final repo = ref.watch(budgetRepositoryProvider);
  return await repo.getAvailableMonths();
});

/// Fetches all active budgets and spending calculations for the selected month
final monthlyBudgetsProvider = FutureProvider.autoDispose<List<BudgetStatus>>((
  ref,
) async {
  final repo = ref.watch(budgetRepositoryProvider);
  final selectedMonth = ref.watch(selectedBudgetMonthProvider);
  return await repo.getBudgetsForMonth(selectedMonth);
});

/// Fetches the overall monthly budget status for the selected month
final overallBudgetStatusProvider = FutureProvider.autoDispose<BudgetStatus?>((
  ref,
) async {
  final repo = ref.watch(budgetRepositoryProvider);
  final selectedMonth = ref.watch(selectedBudgetMonthProvider);
  return await repo.getOverallBudget(selectedMonth);
});
