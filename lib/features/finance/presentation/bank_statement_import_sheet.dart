import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
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
import '../services/bank_statement_pdf_service.dart';
import '../services/smart_transaction_parser.dart';
import '../utils/category_icons.dart';

/// Sheet that allows users to pick a bank statement PDF, extract transactions
/// completely offline, review line items, and batch-import them into the database.
class BankStatementImportSheet extends ConsumerStatefulWidget {
  final Uint8List? preloadedPdfBytes;
  final String? preloadedFileName;

  const BankStatementImportSheet({
    super.key,
    this.preloadedPdfBytes,
    this.preloadedFileName,
  });

  @override
  ConsumerState<BankStatementImportSheet> createState() =>
      _BankStatementImportSheetState();
}

class _BankStatementImportSheetState
    extends ConsumerState<BankStatementImportSheet> {
  Uint8List? _pdfBytes;
  String? _fileName;

  bool _isLoading = false;
  String? _errorMessage;
  bool _isPasswordRequired = false;
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;

  BankStatementParseResult? _parseResult;
  List<ParsedTransactionDraft> _items = [];
  final Set<int> _selectedIndices = {};
  String _activeFilter = 'ALL'; // 'ALL', 'EXPENSE', 'INCOME'

  bool _isImporting = false;

  @override
  void initState() {
    super.initState();
    if (widget.preloadedPdfBytes != null) {
      _pdfBytes = widget.preloadedPdfBytes;
      _fileName = widget.preloadedFileName ?? 'bank_statement.pdf';
      _processBytes(_pdfBytes!);
    }
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _pickPdfFile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _isPasswordRequired = false;
    });

    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (files.isEmpty) {
        setState(() => _isLoading = false);
        return;
      }

      final file = files.single;
      final bytes = await file.readAsBytes();

      if (bytes.isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Could not read file data. Please try again.';
        });
        return;
      }

      _pdfBytes = bytes;
      _fileName = file.name;
      await _processBytes(bytes);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to open file: $e';
      });
    }
  }

  Future<void> _processBytes(Uint8List bytes, {String? password}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await BankStatementPdfService.parsePdfBytes(
        bytes,
        password: password,
      );

      if (result.isPasswordProtected) {
        setState(() {
          _isLoading = false;
          _isPasswordRequired = true;
          _errorMessage =
              'This statement is password protected. Enter password (e.g. PAN or DOB DDMMYYYY).';
        });
        return;
      }

      if (result.error != null && !result.isSuccess) {
        setState(() {
          _isLoading = false;
          _isPasswordRequired = false;
          _errorMessage = result.error;
        });
        return;
      }

      if (result.transactions.isEmpty) {
        setState(() {
          _isLoading = false;
          _isPasswordRequired = false;
          _errorMessage =
              'No transaction line items detected. Make sure the PDF contains digital text (not a scanned image).';
        });
        return;
      }

      setState(() {
        _isLoading = false;
        _isPasswordRequired = false;
        _parseResult = result;
        _items = List.from(result.transactions);
        _selectedIndices.clear();
        for (var i = 0; i < _items.length; i++) {
          _selectedIndices.add(i);
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error parsing bank statement: $e';
      });
    }
  }

  Future<void> _submitPassword() async {
    final pwd = _passwordController.text.trim();
    if (pwd.isEmpty || _pdfBytes == null) return;
    await _processBytes(_pdfBytes!, password: pwd);
  }

  List<int> get _filteredIndices {
    final list = <int>[];
    for (var i = 0; i < _items.length; i++) {
      final item = _items[i];
      if (_activeFilter == 'EXPENSE' && item.type != TransactionType.expense) {
        continue;
      }
      if (_activeFilter == 'INCOME' && item.type != TransactionType.income) {
        continue;
      }
      list.add(i);
    }
    return list;
  }

  Money get _selectedDebitTotal {
    int sum = 0;
    for (final idx in _selectedIndices) {
      if (idx < _items.length && _items[idx].type == TransactionType.expense) {
        sum += _items[idx].amount.cents;
      }
    }
    return Money(sum);
  }

  Money get _selectedCreditTotal {
    int sum = 0;
    for (final idx in _selectedIndices) {
      if (idx < _items.length && _items[idx].type == TransactionType.income) {
        sum += _items[idx].amount.cents;
      }
    }
    return Money(sum);
  }

  void _showCategoryPicker(
    int index,
    List<Category> allCategories,
    ParsedTransactionDraft draft,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final isDark = theme.brightness == Brightness.dark;

        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.85,
          builder: (_, scrollCtrl) => Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    'SELECT CATEGORY',
                    style: TextStyle(
                      fontFamily: 'NotoSansMono',
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.builder(
                    controller: scrollCtrl,
                    itemCount: allCategories.length,
                    itemBuilder: (_, catIdx) {
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
                            ? const Icon(Icons.check_rounded,
                                color: AppColors.nothingRed)
                            : null,
                        onTap: () {
                          setState(() {
                            _items[index] =
                                draft.copyWith(categoryId: cat.id);
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

  Future<void> _importSelected() async {
    if (_selectedIndices.isEmpty) return;

    setState(() => _isImporting = true);
    try {
      final repo = ref.read(transactionRepositoryProvider);
      final now = DateTime.now();

      final transactions = _selectedIndices.map((idx) {
        final draft = _items[idx];
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
              'Successfully imported ${transactions.length} transactions.',
            ),
            backgroundColor: AppColors.incomeGreenDark,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isImporting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error importing transactions: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final isWearable = AppBreakpoints.isWearable(context);
    final settings = ref.watch(settingsProvider);
    final categoriesAsync = ref.watch(categoriesProvider(null));
    final categoriesList = categoriesAsync.value ?? [];
    final categoryMap = {for (final c in categoriesList) c.id: c};

    return DraggableScrollableSheet(
      initialChildSize: isWearable ? 1.0 : 0.92,
      minChildSize: isWearable ? 0.7 : 0.5,
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
                                  'BANK STATEMENT PDF',
                                  style: TextStyle(
                                    fontFamily: 'NotoSansMono',
                                    fontSize: isWearable ? 13 : 15,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.6,
                                    color: colorScheme.onSurface,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (!isWearable)
                                  Text(
                                    '100% offline & secure on-device statement import',
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

              // 3. Body Content
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(strokeWidth: 2.5),
                            SizedBox(height: 16),
                            Text(
                              'Extracting & parsing statement...',
                              style: TextStyle(
                                fontFamily: 'NotoSansMono',
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      )
                    : _items.isEmpty
                        ? _buildUploadPrompt(context, isDark, isWearable)
                        : _buildReviewContent(
                            context,
                            scrollController,
                            isDark,
                            isWearable,
                            settings.currencySymbol,
                            categoriesList,
                            categoryMap,
                          ),
              ),

              // 4. Bottom Commit Bar (When transactions available)
              if (_items.isNotEmpty)
                _buildCommitBar(context, settings.currencySymbol, isDark),
            ],
          ),
        );
      },
    );
  }

  Widget _buildUploadPrompt(
    BuildContext context,
    bool isDark,
    bool isWearable,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_isPasswordRequired) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.primarySurfaceDark
                    : AppColors.primarySurfaceLight,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark
                      ? AppColors.nothingRedDark
                      : AppColors.nothingRed,
                  width: 1.2,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.lock_outline_rounded,
                        color: isDark
                            ? AppColors.nothingRedDark
                            : AppColors.nothingRed,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'ENCRYPTED PDF',
                        style: TextStyle(
                          fontFamily: 'NotoSansMono',
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This statement is protected by your bank. Standard passwords are date of birth (DDMMYYYY) or PAN.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Statement Password',
                      hintText: 'e.g. 15081995 or ABCDE1234F',
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () {
                          setState(
                              () => _obscurePassword = !_obscurePassword);
                        },
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onSubmitted: (_) => _submitPassword(),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _pickPdfFile,
                          child: const Text('PICK ANOTHER'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton(
                          onPressed: _submitPassword,
                          child: const Text('UNLOCK'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ] else ...[
            // Dashed / Wireframe Upload Box
            InkWell(
              onTap: _pickPdfFile,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 36,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.secondarySurfaceDark
                      : AppColors.secondarySurfaceLight,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark
                        ? AppColors.borderDividerDark
                        : AppColors.borderDividerLight,
                    width: 1.2,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: (isDark
                                ? AppColors.nothingRedDark
                                : AppColors.nothingRed)
                            .withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.picture_as_pdf_outlined,
                        size: 28,
                        color: isDark
                            ? AppColors.nothingRedDark
                            : AppColors.nothingRed,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'SELECT BANK STATEMENT PDF',
                      style: TextStyle(
                        fontFamily: 'NotoSansMono',
                        fontWeight: FontWeight.w700,
                        fontSize: isWearable ? 12 : 14,
                        letterSpacing: 0.5,
                        color: colorScheme.onSurface,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Pick any e-statement downloaded from your banking app.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: _pickPdfFile,
                      icon: const Icon(Icons.file_upload_outlined, size: 18),
                      label: const Text('BROWSE FILES'),
                    ),
                  ],
                ),
              ),
            ),
          ],

          if (_errorMessage != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded,
                      color: Colors.red, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(fontSize: 12, color: Colors.red),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),

          // Bank compatibility badges
          Text(
            'OFFLINE COMPATIBILITY',
            style: TextStyle(
              fontFamily: 'NotoSansMono',
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurfaceVariant,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _buildBadge('HDFC Bank', isDark),
              _buildBadge('State Bank of India', isDark),
              _buildBadge('ICICI Bank', isDark),
              _buildBadge('Axis Bank', isDark),
              _buildBadge('Kotak Mahindra', isDark),
              _buildBadge('Standard Tabular Statements', isDark),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String text, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.primarySurfaceDark
            : AppColors.primarySurfaceLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark
              ? AppColors.borderDividerDark
              : AppColors.borderDividerLight,
          width: 0.8,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: isDark
              ? AppColors.secondaryTextDark
              : AppColors.secondaryTextLight,
        ),
      ),
    );
  }

  Widget _buildReviewContent(
    BuildContext context,
    ScrollController scrollController,
    bool isDark,
    bool isWearable,
    String currencySymbol,
    List<Category> allCategories,
    Map<String, Category> categoryMap,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final filtered = _filteredIndices;

    return Column(
      children: [
        // 1. Statement Summary Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: isDark
              ? AppColors.primarySurfaceDark
              : AppColors.primarySurfaceLight,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      _parseResult?.bankName?.toUpperCase() ?? 'BANK STATEMENT',
                      style: const TextStyle(
                        fontFamily: 'NotoSansMono',
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        letterSpacing: 0.5,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  InkWell(
                    onTap: _pickPdfFile,
                    child: Text(
                      'CHANGE PDF',
                      style: TextStyle(
                        fontFamily: 'NotoSansMono',
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                        color: isDark
                            ? AppColors.nothingRedDark
                            : AppColors.nothingRed,
                      ),
                    ),
                  ),
                ],
              ),
              if (_fileName != null) ...[
                const SizedBox(height: 2),
                Text(
                  _fileName!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildSummaryItem(
                      label: 'DEBITS',
                      amount: _selectedDebitTotal,
                      type: FinancialAmountType.expense,
                      currencySymbol: currencySymbol,
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 24,
                    color: isDark
                        ? AppColors.borderDividerDark
                        : AppColors.borderDividerLight,
                  ),
                  Expanded(
                    child: _buildSummaryItem(
                      label: 'CREDITS',
                      amount: _selectedCreditTotal,
                      type: FinancialAmountType.income,
                      currencySymbol: currencySymbol,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // 2. Filter & Selection Controls
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Filters
              Row(
                children: [
                  _buildFilterTab('ALL', 'All (${_items.length})', isDark),
                  const SizedBox(width: 4),
                  _buildFilterTab('EXPENSE', 'Debits', isDark),
                  const SizedBox(width: 4),
                  _buildFilterTab('INCOME', 'Credits', isDark),
                ],
              ),
              // Select/Deselect All
              TextButton(
                onPressed: () {
                  setState(() {
                    if (_selectedIndices.length == _items.length) {
                      _selectedIndices.clear();
                    } else {
                      _selectedIndices.clear();
                      for (var i = 0; i < _items.length; i++) {
                        _selectedIndices.add(i);
                      }
                    }
                  });
                },
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                ),
                child: Text(
                  _selectedIndices.length == _items.length
                      ? 'DESELECT ALL'
                      : 'SELECT ALL',
                  style: const TextStyle(
                    fontFamily: 'NotoSansMono',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // 3. Transactions List
        Expanded(
          child: ListView.separated(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
            itemCount: filtered.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, idx) {
              final originalIdx = filtered[idx];
              final draft = _items[originalIdx];
              final isSelected = _selectedIndices.contains(originalIdx);

              final cat = categoryMap[draft.categoryId];
              final catName = cat?.name ?? 'Other';
              final catColor =
                  cat != null ? Color(cat.color) : Colors.grey;
              final catIcon = cat != null
                  ? CategoryIconHelper.getIcon(cat.icon)
                  : Icons.category_rounded;

              return _buildStatementItemCard(
                context,
                originalIdx,
                draft,
                isSelected,
                catName,
                catColor,
                catIcon,
                allCategories,
                currencySymbol,
                isDark,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryItem({
    required String label,
    required Money amount,
    required FinancialAmountType type,
    required String currencySymbol,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'NotoSansMono',
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 2),
        FinancialAmountText(
          amount: amount,
          type: type,
          currencySymbol: currencySymbol,
          showSign: true,
          style: const TextStyle(
            fontFamily: 'NotoSansMono',
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _buildFilterTab(String id, String label, bool isDark) {
    final isSelected = _activeFilter == id;
    final activeBorder = isDark
        ? AppColors.nothingRedDark
        : AppColors.nothingRed;

    return InkWell(
      onTap: () => setState(() => _activeFilter = id),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark
                  ? AppColors.secondarySurfaceDark
                  : AppColors.secondarySurfaceLight)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? activeBorder
                : (isDark
                    ? AppColors.borderDividerDark
                    : AppColors.borderDividerLight),
            width: isSelected ? 1.4 : 0.8,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'NotoSansMono',
            fontSize: 10,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? activeBorder : null,
          ),
        ),
      ),
    );
  }

  Widget _buildStatementItemCard(
    BuildContext context,
    int index,
    ParsedTransactionDraft draft,
    bool isSelected,
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

    return InkWell(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedIndices.remove(index);
          } else {
            _selectedIndices.add(index);
          }
        });
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.primarySurfaceDark
              : AppColors.primarySurfaceLight,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? (isDark
                    ? AppColors.nothingRedDark
                    : AppColors.nothingRed)
                : (isDark
                    ? AppColors.borderDividerDark
                    : AppColors.borderDividerLight),
            width: isSelected ? 1.4 : 0.8,
          ),
        ),
        child: Row(
          children: [
            Checkbox(
              value: isSelected,
              activeColor: isDark
                  ? AppColors.nothingRedDark
                  : AppColors.nothingRed,
              onChanged: (val) {
                setState(() {
                  if (val == true) {
                    _selectedIndices.add(index);
                  } else {
                    _selectedIndices.remove(index);
                  }
                });
              },
            ),

            // Category Avatar (Tappable to reassign)
            InkWell(
              onTap: () =>
                  _showCategoryPicker(index, allCategories, draft),
              borderRadius: BorderRadius.circular(20),
              child: CircleAvatar(
                radius: 16,
                backgroundColor: catColor.withValues(alpha: 0.18),
                child: Icon(catIcon, color: catColor, size: 16),
              ),
            ),
            const SizedBox(width: 10),

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
                  const SizedBox(height: 3),
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
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: catColor,
                          ),
                        ),
                      ),
                      Text(
                        '•',
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 9,
                        ),
                      ),
                      // Payment Method
                      Text(
                        draft.paymentMethod.toUpperCase(),
                        style: TextStyle(
                          fontFamily: 'NotoSansMono',
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        '•',
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 9,
                        ),
                      ),
                      // Date
                      Text(
                        AppDateUtils.toShortDate(draft.date),
                        style: TextStyle(
                          fontFamily: 'NotoSansMono',
                          fontSize: 9,
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
              style: const TextStyle(
                fontFamily: 'NotoSansMono',
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommitBar(
    BuildContext context,
    String currencySymbol,
    bool isDark,
  ) {
    final theme = Theme.of(context);
    final count = _selectedIndices.length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        border: Border(
          top: BorderSide(
            color: isDark
                ? AppColors.borderDividerDark
                : AppColors.borderDividerLight,
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$count OF ${_items.length} SELECTED',
                    style: TextStyle(
                      fontFamily: 'NotoSansMono',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurfaceVariant,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Debits: ${_selectedDebitTotal.format(symbol: currencySymbol)}',
                    style: TextStyle(
                      fontFamily: 'NotoSansMono',
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? AppColors.nothingRedDark
                          : AppColors.nothingRed,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed:
                  _selectedIndices.isEmpty || _isImporting ? null : _importSelected,
              icon: _isImporting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.download_done_rounded, size: 18),
              label: Text(
                _isImporting ? 'IMPORTING...' : 'IMPORT ($count)',
                style: const TextStyle(
                  fontFamily: 'NotoSansMono',
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
