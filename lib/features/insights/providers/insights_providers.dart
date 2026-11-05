import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/date_utils.dart';
import '../../finance/providers/budget_providers.dart';
import '../../finance/providers/savings_providers.dart';
import '../../finance/providers/transaction_providers.dart';
import '../../habits/models/habit_stats.dart';
import '../../habits/providers/habit_providers.dart';
import '../../settings/providers/settings_provider.dart';
import '../../wellness/providers/wellness_providers.dart';
import '../models/deterministic_insight.dart';
import '../services/insights_engine.dart';

final insightsEngineProvider = Provider<InsightsEngine>((ref) {
  return const InsightsEngine();
});

/// Computes all valid deterministic insights based on persisted local records
final deterministicInsightsProvider =
    FutureProvider.autoDispose<List<DeterministicInsight>>((ref) async {
      final engine = ref.watch(insightsEngineProvider);
      final settings = ref.watch(settingsProvider);
      final currencySymbol = settings.currencySymbol;

      final habitRepo = ref.watch(habitRepositoryProvider);
      final transRepo = ref.watch(transactionRepositoryProvider);
      final budgetRepo = ref.watch(budgetRepositoryProvider);
      final savingsRepo = ref.watch(savingsRepositoryProvider);
      final moodRepo = ref.watch(moodRepositoryProvider);
      final breathingRepo = ref.watch(breathingRepositoryProvider);
      final journalRepo = ref.watch(journalRepositoryProvider);

      final now = DateTime.now();
      final currentMonthStr = AppDateUtils.toIsoMonth(now);
      final prevMonthDate = DateTime(now.year, now.month - 1);

      final allInsights = <DeterministicInsight>[];

      // 1. Habit Insights
      final activeHabits = await habitRepo.getHabits(includeArchived: false);
      final statsMap = <String, HabitStats>{};
      for (final habit in activeHabits) {
        statsMap[habit.id] = await habitRepo.getHabitStats(
          habit,
          asOfDate: now,
        );
      }
      allInsights.addAll(
        engine.evaluateHabits(habits: activeHabits, statsMap: statsMap),
      );

      // 2. Spending Consistency & Month-over-Month Comparisons
      final startOfCurrentMonth = AppDateUtils.startOfMonth(now);
      final endOfCurrentMonth = AppDateUtils.endOfMonth(now);
      final startOfPrevMonth = AppDateUtils.startOfMonth(prevMonthDate);
      final endOfPrevMonth = AppDateUtils.endOfMonth(prevMonthDate);

      final currentMonthTransactions = await transRepo.getTransactions(
        startDate: startOfCurrentMonth,
        endDate: endOfCurrentMonth,
      );
      final prevMonthTransactions = await transRepo.getTransactions(
        startDate: startOfPrevMonth,
        endDate: endOfPrevMonth,
      );

      allInsights.addAll(
        engine.evaluateExpenseConsistency(
          recentExpenses: currentMonthTransactions,
          asOfDate: now,
        ),
      );

      allInsights.addAll(
        engine.evaluateSpendingComparison(
          currentMonthExpenses: currentMonthTransactions
              .where((t) => t.isExpense)
              .toList(),
          previousMonthExpenses: prevMonthTransactions
              .where((t) => t.isExpense)
              .toList(),
          currencySymbol: currencySymbol,
        ),
      );

      // 3. Savings Goal Milestones
      final savingsGoals = await savingsRepo.getSavingsGoals();
      allInsights.addAll(
        engine.evaluateSavingsGoals(
          goals: savingsGoals,
          currencySymbol: currencySymbol,
        ),
      );

      // 4. Budget Tracking Limits
      final budgets = await budgetRepo.getBudgetsForMonth(currentMonthStr);
      allInsights.addAll(
        engine.evaluateBudgets(
          budgetStatuses: budgets,
          currencySymbol: currencySymbol,
        ),
      );

      // 5. Wellness & Mindfulness Check-ins
      final recentMoods = await moodRepo.getRecentEntries(limit: 10);
      final breathingStats = await breathingRepo.getBreathingStats();
      final recentJournals = await journalRepo.getEntries(limit: 10);

      allInsights.addAll(
        engine.evaluateWellness(
          recentMoods: recentMoods,
          breathingMinutes: breathingStats.totalMinutes,
          completedBreathingSessions: breathingStats.totalSessions,
          recentJournalCount: recentJournals.length,
        ),
      );

      return allInsights;
    });
