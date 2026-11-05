import '../../../core/database/app_database.dart';
import '../../../core/database/tables.dart';
import '../../../core/utils/money.dart';
import '../models/category.dart';
import '../models/transaction.dart';

enum TransactionSortOrder {
  dateDesc('Date (Newest first)'),
  dateAsc('Date (Oldest first)'),
  amountDesc('Amount (Highest first)'),
  amountAsc('Amount (Lowest first)');

  final String label;
  const TransactionSortOrder(this.label);
}

class PeriodTotals {
  final Money totalIncome;
  final Money totalExpense;
  final Money netBalance;
  final int transactionCount;

  const PeriodTotals({
    required this.totalIncome,
    required this.totalExpense,
    required this.netBalance,
    required this.transactionCount,
  });

  const PeriodTotals.zero()
    : totalIncome = const Money.zero(),
      totalExpense = const Money.zero(),
      netBalance = const Money.zero(),
      transactionCount = 0;
}

/// Repository managing CRUD and queries for Transactions and Categories in SQLite
class TransactionRepository {
  final AppDatabase _database;

  TransactionRepository(this._database);

  /// Retrieves filtered and sorted transactions with joined category metadata
  Future<List<FinancialTransaction>> getTransactions({
    DateTime? startDate,
    DateTime? endDate,
    TransactionType? type,
    String? categoryId,
    String? searchQuery,
    TransactionSortOrder sort = TransactionSortOrder.dateDesc,
  }) async {
    final db = await _database.database;

    final whereClauses = <String>[];
    final whereArgs = <dynamic>[];

    if (startDate != null) {
      whereClauses.add('t.transaction_date >= ?');
      whereArgs.add(startDate.toIso8601String());
    }

    if (endDate != null) {
      whereClauses.add('t.transaction_date <= ?');
      whereArgs.add(endDate.toIso8601String());
    }

    if (type != null) {
      whereClauses.add('t.type = ?');
      whereArgs.add(type.toDbString());
    }

    if (categoryId != null && categoryId.isNotEmpty) {
      whereClauses.add('t.category_id = ?');
      whereArgs.add(categoryId);
    }

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final query = '%${searchQuery.trim()}%';
      whereClauses.add(
        '(t.description LIKE ? OR t.note LIKE ? OR c.name LIKE ?)',
      );
      whereArgs.addAll([query, query, query]);
    }

    final whereSql = whereClauses.isNotEmpty
        ? 'WHERE ${whereClauses.join(' AND ')}'
        : '';

    String orderBySql;
    switch (sort) {
      case TransactionSortOrder.dateDesc:
        orderBySql = 'ORDER BY t.transaction_date DESC, t.created_at DESC';
        break;
      case TransactionSortOrder.dateAsc:
        orderBySql = 'ORDER BY t.transaction_date ASC, t.created_at ASC';
        break;
      case TransactionSortOrder.amountDesc:
        orderBySql = 'ORDER BY t.amount_cents DESC';
        break;
      case TransactionSortOrder.amountAsc:
        orderBySql = 'ORDER BY t.amount_cents ASC';
        break;
    }

    final sql =
        '''
      SELECT 
        t.*,
        c.name AS category_name,
        c.color AS category_color,
        c.icon AS category_icon
      FROM ${DbTables.transactions} t
      LEFT JOIN ${DbTables.categories} c ON t.category_id = c.id
      $whereSql
      $orderBySql
    ''';

    final results = await db.rawQuery(sql, whereArgs);
    return results.map((row) => FinancialTransaction.fromMap(row)).toList();
  }

  /// Fetches a single transaction by ID
  Future<FinancialTransaction?> getTransactionById(String id) async {
    final db = await _database.database;
    final results = await db.rawQuery(
      '''
      SELECT 
        t.*,
        c.name AS category_name,
        c.color AS category_color,
        c.icon AS category_icon
      FROM ${DbTables.transactions} t
      LEFT JOIN ${DbTables.categories} c ON t.category_id = c.id
      WHERE t.id = ?
      LIMIT 1
      ''',
      [id],
    );

    if (results.isEmpty) return null;
    return FinancialTransaction.fromMap(results.first);
  }

  /// Inserts a new transaction atomically
  Future<void> createTransaction(FinancialTransaction transaction) async {
    final db = await _database.database;
    await db.insert(DbTables.transactions, transaction.toMap());
  }

  /// Inserts multiple transactions atomically in a single database transaction
  Future<void> createTransactions(List<FinancialTransaction> transactions) async {
    if (transactions.isEmpty) return;
    final db = await _database.database;
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final tx in transactions) {
        batch.insert(DbTables.transactions, tx.toMap());
      }
      await batch.commit(noResult: true);
    });
  }

  /// Updates an existing transaction
  Future<void> updateTransaction(FinancialTransaction transaction) async {
    final db = await _database.database;
    await db.update(
      DbTables.transactions,
      transaction.toMap(),
      where: 'id = ?',
      whereArgs: [transaction.id],
    );
  }

  /// Deletes a transaction by ID and any linked spending reflection
  Future<void> deleteTransaction(String id) async {
    final db = await _database.database;
    await db.transaction((txn) async {
      try {
        await txn.delete(
          DbTables.spendingReflections,
          where: 'transaction_id = ?',
          whereArgs: [id],
        );
      } catch (_) {
        // Table might not exist in older schema versions
      }
      await txn.delete(DbTables.transactions, where: 'id = ?', whereArgs: [id]);
    });
  }

  /// Retrieves categories, optionally filtered by type ('expense', 'income', or 'both')
  Future<List<Category>> getCategories({String? type}) async {
    final db = await _database.database;

    List<Map<String, dynamic>> results;
    if (type != null) {
      results = await db.query(
        DbTables.categories,
        where: 'type = ? OR type = ?',
        whereArgs: [type, 'both'],
        orderBy: 'name ASC',
      );
    } else {
      results = await db.query(DbTables.categories, orderBy: 'name ASC');
    }

    return results.map((row) => Category.fromMap(row)).toList();
  }

  /// Fetches a single category by ID
  Future<Category?> getCategoryById(String id) async {
    final db = await _database.database;
    final results = await db.query(
      DbTables.categories,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (results.isEmpty) return null;
    return Category.fromMap(results.first);
  }

  /// Creates a new category
  Future<void> createCategory(Category category) async {
    final db = await _database.database;
    await db.insert(DbTables.categories, category.toMap());
  }

  /// Updates a category
  Future<void> updateCategory(Category category) async {
    final db = await _database.database;
    await db.update(
      DbTables.categories,
      category.toMap(),
      where: 'id = ?',
      whereArgs: [category.id],
    );
  }

  /// Checks how many transactions use this category
  Future<int> getTransactionCountForCategory(String categoryId) async {
    final db = await _database.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM ${DbTables.transactions} WHERE category_id = ?',
      [categoryId],
    );
    return (result.first['count'] as num?)?.toInt() ?? 0;
  }

  /// Deletes a category safely; returns false if category has existing transactions
  Future<bool> deleteCategory(String id) async {
    final count = await getTransactionCountForCategory(id);
    if (count > 0) {
      return false; // Prevent deletion of categories with active records
    }

    final db = await _database.database;
    final deletedRows = await db.delete(
      DbTables.categories,
      where: 'id = ?',
      whereArgs: [id],
    );
    return deletedRows > 0;
  }

  /// Calculates total income, expense, and net balance for a date range
  Future<PeriodTotals> getPeriodTotals({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final db = await _database.database;

    final whereClauses = <String>[];
    final whereArgs = <dynamic>[];

    if (startDate != null) {
      whereClauses.add('transaction_date >= ?');
      whereArgs.add(startDate.toIso8601String());
    }

    if (endDate != null) {
      whereClauses.add('transaction_date <= ?');
      whereArgs.add(endDate.toIso8601String());
    }

    final whereSql = whereClauses.isNotEmpty
        ? 'WHERE ${whereClauses.join(' AND ')}'
        : '';

    final sql =
        '''
      SELECT 
        type,
        COALESCE(SUM(amount_cents), 0) AS total_cents,
        COUNT(*) AS count
      FROM ${DbTables.transactions}
      $whereSql
      GROUP BY type
    ''';

    final results = await db.rawQuery(sql, whereArgs);

    int incomeCents = 0;
    int expenseCents = 0;
    int totalCount = 0;

    for (final row in results) {
      final type = row['type'] as String?;
      final cents = (row['total_cents'] as num?)?.toInt() ?? 0;
      final count = (row['count'] as num?)?.toInt() ?? 0;
      totalCount += count;

      if (type == 'income') {
        incomeCents = cents;
      } else if (type == 'expense') {
        expenseCents = cents;
      }
    }

    final income = Money(incomeCents);
    final expense = Money(expenseCents);
    final net = income - expense;

    return PeriodTotals(
      totalIncome: income,
      totalExpense: expense,
      netBalance: net,
      transactionCount: totalCount,
    );
  }
}
