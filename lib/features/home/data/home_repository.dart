import '../../../core/database/app_database.dart';
import '../../../core/database/tables.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/money.dart';
import '../../habits/models/habit.dart';
import '../../wellness/models/mood_entry.dart';

/// Aggregated data object for the Home Dashboard
class HomeSummary {
  final DateTime selectedMonth;
  final Money monthlyIncome;
  final Money monthlyExpense;
  final Money netBalance;
  final Money? monthlyBudget;
  final Money? remainingBudget;
  final double? budgetUsedFraction;
  final int totalSavingsTargetCents;
  final int totalSavedCents;
  final MoodEntry? todayMood;
  final List<Habit> todayHabits;
  final int completedHabitsCount;
  final int totalHabitsCount;
  final String insightMessage;

  const HomeSummary({
    required this.selectedMonth,
    required this.monthlyIncome,
    required this.monthlyExpense,
    required this.netBalance,
    this.monthlyBudget,
    this.remainingBudget,
    this.budgetUsedFraction,
    required this.totalSavingsTargetCents,
    required this.totalSavedCents,
    this.todayMood,
    required this.todayHabits,
    required this.completedHabitsCount,
    required this.totalHabitsCount,
    required this.insightMessage,
  });

  bool get hasTransactions => !monthlyIncome.isZero || !monthlyExpense.isZero;
  bool get hasBudget => monthlyBudget != null && monthlyBudget!.isPositive;
  bool get hasSavingsGoals => totalSavingsTargetCents > 0;
  bool get hasHabits => totalHabitsCount > 0;
  bool get isMoodLoggedToday => todayMood != null;
}

/// Repository responsible for loading real dashboard data from SQLite
class HomeRepository {
  final AppDatabase _database;

  HomeRepository(this._database);

  /// Loads home summary for the given month (defaults to current date)
  Future<HomeSummary> getHomeSummary([DateTime? targetDate]) async {
    final now = targetDate ?? DateTime.now();
    final db = await _database.database;

    final startOfMonth = AppDateUtils.startOfMonth(now).toIso8601String();
    final endOfMonth = AppDateUtils.endOfMonth(now).toIso8601String();
    final monthYearStr = AppDateUtils.toIsoMonth(now);
    final todayStr = AppDateUtils.toIsoDate(now);

    // 1. Calculate Monthly Income and Expenses
    final transResult = await db.rawQuery(
      '''
      SELECT 
        type, 
        COALESCE(SUM(amount_cents), 0) AS total_cents
      FROM ${DbTables.transactions}
      WHERE transaction_date >= ? AND transaction_date <= ?
      GROUP BY type
      ''',
      [startOfMonth, endOfMonth],
    );

    int incomeCents = 0;
    int expenseCents = 0;

    for (final row in transResult) {
      final type = row['type'] as String?;
      final total = (row['total_cents'] as num?)?.toInt() ?? 0;
      if (type == 'income') {
        incomeCents = total;
      } else if (type == 'expense') {
        expenseCents = total;
      }
    }

    final income = Money(incomeCents);
    final expense = Money(expenseCents);
    final net = income - expense;

    // 2. Monthly Budget check
    final budgetResult = await db.query(
      DbTables.budgets,
      where: 'month_year = ?',
      whereArgs: [monthYearStr],
    );

    Money? totalBudget;
    Money? remainingBudget;
    double? budgetFraction;

    if (budgetResult.isNotEmpty) {
      int totalBudgetCents = 0;
      final overallRow = budgetResult
          .where((r) => r['category_id'] == null)
          .firstOrNull;
      if (overallRow != null) {
        totalBudgetCents = (overallRow['amount_cents'] as int? ?? 0);
      } else {
        for (final row in budgetResult) {
          totalBudgetCents += (row['amount_cents'] as int? ?? 0);
        }
      }
      if (totalBudgetCents > 0) {
        totalBudget = Money(totalBudgetCents);
        final remainingCents = totalBudgetCents - expenseCents;
        remainingBudget = Money(remainingCents);
        budgetFraction = (expenseCents / totalBudgetCents).clamp(0.0, 1.5);
      }
    }

    // 3. Savings Goals totals
    final savingsResult = await db.rawQuery('''
      SELECT 
        COALESCE(SUM(target_amount_cents), 0) AS target_total,
        COALESCE(SUM(current_amount_cents), 0) AS current_total
      FROM ${DbTables.savingsGoals}
      ''');

    int savingsTarget = 0;
    int savingsCurrent = 0;
    if (savingsResult.isNotEmpty) {
      savingsTarget =
          (savingsResult.first['target_total'] as num?)?.toInt() ?? 0;
      savingsCurrent =
          (savingsResult.first['current_total'] as num?)?.toInt() ?? 0;
    }

    // 4. Today's Mood check
    final moodResult = await db.query(
      DbTables.moodEntries,
      where: 'entry_date = ?',
      whereArgs: [todayStr],
      orderBy: 'created_at DESC',
      limit: 1,
    );

    MoodEntry? todayMood;
    if (moodResult.isNotEmpty) {
      todayMood = MoodEntry.fromMap(moodResult.first);
    }

    // 5. Habits & Completions for today
    final activeHabitsResult = await db.query(
      DbTables.habits,
      where: 'is_archived = 0',
      orderBy: 'created_at ASC',
    );

    final completionsResult = await db.query(
      DbTables.habitCompletions,
      where: 'completion_date = ?',
      whereArgs: [todayStr],
    );

    final completedHabitIds = completionsResult
        .map((row) => row['habit_id'] as String)
        .toSet();

    final List<Habit> todayHabits = [];
    int completedCount = 0;

    // Filter habits scheduled for today
    final weekday = now.weekday; // 1 (Mon) to 7 (Sun)
    for (final row in activeHabitsResult) {
      final habit = Habit.fromMap(
        row,
        isCompletedToday: completedHabitIds.contains(row['id'] as String),
      );

      // Check schedule
      bool isDueToday = false;
      if (habit.scheduleType == 'daily') {
        isDueToday = true;
      } else if (habit.scheduleDays != null) {
        final days = habit.scheduleDays!
            .split(',')
            .map((s) => int.tryParse(s.trim()))
            .whereType<int>();
        if (days.contains(weekday)) {
          isDueToday = true;
        }
      } else {
        isDueToday = true;
      }

      if (isDueToday) {
        todayHabits.add(habit);
        if (habit.isCompletedToday) {
          completedCount++;
        }
      }
    }

    // 6. Generate honest, data-backed insights
    final insight = _generateHonestInsight(
      income: income,
      expense: expense,
      budget: totalBudget,
      remainingBudget: remainingBudget,
      mood: todayMood,
      habitsCount: todayHabits.length,
      completedHabitsCount: completedCount,
    );

    return HomeSummary(
      selectedMonth: now,
      monthlyIncome: income,
      monthlyExpense: expense,
      netBalance: net,
      monthlyBudget: totalBudget,
      remainingBudget: remainingBudget,
      budgetUsedFraction: budgetFraction,
      totalSavingsTargetCents: savingsTarget,
      totalSavedCents: savingsCurrent,
      todayMood: todayMood,
      todayHabits: todayHabits,
      completedHabitsCount: completedCount,
      totalHabitsCount: todayHabits.length,
      insightMessage: insight,
    );
  }

  /// Generates non-judgmental, purely evidence-based insights
  String _generateHonestInsight({
    required Money income,
    required Money expense,
    required Money? budget,
    required Money? remainingBudget,
    required MoodEntry? mood,
    required int habitsCount,
    required int completedHabitsCount,
  }) {
    if (income.isZero && expense.isZero && mood == null && habitsCount == 0) {
      return 'Welcome to Mind & Money. Start tracking your expenses and daily reflections to build lasting clarity.';
    }

    if (budget != null && remainingBudget != null) {
      if (remainingBudget.isNegative) {
        return 'Monthly budget limit reached. Review recent expenses in the Money tab to plan upcoming needs.';
      } else if (expense.cents > (budget.cents * 0.85)) {
        return 'You have used over 85% of your planned monthly budget. Remaining: ${remainingBudget.format()}.';
      }
    }

    if (habitsCount > 0 && completedHabitsCount == habitsCount) {
      return 'All daily habits completed for today. Well done on staying consistent.';
    }

    if (mood != null && (expense.isPositive || income.isPositive)) {
      return 'Mind and money logged for today. Daily awareness supports balanced financial and emotional choices.';
    }

    if (expense.isPositive) {
      return 'Total expenses recorded this month: ${expense.format()}. Track category breakdowns to identify patterns.';
    }

    return 'Take a quiet moment to reflect on your daily priorities and spending intentions.';
  }

  /// Toggle habit completion for a specific date
  Future<void> toggleHabitCompletion(String habitId, String dateStr) async {
    final db = await _database.database;

    final existing = await db.query(
      DbTables.habitCompletions,
      where: 'habit_id = ? AND completion_date = ?',
      whereArgs: [habitId, dateStr],
    );

    if (existing.isNotEmpty) {
      await db.delete(
        DbTables.habitCompletions,
        where: 'habit_id = ? AND completion_date = ?',
        whereArgs: [habitId, dateStr],
      );
    } else {
      await db.insert(DbTables.habitCompletions, {
        'id': 'comp_${DateTime.now().microsecondsSinceEpoch}',
        'habit_id': habitId,
        'completion_date': dateStr,
        'completed_at': DateTime.now().toIso8601String(),
      });
    }
  }

  /// Quick record mood rating
  Future<void> recordQuickMood(int rating, [String? note]) async {
    final db = await _database.database;
    final now = DateTime.now();
    final todayStr = AppDateUtils.toIsoDate(now);
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';

    await db.insert(DbTables.moodEntries, {
      'id': 'mood_${now.microsecondsSinceEpoch}',
      'entry_date': todayStr,
      'entry_time': timeStr,
      'rating': rating,
      'emotion_labels': null,
      'stress_rating': null,
      'energy_rating': null,
      'sleep_rating': null,
      'note': note,
      'created_at': now.toIso8601String(),
    });
  }
}
