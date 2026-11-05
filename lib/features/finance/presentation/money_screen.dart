import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/responsive_layout.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/empty_state_card.dart';
import '../../../core/widgets/financial_amount_text.dart';
import '../../settings/providers/settings_provider.dart';
import '../models/payment_method.dart';
import '../models/transaction.dart';
import '../providers/transaction_providers.dart';
import '../repositories/transaction_repository.dart';
import '../utils/category_icons.dart';
import 'budgets_view.dart';
import 'reports_view.dart';
import 'savings_view.dart';
import 'bank_statement_import_sheet.dart';
import 'quick_catch_up_sheet.dart';
import 'transaction_form_sheet.dart';

class MoneyScreen extends ConsumerStatefulWidget {
  const MoneyScreen({super.key});

  @override
  ConsumerState<MoneyScreen> createState() => _MoneyScreenState();
}

class _MoneyScreenState extends ConsumerState<MoneyScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: ref.read(moneySubTabProvider),
    );
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        ref.read(moneySubTabProvider.notifier).setSubTab(_tabController.index);
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _openTransactionForm([FinancialTransaction? transaction]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => TransactionFormSheet(transactionToEdit: transaction),
    );
  }

  void _openQuickCatchUp([DateTime? initialDate]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => QuickCatchUpSheet(initialBatchDate: initialDate),
    );
  }

  void _openBankStatementImport() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const BankStatementImportSheet(),
    );
  }

  Future<void> _pickCustomDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: DateTimeRange(
        start: DateTime(now.year, now.month, 1),
        end: now,
      ),
    );

    if (picked != null) {
      ref
          .read(transactionFilterProvider.notifier)
          .setCustomRange(
            picked.start,
            DateTime(
              picked.end.year,
              picked.end.month,
              picked.end.day,
              23,
              59,
              59,
            ),
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(moneySubTabProvider, (prev, next) {
      if (_tabController.index != next) {
        _tabController.animateTo(next);
      }
    });

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final filter = ref.watch(transactionFilterProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Money'),
        actions: _tabController.index == 0
            ? [
                IconButton(
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  tooltip: 'Upload Bank Statement (PDF)',
                  onPressed: () => _openBankStatementImport(),
                ),
                IconButton(
                  icon: const Icon(Icons.bolt_rounded),
                  tooltip: 'Quick Catch-Up & Paste SMS',
                  onPressed: () => _openQuickCatchUp(),
                ),
                IconButton(
                  icon: const Icon(Icons.sort_rounded),
                  tooltip: 'Sort by',
                  onPressed: () => _showSortDialog(context, filter.sortOrder),
                ),
                IconButton(
                  icon: const Icon(Icons.filter_alt_outlined),
                  tooltip: 'Reset Filters',
                  onPressed: () {
                    _searchController.clear();
                    ref.read(transactionFilterProvider.notifier).resetFilters();
                  },
                ),
              ]
            : null,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelColor: colorScheme.primary,
          unselectedLabelColor: colorScheme.onSurfaceVariant,
          indicatorColor: colorScheme.primary,
          tabs: const [
            Tab(
              text: 'Transactions',
              icon: Icon(Icons.receipt_long_rounded, size: 20),
            ),
            Tab(text: 'Budgets', icon: Icon(Icons.pie_chart_rounded, size: 20)),
            Tab(text: 'Savings', icon: Icon(Icons.savings_rounded, size: 20)),
            Tab(text: 'Reports', icon: Icon(Icons.bar_chart_rounded, size: 20)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTransactionsTab(context),
          const BudgetsView(),
          const SavingsView(),
          const ReportsView(),
        ],
      ),
    );
  }

  Widget _buildTransactionsTab(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final settings = ref.watch(settingsProvider);
    final filter = ref.watch(transactionFilterProvider);
    final transactionsAsync = ref.watch(filteredTransactionsProvider);
    final totalsAsync = ref.watch(periodTotalsProvider);
    final categoriesAsync = ref.watch(categoriesProvider(null));

    return Scaffold(
      floatingActionButton: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'quick_catch_up_fab',
            tooltip: 'Quick Catch-Up & Paste SMS',
            backgroundColor: isDark
                ? AppColors.secondarySurfaceDark
                : AppColors.secondarySurfaceLight,
            foregroundColor: isDark
                ? AppColors.nothingRedDark
                : AppColors.nothingRed,
            onPressed: () => _openQuickCatchUp(),
            child: const Icon(Icons.bolt_rounded, size: 22),
          ),
          const SizedBox(width: 8),
          FloatingActionButton.extended(
            heroTag: 'add_transaction_fab',
            onPressed: () => _openTransactionForm(),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add Transaction'),
          ),
        ],
      ),
      body: ResponsiveContentWrapper(
        child: Column(
          children: [
            // 1. Period Totals Header
            totalsAsync.when(
              loading: () => const SizedBox(
                height: 70,
                child: Center(child: LinearProgressIndicator()),
              ),
              error: (err, stack) => const SizedBox.shrink(),
              data: (totals) {
                final netType = totals.netBalance.isNegative
                    ? FinancialAmountType.expense
                    : (totals.netBalance.isZero
                          ? FinancialAmountType.neutral
                          : FinancialAmountType.income);

                return Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: colorScheme.outline, width: 0.8),
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isUltraNarrow = constraints.maxWidth < 320;
                      if (isUltraNarrow) {
                        return Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Income',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: FinancialAmountText(
                                    amount: totals.totalIncome,
                                    currencySymbol: settings.currencySymbol,
                                    type: FinancialAmountType.income,
                                    alignment: Alignment.centerRight,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Expenses',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: FinancialAmountText(
                                    amount: totals.totalExpense,
                                    currencySymbol: settings.currencySymbol,
                                    type: FinancialAmountType.expense,
                                    alignment: Alignment.centerRight,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Divider(
                              height: 1,
                              color: colorScheme.outline.withValues(alpha: 0.5),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Net Balance',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: FinancialAmountText(
                                    amount: totals.netBalance,
                                    currencySymbol: settings.currencySymbol,
                                    type: netType,
                                    alignment: Alignment.centerRight,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );
                      }

                      return Row(
                        children: [
                          _buildTotalColumn(
                            context,
                            label: 'Income',
                            amount: totals.totalIncome,
                            type: FinancialAmountType.income,
                            currencySymbol: settings.currencySymbol,
                          ),
                          Container(
                            width: 1,
                            height: 28,
                            color: colorScheme.outline,
                          ),
                          _buildTotalColumn(
                            context,
                            label: 'Expenses',
                            amount: totals.totalExpense,
                            type: FinancialAmountType.expense,
                            currencySymbol: settings.currencySymbol,
                          ),
                          Container(
                            width: 1,
                            height: 28,
                            color: colorScheme.outline,
                          ),
                          _buildTotalColumn(
                            context,
                            label: 'Net Balance',
                            amount: totals.netBalance,
                            type: netType,
                            currencySymbol: settings.currencySymbol,
                          ),
                        ],
                      );
                    },
                  ),
                );
              },
            ),

            // 2. Search & Filters Row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search transactions...',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            ref
                                .read(transactionFilterProvider.notifier)
                                .setSearchQuery('');
                          },
                        )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  isDense: true,
                ),
                onChanged: (val) {
                  ref
                      .read(transactionFilterProvider.notifier)
                      .setSearchQuery(val);
                },
              ),
            ),

            // 3. Filter Chips (Date presets, Type, Categories)
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                children: [
                  // Type Filter: All / Expense / Income
                  FilterChip(
                    label: const Text('All'),
                    selected: filter.type == null,
                    onSelected: (_) => ref
                        .read(transactionFilterProvider.notifier)
                        .setType(null),
                  ),
                  const SizedBox(width: 6),
                  FilterChip(
                    label: const Text('Expenses'),
                    selected: filter.type == TransactionType.expense,
                    onSelected: (_) => ref
                        .read(transactionFilterProvider.notifier)
                        .setType(TransactionType.expense),
                  ),
                  const SizedBox(width: 6),
                  FilterChip(
                    label: const Text('Income'),
                    selected: filter.type == TransactionType.income,
                    onSelected: (_) => ref
                        .read(transactionFilterProvider.notifier)
                        .setType(TransactionType.income),
                  ),
                  const SizedBox(width: 12),
                  Container(width: 1, height: 24, color: colorScheme.outline),
                  const SizedBox(width: 12),

                  // Date Presets
                  ...DateRangePreset.values.map((preset) {
                    final isSelected = filter.preset == preset;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: FilterChip(
                        label: Text(preset.label),
                        selected: isSelected,
                        onSelected: (_) {
                          if (preset == DateRangePreset.custom) {
                            _pickCustomDateRange();
                          } else {
                            ref
                                .read(transactionFilterProvider.notifier)
                                .setPreset(preset);
                          }
                        },
                      ),
                    );
                  }),

                  // Category Filter Chip
                  categoriesAsync.maybeWhen(
                    data: (categories) {
                      final selectedCat = categories
                          .where((c) => c.id == filter.categoryId)
                          .firstOrNull;
                      return ActionChip(
                        avatar: selectedCat != null
                            ? CircleAvatar(
                                radius: 8,
                                backgroundColor: Color(selectedCat.color),
                              )
                            : const Icon(Icons.category_outlined, size: 16),
                        label: Text(
                          selectedCat != null ? selectedCat.name : 'Category',
                        ),
                        onPressed: () => _showCategoryFilterSheet(
                          context,
                          categories,
                          filter.categoryId,
                        ),
                      );
                    },
                    orElse: () => const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
            const Divider(height: 8),

            // 4. Transactions List
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(filteredTransactionsProvider);
                  ref.invalidate(periodTotalsProvider);
                  await ref.read(filteredTransactionsProvider.future);
                },
                child: transactionsAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (err, _) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            size: 40,
                            color: Colors.red,
                          ),
                          const SizedBox(height: 10),
                          Text('Error loading transactions: $err'),
                          const SizedBox(height: 12),
                          FilledButton(
                            onPressed: () =>
                                ref.invalidate(filteredTransactionsProvider),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  data: (transactions) {
                    if (transactions.isEmpty) {
                      final isFiltered =
                          filter.searchQuery.isNotEmpty ||
                          filter.type != null ||
                          filter.categoryId != null ||
                          filter.preset != DateRangePreset.thisMonth;

                      return Center(
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(24),
                          child: EmptyStateCard(
                            icon: isFiltered
                                ? Icons.search_off_rounded
                                : Icons.receipt_long_outlined,
                            title: isFiltered
                                ? 'No matching transactions'
                                : 'No transactions recorded',
                            description: isFiltered
                                ? 'Try adjusting your filters, date range, or search keywords.'
                                : 'Tap the button below to add your first income or expense.',
                            actionLabel: isFiltered
                                ? 'Clear Filters'
                                : 'Add Transaction',
                            onAction: () {
                              if (isFiltered) {
                                _searchController.clear();
                                ref
                                    .read(transactionFilterProvider.notifier)
                                    .resetFilters();
                              } else {
                                _openTransactionForm();
                              }
                            },
                          ),
                        ),
                      );
                    }

                    // Group transactions by date
                    final groups = _groupTransactionsByDate(transactions);

                    return ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.only(bottom: 84),
                      itemCount: groups.length,
                      itemBuilder: (context, index) {
                        final group = groups[index];
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildDateGroupHeader(
                              context,
                              group.date,
                              group.dayTotal,
                              settings.currencySymbol,
                            ),
                            ...group.items.map(
                              (tx) => _buildTransactionTile(
                                context,
                                tx,
                                settings.currencySymbol,
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalColumn(
    BuildContext context, {
    required String label,
    required Money amount,
    required FinancialAmountType type,
    required String currencySymbol,
  }) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          FinancialAmountText(
            amount: amount,
            currencySymbol: currencySymbol,
            type: type,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateGroupHeader(
    BuildContext context,
    DateTime date,
    Money dayTotal,
    String currencySymbol,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final now = DateTime.now();

    String title;
    if (AppDateUtils.isSameDay(date, now)) {
      title = 'Today';
    } else if (AppDateUtils.isSameDay(
      date,
      now.subtract(const Duration(days: 1)),
    )) {
      title = 'Yesterday';
    } else {
      title = AppDateUtils.toShortDate(date);
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            dayTotal.format(symbol: currencySymbol, includeSign: true),
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: dayTotal.isNegative
                  ? AppColors.expenseCoral
                  : (dayTotal.isZero
                        ? colorScheme.onSurfaceVariant
                        : AppColors.incomeGreen),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionTile(
    BuildContext context,
    FinancialTransaction tx,
    String currencySymbol,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isIncome = tx.type == TransactionType.income;
    final catColor = Color(tx.categoryColor ?? 0xFF90A4AE);
    final iconData = CategoryIconHelper.getIcon(tx.categoryIcon);
    final paymentMethod = PaymentMethod.fromId(tx.paymentMethod);

    return InkWell(
      onTap: () => _openTransactionForm(tx),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: catColor.withValues(alpha: 0.18),
              child: Icon(iconData, color: catColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tx.description ?? tx.categoryName ?? 'Transaction',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      if (tx.categoryName != null) ...[
                        Flexible(
                          child: Text(
                            tx.categoryName!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontSize: 11,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '•',
                          style: TextStyle(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 10,
                          ),
                        ),
                        const SizedBox(width: 4),
                      ],
                      Flexible(
                        child: Text(
                          paymentMethod.label,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '•',
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 10,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        AppDateUtils.toDisplayTime(tx.transactionDate),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FinancialAmountText(
              amount: tx.amount,
              currencySymbol: currencySymbol,
              type: isIncome
                  ? FinancialAmountType.income
                  : FinancialAmountType.expense,
              showSign: true,
              showIcon: true,
              alignment: Alignment.centerRight,
            ),
          ],
        ),
      ),
    );
  }

  void _showSortDialog(BuildContext context, TransactionSortOrder currentSort) {
    showDialog(
      context: context,
      builder: (dialogCtx) => SimpleDialog(
        title: const Text('Sort Transactions'),
        children: TransactionSortOrder.values.map((order) {
          final isSelected = order == currentSort;
          return ListTile(
            title: Text(order.label),
            trailing: isSelected
                ? const Icon(Icons.check_rounded, color: AppColors.sagePrimary)
                : null,
            onTap: () {
              ref.read(transactionFilterProvider.notifier).setSortOrder(order);
              Navigator.of(dialogCtx).pop();
            },
          );
        }).toList(),
      ),
    );
  }

  void _showCategoryFilterSheet(
    BuildContext context,
    List<dynamic> categories,
    String? selectedCategoryId,
  ) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Filter by Category',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          ListTile(
            title: const Text('All Categories'),
            trailing: selectedCategoryId == null
                ? const Icon(Icons.check, color: AppColors.sagePrimary)
                : null,
            onTap: () {
              ref.read(transactionFilterProvider.notifier).setCategory(null);
              Navigator.of(ctx).pop();
            },
          ),
          ...categories.map((c) {
            final isSelected = c.id == selectedCategoryId;
            return ListTile(
              leading: CircleAvatar(
                radius: 14,
                backgroundColor: Color(c.color).withValues(alpha: 0.2),
                child: Icon(
                  CategoryIconHelper.getIcon(c.icon),
                  color: Color(c.color),
                  size: 16,
                ),
              ),
              title: Text(c.name),
              trailing: isSelected
                  ? const Icon(Icons.check, color: AppColors.sagePrimary)
                  : null,
              onTap: () {
                ref.read(transactionFilterProvider.notifier).setCategory(c.id);
                Navigator.of(ctx).pop();
              },
            );
          }),
        ],
      ),
    );
  }

  List<_DateGroup> _groupTransactionsByDate(
    List<FinancialTransaction> transactions,
  ) {
    final Map<String, List<FinancialTransaction>> groupsMap = {};
    for (final tx in transactions) {
      final dateKey = AppDateUtils.toIsoDate(tx.transactionDate);
      groupsMap.putIfAbsent(dateKey, () => []).add(tx);
    }

    final List<_DateGroup> groups = [];
    for (final entry in groupsMap.entries) {
      final date = DateTime.parse(entry.key);
      int netCents = 0;
      for (final tx in entry.value) {
        if (tx.type == TransactionType.income) {
          netCents += tx.amount.cents;
        } else {
          netCents -= tx.amount.cents;
        }
      }
      groups.add(
        _DateGroup(date: date, items: entry.value, dayTotal: Money(netCents)),
      );
    }
    return groups;
  }
}

class _DateGroup {
  final DateTime date;
  final List<FinancialTransaction> items;
  final Money dayTotal;

  _DateGroup({required this.date, required this.items, required this.dayTotal});
}
