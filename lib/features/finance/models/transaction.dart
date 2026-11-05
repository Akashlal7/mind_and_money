import '../../../core/utils/money.dart';

enum TransactionType {
  income,
  expense;

  static TransactionType fromString(String val) {
    return val.toLowerCase() == 'income'
        ? TransactionType.income
        : TransactionType.expense;
  }

  String toDbString() => name;
}

/// Model representing a financial transaction (income or expense)
class FinancialTransaction {
  final String id;
  final Money amount;
  final TransactionType type;
  final String categoryId;
  final DateTime transactionDate;
  final String? description;
  final String? paymentMethod;
  final String? note;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Optional category name and color for UI display
  final String? categoryName;
  final int? categoryColor;
  final String? categoryIcon;

  const FinancialTransaction({
    required this.id,
    required this.amount,
    required this.type,
    required this.categoryId,
    required this.transactionDate,
    this.description,
    this.paymentMethod,
    this.note,
    required this.createdAt,
    required this.updatedAt,
    this.categoryName,
    this.categoryColor,
    this.categoryIcon,
  });

  bool get isExpense => type == TransactionType.expense;
  bool get isIncome => type == TransactionType.income;

  FinancialTransaction copyWith({
    String? id,
    Money? amount,
    TransactionType? type,
    String? categoryId,
    DateTime? transactionDate,
    String? description,
    String? paymentMethod,
    String? note,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? categoryName,
    int? categoryColor,
    String? categoryIcon,
  }) {
    return FinancialTransaction(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      categoryId: categoryId ?? this.categoryId,
      transactionDate: transactionDate ?? this.transactionDate,
      description: description ?? this.description,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      categoryName: categoryName ?? this.categoryName,
      categoryColor: categoryColor ?? this.categoryColor,
      categoryIcon: categoryIcon ?? this.categoryIcon,
    );
  }

  factory FinancialTransaction.fromMap(Map<String, dynamic> map) {
    return FinancialTransaction(
      id: map['id'] as String,
      amount: Money(map['amount_cents'] as int),
      type: TransactionType.fromString(map['type'] as String),
      categoryId: map['category_id'] as String,
      transactionDate: DateTime.parse(map['transaction_date'] as String),
      description: map['description'] as String?,
      paymentMethod: map['payment_method'] as String?,
      note: map['note'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      categoryName: map['category_name'] as String?,
      categoryColor: map['category_color'] as int?,
      categoryIcon: map['category_icon'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'amount_cents': amount.cents,
      'type': type.toDbString(),
      'category_id': categoryId,
      'transaction_date': transactionDate.toIso8601String(),
      'description': description,
      'payment_method': paymentMethod,
      'note': note,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
