import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/responsive_layout.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/money.dart';
import '../models/savings_goal.dart';
import '../providers/savings_providers.dart';

/// Modal bottom sheet to create or edit a savings goal.
class SavingsGoalFormSheet extends ConsumerStatefulWidget {
  final SavingsGoal? goalToEdit;

  const SavingsGoalFormSheet({super.key, this.goalToEdit});

  @override
  ConsumerState<SavingsGoalFormSheet> createState() =>
      _SavingsGoalFormSheetState();
}

class _SavingsGoalFormSheetState extends ConsumerState<SavingsGoalFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _targetController = TextEditingController();
  final _initialDepositController = TextEditingController();

  DateTime? _targetDate;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final g = widget.goalToEdit;
    if (g != null) {
      _nameController.text = g.name;
      _targetController.text = (g.targetAmount.cents / 100).toStringAsFixed(2);
      _targetDate = g.targetDate;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _targetController.dispose();
    _initialDepositController.dispose();
    super.dispose();
  }

  Future<void> _pickTargetDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _targetDate ?? now.add(const Duration(days: 90)),
      firstDate: now,
      lastDate: DateTime(2045),
      helpText: 'Select Target Date',
    );

    if (picked != null) {
      setState(() => _targetDate = picked);
    }
  }

  Future<void> _saveGoal() async {
    if (!_formKey.currentState!.validate()) return;

    final targetMoney = Money.tryParseAmount(_targetController.text.trim());
    if (targetMoney == null || !targetMoney.isPositive) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Target amount must be greater than zero'),
        ),
      );
      return;
    }

    Money? initialDeposit;
    if (widget.goalToEdit == null &&
        _initialDepositController.text.trim().isNotEmpty) {
      initialDeposit = Money.tryParseAmount(
        _initialDepositController.text.trim(),
      );
    }

    setState(() => _isSaving = true);
    final repo = ref.read(savingsRepositoryProvider);
    final now = DateTime.now();

    try {
      if (widget.goalToEdit != null) {
        final updated = widget.goalToEdit!.copyWith(
          name: _nameController.text.trim(),
          targetAmount: targetMoney,
          targetDate: _targetDate,
          updatedAt: now,
        );
        await repo.updateSavingsGoal(updated);
      } else {
        final newGoal = SavingsGoal(
          id: 'goal_${now.microsecondsSinceEpoch}',
          name: _nameController.text.trim(),
          targetAmount: targetMoney,
          currentAmount: const Money.zero(),
          targetDate: _targetDate,
          createdAt: now,
          updatedAt: now,
        );
        await repo.createSavingsGoal(newGoal, initialDeposit: initialDeposit);
      }

      ref.invalidate(savingsGoalsProvider);

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save savings goal: $e')),
        );
      }
    }
  }

  Future<void> _deleteGoal() async {
    if (widget.goalToEdit == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Savings Goal'),
        content: const Text(
          'Are you sure you want to delete this savings goal? Its contribution history will also be removed.',
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
    final repo = ref.read(savingsRepositoryProvider);

    try {
      await repo.deleteSavingsGoal(widget.goalToEdit!.id);
      ref.invalidate(savingsGoalsProvider);
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to delete goal: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isEditing = widget.goalToEdit != null;

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
                        isEditing ? 'Edit Savings Goal' : 'New Savings Goal',
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
                        tooltip: 'Delete Goal',
                        onPressed: _isSaving ? null : _deleteGoal,
                      ),
                  ],
                ),
                const SizedBox(height: 16),

                // Goal Name
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Goal Name',
                    hintText: 'e.g. Emergency Fund, Vacation, New Laptop',
                    prefixIcon: Icon(Icons.flag_rounded),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please enter a goal name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Target Amount
                TextFormField(
                  controller: _targetController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Target Amount',
                    hintText: '0.00',
                    prefixIcon: Icon(Icons.savings_rounded),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please enter a target amount';
                    }
                    final m = Money.tryParseAmount(val.trim());
                    if (m == null || !m.isPositive) {
                      return 'Target amount must be greater than zero';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Optional Initial Deposit (Create mode only)
                if (!isEditing) ...[
                  TextFormField(
                    controller: _initialDepositController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Initial Deposit (Optional)',
                      hintText: '0.00',
                      prefixIcon: Icon(Icons.add_circle_outline_rounded),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Target Date Selector
                InkWell(
                  onTap: _pickTargetDate,
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
                              Icons.event_rounded,
                              size: 20,
                              color: colorScheme.primary,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              _targetDate != null
                                  ? 'Target Date: ${AppDateUtils.toDisplayDate(_targetDate!)}'
                                  : 'Target Date (Optional)',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: _targetDate != null
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                        if (_targetDate != null)
                          IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () => setState(() => _targetDate = null),
                          )
                        else
                          const Icon(Icons.arrow_drop_down_rounded),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Save Button
                FilledButton.icon(
                  onPressed: _isSaving ? null : _saveGoal,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.tealSecondary,
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
                        : (isEditing ? 'Update Goal' : 'Create Goal'),
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
