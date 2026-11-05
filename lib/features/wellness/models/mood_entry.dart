/// Represents a daily mood check-in entry
class MoodEntry {
  final String id;
  final String entryDate; // YYYY-MM-DD
  final String entryTime; // HH:MM:SS
  final int rating; // 1 (Difficult) to 5 (Thriving)
  final String? emotionLabels; // comma-separated tags
  final int? stressRating; // 1 to 5
  final int? energyRating; // 1 to 5
  final int? sleepRating; // 1 to 5
  final String? note;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const MoodEntry({
    required this.id,
    required this.entryDate,
    required this.entryTime,
    required this.rating,
    this.emotionLabels,
    this.stressRating,
    this.energyRating,
    this.sleepRating,
    this.note,
    required this.createdAt,
    this.updatedAt,
  }) : assert(
         rating >= 1 && rating <= 5,
         'Mood rating must be between 1 and 5',
       );

  factory MoodEntry.fromMap(Map<String, dynamic> map) {
    return MoodEntry(
      id: map['id'] as String,
      entryDate: map['entry_date'] as String,
      entryTime: map['entry_time'] as String,
      rating: map['rating'] as int,
      emotionLabels: map['emotion_labels'] as String?,
      stressRating: map['stress_rating'] as int?,
      energyRating: map['energy_rating'] as int?,
      sleepRating: map['sleep_rating'] as int?,
      note: map['note'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'entry_date': entryDate,
      'entry_time': entryTime,
      'rating': rating,
      'emotion_labels': emotionLabels,
      'stress_rating': stressRating,
      'energy_rating': energyRating,
      'sleep_rating': sleepRating,
      'note': note,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  MoodEntry copyWith({
    String? id,
    String? entryDate,
    String? entryTime,
    int? rating,
    String? emotionLabels,
    int? stressRating,
    int? energyRating,
    int? sleepRating,
    String? note,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MoodEntry(
      id: id ?? this.id,
      entryDate: entryDate ?? this.entryDate,
      entryTime: entryTime ?? this.entryTime,
      rating: rating ?? this.rating,
      emotionLabels: emotionLabels ?? this.emotionLabels,
      stressRating: stressRating ?? this.stressRating,
      energyRating: energyRating ?? this.energyRating,
      sleepRating: sleepRating ?? this.sleepRating,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// List of individual emotion tags
  List<String> get tags {
    if (emotionLabels == null || emotionLabels!.trim().isEmpty) return const [];
    return emotionLabels!
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  /// User-friendly label for mood rating
  String get moodLabel {
    switch (rating) {
      case 1:
        return 'Difficult';
      case 2:
        return 'Low';
      case 3:
        return 'Neutral';
      case 4:
        return 'Good';
      case 5:
        return 'Thriving';
      default:
        return 'Neutral';
    }
  }

  /// Emoji representation for mood rating
  String get moodEmoji {
    switch (rating) {
      case 1:
        return '😔';
      case 2:
        return '🙁';
      case 3:
        return '😐';
      case 4:
        return '🙂';
      case 5:
        return '😊';
      default:
        return '😐';
    }
  }
}
