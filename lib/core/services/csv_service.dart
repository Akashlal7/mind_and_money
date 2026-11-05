import '../database/app_database.dart';
import '../database/tables.dart';

/// Service responsible for generating standard RFC 4180 compliant CSV exports
/// of all financial transactions with proper escaping of quotes, commas, and line breaks.
class CsvExportService {
  final AppDatabase _database;

  const CsvExportService(this._database);

  /// Escapes a single CSV value according to RFC 4180 standards:
  /// - If the field contains comma, quote, or newline, enclose in double quotes.
  /// - Any internal double quote is escaped by doubling it (`""`).
  static String escapeCsvField(String? value) {
    if (value == null) return '';
    if (value.contains(',') ||
        value.contains('"') ||
        value.contains('\n') ||
        value.contains('\r')) {
      final escaped = value.replaceAll('"', '""');
      return '"$escaped"';
    }
    return value;
  }

  /// Exports all financial transactions to a CSV string.
  /// Resolves category IDs to category names.
  Future<String> exportTransactionsToCsv() async {
    final db = await _database.database;

    // Fetch categories lookup map
    final categoryRows = await db.query(DbTables.categories);
    final categoryMap = <String, String>{};
    for (final row in categoryRows) {
      final id = row['id'] as String;
      final name = row['name'] as String;
      categoryMap[id] = name;
    }

    // Fetch transactions sorted by date descending
    final txRows = await db.query(
      DbTables.transactions,
      orderBy: 'transaction_date DESC, created_at DESC',
    );

    final buffer = StringBuffer();
    // Standard RFC 4180 CSV Header
    buffer.writeln(
      'id,date,type,category,amount,payment_method,description,note,created_at',
    );

    for (final row in txRows) {
      final id = row['id'] as String;
      final date = (row['transaction_date'] as String?)?.split('T').first ?? '';
      final type = row['type'] as String? ?? 'expense';
      final categoryId = row['category_id'] as String? ?? '';
      final categoryName = categoryMap[categoryId] ?? categoryId;

      final amountCents = row['amount_cents'] as int? ?? 0;
      final amountDecimal = (amountCents / 100).toStringAsFixed(2);

      final paymentMethod = row['payment_method'] as String? ?? '';
      final description = row['description'] as String? ?? '';
      final note = row['note'] as String? ?? '';
      final createdAt = row['created_at'] as String? ?? '';

      final line = [
        escapeCsvField(id),
        escapeCsvField(date),
        escapeCsvField(type),
        escapeCsvField(categoryName),
        escapeCsvField(amountDecimal),
        escapeCsvField(paymentMethod),
        escapeCsvField(description),
        escapeCsvField(note),
        escapeCsvField(createdAt),
      ].join(',');

      buffer.writeln(line);
    }

    return buffer.toString();
  }
}
