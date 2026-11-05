import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/responsive_layout.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/id_generator.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/financial_amount_text.dart';
import '../../home/providers/home_providers.dart';
import '../../settings/providers/settings_provider.dart';
import '../models/category.dart';
import '../models/transaction.dart';
import '../providers/reports_providers.dart';
import '../providers/transaction_providers.dart';
import '../services/smart_transaction_parser.dart';
import '../utils/category_icons.dart';
import 'bank_statement_import_sheet.dart';

/// Mind & Money — Fast Catch-Up & Bank SMS Batch Logger.
/// Allows rapid logging of multiple missed transactions in seconds through
/// Bank SMS copy-pasting, one-liner natural language parsing, and quick batch queues.
class QuickCatchUpSheet extends ConsumerStatefulWidget {
  final DateTime? initialBatchDate;

  const QuickCatchUpSheet({super.key, this.initialBatchDate});

  @override
  ConsumerState<QuickCatchUpSheet> createState() => _QuickCatchUpSheetState();
}

class _QuickCatchUpSheetState extends ConsumerState<QuickCatchUpSheet> {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  late DateTime _batchDate;
  final List<ParsedTransactionDraft> _stagedDrafts = [];
  bool _isCommitting = false;

  @override
  void initState() {
    super.initState();
    _batchDate = widget.initialBatchDate ?? DateTime.now();
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _addFromText(String text) {
    if (text.trim().isEmpty) return;

    final parsed = SmartTransactionParser.parse(
      text,
      fallbackDate: _batchDate,
    );

    if (parsed.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not detect amount. Try e.g. "Coffee 120" or paste bank SMS.',
          ),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() {
      _stagedDrafts.addAll(parsed);
      _textController.clear();
    });
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text == null || text.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Clipboard is empty. Copy bank SMS or receipt first.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    _addFromText(text);
  }

  void _openBankStatementImport() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const BankStatementImportSheet(),
    );
  }

  Future<void> _pickCustomDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _batchDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _batchDate = DateTime(
          picked.year,
          picked.month,
          picked.day,
          _batchDate.hour,
          _batchDate.minute,
        );
      });
    }
  }

  Future<void> _commitAll() async {
    if (_stagedDrafts.isEmpty) return;

    setState(() => _isCommitting = true);
    try {
      final repo = ref.read(transactionRepositoryProvider);
      final now = DateTime.now();

      final transactions = _stagedDrafts.map((draft) {
        return FinancialTransaction(
          id: IdGenerator.generate(),
          amount: draft.amount,
          type: draft.type,
          categoryId: draft.categoryId,
          transactionDate: draft.date,
          description: draft.description,
          paymentMethod: draft.paymentMethod,
          note: draft.rawText != draft.description ? draft.rawText : null,
          createdAt: now,
          updatedAt: now,
        );
      }).toList();

      await repo.createTransactions(transactions);

      // Invalidate relevant providers to update all views immediately
      ref.invalidate(filteredTransactionsProvider);
      ref.invalidate(periodTotalsProvider);
      ref.invalidate(homeSummaryProvider);
      ref.invalidate(financialReportProvider);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Logged ${transactions.length} transactions successfully.',
            ),
            backgroundColor: AppColors.incomeGreenDark,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving transactions: $e')),
        );
        setState(() => _isCommitting = false);
      }
    }
  }

  void _showCategoryPicker(
    int index,
    List<Category> allCategories,
    ParsedTransactionDraft draft,
  ) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select Category',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.builder(
                    itemCount: allCategories.length,
                    itemBuilder: (ctx, catIdx) {
                      final cat = allCategories[catIdx];
                      final isSelected = cat.id == draft.categoryId;
                      final catColor = Color(cat.color);
                      final icon = CategoryIconHelper.getIcon(cat.icon);

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: catColor.withValues(alpha: 0.2),
                          child: Icon(icon, color: catColor, size: 18),
                        ),
                        title: Text(cat.name),
                        trailing: isSelected
                            ? const Icon(Icons.check_rounded, color: Colors.red)
                            : null,
                        onTap: () {
                          setState(() {
                            _stagedDrafts[index] = draft.copyWith(
                              categoryId: cat.id,
                            );
                          });
                          Navigator.pop(ctx);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Money get _totalExpense {
    int total = 0;
    for (final d in _stagedDrafts) {
      if (d.type == TransactionType.expense) {
        total += d.amount.cents;
      }
    }
    return Money(total);
  }

  Money get _totalIncome {
    int total = 0;
    for (final d in _stagedDrafts) {
      if (d.type == TransactionType.income) {
        total += d.amount.cents;
      }
    }
    return Money(total);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final settings = ref.watch(settingsProvider);
    final isWearable = AppBreakpoints.isWearable(context);
    final categoriesAsync = ref.watch(categoriesProvider(null));

    final categoriesList = categoriesAsync.value ?? [];
    final categoryMap = {for (final c in categoriesList) c.id: c};

    final now = DateTime.now();
    final isToday = _batchDate.year == now.year &&
        _batchDate.month == now.month &&
        _batchDate.day == now.day;
    final isYesterday = _batchDate.year == now.year &&
        _batchDate.month == now.month &&
        _batchDate.day == (now.day - 1);
    final is2DaysAgo = _batchDate.year == now.year &&
        _batchDate.month == now.month &&
        _batchDate.day == (now.day - 2);

    return DraggableScrollableSheet(
      initialChildSize: isWearable ? 1.0 : 0.88,
      minChildSize: isWearable ? 0.6 : 0.5,
      maxChildSize: 1.0,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // 1. Drag Handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // 2. Sheet Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppColors.nothingRedDark
                                  : AppColors.nothingRed,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'QUICK CATCH-UP',
                                  style: TextStyle(
                                    fontFamily: 'NotoSansMono',
                                    fontSize: isWearable ? 14 : 16,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.6,
                                    color: colorScheme.onSurface,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (!isWearable)
                                  Text(
                                    'Paste bank SMS or type one-liners to catch up missed days',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // 3. Batch Target Date Selector
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                color: isDark
                    ? AppColors.primarySurfaceDark
                    : AppColors.primarySurfaceLight,
                child: Row(
                  children: [
                    Icon(
                      Icons.event_available_rounded,
                      size: 16,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Log for:',
                      style: TextStyle(
                        fontFamily: 'NotoSansMono',
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildDateChip(
                              label: 'Today',
                              isSelected: isToday,
                              onTap: () => setState(() => _batchDate = now),
                              isDark: isDark,
                            ),
                            const SizedBox(width: 6),
                            _buildDateChip(
                              label: 'Yesterday',
                              isSelected: isYesterday,
                              onTap: () => setState(
                                () => _batchDate = DateTime(
                                  now.year,
                                  now.month,
                                  now.day - 1,
                                  now.hour,
                                  now.minute,
                                ),
                              ),
                              isDark: isDark,
                            ),
                            const SizedBox(width: 6),
                            _buildDateChip(
                              label: '2 Days Ago',
                              isSelected: is2DaysAgo,
                              onTap: () => setState(
                                () => _batchDate = DateTime(
                                  now.year,
                                  now.month,
                                  now.day - 2,
                                  now.hour,
                                  now.minute,
                                ),
                              ),
                              isDark: isDark,
                            ),
                            const SizedBox(width: 6),
                            _buildDateChip(
                              label: isToday || isYesterday || is2DaysAgo
                                  ? 'Custom'
                                  : AppDateUtils.toShortDate(_batchDate),
                              isSelected:
                                  !isToday && !isYesterday && !is2DaysAgo,
                              onTap: _pickCustomDate,
                              isDark: isDark,
                              icon: Icons.calendar_today_rounded,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // 4. Smart Input Bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _textController,
                        focusNode: _focusNode,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (val) {
                          _addFromText(val);
                          _focusNode.requestFocus();
                        },
                        decoration: InputDecoration(
                          hintText: isWearable
                              ? 'e.g. Coffee 120'
                              : 'e.g. "Coffee 120", "Uber 350 card", or paste SMS',
                          hintStyle: TextStyle(
                            fontSize: 13,
                            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          prefixIcon: Icon(
                            Icons.bolt_rounded,
                            size: 20,
                            color: isDark
                                ? AppColors.nothingRedDark
                                : AppColors.nothingRed,
                          ),
                          filled: true,
                          fillColor: isDark
                              ? AppColors.secondarySurfaceDark
                              : AppColors.secondarySurfaceLight,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: isDark
                                  ? AppColors.borderDividerDark
                                  : AppColors.borderDividerLight,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // PDF Statement Button
                    IconButton(
                      onPressed: _openBankStatementImport,
                      tooltip: 'Upload Bank Statement (PDF)',
                      icon: const Icon(Icons.picture_as_pdf_outlined, size: 20),
                      visualDensity: VisualDensity.compact,
                    ),
                    const SizedBox(width: 4),
                    // Paste Button
                    OutlinedButton.icon(
                      onPressed: _pasteFromClipboard,
                      icon: const Icon(Icons.paste_rounded, size: 16),
                      label: const Text('PASTE'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 12,
                        ),
                        textStyle: const TextStyle(
                          fontFamily: 'NotoSansMono',
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Add Button
                    FilledButton(
                      onPressed: () {
                        _addFromText(_textController.text);
                        _focusNode.requestFocus();
                      },
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                      child: const Icon(Icons.arrow_upward_rounded, size: 18),
                    ),
                  ],
                ),
              ),

              // 5. Staged Transaction List
              Expanded(
                child: _stagedDrafts.isEmpty
                    ? _buildEmptyState(context, isDark, scrollController)
                    : ListView.separated(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                        itemCount: _stagedDrafts.length,
                        separatorBuilder: (ctx, _) => const SizedBox(height: 8),
                        itemBuilder: (ctx, idx) {
                          final draft = _stagedDrafts[idx];
                          final category = categoryMap[draft.categoryId];
                          final catName = category?.name ?? 'Other';
                          final catColor = Color(
                            category?.color ?? 0xFF90A4AE,
                          );
                          final catIcon = CategoryIconHelper.getIcon(
                            category?.icon ?? 'category',
                          );

                          return _buildDraftCard(
                            context,
                            idx,
                            draft,
                            catName,
                            catColor,
                            catIcon,
                            categoriesList,
                            settings.currencySymbol,
                            isDark,
                          );
                        },
                      ),
              ),

              // 6. Bottom Sticky Action & Summary Bar
              if (_stagedDrafts.isNotEmpty)
                _buildCommitBar(context, settings.currencySymbol, isDark),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDateChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
    IconData? icon,
  }) {
    final activeBg = isDark
        ? AppColors.secondarySurfaceDark
        : AppColors.secondarySurfaceLight;
    final activeBorder = isDark
        ? AppColors.nothingRedDark
        : AppColors.nothingRed;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? activeBg : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? activeBorder
                : (isDark
                    ? AppColors.borderDividerDark
                    : AppColors.borderDividerLight),
            width: isSelected ? 1.4 : 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 12, color: isSelected ? activeBorder : null),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontFamily: 'NotoSansMono',
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? activeBorder : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    bool isDark,
    ScrollController scrollController,
  ) {
    return SingleChildScrollView(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 36,
              color: isDark
                  ? AppColors.secondaryTextDark
                  : AppColors.secondaryTextLight,
            ),
            const SizedBox(height: 8),
            Text(
              'No items staged yet',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Paste bank SMS or try a 1-tap quick example below:',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              children: [
                _buildExampleChip('Coffee 120'),
                _buildExampleChip('Lunch 250'),
                _buildExampleChip('Uber 350 card'),
                _buildExampleChip('Groceries 1500 blinkit upi'),
                _buildExampleChip('Electricity 1200'),
              ],
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _openBankStatementImport,
              icon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
              label: const Text('UPLOAD BANK STATEMENT (PDF)'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                textStyle: const TextStyle(
                  fontFamily: 'NotoSansMono',
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExampleChip(String text) {
    return ActionChip(
      label: Text(
        '+ $text',
        style: const TextStyle(
          fontFamily: 'NotoSansMono',
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
      onPressed: () => _addFromText(text),
    );
  }

  Widget _buildDraftCard(
    BuildContext context,
    int index,
    ParsedTransactionDraft draft,
    String catName,
    Color catColor,
    IconData catIcon,
    List<Category> allCategories,
    String currencySymbol,
    bool isDark,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isExpense = draft.type == TransactionType.expense;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.primarySurfaceDark
            : AppColors.primarySurfaceLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? AppColors.borderDividerDark
              : AppColors.borderDividerLight,
          width: 0.8,
        ),
      ),
      child: Row(
        children: [
          // Category Avatar (Tappable to reassign)
          InkWell(
            onTap: () => _showCategoryPicker(index, allCategories, draft),
            borderRadius: BorderRadius.circular(20),
            child: CircleAvatar(
              radius: 18,
              backgroundColor: catColor.withValues(alpha: 0.18),
              child: Icon(catIcon, color: catColor, size: 18),
            ),
          ),
          const SizedBox(width: 12),

          // Details Column
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  draft.description,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    // Category Tag
                    InkWell(
                      onTap: () =>
                          _showCategoryPicker(index, allCategories, draft),
                      child: Text(
                        catName,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: catColor,
                        ),
                      ),
                    ),
                    Text(
                      '•',
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 10,
                      ),
                    ),
                    // Payment Method Badge
                    Text(
                      draft.paymentMethod.toUpperCase(),
                      style: TextStyle(
                        fontFamily: 'NotoSansMono',
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      '•',
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 10,
                      ),
                    ),
                    // Date
                    Text(
                      AppDateUtils.toShortDate(draft.date),
                      style: TextStyle(
                        fontFamily: 'NotoSansMono',
                        fontSize: 10,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Amount
          FinancialAmountText(
            amount: draft.amount,
            type: isExpense
                ? FinancialAmountType.expense
                : FinancialAmountType.income,
            currencySymbol: currencySymbol,
            showSign: true,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
          ),
          const SizedBox(width: 4),

          // Delete draft
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, size: 18),
            color: colorScheme.onSurfaceVariant,
            visualDensity: VisualDensity.compact,
            onPressed: () {
              setState(() {
                _stagedDrafts.removeAt(index);
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCommitBar(
    BuildContext context,
    String currencySymbol,
    bool isDark,
  ) {
    final count = _stagedDrafts.length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.primarySurfaceDark
            : AppColors.primarySurfaceLight,
        border: Border(
          top: BorderSide(
            color: isDark
                ? AppColors.borderDividerDark
                : AppColors.borderDividerLight,
            width: 1.0,
          ),
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Running Total Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$count ${count == 1 ? 'ITEM' : 'ITEMS'} STAGED',
                    style: const TextStyle(
                      fontFamily: 'NotoSansMono',
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      if (_totalExpense.cents > 0)
                        Text(
                          '-${_totalExpense.format(symbol: currencySymbol)}',
                          style: TextStyle(
                            fontFamily: 'NotoSansMono',
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: isDark
                                ? AppColors.nothingRedDark
                                : AppColors.nothingRed,
                          ),
                        ),
                      if (_totalExpense.cents > 0 && _totalIncome.cents > 0)
                        const Text('  /  '),
                      if (_totalIncome.cents > 0)
                        Text(
                          '+${_totalIncome.format(symbol: currencySymbol)}',
                          style: TextStyle(
                            fontFamily: 'NotoSansMono',
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: isDark
                                ? AppColors.incomeGreenDark
                                : AppColors.incomeGreen,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),

            // Save All Button
            FilledButton.icon(
              onPressed: _isCommitting ? null : _commitAll,
              style: FilledButton.styleFrom(
                backgroundColor: isDark
                    ? AppColors.nothingRedDark
                    : AppColors.nothingRed,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: _isCommitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check_rounded, size: 18),
              label: Text(
                _isCommitting ? 'SAVING...' : 'SAVE ALL ($count)',
                style: const TextStyle(
                  fontFamily: 'NotoSansMono',
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  letterSpacing: 0.6,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
