import '../../../core/database/app_database.dart';
import '../../../core/database/tables.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/money.dart';
import '../models/budget.dart';

/// Repository managing SQLite persistence and financial calculations for monthly budgets.
class BudgetRepository {
  final AppDatabase _database;

  BudgetRepository(this._database);

  /// Retrieves all budgets (overall and category-specific) for the given month,
  /// joined with their actual expense spending for that month.
  Future<List<BudgetStatus>> getBudgetsForMonth(String monthYear) async {
    final db = await _database.database;

    // Determine start and end date boundaries for the given month
    final parsed = _parseMonthYear(monthYear);
    final startOfMonth = AppDateUtils.startOfMonth(parsed).toIso8601String();
    final endOfMonth = AppDateUtils.endOfMonth(parsed).toIso8601String();

    // 1. Fetch budgets for the month with category details
    final budgetRows = await db.rawQuery(
      '''
      SELECT 
        b.id,
        b.category_id,
        b.amount_cents,
        b.month_year,
        b.created_at,
        b.updated_at,
        c.name AS category_name,
        c.icon AS category_icon,
        c.color AS category_color
      FROM ${DbTables.budgets} b
      LEFT JOIN ${DbTables.categories} c ON b.category_id = c.id
      WHERE b.month_year = ?
      ORDER BY 
        CASE WHEN b.category_id IS NULL THEN 0 ELSE 1 END,
        c.name ASC
      ''',
      [monthYear],
    );

    if (budgetRows.isEmpty) {
      return [];
    }

    // 2. Fetch total overall expense spending for the month
    final overallResult = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(amount_cents), 0) AS total_cents
      FROM ${DbTables.transactions}
      WHERE type = 'expense'
        AND transaction_date >= ?
        AND transaction_date <= ?
      ''',
      [startOfMonth, endOfMonth],
    );
    final overallSpentCents =
        (overallResult.first['total_cents'] as num?)?.toInt() ?? 0;

    // 3. Fetch category-wise expense spending for the month
    final categoryResult = await db.rawQuery(
      '''
      SELECT 
        category_id,
        COALESCE(SUM(amount_cents), 0) AS total_cents
      FROM ${DbTables.transactions}
      WHERE type = 'expense'
        AND transaction_date >= ?
        AND transaction_date <= ?
      GROUP BY category_id
      ''',
      [startOfMonth, endOfMonth],
    );

    final Map<String, int> categorySpentMap = {};
    for (final row in categoryResult) {
      final catId = row['category_id'] as String?;
      final spent = (row['total_cents'] as num?)?.toInt() ?? 0;
      if (catId != null) {
        categorySpentMap[catId] = spent;
      }
    }

    // 4. Construct BudgetStatus objects with accurate spent figures
    final List<BudgetStatus> results = [];
    for (final row in budgetRows) {
      final budget = Budget.fromMap(row);
      final spentCents = budget.isOverall
          ? overallSpentCents
          : (categorySpentMap[budget.categoryId] ?? 0);

      results.add(BudgetStatus(budget: budget, spent: Money(spentCents)));
    }

    return results;
  }

  /// Retrieves the overall budget status for the given month, if configured.
  Future<BudgetStatus?> getOverallBudget(String monthYear) async {
    final budgets = await getBudgetsForMonth(monthYear);
    for (final status in budgets) {
      if (status.budget.isOverall) {
        return status;
      }
    }
    return null;
  }

  /// Creates a new budget or replaces an existing budget for the same category and month.
  Future<void> saveBudget(Budget budget) async {
    final db = await _database.database;
    final now = DateTime.now();

    // Check if a budget already exists for this category/overall in the given month
    String whereClause;
    List<dynamic> whereArgs;
    if (budget.categoryId == null) {
      whereClause = 'category_id IS NULL AND month_year = ?';
      whereArgs = [budget.monthYear];
    } else {
      whereClause = 'category_id = ? AND month_year = ?';
      whereArgs = [budget.categoryId, budget.monthYear];
    }

    final existing = await db.query(
      DbTables.budgets,
      where: whereClause,
      whereArgs: whereArgs,
      limit: 1,
    );

    if (existing.isNotEmpty) {
      // Update existing budget
      final existingId = existing.first['id'] as String;
      await db.update(
        DbTables.budgets,
        {
          'amount_cents': budget.amount.cents,
          'updated_at': now.toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [existingId],
      );
    } else {
      // Insert new budget
      await db.insert(DbTables.budgets, budget.toMap());
    }
  }

  /// Deletes a budget by its primary key ID.
  Future<void> deleteBudget(String budgetId) async {
    final db = await _database.database;
    await db.delete(DbTables.budgets, where: 'id = ?', whereArgs: [budgetId]);
  }

  /// Copies all budgets configured in [fromMonthYear] into [toMonthYear].
  /// Any existing budgets in [toMonthYear] with matching categories are overwritten.
  Future<int> copyBudgets({
    required String fromMonthYear,
    required String toMonthYear,
  }) async {
    final db = await _database.database;
    final sourceBudgets = await db.query(
      DbTables.budgets,
      where: 'month_year = ?',
      whereArgs: [fromMonthYear],
    );

    if (sourceBudgets.isEmpty) return 0;

    int copiedCount = 0;
    final now = DateTime.now();

    await db.transaction((txn) async {
      for (final row in sourceBudgets) {
        final categoryId = row['category_id'] as String?;
        final amountCents = row['amount_cents'] as int;

        // Check if destination month already has this budget
        String whereClause = categoryId == null
            ? 'category_id IS NULL AND month_year = ?'
            : 'category_id = ? AND month_year = ?';
        List<dynamic> whereArgs = categoryId == null
            ? [toMonthYear]
            : [categoryId, toMonthYear];

        final existing = await txn.query(
          DbTables.budgets,
          where: whereClause,
          whereArgs: whereArgs,
          limit: 1,
        );

        if (existing.isNotEmpty) {
          await txn.update(
            DbTables.budgets,
            {'amount_cents': amountCents, 'updated_at': now.toIso8601String()},
            where: 'id = ?',
            whereArgs: [existing.first['id'] as String],
          );
        } else {
          await txn.insert(DbTables.budgets, {
            'id': 'bgt_${now.microsecondsSinceEpoch}_$copiedCount',
            'category_id': categoryId,
            'amount_cents': amountCents,
            'month_year': toMonthYear,
            'created_at': now.toIso8601String(),
            'updated_at': now.toIso8601String(),
          });
        }
        copiedCount++;
      }
    });

    return copiedCount;
  }

  /// Returns all distinct months with budget records or transaction records,
  /// ordered newest first (e.g. ['2026-10', '2026-09']).
  Future<List<String>> getAvailableMonths() async {
    final db = await _database.database;

    final result = await db.rawQuery('''
      SELECT DISTINCT month_year FROM ${DbTables.budgets}
      UNION
      SELECT DISTINCT substr(transaction_date, 1, 7) AS month_year FROM ${DbTables.transactions}
      ORDER BY month_year DESC
    ''');

    final months = result
        .map((r) => r['month_year'] as String?)
        .whereType<String>()
        .where((m) => RegExp(r'^\d{4}-\d{2}$').hasMatch(m))
        .toList();

    // Ensure the current month is always present in the list
    final currentMonth = AppDateUtils.toIsoMonth(DateTime.now());
    if (!months.contains(currentMonth)) {
      months.insert(0, currentMonth);
      months.sort((a, b) => b.compareTo(a));
    }

    return months;
  }

  DateTime _parseMonthYear(String monthYear) {
    final parts = monthYear.split('-');
    if (parts.length == 2) {
      final y = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      if (y != null && m != null && m >= 1 && m <= 12) {
        return DateTime(y, m, 1);
      }
    }
    return DateTime.now();
  }
}
