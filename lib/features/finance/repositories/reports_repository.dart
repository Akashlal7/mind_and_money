import 'package:intl/intl.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/tables.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/money.dart';
import '../models/report_data.dart';

/// Repository that calculates real financial analytics, chart data sets,
/// and screen reader summaries from persisted SQLite records.
class ReportsRepository {
  final AppDatabase _database;

  ReportsRepository(this._database);

  /// Generates a complete financial report for the specified date range.
  Future<FinancialReportSummary> getFinancialReport({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final db = await _database.database;
    final startIso = AppDateUtils.startOfDay(startDate).toIso8601String();
    final endIso = AppDateUtils.endOfDay(endDate).toIso8601String();

    // 1. Total Income and Total Expense in period
    final totalsResult = await db.rawQuery(
      '''
      SELECT 
        type, 
        COALESCE(SUM(amount_cents), 0) AS total_cents
      FROM ${DbTables.transactions}
      WHERE transaction_date >= ? AND transaction_date <= ?
      GROUP BY type
      ''',
      [startIso, endIso],
    );

    int incomeCents = 0;
    int expenseCents = 0;
    for (final row in totalsResult) {
      final type = row['type'] as String?;
      final total = (row['total_cents'] as num?)?.toInt() ?? 0;
      if (type == 'income') {
        incomeCents = total;
      } else if (type == 'expense') {
        expenseCents = total;
      }
    }

    final totalIncome = Money(incomeCents);
    final totalExpense = Money(expenseCents);

    // 2. Category-wise expense breakdown
    final categoryResult = await db.rawQuery(
      '''
      SELECT 
        t.category_id,
        COALESCE(c.name, 'Uncategorized') AS category_name,
        COALESCE(c.icon, 'category') AS category_icon,
        COALESCE(c.color, 4287661230) AS category_color, -- 0xFF90A4AE
        COALESCE(SUM(t.amount_cents), 0) AS total_cents
      FROM ${DbTables.transactions} t
      LEFT JOIN ${DbTables.categories} c ON t.category_id = c.id
      WHERE t.type = 'expense'
        AND t.transaction_date >= ?
        AND t.transaction_date <= ?
      GROUP BY t.category_id
      ORDER BY total_cents DESC
      ''',
      [startIso, endIso],
    );

    final List<CategoryExpenseBreakdown> categoryBreakdown = [];
    for (final row in categoryResult) {
      final cents = (row['total_cents'] as num?)?.toInt() ?? 0;
      final percentage = expenseCents > 0
          ? ((cents / expenseCents) * 100.0)
          : 0.0;

      categoryBreakdown.add(
        CategoryExpenseBreakdown(
          categoryId: row['category_id'] as String? ?? '',
          categoryName: row['category_name'] as String,
          categoryIcon: row['category_icon'] as String,
          categoryColor: (row['category_color'] as num?)?.toInt() ?? 0xFF90A4AE,
          amount: Money(cents),
          percentage: percentage,
        ),
      );
    }

    // 3. Spending Trends: 6-month historical lookback ending at endDate
    final List<SpendingTrendPoint> spendingTrends = [];
    final monthFormat = DateFormat('MMM yy');

    for (int i = 5; i >= 0; i--) {
      // Calculate each month relative to endDate
      final yearMonthDate = DateTime(endDate.year, endDate.month - i, 1);
      final mStart = AppDateUtils.startOfMonth(yearMonthDate).toIso8601String();
      final mEnd = AppDateUtils.endOfMonth(yearMonthDate).toIso8601String();
      final mKey = AppDateUtils.toIsoMonth(yearMonthDate);
      final mLabel = monthFormat.format(yearMonthDate);

      final monthQueryResult = await db.rawQuery(
        '''
        SELECT 
          type, 
          COALESCE(SUM(amount_cents), 0) AS total_cents
        FROM ${DbTables.transactions}
        WHERE transaction_date >= ? AND transaction_date <= ?
        GROUP BY type
        ''',
        [mStart, mEnd],
      );

      int mIncome = 0;
      int mExpense = 0;
      for (final row in monthQueryResult) {
        final type = row['type'] as String?;
        final sum = (row['total_cents'] as num?)?.toInt() ?? 0;
        if (type == 'income') {
          mIncome = sum;
        } else if (type == 'expense') {
          mExpense = sum;
        }
      }

      spendingTrends.add(
        SpendingTrendPoint(
          monthYear: mKey,
          label: mLabel,
          expenseAmount: Money(mExpense),
          incomeAmount: Money(mIncome),
        ),
      );
    }

    // 4. Budget Utilization for the target month
    final targetMonthYear = AppDateUtils.toIsoMonth(endDate);
    final budgetRows = await db.rawQuery(
      '''
      SELECT 
        b.id,
        b.category_id,
        b.amount_cents,
        c.name AS category_name,
        c.color AS category_color
      FROM ${DbTables.budgets} b
      LEFT JOIN ${DbTables.categories} c ON b.category_id = c.id
      WHERE b.month_year = ?
      ORDER BY CASE WHEN b.category_id IS NULL THEN 0 ELSE 1 END, c.name ASC
      ''',
      [targetMonthYear],
    );

    final List<BudgetUtilizationItem> budgetUtilizations = [];
    if (budgetRows.isNotEmpty) {
      final startOfTargetMonth = AppDateUtils.startOfMonth(endDate)
          .toIso8601String();
      final endOfTargetMonth = AppDateUtils.endOfMonth(endDate)
          .toIso8601String();

      // Overall monthly expense
      final targetMonthOverallResult = await db.rawQuery(
        '''
        SELECT COALESCE(SUM(amount_cents), 0) AS total_cents
        FROM ${DbTables.transactions}
        WHERE type = 'expense'
          AND transaction_date >= ?
          AND transaction_date <= ?
        ''',
        [startOfTargetMonth, endOfTargetMonth],
      );
      final targetOverallExpenseCents =
          (targetMonthOverallResult.first['total_cents'] as num?)?.toInt() ?? 0;

      // Category spending for target month
      final targetCatResult = await db.rawQuery(
        '''
        SELECT category_id, COALESCE(SUM(amount_cents), 0) AS total_cents
        FROM ${DbTables.transactions}
        WHERE type = 'expense'
          AND transaction_date >= ?
          AND transaction_date <= ?
        GROUP BY category_id
        ''',
        [startOfTargetMonth, endOfTargetMonth],
      );
      final Map<String, int> catSpent = {};
      for (final row in targetCatResult) {
        final cid = row['category_id'] as String?;
        if (cid != null) {
          catSpent[cid] = (row['total_cents'] as num?)?.toInt() ?? 0;
        }
      }

      for (final row in budgetRows) {
        final catId = row['category_id'] as String?;
        final budgetCents = row['amount_cents'] as int;
        final spentCents = catId == null
            ? targetOverallExpenseCents
            : (catSpent[catId] ?? 0);
        final title = catId == null
            ? 'Overall Monthly Budget'
            : (row['category_name'] as String? ?? 'Category Budget');
        final color = (row['category_color'] as num?)?.toInt();
        final pct = budgetCents > 0
            ? ((spentCents / budgetCents) * 100).round()
            : 0;

        budgetUtilizations.add(
          BudgetUtilizationItem(
            budgetId: row['id'] as String,
            title: title,
            categoryColor: color,
            budgetAmount: Money(budgetCents),
            spentAmount: Money(spentCents),
            percentage: pct,
          ),
        );
      }
    }

    return FinancialReportSummary(
      periodStart: startDate,
      periodEnd: endDate,
      totalIncome: totalIncome,
      totalExpense: totalExpense,
      categoryBreakdown: categoryBreakdown,
      spendingTrends: spendingTrends,
      budgetUtilizations: budgetUtilizations,
    );
  }
}
