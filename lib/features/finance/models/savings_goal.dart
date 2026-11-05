import '../../../core/utils/money.dart';

/// Represents a targeted savings goal with an optional completion date and current saved balance.
class SavingsGoal {
  final String id;
  final String name;
  final Money targetAmount;
  final Money currentAmount;
  final DateTime? targetDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SavingsGoal({
    required this.id,
    required this.name,
    required this.targetAmount,
    required this.currentAmount,
    this.targetDate,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Amount still needed to achieve the target. Zero if goal is already met or exceeded.
  Money get remainingAmount {
    if (currentAmount.cents >= targetAmount.cents) {
      return const Money.zero();
    }
    return targetAmount - currentAmount;
  }

  /// Progress fraction clamped between 0.0 and 1.0.
  double get progressFraction {
    if (targetAmount.cents <= 0) return 0.0;
    return (currentAmount.cents / targetAmount.cents).clamp(0.0, 1.0);
  }

  /// Integer progress percentage (e.g. 85 for 85%).
  int get percentage {
    return (progressFraction * 100).round();
  }

  /// True if current saved amount meets or exceeds the target amount.
  bool get isCompleted =>
      targetAmount.cents > 0 && currentAmount.cents >= targetAmount.cents;

  SavingsGoal copyWith({
    String? id,
    String? name,
    Money? targetAmount,
    Money? currentAmount,
    DateTime? targetDate,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SavingsGoal(
      id: id ?? this.id,
      name: name ?? this.name,
      targetAmount: targetAmount ?? this.targetAmount,
      currentAmount: currentAmount ?? this.currentAmount,
      targetDate: targetDate ?? this.targetDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'target_amount_cents': targetAmount.cents,
      'current_amount_cents': currentAmount.cents,
      'target_date': targetDate?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory SavingsGoal.fromMap(Map<String, dynamic> map) {
    return SavingsGoal(
      id: map['id'] as String,
      name: map['name'] as String,
      targetAmount: Money(map['target_amount_cents'] as int? ?? 0),
      currentAmount: Money(map['current_amount_cents'] as int? ?? 0),
      targetDate: map['target_date'] != null
          ? DateTime.tryParse(map['target_date'] as String)
          : null,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}
