import '../../../core/utils/money.dart';

/// Represents a monthly expense budget, either for an overall monthly limit
/// (when [categoryId] is null) or for a specific category.
class Budget {
  final String id;
  final String? categoryId;
  final String? categoryName;
  final String? categoryIcon;
  final int? categoryColor;
  final Money amount;
  final String monthYear; // Format: 'YYYY-MM'
  final DateTime createdAt;
  final DateTime updatedAt;

  const Budget({
    required this.id,
    this.categoryId,
    this.categoryName,
    this.categoryIcon,
    this.categoryColor,
    required this.amount,
    required this.monthYear,
    required this.createdAt,
    required this.updatedAt,
  });

  /// True if this is an overall monthly limit across all expense categories.
  bool get isOverall => categoryId == null;

  Budget copyWith({
    String? id,
    String? categoryId,
    String? categoryName,
    String? categoryIcon,
    int? categoryColor,
    Money? amount,
    String? monthYear,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Budget(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      categoryIcon: categoryIcon ?? this.categoryIcon,
      categoryColor: categoryColor ?? this.categoryColor,
      amount: amount ?? this.amount,
      monthYear: monthYear ?? this.monthYear,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'category_id': categoryId,
      'amount_cents': amount.cents,
      'month_year': monthYear,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory Budget.fromMap(Map<String, dynamic> map) {
    return Budget(
      id: map['id'] as String,
      categoryId: map['category_id'] as String?,
      categoryName: map['category_name'] as String?,
      categoryIcon: map['category_icon'] as String?,
      categoryColor: map['category_color'] as int?,
      amount: Money(map['amount_cents'] as int? ?? 0),
      monthYear: map['month_year'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}

/// Combines a [Budget] definition with actual calculated spending for its month/category.
class BudgetStatus {
  final Budget budget;
  final Money spent;

  const BudgetStatus({required this.budget, required this.spent});

  /// Remaining amount before budget is exceeded (can be negative if over budget).
  Money get remaining => budget.amount - spent;

  /// Fraction of budget consumed (0.0 to 1.0 or greater if overspent).
  double get usedFraction {
    if (budget.amount.cents <= 0) return 0.0;
    return spent.cents / budget.amount.cents;
  }

  /// Clamped progress for linear progress indicators (0.0 to 1.0).
  double get progressClamp => usedFraction.clamp(0.0, 1.0);

  /// True if actual spending exceeds the budget amount.
  bool get isOverBudget => remaining.isNegative;

  /// True if spending has reached or exceeded 80% of budget without yet exceeding 100%.
  bool get isNearLimit => !isOverBudget && usedFraction >= 0.80;

  /// Percentage used rounded for display (e.g., 75%).
  int get percentageUsed {
    if (budget.amount.cents <= 0) return 0;
    return (usedFraction * 100).round();
  }
}
