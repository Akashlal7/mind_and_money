import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/responsive_layout.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/id_generator.dart';
import '../../../core/utils/money.dart';
import '../../home/providers/home_providers.dart';
import '../../settings/providers/settings_provider.dart';
import '../../wellness/presentation/reflection/spending_reflection_sheet.dart';
import '../../wellness/providers/wellness_providers.dart';
import '../models/payment_method.dart';
import '../models/transaction.dart';
import '../providers/transaction_providers.dart';
import '../services/smart_transaction_parser.dart';
import '../utils/category_icons.dart';
import 'category_management_dialog.dart';
import 'bank_statement_import_sheet.dart';
import 'quick_catch_up_sheet.dart';

class TransactionFormSheet extends ConsumerStatefulWidget {
  final FinancialTransaction? transactionToEdit;
  final TransactionType initialType;

  const TransactionFormSheet({
    super.key,
    this.transactionToEdit,
    this.initialType = TransactionType.expense,
  });

  @override
  ConsumerState<TransactionFormSheet> createState() =>
      _TransactionFormSheetState();
}

class _TransactionFormSheetState extends ConsumerState<TransactionFormSheet> {
  final _formKey = GlobalKey<FormState>();

  late TransactionType _selectedType;
  late TextEditingController _amountController;
  late TextEditingController _descriptionController;
  late TextEditingController _noteController;

  String? _selectedCategoryId;
  late DateTime _selectedDateTime;
  String _selectedPaymentMethod = 'cash';
  bool _isSaving = false;

  bool get _isEditing => widget.transactionToEdit != null;

  @override
  void initState() {
    super.initState();
    final editTx = widget.transactionToEdit;

    if (editTx != null) {
      _selectedType = editTx.type;
      _amountController = TextEditingController(
        text: editTx.amount.toDouble().toStringAsFixed(2),
      );
      _descriptionController = TextEditingController(
        text: editTx.description ?? '',
      );
      _noteController = TextEditingController(text: editTx.note ?? '');
      _selectedCategoryId = editTx.categoryId;
      _selectedDateTime = editTx.transactionDate;
      _selectedPaymentMethod = editTx.paymentMethod ?? 'cash';
    } else {
      _selectedType = widget.initialType;
      _amountController = TextEditingController();
      _descriptionController = TextEditingController();
      _noteController = TextEditingController();
      _selectedDateTime = DateTime.now();
      _selectedPaymentMethod = 'cash';
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pasteAndAutoFill() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text == null || text.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Clipboard is empty.')),
        );
      }
      return;
    }

    final drafts = SmartTransactionParser.parse(text);
    if (drafts.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not detect transaction details from clipboard.'),
          ),
        );
      }
      return;
    }

    final draft = drafts.first;
    setState(() {
      _selectedType = draft.type;
      _amountController.text = draft.amount.toDouble().toStringAsFixed(2);
      _descriptionController.text = draft.description;
      _selectedCategoryId = draft.categoryId;
      _selectedDateTime = draft.date;
      _selectedPaymentMethod = draft.paymentMethod;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Auto-filled from copied Bank SMS / text!'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDateTime,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _selectedDateTime = DateTime(
          picked.year,
          picked.month,
          picked.day,
          _selectedDateTime.hour,
          _selectedDateTime.minute,
        );
      });
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDateTime),
    );
    if (picked != null) {
      setState(() {
        _selectedDateTime = DateTime(
          _selectedDateTime.year,
          _selectedDateTime.month,
          _selectedDateTime.day,
          picked.hour,
          picked.minute,
        );
      });
    }
  }

  Future<void> _saveTransaction() async {
    if (!_formKey.currentState!.validate()) return;
    final categories =
        ref.read(categoriesProvider(_selectedType.toDbString())).value ?? [];
    final categoryId =
        _selectedCategoryId ??
        (categories.isNotEmpty ? categories.first.id : null);
    if (categoryId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a category')));
      return;
    }

    final amountText = _amountController.text.trim();
    final money = Money.tryParse(amountText);
    if (money == null || !money.isPositive) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid positive amount')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final repo = ref.read(transactionRepositoryProvider);
      final desc = _descriptionController.text.trim();
      final note = _noteController.text.trim();
      final now = DateTime.now();

      String savedTxId = '';
      if (_isEditing) {
        savedTxId = widget.transactionToEdit!.id;
        final updatedTx = FinancialTransaction(
          id: savedTxId,
          amount: money,
          type: _selectedType,
          categoryId: categoryId,
          transactionDate: _selectedDateTime,
          description: desc.isEmpty ? null : desc,
          paymentMethod: _selectedPaymentMethod,
          note: note.isEmpty ? null : note,
          createdAt: widget.transactionToEdit!.createdAt,
          updatedAt: now,
        );
        await repo.updateTransaction(updatedTx);
      } else {
        savedTxId = 'tx_${IdGenerator.generate()}';
        final newTx = FinancialTransaction(
          id: savedTxId,
          amount: money,
          type: _selectedType,
          categoryId: categoryId,
          transactionDate: _selectedDateTime,
          description: desc.isEmpty ? null : desc,
          paymentMethod: _selectedPaymentMethod,
          note: note.isEmpty ? null : note,
          createdAt: now,
          updatedAt: now,
        );
        await repo.createTransaction(newTx);
      }

      // Invalidate relevant providers to update UI in real-time
      ref.invalidate(filteredTransactionsProvider);
      ref.invalidate(periodTotalsProvider);
      ref.invalidate(homeSummaryProvider);

      final isNewExpense =
          !_isEditing && _selectedType == TransactionType.expense;

      if (mounted) {
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
        if (isNewExpense) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Expense added.'),
              action: SnackBarAction(
                label: 'Reflect',
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                    ),
                    builder: (ctx) => SpendingReflectionSheet(
                      transactionId: savedTxId,
                      transactionAmount: money.formatted,
                    ),
                  );
                },
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _isEditing
                    ? 'Transaction updated successfully.'
                    : 'Transaction added successfully.',
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving transaction: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Transaction?'),
        content: const Text(
          'Are you sure you want to permanently delete this transaction record?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              final repo = ref.read(transactionRepositoryProvider);
              await repo.deleteTransaction(widget.transactionToEdit!.id);

              ref.invalidate(filteredTransactionsProvider);
              ref.invalidate(periodTotalsProvider);
              ref.invalidate(homeSummaryProvider);

              if (mounted) {
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Transaction deleted.')),
                );
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final settings = ref.watch(settingsProvider);
    final categoriesAsync = ref.watch(
      categoriesProvider(_selectedType.toDbString()),
    );

    return ResponsiveContentWrapper(
      maxWidth: 600,
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        _isEditing ? 'Edit Transaction' : 'Record Transaction',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Quick Batch & Statement Options Banner
                if (!_isEditing) ...[
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            Navigator.pop(context);
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (ctx) => const QuickCatchUpSheet(),
                            );
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: theme.brightness == Brightness.dark
                                  ? AppColors.secondarySurfaceDark
                                  : AppColors.secondarySurfaceLight,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: theme.brightness == Brightness.dark
                                    ? AppColors.borderDividerDark
                                    : AppColors.borderDividerLight,
                                width: 0.8,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.bolt_rounded,
                                  size: 15,
                                  color: theme.brightness == Brightness.dark
                                      ? AppColors.nothingRedDark
                                      : AppColors.nothingRed,
                                ),
                                const SizedBox(width: 4),
                                const Flexible(
                                  child: Text(
                                    'Quick Catch-Up',
                                    style: TextStyle(
                                      fontFamily: 'NotoSansMono',
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            Navigator.pop(context);
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (ctx) => const BankStatementImportSheet(),
                            );
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: theme.brightness == Brightness.dark
                                  ? AppColors.secondarySurfaceDark
                                  : AppColors.secondarySurfaceLight,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: theme.brightness == Brightness.dark
                                    ? AppColors.borderDividerDark
                                    : AppColors.borderDividerLight,
                                width: 0.8,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.picture_as_pdf_outlined,
                                  size: 15,
                                  color: theme.brightness == Brightness.dark
                                      ? AppColors.nothingRedDark
                                      : AppColors.nothingRed,
                                ),
                                const SizedBox(width: 4),
                                const Flexible(
                                  child: Text(
                                    'PDF Statement',
                                    style: TextStyle(
                                      fontFamily: 'NotoSansMono',
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],

                // Income / Expense Toggle
                SegmentedButton<TransactionType>(
                  segments: const [
                    ButtonSegment(
                      value: TransactionType.expense,
                      icon: Icon(
                        Icons.remove_circle_outline_rounded,
                        color: AppColors.expenseCoral,
                      ),
                      label: Text('Expense'),
                    ),
                    ButtonSegment(
                      value: TransactionType.income,
                      icon: Icon(
                        Icons.add_circle_outline_rounded,
                        color: AppColors.incomeGreen,
                      ),
                      label: Text('Income'),
                    ),
                  ],
                  selected: {_selectedType},
                  onSelectionChanged: (val) {
                    setState(() {
                      _selectedType = val.first;
                      _selectedCategoryId =
                          null; // Reset category when switching type
                    });
                  },
                ),
                const SizedBox(height: 16),

                // Amount Input
                TextFormField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: const TextStyle(
                    fontFamily: 'NotoSansMono',
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Amount',
                    prefixText: '${settings.currencySymbol} ',
                    prefixStyle: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: _selectedType == TransactionType.expense
                          ? AppColors.expenseCoral
                          : AppColors.incomeGreen,
                    ),
                    hintText: '0.00',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.paste_rounded, size: 20),
                      tooltip: 'Auto-fill from copied bank SMS',
                      onPressed: _pasteAndAutoFill,
                    ),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please enter an amount';
                    }
                    final parsed = double.tryParse(val.trim());
                    if (parsed == null || parsed <= 0) {
                      return 'Enter a valid amount greater than 0';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Category Selector
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Category',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (_) => const CategoryManagementDialog(),
                        );
                      },
                      icon: const Icon(Icons.settings_outlined, size: 16),
                      label: const Text('Manage'),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                categoriesAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => Text('Error loading categories: $e'),
                  data: (categories) {
                    if (categories.isEmpty) {
                      return const Text('No categories available.');
                    }

                    final activeCatId =
                        _selectedCategoryId ?? categories.first.id;

                    return SizedBox(
                      height: 82,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: categories.length,
                        separatorBuilder: (ctx, _) => const SizedBox(width: 8),
                        itemBuilder: (ctx, idx) {
                          final cat = categories[idx];
                          final isSelected = activeCatId == cat.id;
                          final icon = CategoryIconHelper.getIcon(cat.icon);
                          final catColor = Color(cat.color);

                          return InkWell(
                            onTap: () =>
                                setState(() => _selectedCategoryId = cat.id),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              width: 76,
                              padding: const EdgeInsets.symmetric(
                                vertical: 8,
                                horizontal: 4,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? catColor.withValues(alpha: 0.18)
                                    : colorScheme.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? catColor
                                      : colorScheme.outline,
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  CircleAvatar(
                                    radius: 16,
                                    backgroundColor: catColor.withValues(
                                      alpha: 0.2,
                                    ),
                                    child: Icon(
                                      icon,
                                      color: catColor,
                                      size: 18,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    cat.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      fontWeight: isSelected
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),

                // Date and Time Row
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickDate,
                        icon: const Icon(
                          Icons.calendar_today_rounded,
                          size: 16,
                        ),
                        label: Text(
                          AppDateUtils.toShortDate(_selectedDateTime),
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickTime,
                        icon: const Icon(Icons.access_time_rounded, size: 16),
                        label: Text(
                          AppDateUtils.toDisplayTime(_selectedDateTime),
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Description Field
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description / Payee (Optional)',
                    hintText: 'e.g. Grocery Store, Client Invoice',
                  ),
                ),
                const SizedBox(height: 14),

                // Payment Method Dropdown
                DropdownButtonFormField<String>(
                  initialValue: _selectedPaymentMethod,
                  decoration: const InputDecoration(
                    labelText: 'Payment Method',
                  ),
                  items: PaymentMethod.standard.map((method) {
                    return DropdownMenuItem<String>(
                      value: method.id,
                      child: Row(
                        children: [
                          Icon(
                            method.icon,
                            size: 18,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(width: 10),
                          Text(method.label),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedPaymentMethod = val);
                    }
                  },
                ),
                const SizedBox(height: 14),

                // Note Field
                TextFormField(
                  controller: _noteController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Note (Optional)',
                    hintText: 'Add additional personal details...',
                  ),
                ),
                const SizedBox(height: 20),

                // Save Button
                FilledButton(
                  onPressed: _isSaving ? null : _saveTransaction,
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          _isEditing
                              ? 'Update Transaction'
                              : 'Save Transaction',
                        ),
                ),

                // Delete & Reflection buttons if in edit mode
                if (_isEditing) ...[
                  if (_selectedType == TransactionType.expense) ...[
                    const SizedBox(height: 10),
                    Consumer(
                      builder: (context, ref, _) {
                        final reflectionAsync = ref.watch(
                          transactionReflectionProvider(
                            widget.transactionToEdit!.id,
                          ),
                        );
                        final reflection = reflectionAsync.value;
                        return OutlinedButton.icon(
                          onPressed: () {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(20),
                                ),
                              ),
                              builder: (ctx) => SpendingReflectionSheet(
                                transactionId: widget.transactionToEdit!.id,
                                transactionAmount:
                                    widget.transactionToEdit!.amount.formatted,
                                existingReflection: reflection,
                              ),
                            );
                          },
                          icon: const Icon(Icons.spa_outlined, size: 18),
                          label: Text(
                            reflection != null
                                ? 'Edit Spending Reflection'
                                : 'Add Spending Reflection (Optional)',
                          ),
                        );
                      },
                    ),
                  ],
                  const SizedBox(height: 10),
                  TextButton.icon(
                    onPressed: _isSaving ? null : _confirmDelete,
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      color: colorScheme.error,
                    ),
                    label: Text(
                      'Delete Transaction',
                      style: TextStyle(color: colorScheme.error),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
