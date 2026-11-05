import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/responsive_layout.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/empty_state_card.dart';
import '../../../core/widgets/financial_amount_text.dart';
import '../../settings/providers/settings_provider.dart';
import '../models/budget.dart';
import '../providers/budget_providers.dart';
import '../utils/category_icons.dart';
import 'budget_form_sheet.dart';

/// Presentation view for managing overall and category-specific expense budgets.
class BudgetsView extends ConsumerWidget {
  const BudgetsView({super.key});

  void _openBudgetForm(
    BuildContext context, [
    Budget? budget,
    String? monthYear,
  ]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) =>
          BudgetFormSheet(budgetToEdit: budget, initialMonthYear: monthYear),
    );
  }

  void _changeMonth(WidgetRef ref, String currentMonthYear, int deltaMonths) {
    final parts = currentMonthYear.split('-');
    if (parts.length == 2) {
      final y = int.parse(parts[0]);
      final m = int.parse(parts[1]);
      final newDate = DateTime(y, m + deltaMonths, 1);
      ref.read(selectedBudgetMonthProvider.notifier).setDate(newDate);
    }
  }

  Future<void> _copyFromPreviousMonth(
    BuildContext context,
    WidgetRef ref,
    String currentMonthYear,
  ) async {
    final parts = currentMonthYear.split('-');
    if (parts.length != 2) return;
    final y = int.parse(parts[0]);
    final m = int.parse(parts[1]);
    final prevDate = DateTime(y, m - 1, 1);
    final prevMonthYear = AppDateUtils.toIsoMonth(prevDate);

    final repo = ref.read(budgetRepositoryProvider);
    final copied = await repo.copyBudgets(
      fromMonthYear: prevMonthYear,
      toMonthYear: currentMonthYear,
    );

    if (context.mounted) {
      if (copied > 0) {
        ref.invalidate(monthlyBudgetsProvider);
        ref.invalidate(overallBudgetStatusProvider);
        ref.invalidate(availableBudgetMonthsProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Copied $copied budget(s) from $prevMonthYear'),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No budgets found in $prevMonthYear to copy.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final settings = ref.watch(settingsProvider);
    final currentMonthYear = ref.watch(selectedBudgetMonthProvider);
    final budgetsAsync = ref.watch(monthlyBudgetsProvider);
    final availableMonthsAsync = ref.watch(availableBudgetMonthsProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openBudgetForm(context, null, currentMonthYear),
        backgroundColor: AppColors.sagePrimary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Set Budget'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(monthlyBudgetsProvider);
          ref.invalidate(overallBudgetStatusProvider);
          await ref.read(monthlyBudgetsProvider.future);
        },
        child: ResponsiveContentWrapper(
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
            children: [
              // 1. Month Navigation Header
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: colorScheme.outline, width: 0.8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left_rounded),
                      tooltip: 'Previous Month',
                      onPressed: () => _changeMonth(ref, currentMonthYear, -1),
                    ),
                    availableMonthsAsync.maybeWhen(
                      data: (months) {
                        final allMonths = {currentMonthYear, ...months}.toList()
                          ..sort((a, b) => b.compareTo(a));
                        return Flexible(
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: currentMonthYear,
                              isDense: true,
                              icon: const Icon(Icons.arrow_drop_down_rounded),
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: colorScheme.onSurface,
                              ),
                              items: allMonths.map((m) {
                                return DropdownMenuItem<String>(
                                  value: m,
                                  child: Text(
                                    _formatMonthYear(m),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  ref
                                      .read(
                                        selectedBudgetMonthProvider.notifier,
                                      )
                                      .setMonth(val);
                                }
                              },
                            ),
                          ),
                        );
                      },
                      orElse: () => Flexible(
                        child: Text(
                          _formatMonthYear(currentMonthYear),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.copy_rounded, size: 20),
                          tooltip: 'Copy from Last Month',
                          onPressed: () => _copyFromPreviousMonth(
                            context,
                            ref,
                            currentMonthYear,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right_rounded),
                          tooltip: 'Next Month',
                          onPressed: () =>
                              _changeMonth(ref, currentMonthYear, 1),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 2. Budget Data Content
              budgetsAsync.when(
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
                        Text('Error loading budgets: $err'),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: () =>
                              ref.invalidate(monthlyBudgetsProvider),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
                data: (budgetList) {
                  if (budgetList.isEmpty) {
                    return EmptyStateCard(
                      icon: Icons.savings_outlined,
                      title:
                          'No budgets for ${_formatMonthYear(currentMonthYear)}',
                      description: 'Create an overall monthly expense budget or track individual category limits to stay mindful of spending.',
                      actionLabel: 'Set Monthly Budget',
                      onAction: () =>
                          _openBudgetForm(context, null, currentMonthYear),
                    );
                  }

                  final overallStatus = budgetList
                      .where((b) => b.budget.isOverall)
                      .firstOrNull;
                  final categoryBudgets = budgetList
                      .where((b) => !b.budget.isOverall)
                      .toList();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Overall Budget Card
                      if (overallStatus != null) ...[
                        _buildOverallBudgetCard(
                          context,
                          overallStatus,
                          settings.currencySymbol,
                        ),
                        const SizedBox(height: 20),
                      ],

                      // Category Budgets Header
                      if (categoryBudgets.isNotEmpty) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Category Budgets',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              '${categoryBudgets.length} configured',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ...categoryBudgets.map(
                          (status) => _buildCategoryBudgetCard(
                            context,
                            status,
                            settings.currencySymbol,
                          ),
                        ),
                      ],
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

  Widget _buildOverallBudgetCard(
    BuildContext context,
    BudgetStatus status,
    String currencySymbol,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final b = status.budget;

    final isDark = theme.brightness == Brightness.dark;

    Color progressColor;
    String statusBadge;
    Color badgeBgColor;
    Color badgeTextColor;

    if (status.isOverBudget) {
      progressColor = isDark
          ? AppColors.expenseCoralDark
          : AppColors.expenseCoral;
      statusBadge =
          'Exceeded by ${(-status.remaining).format(symbol: currencySymbol)}';
      badgeBgColor = isDark
          ? AppColors.expenseContainerDark
          : AppColors.expenseContainerLight;
      badgeTextColor = isDark
          ? AppColors.onExpenseContainerDark
          : AppColors.onExpenseContainerLight;
    } else if (status.isNearLimit) {
      progressColor = isDark
          ? AppColors.warningAmberDark
          : AppColors.warningAmber;
      statusBadge = 'Approaching limit (${status.percentageUsed}%)';
      badgeBgColor = isDark
          ? AppColors.warningContainerDark
          : AppColors.warningContainerLight;
      badgeTextColor = isDark
          ? AppColors.onWarningContainerDark
          : AppColors.onWarningContainerLight;
    } else {
      progressColor = isDark
          ? AppColors.sagePrimaryDark
          : AppColors.sagePrimary;
      statusBadge = '${status.percentageUsed}% used';
      badgeBgColor = isDark
          ? AppColors.incomeContainerDark
          : AppColors.incomeContainerLight;
      badgeTextColor = isDark
          ? AppColors.onIncomeContainerDark
          : AppColors.onIncomeContainerLight;
    }

    return Card(
      child: InkWell(
        onTap: () => _openBudgetForm(context, b),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.sageContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.all_inclusive_rounded,
                            size: 18,
                            color: AppColors.onSageContainer,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            'Overall Monthly Limit',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: badgeBgColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      statusBadge,
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: badgeTextColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Metrics Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Actual Spent',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            status.spent.format(symbol: currencySymbol),
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: status.isOverBudget
                                  ? AppColors.expenseCoral
                                  : colorScheme.onSurface,
                            ),
                            maxLines: 1,
                          ),
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
                          status.isOverBudget ? 'Over Budget' : 'Remaining',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        FinancialAmountText(
                          amount: status.remaining,
                          currencySymbol: currencySymbol,
                          type: status.isOverBudget
                              ? FinancialAmountType.expense
                              : FinancialAmountType.income,
                          showSign: status.isOverBudget,
                          showIcon: true,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Progress Bar
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: status.progressClamp,
                  minHeight: 8,
                  backgroundColor: colorScheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                ),
              ),
              const SizedBox(height: 8),

              Text(
                'Total Monthly Budget: ${b.amount.format(symbol: currencySymbol)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryBudgetCard(
    BuildContext context,
    BudgetStatus status,
    String currencySymbol,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final b = status.budget;
    final catColor = Color(b.categoryColor ?? 0xFF90A4AE);
    final iconData = CategoryIconHelper.getIcon(b.categoryIcon);

    Color progressColor;
    if (status.isOverBudget) {
      progressColor = AppColors.expenseCoral;
    } else if (status.isNearLimit) {
      progressColor = AppColors.warningAmber;
    } else {
      progressColor = catColor;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () => _openBudgetForm(context, b),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: catColor.withValues(alpha: 0.18),
                    child: Icon(iconData, size: 16, color: catColor),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          b.categoryName ?? 'Category',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '${status.spent.format(symbol: currencySymbol)} of ${b.amount.format(symbol: currencySymbol)}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontSize: 11,
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
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Text(
                            status.remaining.format(symbol: currencySymbol),
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: status.isOverBudget
                                  ? AppColors.expenseCoral
                                  : AppColors.incomeGreen,
                            ),
                          ),
                        ),
                        Text(
                          status.isOverBudget ? 'Over limit' : 'Left',
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontSize: 10,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: status.progressClamp,
                  minHeight: 6,
                  backgroundColor: colorScheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatMonthYear(String monthYear) {
    final parts = monthYear.split('-');
    if (parts.length == 2) {
      final y = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      if (y != null && m != null) {
        return AppDateUtils.toMonthYear(DateTime(y, m));
      }
    }
    return monthYear;
  }
}
