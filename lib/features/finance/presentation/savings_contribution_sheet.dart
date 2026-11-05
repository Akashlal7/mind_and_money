import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/responsive_layout.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/money.dart';
import '../models/savings_goal.dart';
import '../providers/savings_providers.dart';

/// Modal sheet to record a savings deposit or withdrawal for a goal.
class SavingsContributionSheet extends ConsumerStatefulWidget {
  final SavingsGoal goal;
  final bool initialIsWithdrawal;

  const SavingsContributionSheet({
    super.key,
    required this.goal,
    this.initialIsWithdrawal = false,
  });

  @override
  ConsumerState<SavingsContributionSheet> createState() =>
      _SavingsContributionSheetState();
}

class _SavingsContributionSheetState
    extends ConsumerState<SavingsContributionSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  late bool _isWithdrawal;
  DateTime _date = DateTime.now();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _isWithdrawal = widget.initialIsWithdrawal;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      helpText: 'Select Transaction Date',
    );

    if (picked != null) {
      setState(() => _date = picked);
    }
  }

  Future<void> _saveRecord() async {
    if (!_formKey.currentState!.validate()) return;

    final amountMoney = Money.tryParseAmount(_amountController.text.trim());
    if (amountMoney == null || !amountMoney.isPositive) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Amount must be greater than zero')),
      );
      return;
    }

    if (_isWithdrawal && amountMoney.cents > widget.goal.currentAmount.cents) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Cannot withdraw more than current balance (${widget.goal.currentAmount.format()})',
          ),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    final repo = ref.read(savingsRepositoryProvider);

    try {
      if (_isWithdrawal) {
        await repo.recordWithdrawal(
          goalId: widget.goal.id,
          amount: amountMoney,
          date: _date,
          note: _noteController.text.trim().isEmpty
              ? null
              : _noteController.text.trim(),
        );
      } else {
        await repo.addContribution(
          goalId: widget.goal.id,
          amount: amountMoney,
          date: _date,
          note: _noteController.text.trim().isEmpty
              ? null
              : _noteController.text.trim(),
        );
      }

      ref.invalidate(savingsGoalsProvider);
      ref.invalidate(goalContributionsProvider(widget.goal.id));

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to record transaction: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final title = _isWithdrawal ? 'Record Withdrawal' : 'Add Deposit';
    final actionColor = _isWithdrawal
        ? AppColors.expenseCoral
        : AppColors.tealSecondary;

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
                Text(
                  '$title: ${widget.goal.name}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(
                  'Current Balance: ${widget.goal.currentAmount.format()} (Target: ${widget.goal.targetAmount.format()})',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 16),

                // Educational Banner
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.tealContainer.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.tealSecondary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        size: 18,
                        color: AppColors.tealSecondary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Allocating savings sets money aside toward your goals. It is not an expense and does not reduce your monthly budget.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 12,
                            color: AppColors.onTealContainer,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Type Selector: Deposit vs Withdrawal
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment<bool>(
                      value: false,
                      label: Text('Deposit / Save'),
                      icon: Icon(Icons.arrow_downward_rounded),
                    ),
                    ButtonSegment<bool>(
                      value: true,
                      label: Text('Withdrawal'),
                      icon: Icon(Icons.arrow_upward_rounded),
                    ),
                  ],
                  selected: {_isWithdrawal},
                  onSelectionChanged: (set) {
                    setState(() => _isWithdrawal = set.first);
                  },
                ),
                const SizedBox(height: 16),

                // Amount input
                TextFormField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: _isWithdrawal
                        ? 'Withdrawal Amount'
                        : 'Deposit Amount',
                    hintText: '0.00',
                    prefixIcon: const Icon(Icons.currency_rupee_rounded),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please enter an amount';
                    }
                    final m = Money.tryParseAmount(val.trim());
                    if (m == null || !m.isPositive) {
                      return 'Amount must be greater than zero';
                    }
                    if (_isWithdrawal &&
                        m.cents > widget.goal.currentAmount.cents) {
                      return 'Exceeds current balance (${widget.goal.currentAmount.format()})';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Date Picker
                InkWell(
                  onTap: _pickDate,
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
                              Icons.calendar_today_rounded,
                              size: 18,
                              color: colorScheme.primary,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Date: ${AppDateUtils.toDisplayDate(_date)}',
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

                // Note Field
                TextFormField(
                  controller: _noteController,
                  decoration: const InputDecoration(
                    labelText: 'Note (Optional)',
                    hintText: 'e.g. Monthly salary transfer, emergency need',
                    prefixIcon: Icon(Icons.notes_rounded),
                  ),
                ),
                const SizedBox(height: 24),

                // Save button
                FilledButton.icon(
                  onPressed: _isSaving ? null : _saveRecord,
                  style: FilledButton.styleFrom(
                    backgroundColor: actionColor,
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
                        : (_isWithdrawal
                              ? 'Record Withdrawal'
                              : 'Save Deposit'),
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
