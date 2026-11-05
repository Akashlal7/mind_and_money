import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/responsive_layout.dart';
import '../../../core/utils/date_utils.dart';
import '../../settings/providers/settings_provider.dart';
import '../models/savings_goal.dart';
import '../providers/savings_providers.dart';
import 'savings_contribution_sheet.dart';
import 'savings_goal_form_sheet.dart';

/// Modal sheet showing details and transaction history for a savings goal.
class SavingsDetailSheet extends ConsumerWidget {
  final SavingsGoal goal;

  const SavingsDetailSheet({super.key, required this.goal});

  void _openContributionSheet(BuildContext context, bool isWithdrawal) {
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

  void _openEditGoal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SavingsGoalFormSheet(goalToEdit: goal),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final settings = ref.watch(settingsProvider);
    final contributionsAsync = ref.watch(goalContributionsProvider(goal.id));

    // Watch updated goal state from savingsGoalsProvider
    final goalsAsync = ref.watch(savingsGoalsProvider);
    final activeGoal = goalsAsync.maybeWhen(
      data: (list) => list.where((g) => g.id == goal.id).firstOrNull ?? goal,
      orElse: () => goal,
    );

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return ResponsiveContentWrapper(
          maxWidth: 640,
          child: Container(
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: Column(
              children: [
                // Sheet Handle
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 10, bottom: 6),
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colorScheme.outline.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    activeGoal.name,
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (activeGoal.isCompleted) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
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
                                  ),
                                ],
                              ],
                            ),
                            if (activeGoal.targetDate != null)
                              Text(
                                'Target Date: ${AppDateUtils.toDisplayDate(activeGoal.targetDate!)}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        tooltip: 'Edit Goal',
                        onPressed: () => _openEditGoal(context),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),

                // Scrollable Body
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(20),
                    children: [
                      // Overview Metric Card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest.withValues(
                            alpha: 0.4,
                          ),
                          borderRadius: BorderRadius.circular(14),
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
                                Flexible(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Saved Balance',
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color:
                                                  colorScheme.onSurfaceVariant,
                                            ),
                                      ),
                                      const SizedBox(height: 2),
                                      FittedBox(
                                        fit: BoxFit.scaleDown,
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          activeGoal.currentAmount.format(
                                            symbol: settings.currencySymbol,
                                          ),
                                          style: theme.textTheme.headlineSmall
                                              ?.copyWith(
                                                fontWeight: FontWeight.w800,
                                                color: AppColors.tealSecondary,
                                              ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        'Target',
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color:
                                                  colorScheme.onSurfaceVariant,
                                            ),
                                      ),
                                      const SizedBox(height: 2),
                                      FittedBox(
                                        fit: BoxFit.scaleDown,
                                        alignment: Alignment.centerRight,
                                        child: Text(
                                          activeGoal.targetAmount.format(
                                            symbol: settings.currencySymbol,
                                          ),
                                          style: theme.textTheme.titleMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.w700,
                                              ),
                                        ),
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
                                value: activeGoal.progressFraction,
                                minHeight: 8,
                                backgroundColor:
                                    colorScheme.surfaceContainerHighest,
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  AppColors.tealSecondary,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${activeGoal.percentage}% achieved',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.tealSecondary,
                                  ),
                                ),
                                Text(
                                  activeGoal.isCompleted
                                      ? 'Goal Reached!'
                                      : '${activeGoal.remainingAmount.format(symbol: settings.currencySymbol)} left',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Quick Action Buttons (Deposit / Withdraw)
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: () =>
                                  _openContributionSheet(context, false),
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.tealSecondary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                              icon: const Icon(Icons.add_rounded, size: 20),
                              label: const Text(
                                'Add Deposit',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: activeGoal.currentAmount.isPositive
                                  ? () => _openContributionSheet(context, true)
                                  : null,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.expenseCoral,
                                side: const BorderSide(
                                  color: AppColors.expenseCoral,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                              icon: const Icon(Icons.remove_rounded, size: 20),
                              label: const Text(
                                'Withdraw',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // History Section
                      Text(
                        'Contribution History',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),

                      contributionsAsync.when(
                        loading: () => const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: CircularProgressIndicator(),
                          ),
                        ),
                        error: (e, _) => Text('Error loading history: $e'),
                        data: (history) {
                          if (history.isEmpty) {
                            return Container(
                              padding: const EdgeInsets.all(20),
                              alignment: Alignment.center,
                              child: Text(
                                'No contributions recorded yet.\nTap "Add Deposit" to start saving.',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            );
                          }

                          return ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: history.length,
                            separatorBuilder: (_, _) =>
                                const Divider(height: 1),
                            itemBuilder: (context, idx) {
                              final entry = history[idx];
                              final isDeposit = entry.isContribution;
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: CircleAvatar(
                                  radius: 16,
                                  backgroundColor: isDeposit
                                      ? const Color(0xFFE0F2F1)
                                      : const Color(0xFFFFEBEE),
                                  child: Icon(
                                    isDeposit
                                        ? Icons.arrow_downward_rounded
                                        : Icons.arrow_upward_rounded,
                                    size: 16,
                                    color: isDeposit
                                        ? AppColors.tealSecondary
                                        : AppColors.expenseCoral,
                                  ),
                                ),
                                title: Text(
                                  entry.note ??
                                      (isDeposit ? 'Deposit' : 'Withdrawal'),
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Text(
                                  AppDateUtils.toDisplayDate(entry.date),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                    fontSize: 11,
                                  ),
                                ),
                                trailing: Text(
                                  entry.amount.format(
                                    symbol: settings.currencySymbol,
                                    includeSign: true,
                                  ),
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: isDeposit
                                        ? AppColors.tealSecondary
                                        : AppColors.expenseCoral,
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
