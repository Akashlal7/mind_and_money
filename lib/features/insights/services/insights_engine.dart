import '../../../core/utils/date_utils.dart';
import '../../../core/utils/money.dart';
import '../../finance/models/budget.dart';
import '../../finance/models/savings_goal.dart';
import '../../finance/models/transaction.dart';
import '../../habits/models/habit.dart';
import '../../habits/models/habit_stats.dart';
import '../../wellness/models/mood_entry.dart';
import '../models/deterministic_insight.dart';

/// Pure, deterministic local insights calculation engine.
///
/// Adheres strictly to:
/// - Evidence-based observations only (backed by saved records).
/// - Minimum sample-size thresholds to prevent misleading conclusions.
/// - Neutral, non-judgmental wording without guilt, pressure, or medical claims.
/// - No external network, remote AI, or cloud dependencies.
class InsightsEngine {
  const InsightsEngine();

  /// Evaluates habit consistency and streaks
  List<DeterministicInsight> evaluateHabits({
    required List<Habit> habits,
    required Map<String, HabitStats> statsMap,
  }) {
    final insights = <DeterministicInsight>[];

    for (final habit in habits) {
      if (habit.isArchived) continue;
      final stats = statsMap[habit.id];
      if (stats == null) continue;

      // Threshold: at least 7 scheduled days elapsed
      if (stats.totalScheduledDays >= 7 && stats.completionRate >= 0.70) {
        insights.add(
          DeterministicInsight(
            id: 'habit_consistency_${habit.id}',
            category: InsightCategory.habits,
            type: InsightType.observation,
            title: 'Habit Consistency',
            message:
                'You completed "${habit.name}" on ${stats.totalCompletions} of ${stats.totalScheduledDays} scheduled days (${stats.completionPercentage}%).',
            icon: 'check_circle_rounded',
            color: 0xFF4CAF50,
          ),
        );
      }

      // Streak observation (at least 3 days)
      if (stats.currentStreak >= 3) {
        insights.add(
          DeterministicInsight(
            id: 'habit_streak_${habit.id}',
            category: InsightCategory.habits,
            type: InsightType.observation,
            title: 'Current Habit Streak',
            message:
                'You have maintained a ${stats.currentStreak}-day active streak for "${habit.name}".',
            icon: 'local_fire_department_rounded',
            color: 0xFFFF9800,
          ),
        );
      }
    }

    return insights;
  }

  /// Evaluates expense tracking frequency over the past 14 days
  List<DeterministicInsight> evaluateExpenseConsistency({
    required List<FinancialTransaction> recentExpenses,
    required DateTime asOfDate,
  }) {
    final insights = <DeterministicInsight>[];
    final cutoff = asOfDate.subtract(const Duration(days: 14));

    final distinctDays = recentExpenses
        .where((t) => t.isExpense && !t.transactionDate.isBefore(cutoff))
        .map((t) => AppDateUtils.toIsoDate(t.transactionDate))
        .toSet();

    // Threshold: at least 5 days recorded out of the past 14
    if (distinctDays.length >= 5) {
      insights.add(
        DeterministicInsight(
          id: 'expense_tracking_consistency',
          category: InsightCategory.spending,
          type: InsightType.observation,
          title: 'Expense Tracking Consistency',
          message:
              'You recorded expenses on ${distinctDays.length} of the last 14 days.',
          icon: 'receipt_long_rounded',
          color: 0xFF2196F3,
        ),
      );
    }

    return insights;
  }

  /// Evaluates month-over-month spending comparisons
  List<DeterministicInsight> evaluateSpendingComparison({
    required List<FinancialTransaction> currentMonthExpenses,
    required List<FinancialTransaction> previousMonthExpenses,
    required String currencySymbol,
  }) {
    final insights = <DeterministicInsight>[];

    // Threshold: at least 3 expense records in each month
    if (currentMonthExpenses.length < 3 || previousMonthExpenses.length < 3) {
      return insights;
    }

    final currentTotal = currentMonthExpenses.fold<Money>(
      const Money.zero(),
      (sum, t) => sum + t.amount,
    );
    final prevTotal = previousMonthExpenses.fold<Money>(
      const Money.zero(),
      (sum, t) => sum + t.amount,
    );

    if (currentTotal > prevTotal && prevTotal.isPositive) {
      final diff = currentTotal - prevTotal;
      insights.add(
        DeterministicInsight(
          id: 'spending_mom_higher',
          category: InsightCategory.spending,
          type: InsightType.observation,
          title: 'Monthly Spending Trend',
          message:
              'Recorded spending this month ($currencySymbol${currentTotal.format()}) is higher than last month ($currencySymbol${prevTotal.format()}) by $currencySymbol${diff.format()}.',
          icon: 'trending_up_rounded',
          color: 0xFFE57373,
        ),
      );
    } else if (currentTotal < prevTotal && currentTotal.isPositive) {
      final diff = prevTotal - currentTotal;
      insights.add(
        DeterministicInsight(
          id: 'spending_mom_lower',
          category: InsightCategory.spending,
          type: InsightType.observation,
          title: 'Monthly Spending Trend',
          message:
              'Recorded spending this month ($currencySymbol${currentTotal.format()}) is $currencySymbol${diff.format()} lower than last month ($currencySymbol${prevTotal.format()}).',
          icon: 'trending_down_rounded',
          color: 0xFF81C784,
        ),
      );
    }

    return insights;
  }

  /// Evaluates savings goal funding progress
  List<DeterministicInsight> evaluateSavingsGoals({
    required List<SavingsGoal> goals,
    required String currencySymbol,
  }) {
    final insights = <DeterministicInsight>[];

    for (final goal in goals) {
      // Threshold: at least 25% progress and goal not zero
      if (goal.targetAmount.isPositive && goal.percentage >= 25) {
        insights.add(
          DeterministicInsight(
            id: 'savings_progress_${goal.id}',
            category: InsightCategory.savings,
            type: InsightType.observation,
            title: 'Savings Progress',
            message:
                'You have funded ${goal.percentage}% of your "${goal.name}" target ($currencySymbol${goal.currentAmount.format()} of $currencySymbol${goal.targetAmount.format()}).',
            icon: 'savings_rounded',
            color: 0xFF64B5F6,
          ),
        );
      }
    }

    return insights;
  }

  /// Evaluates budget utilization
  List<DeterministicInsight> evaluateBudgets({
    required List<BudgetStatus> budgetStatuses,
    required String currencySymbol,
  }) {
    final insights = <DeterministicInsight>[];

    for (final status in budgetStatuses) {
      if (status.percentageUsed >= 85) {
        final categoryName = status.budget.categoryName ?? 'Overall';
        insights.add(
          DeterministicInsight(
            id: 'budget_limit_${status.budget.id}',
            category: InsightCategory.budget,
            type: InsightType.observation,
            title: 'Budget Alert',
            message:
                'You have reached ${status.percentageUsed}% of your monthly $categoryName budget limit ($currencySymbol${status.spent.format()} of $currencySymbol${status.budget.amount.format()}).',
            icon: 'warning_amber_rounded',
            color: 0xFFFFB74D,
          ),
        );
      }
    }

    return insights;
  }

  /// Evaluates mindfulness check-ins and breathing session activity
  List<DeterministicInsight> evaluateWellness({
    required List<MoodEntry> recentMoods,
    required int breathingMinutes,
    required int completedBreathingSessions,
    required int recentJournalCount,
  }) {
    final insights = <DeterministicInsight>[];

    // Threshold: at least 3 mood logs in 7 days
    if (recentMoods.length >= 3) {
      insights.add(
        DeterministicInsight(
          id: 'wellness_mood_logs',
          category: InsightCategory.wellness,
          type: InsightType.observation,
          title: 'Mood Reflection Activity',
          message:
              'You recorded ${recentMoods.length} emotional check-ins over the past week.',
          icon: 'mood_rounded',
          color: 0xFFBA68C8,
        ),
      );
    }

    // Threshold: at least 2 breathing sessions
    if (completedBreathingSessions >= 2) {
      insights.add(
        DeterministicInsight(
          id: 'wellness_breathing_activity',
          category: InsightCategory.wellness,
          type: InsightType.observation,
          title: 'Mindful Breathing',
          message:
              'You completed $completedBreathingSessions breathing sessions totaling $breathingMinutes minutes.',
          icon: 'air_rounded',
          color: 0xFF4DB6AC,
        ),
      );
    }

    return insights;
  }
}
