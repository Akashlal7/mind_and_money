import '../../../core/utils/money.dart';

/// Data point for monthly income vs expense comparison.
class MonthlyComparisonData {
  final DateTime month;
  final Money income;
  final Money expense;

  const MonthlyComparisonData({
    required this.month,
    required this.income,
    required this.expense,
  });

  Money get net => income - expense;
}

/// Category spending share for pie/donut charts.
class CategoryExpenseBreakdown {
  final String categoryId;
  final String categoryName;
  final String categoryIcon;
  final int categoryColor;
  final Money amount;
  final double percentage; // 0.0 - 100.0

  const CategoryExpenseBreakdown({
    required this.categoryId,
    required this.categoryName,
    required this.categoryIcon,
    required this.categoryColor,
    required this.amount,
    required this.percentage,
  });
}

/// A monthly point in a longitudinal spending trend line/bar chart.
class SpendingTrendPoint {
  final String monthYear; // 'YYYY-MM'
  final String label; // 'Oct 26'
  final Money expenseAmount;
  final Money incomeAmount;

  const SpendingTrendPoint({
    required this.monthYear,
    required this.label,
    required this.expenseAmount,
    required this.incomeAmount,
  });
}

/// Budget vs actual spending item for utilization reports.
class BudgetUtilizationItem {
  final String budgetId;
  final String title;
  final int? categoryColor;
  final Money budgetAmount;
  final Money spentAmount;
  final int percentage;

  const BudgetUtilizationItem({
    required this.budgetId,
    required this.title,
    this.categoryColor,
    required this.budgetAmount,
    required this.spentAmount,
    required this.percentage,
  });

  bool get isOverBudget => spentAmount.cents > budgetAmount.cents;
}

/// Complete aggregated financial report for a chosen time boundary.
class FinancialReportSummary {
  final DateTime periodStart;
  final DateTime periodEnd;
  final Money totalIncome;
  final Money totalExpense;
  final List<CategoryExpenseBreakdown> categoryBreakdown;
  final List<SpendingTrendPoint> spendingTrends;
  final List<BudgetUtilizationItem> budgetUtilizations;

  const FinancialReportSummary({
    required this.periodStart,
    required this.periodEnd,
    required this.totalIncome,
    required this.totalExpense,
    required this.categoryBreakdown,
    required this.spendingTrends,
    required this.budgetUtilizations,
  });

  Money get netSavings => totalIncome - totalExpense;

  double get savingsRate {
    if (totalIncome.cents <= 0) return 0.0;
    if (netSavings.cents <= 0) return 0.0;
    return (netSavings.cents / totalIncome.cents) * 100.0;
  }

  bool get isEmpty => totalIncome.isZero && totalExpense.isZero;

  /// Concise text summary designed specifically for screen readers and accessibility.
  String get screenReaderSummary {
    if (isEmpty) {
      return 'No financial records found for the selected period.';
    }
    final buffer = StringBuffer();
    buffer.write(
      'Financial report. Total income is ${totalIncome.format()}, '
      'total expense is ${totalExpense.format()}. '
      'Net result is ${netSavings.format()}. ',
    );
    if (categoryBreakdown.isNotEmpty) {
      final topCat = categoryBreakdown.first;
      buffer.write(
        'Top spending category is ${topCat.categoryName} at '
        '${topCat.amount.format()}, which accounts for ${topCat.percentage.toStringAsFixed(1)} percent of expenses. ',
      );
    }
    if (budgetUtilizations.isNotEmpty) {
      final overBudgetCount = budgetUtilizations
          .where((b) => b.isOverBudget)
          .length;
      if (overBudgetCount > 0) {
        buffer.write('$overBudgetCount budget limits exceeded. ');
      } else {
        buffer.write('All active budgets are within limits. ');
      }
    }
    return buffer.toString().trim();
  }
}
