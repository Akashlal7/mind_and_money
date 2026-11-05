import '../../../core/utils/money.dart';

/// Represents a financial contribution (positive amount) or withdrawal (negative amount)
/// allocated to/from a specific savings goal.
class SavingsContribution {
  final String id;
  final String goalId;
  final Money amount; // Positive = deposit/contribution, Negative = withdrawal
  final DateTime date;
  final String? note;
  final DateTime createdAt;

  const SavingsContribution({
    required this.id,
    required this.goalId,
    required this.amount,
    required this.date,
    this.note,
    required this.createdAt,
  });

  /// True if this entry represents a withdrawal from the savings goal.
  bool get isWithdrawal => amount.isNegative;

  /// True if this entry represents a deposit into the savings goal.
  bool get isContribution => !amount.isNegative;

  SavingsContribution copyWith({
    String? id,
    String? goalId,
    Money? amount,
    DateTime? date,
    String? note,
    DateTime? createdAt,
  }) {
    return SavingsContribution(
      id: id ?? this.id,
      goalId: goalId ?? this.goalId,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'goal_id': goalId,
      'amount_cents': amount.cents,
      'date': date.toIso8601String(),
      'note': note,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory SavingsContribution.fromMap(Map<String, dynamic> map) {
    return SavingsContribution(
      id: map['id'] as String,
      goalId: map['goal_id'] as String,
      amount: Money(map['amount_cents'] as int? ?? 0),
      date: DateTime.parse(map['date'] as String),
      note: map['note'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
