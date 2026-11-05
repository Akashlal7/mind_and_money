import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/responsive_layout.dart';

/// Mind & Money — Nothing OS Quick Actions Grid.
/// Minimal monochrome action tiles with wireframe borders, geometric icons,
/// and restrained status indicators.
class QuickActionsRow extends StatelessWidget {
  final VoidCallback onAddExpense;
  final VoidCallback onAddIncome;
  final VoidCallback onViewTransactions;
  final VoidCallback onViewBudgets;

  const QuickActionsRow({
    super.key,
    required this.onAddExpense,
    required this.onAddIncome,
    required this.onViewTransactions,
    required this.onViewBudgets,
  });

  @override
  Widget build(BuildContext context) {
    final isNarrow = AppBreakpoints.isNarrow(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final actions = [
      (
        label: 'Add Expense',
        icon: Icons.remove_circle_outline_rounded,
        color: isDark ? AppColors.nothingRedDark : AppColors.nothingRed,
        bgColor: isDark
            ? AppColors.expenseContainerDark
            : AppColors.expenseContainerLight,
        onTap: onAddExpense,
      ),
      (
        label: 'Add Income',
        icon: Icons.add_circle_outline_rounded,
        color: isDark ? AppColors.incomeGreenDark : AppColors.incomeGreen,
        bgColor: isDark
            ? AppColors.incomeContainerDark
            : AppColors.incomeContainerLight,
        onTap: onAddIncome,
      ),
      (
        label: 'Transactions',
        icon: Icons.receipt_long_outlined,
        color: isDark ? AppColors.primaryTextDark : AppColors.primaryTextLight,
        bgColor: isDark
            ? AppColors.secondarySurfaceDark
            : AppColors.secondarySurfaceLight,
        onTap: onViewTransactions,
      ),
      (
        label: 'Budgets',
        icon: Icons.pie_chart_outline_rounded,
        color: isDark ? AppColors.primaryTextDark : AppColors.primaryTextLight,
        bgColor: isDark
            ? AppColors.secondarySurfaceDark
            : AppColors.secondarySurfaceLight,
        onTap: onViewBudgets,
      ),
    ];

    if (isNarrow) {
      // 2x2 Grid for narrow screens (< 360px) to prevent tiny unreadable buttons
      return Column(
        children: [
          Row(
            children: [
              Expanded(child: _buildTile(context, actions[0])),
              const SizedBox(width: 8),
              Expanded(child: _buildTile(context, actions[1])),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _buildTile(context, actions[2])),
              const SizedBox(width: 8),
              Expanded(child: _buildTile(context, actions[3])),
            ],
          ),
        ],
      );
    }

    // 4 in a row on standard and wide devices
    return Row(
      children: [
        for (int i = 0; i < actions.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(child: _buildTile(context, actions[i])),
        ],
      ],
    );
  }

  Widget _buildTile(
    BuildContext context,
    ({
      String label,
      IconData icon,
      Color color,
      Color bgColor,
      VoidCallback onTap,
    })
    action,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Semantics(
      button: true,
      label: action.label,
      child: Material(
        color: isDark
            ? AppColors.primarySurfaceDark
            : AppColors.primarySurfaceLight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isDark
                ? AppColors.borderDividerDark
                : AppColors.borderDividerLight,
            width: 1.0,
          ),
        ),
        child: InkWell(
          onTap: action.onTap,
          borderRadius: BorderRadius.circular(12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 70),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: action.bgColor,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDark
                            ? AppColors.borderDividerDark
                            : AppColors.borderDividerLight,
                        width: 0.8,
                      ),
                    ),
                    child: Icon(action.icon, color: action.color, size: 18),
                  ),
                  const SizedBox(height: 8),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      action.label,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
