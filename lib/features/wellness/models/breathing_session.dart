/// Represents a completed breathing exercise session.
class BreathingSession {
  final String id;
  final String technique; // 'box', '478', 'deep_calm'
  final int durationSeconds;
  final DateTime completedAt;
  final int cyclesCompleted;

  const BreathingSession({
    required this.id,
    required this.technique,
    required this.durationSeconds,
    required this.completedAt,
    required this.cyclesCompleted,
  });

  factory BreathingSession.fromMap(Map<String, dynamic> map) {
    return BreathingSession(
      id: map['id'] as String,
      technique: map['technique'] as String,
      durationSeconds: map['duration_seconds'] as int,
      completedAt: DateTime.parse(map['completed_at'] as String),
      cyclesCompleted: map['cycles_completed'] as int,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'technique': technique,
      'duration_seconds': durationSeconds,
      'completed_at': completedAt.toIso8601String(),
      'cycles_completed': cyclesCompleted,
    };
  }

  String get techniqueTitle {
    switch (technique) {
      case 'box':
        return 'Box Breathing (4-4-4-4)';
      case '478':
        return '4-7-8 Relaxing Breath';
      case 'deep_calm':
        return 'Deep Calm (4-6)';
      default:
        return 'Breathing Exercise';
    }
  }
}
