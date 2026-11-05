import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/responsive_layout.dart';
import '../../../../core/utils/date_utils.dart';
import '../../finance/models/transaction.dart';
import '../../finance/presentation/transaction_form_sheet.dart';
import '../../finance/providers/transaction_providers.dart';
import '../../habits/providers/habit_providers.dart';
import '../../insights/providers/insights_providers.dart';
import '../../navigation/navigation_provider.dart';
import '../../settings/providers/settings_provider.dart';
import '../providers/home_providers.dart';
import 'widgets/budget_progress_card.dart';
import 'widgets/dashboard_header.dart';
import 'widgets/financial_summary_card.dart';
import 'widgets/habits_snapshot_card.dart';
import 'widgets/insights_card.dart';
import 'widgets/quick_actions_row.dart';
import 'widgets/savings_progress_card.dart';
import 'widgets/wellness_snapshot_card.dart';

/// Redesigned Home Dashboard with prioritized hierarchy, responsive wrappers,
/// and smooth Riverpod data updates.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(homeSummaryProvider);
    final settings = ref.watch(settingsProvider);
    final padding = AppBreakpoints.screenPadding(context);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(homeSummaryProvider);
            await ref.read(homeSummaryProvider.future);
          },
          child: summaryAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      size: 48,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Failed to load dashboard',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      err.toString(),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => ref.invalidate(homeSummaryProvider),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
            data: (summary) {
              return ResponsiveContentWrapper(
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: padding.copyWith(bottom: 88),
                  children: [
                    // 1. Compact Header with App Identity & Current Date
                    DashboardHeader(date: summary.selectedMonth),
                    const SizedBox(height: 12),

                    // 2. Monthly Income, Expenses, and Balance Summary
                    FinancialSummaryCard(
                      summary: summary,
                      currencySymbol: settings.currencySymbol,
                    ),
                    const SizedBox(height: 12),

                    // 3. Primary Quick Actions
                    QuickActionsRow(
                      onAddExpense: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(20),
                            ),
                          ),
                          builder: (_) => const TransactionFormSheet(
                            initialType: TransactionType.expense,
                          ),
                        );
                      },
                      onAddIncome: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(20),
                            ),
                          ),
                          builder: (_) => const TransactionFormSheet(
                            initialType: TransactionType.income,
                          ),
                        );
                      },
                      onViewTransactions: () {
                        ref.read(moneySubTabProvider.notifier).setSubTab(0);
                        ref
                            .read(activeTabProvider.notifier)
                            .setTab(AppTab.money.index);
                      },
                      onViewBudgets: () {
                        ref.read(moneySubTabProvider.notifier).setSubTab(1);
                        ref
                            .read(activeTabProvider.notifier)
                            .setTab(AppTab.money.index);
                      },
                    ),
                    const SizedBox(height: 12),

                    // 4. Budget Progress
                    BudgetProgressCard(
                      summary: summary,
                      currencySymbol: settings.currencySymbol,
                      onViewBudgets: () {
                        ref.read(moneySubTabProvider.notifier).setSubTab(1);
                        ref
                            .read(activeTabProvider.notifier)
                            .setTab(AppTab.money.index);
                      },
                    ),
                    const SizedBox(height: 12),

                    // 5. Savings-Goal Progress
                    SavingsProgressCard(
                      summary: summary,
                      currencySymbol: settings.currencySymbol,
                      onViewSavings: () {
                        ref.read(moneySubTabProvider.notifier).setSubTab(2);
                        ref
                            .read(activeTabProvider.notifier)
                            .setTab(AppTab.money.index);
                      },
                    ),
                    const SizedBox(height: 14),

                    // 6. Today's Mood Check-in
                    WellnessSnapshotCard(
                      todayMood: summary.todayMood,
                      onOpenJournal: () {
                        ref
                            .read(activeTabProvider.notifier)
                            .setTab(AppTab.mind.index);
                      },
                    ),
                    const SizedBox(height: 14),

                    // 7. Today's Habits
                    HabitsSnapshotCard(
                      habits: summary.todayHabits,
                      completedCount: summary.completedHabitsCount,
                      totalCount: summary.totalHabitsCount,
                      onToggleHabit: (habit) async {
                        final repo = ref.read(homeRepositoryProvider);
                        final todayStr = AppDateUtils.toIsoDate(DateTime.now());
                        await repo.toggleHabitCompletion(habit.id, todayStr);
                        ref.invalidate(homeSummaryProvider);
                        ref.invalidate(activeHabitsProvider);
                        ref.invalidate(todayScheduledHabitsProvider);
                        ref.invalidate(todayHabitProgressProvider);
                        ref.invalidate(deterministicInsightsProvider);
                      },
                      onManageHabits: () {
                        ref
                            .read(activeTabProvider.notifier)
                            .setTab(AppTab.habits.index);
                      },
                    ),

                    // 8. Optional Insights
                    if (summary.insightMessage.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      InsightsCard(insightMessage: summary.insightMessage),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
