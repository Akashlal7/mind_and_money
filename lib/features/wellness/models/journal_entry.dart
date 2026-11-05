/// Represents a private journal or gratitude reflection entry.
///
/// Designed with strict offline privacy: sensitive contents are kept local,
/// and [toString] omits content and title to prevent accidental logging.
class JournalEntry {
  final String id;
  final String? title;
  final String content;
  final int? moodRating; // 1 to 5 optional mood association
  final String entryDate; // YYYY-MM-DD
  final String entryType; // 'journal' or 'reflection'
  final String? prompt; // Reflection prompt question if applicable
  final DateTime createdAt;
  final DateTime updatedAt;

  const JournalEntry({
    required this.id,
    this.title,
    required this.content,
    this.moodRating,
    required this.entryDate,
    this.entryType = 'journal',
    this.prompt,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isReflection => entryType == 'reflection';

  factory JournalEntry.fromMap(Map<String, dynamic> map) {
    return JournalEntry(
      id: map['id'] as String,
      title: map['title'] as String?,
      content: map['content'] as String,
      moodRating: map['mood_rating'] as int?,
      entryDate: map['entry_date'] as String,
      entryType: map['entry_type'] as String? ?? 'journal',
      prompt: map['prompt'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'mood_rating': moodRating,
      'entry_date': entryDate,
      'entry_type': entryType,
      'prompt': prompt,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  JournalEntry copyWith({
    String? id,
    String? title,
    String? content,
    int? moodRating,
    String? entryDate,
    String? entryType,
    String? prompt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return JournalEntry(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      moodRating: moodRating ?? this.moodRating,
      entryDate: entryDate ?? this.entryDate,
      entryType: entryType ?? this.entryType,
      prompt: prompt ?? this.prompt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    // Redact private text from logs for privacy guarantee
    return 'JournalEntry(id: $id, type: $entryType, date: $entryDate, mood: $moodRating, content: [REDACTED ${content.length} chars])';
  }
}
