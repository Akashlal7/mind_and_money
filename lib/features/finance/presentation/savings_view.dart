import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/responsive_layout.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/empty_state_card.dart';
import '../../settings/providers/settings_provider.dart';
import '../models/savings_goal.dart';
import '../providers/savings_providers.dart';
import 'savings_contribution_sheet.dart';
import 'savings_detail_sheet.dart';
import 'savings_goal_form_sheet.dart';

/// Presentation view for managing savings goals, tracking progress, and recording contributions.
class SavingsView extends ConsumerWidget {
  const SavingsView({super.key});

  void _openCreateGoal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const SavingsGoalFormSheet(),
    );
  }

  void _openDetailSheet(BuildContext context, SavingsGoal goal) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SavingsDetailSheet(goal: goal),
    );
  }

  void _openContributionSheet(
    BuildContext context,
    SavingsGoal goal,
    bool isWithdrawal,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SavingsContributionSheet(
        goal: goal,
        initialIsWithdrawal: isWithdrawal,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final settings = ref.watch(settingsProvider);
    final goalsAsync = ref.watch(savingsGoalsProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openCreateGoal(context),
        backgroundColor: AppColors.tealSecondary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Goal'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(savingsGoalsProvider);
          await ref.read(savingsGoalsProvider.future);
        },
        child: ResponsiveContentWrapper(
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
            children: [
              goalsAsync.when(
                loading: () => const SizedBox(
                  height: 200,
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (err, _) => Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Column(
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          color: Colors.red,
                          size: 36,
                        ),
                        const SizedBox(height: 8),
                        Text('Error loading savings goals: $err'),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: () => ref.invalidate(savingsGoalsProvider),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
                data: (goals) {
                  if (goals.isEmpty) {
                    return EmptyStateCard(
                      icon: Icons.savings_outlined,
                      title: 'No savings goals yet',
                      description: 'Set dedicated targets for emergency funds, vacations, or upcoming purchases to build your future resilience.',
                      actionLabel: 'Create First Goal',
                      onAction: () => _openCreateGoal(context),
                    );
                  }

                  // Calculate cumulative totals across all goals
                  int totalTargetCents = 0;
                  int totalSavedCents = 0;
                  for (final g in goals) {
                    totalTargetCents += g.targetAmount.cents;
                    totalSavedCents += g.currentAmount.cents;
                  }

                  final overallProgress = totalTargetCents > 0
                      ? (totalSavedCents / totalTargetCents).clamp(0.0, 1.0)
                      : 0.0;
                  final overallPct = (overallProgress * 100).round();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 1. Cumulative Savings Progress Banner
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: colorScheme.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: colorScheme.outline,
                            width: 0.8,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: AppColors.tealContainer,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        Icons.savings_rounded,
                                        size: 18,
                                        color: AppColors.onTealContainer,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      'Total Savings Portfolio',
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE0F2F1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '$overallPct% reached',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.tealSecondary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Total Saved',
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color:
                                                  colorScheme.onSurfaceVariant,
                                            ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        Money(totalSavedCents).format(
                                          symbol: settings.currencySymbol,
                                        ),
                                        style: theme.textTheme.headlineSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.w800,
                                              color: AppColors.tealSecondary,
                                            ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        'Combined Target',
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color:
                                                  colorScheme.onSurfaceVariant,
                                            ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        Money(totalTargetCents).format(
                                          symbol: settings.currencySymbol,
                                        ),
                                        style: theme.textTheme.titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                            ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: overallProgress,
                                minHeight: 8,
                                backgroundColor:
                                    colorScheme.surfaceContainerHighest,
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  AppColors.tealSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // 2. Goals List Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Your Goals',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            '${goals.length} active',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // 3. Goal Cards
                      ...goals.map(
                        (goal) => _buildGoalCard(
                          context,
                          goal,
                          settings.currencySymbol,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGoalCard(
    BuildContext context,
    SavingsGoal goal,
    String currencySymbol,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _openDetailSheet(context, goal),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title & Completion badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      goal.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (goal.isCompleted)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Completed 🎉',
                        style: TextStyle(
                          color: AppColors.incomeGreen,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0F2F1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${goal.percentage}%',
                        style: const TextStyle(
                          color: AppColors.tealSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // Balances (Scale-down protection for large amounts & narrow displays)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${goal.currentAmount.format(symbol: currencySymbol)} saved',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.tealSecondary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        'Target: ${goal.targetAmount.format(symbol: currencySymbol)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Progress Bar
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: goal.progressFraction,
                  minHeight: 6,
                  backgroundColor: colorScheme.surfaceContainerHighest,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppColors.tealSecondary,
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Footer: Target date or remaining amount + Action chips
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      goal.targetDate != null
                          ? 'Target: ${AppDateUtils.toDisplayDate(goal.targetDate!)}'
                          : (goal.isCompleted
                              ? 'Target achieved!'
                              : '${goal.remainingAmount.format(symbol: currencySymbol)} remaining'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ActionChip(
                        visualDensity: VisualDensity.compact,
                        avatar: const Icon(
                          Icons.add,
                          size: 14,
                          color: AppColors.tealSecondary,
                        ),
                        label: const Text(
                          'Deposit',
                          style: TextStyle(fontSize: 11),
                        ),
                        onPressed: () =>
                            _openContributionSheet(context, goal, false),
                      ),
                      const SizedBox(width: 6),
                      if (goal.currentAmount.isPositive)
                        ActionChip(
                          visualDensity: VisualDensity.compact,
                          avatar: const Icon(
                            Icons.remove,
                            size: 14,
                            color: AppColors.expenseCoral,
                          ),
                          label: const Text(
                            'Withdraw',
                            style: TextStyle(fontSize: 11),
                          ),
                          onPressed: () =>
                              _openContributionSheet(context, goal, true),
                        ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
