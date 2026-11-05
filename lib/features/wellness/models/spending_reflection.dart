/// Represents an optional, non-judgmental emotional reflection linked to a transaction.
class SpendingReflection {
  final String id;
  final String transactionId;
  final String
  feeling; // e.g. 'calm', 'stressed', 'happy', 'impulsive', 'bored', 'anxious'
  final bool wasPlanned;
  final String spendingNature; // 'necessary', 'optional', 'impulsive'
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SpendingReflection({
    required this.id,
    required this.transactionId,
    required this.feeling,
    required this.wasPlanned,
    required this.spendingNature,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SpendingReflection.fromMap(Map<String, dynamic> map) {
    return SpendingReflection(
      id: map['id'] as String,
      transactionId: map['transaction_id'] as String,
      feeling: map['feeling'] as String,
      wasPlanned: (map['was_planned'] as int) == 1,
      spendingNature: map['spending_nature'] as String,
      notes: map['notes'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'transaction_id': transactionId,
      'feeling': feeling,
      'was_planned': wasPlanned ? 1 : 0,
      'spending_nature': spendingNature,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  SpendingReflection copyWith({
    String? id,
    String? transactionId,
    String? feeling,
    bool? wasPlanned,
    String? spendingNature,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SpendingReflection(
      id: id ?? this.id,
      transactionId: transactionId ?? this.transactionId,
      feeling: feeling ?? this.feeling,
      wasPlanned: wasPlanned ?? this.wasPlanned,
      spendingNature: spendingNature ?? this.spendingNature,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  String get natureLabel {
    switch (spendingNature) {
      case 'necessary':
        return 'Necessary';
      case 'optional':
        return 'Optional';
      case 'impulsive':
        return 'Impulsive';
      default:
        return spendingNature;
    }
  }
}
