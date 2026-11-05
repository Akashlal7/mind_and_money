import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/responsive_layout.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/money.dart';
import '../models/budget.dart';
import '../models/category.dart';
import '../providers/budget_providers.dart';
import '../providers/transaction_providers.dart';
import '../utils/category_icons.dart';

/// Modal bottom sheet to create or edit an overall or category-specific budget.
class BudgetFormSheet extends ConsumerStatefulWidget {
  final Budget? budgetToEdit;
  final String? initialMonthYear;

  const BudgetFormSheet({super.key, this.budgetToEdit, this.initialMonthYear});

  @override
  ConsumerState<BudgetFormSheet> createState() => _BudgetFormSheetState();
}

class _BudgetFormSheetState extends ConsumerState<BudgetFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();

  late bool _isOverall;
  String? _selectedCategoryId;
  late String _monthYear;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final b = widget.budgetToEdit;
    if (b != null) {
      _isOverall = b.isOverall;
      _selectedCategoryId = b.categoryId;
      _monthYear = b.monthYear;
      _amountController.text = (b.amount.cents / 100).toStringAsFixed(2);
    } else {
      _isOverall = true;
      _selectedCategoryId = null;
      _monthYear =
          widget.initialMonthYear ?? AppDateUtils.toIsoMonth(DateTime.now());
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _pickMonth() async {
    final parts = _monthYear.split('-');
    final initialDate = parts.length == 2
        ? DateTime(int.parse(parts[0]), int.parse(parts[1]))
        : DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2040),
      helpText: 'Select Budget Month',
    );

    if (picked != null) {
      setState(() {
        _monthYear = AppDateUtils.toIsoMonth(picked);
      });
    }
  }

  Future<void> _saveBudget() async {
    if (!_formKey.currentState!.validate()) return;

    final parsedMoney = Money.tryParseAmount(_amountController.text.trim());
    if (parsedMoney == null || !parsedMoney.isPositive) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid positive budget amount'),
        ),
      );
      return;
    }

    if (!_isOverall && _selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an expense category')),
      );
      return;
    }

    setState(() => _isSaving = true);
    final now = DateTime.now();
    final repo = ref.read(budgetRepositoryProvider);

    final budget = Budget(
      id: widget.budgetToEdit?.id ?? 'bgt_${now.microsecondsSinceEpoch}',
      categoryId: _isOverall ? null : _selectedCategoryId,
      amount: parsedMoney,
      monthYear: _monthYear,
      createdAt: widget.budgetToEdit?.createdAt ?? now,
      updatedAt: now,
    );

    try {
      await repo.saveBudget(budget);

      // Invalidate providers to immediately refresh UI and home summary
      ref.invalidate(monthlyBudgetsProvider);
      ref.invalidate(overallBudgetStatusProvider);
      ref.invalidate(availableBudgetMonthsProvider);

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to save budget: $e')));
      }
    }
  }

  Future<void> _deleteBudget() async {
    if (widget.budgetToEdit == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Budget'),
        content: const Text(
          'Are you sure you want to delete this budget? Past transactions will remain intact.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.expenseCoral,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _isSaving = true);
    final repo = ref.read(budgetRepositoryProvider);

    try {
      await repo.deleteBudget(widget.budgetToEdit!.id);

      ref.invalidate(monthlyBudgetsProvider);
      ref.invalidate(overallBudgetStatusProvider);
      ref.invalidate(availableBudgetMonthsProvider);

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to delete budget: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final categoriesAsync = ref.watch(categoriesProvider('expense'));
    final isEditing = widget.budgetToEdit != null;

    return ResponsiveContentWrapper(
      maxWidth: 600,
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        isEditing ? 'Edit Budget' : 'Set Budget',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isEditing)
                      IconButton(
                        icon: Icon(
                          Icons.delete_outline_rounded,
                          color: colorScheme.error,
                        ),
                        tooltip: 'Delete Budget',
                        onPressed: _isSaving ? null : _deleteBudget,
                      ),
                  ],
                ),
                const SizedBox(height: 16),

                // Month selector chip
                InkWell(
                  onTap: _pickMonth,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest.withValues(
                        alpha: 0.5,
                      ),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: colorScheme.outline,
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_month_rounded,
                              size: 20,
                              color: colorScheme.primary,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Month: $_monthYear',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const Icon(Icons.arrow_drop_down_rounded),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Budget Type Toggle: Overall vs Category
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment<bool>(
                      value: true,
                      label: Text('Overall Monthly'),
                      icon: Icon(Icons.all_inclusive_rounded),
                    ),
                    ButtonSegment<bool>(
                      value: false,
                      label: Text('Category Budget'),
                      icon: Icon(Icons.category_rounded),
                    ),
                  ],
                  selected: {_isOverall},
                  onSelectionChanged: (newSelection) {
                    setState(() {
                      _isOverall = newSelection.first;
                    });
                  },
                ),
                const SizedBox(height: 16),

                // Category Selector (if category budget)
                if (!_isOverall)
                  categoriesAsync.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (e, _) => Text('Error loading categories: $e'),
                    data: (categories) {
                      if (categories.isEmpty) {
                        return const Text('No expense categories found.');
                      }
                      return DropdownButtonFormField<String>(
                        initialValue:
                            _selectedCategoryId ?? categories.first.id,
                        decoration: const InputDecoration(
                          labelText: 'Expense Category',
                          prefixIcon: Icon(Icons.category_outlined),
                        ),
                        items: categories.map((Category cat) {
                          return DropdownMenuItem<String>(
                            value: cat.id,
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 10,
                                  backgroundColor: Color(cat.color)
                                      .withValues(alpha: 0.2),
                                  child: Icon(
                                    CategoryIconHelper.getIcon(cat.icon),
                                    size: 12,
                                    color: Color(cat.color),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(cat.name),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setState(() => _selectedCategoryId = val);
                        },
                      );
                    },
                  ),
                if (!_isOverall) const SizedBox(height: 16),

                // Amount field
                TextFormField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Budget Amount',
                    hintText: '0.00',
                    prefixIcon: Icon(Icons.currency_rupee_rounded),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please enter a budget amount';
                    }
                    final money = Money.tryParseAmount(val.trim());
                    if (money == null || !money.isPositive) {
                      return 'Amount must be greater than zero';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Save button
                FilledButton.icon(
                  onPressed: _isSaving ? null : _saveBudget,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.sagePrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_rounded),
                  label: Text(
                    _isSaving
                        ? 'Saving...'
                        : (isEditing ? 'Update Budget' : 'Save Budget'),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
