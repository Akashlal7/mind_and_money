/// Model representing a trackable daily or scheduled habit
class Habit {
  final String id;
  final String name;
  final String? description;
  final String scheduleType; // 'daily' or 'weekdays'
  final String? scheduleDays; // comma-separated day numbers (1=Mon, 7=Sun)
  final bool isArchived;
  final int? color;
  final String? icon;
  final String? reminderTime; // e.g., '08:30'
  final DateTime createdAt;
  final DateTime? updatedAt;

  // Runtime field indicating whether it is completed for the target date
  final bool isCompletedToday;

  const Habit({
    required this.id,
    required this.name,
    this.description,
    this.scheduleType = 'daily',
    this.scheduleDays,
    this.isArchived = false,
    this.color,
    this.icon,
    this.reminderTime,
    required this.createdAt,
    this.updatedAt,
    this.isCompletedToday = false,
  });

  /// Set of integer weekday numbers (1=Mon, 7=Sun)
  Set<int> get scheduledDayNumbers {
    if (scheduleType == 'daily') {
      return const {1, 2, 3, 4, 5, 6, 7};
    }
    if (scheduleDays == null || scheduleDays!.isEmpty) {
      return const {1, 2, 3, 4, 5, 6, 7};
    }
    return scheduleDays!
        .split(',')
        .map((s) => int.tryParse(s.trim()))
        .whereType<int>()
        .where((d) => d >= 1 && d <= 7)
        .toSet();
  }

  /// Whether this habit is scheduled for the given weekday (1=Mon, 7=Sun)
  bool isScheduledForWeekday(int weekday) {
    if (scheduleType == 'daily') return true;
    return scheduledDayNumbers.contains(weekday);
  }

  /// Whether this habit is scheduled for the given calendar date
  bool isScheduledForDate(DateTime date) {
    return isScheduledForWeekday(date.weekday);
  }

  /// Readable summary of the schedule
  String get scheduleSummary {
    if (scheduleType == 'daily') {
      return 'Every day';
    }
    final days = scheduledDayNumbers.toList()..sort();
    if (days.length == 7) {
      return 'Every day';
    }
    if (days.length == 5 &&
        days.contains(1) &&
        days.contains(2) &&
        days.contains(3) &&
        days.contains(4) &&
        days.contains(5)) {
      return 'Weekdays (Mon-Fri)';
    }
    if (days.length == 2 && days.contains(6) && days.contains(7)) {
      return 'Weekends';
    }
    const names = {
      1: 'Mon',
      2: 'Tue',
      3: 'Wed',
      4: 'Thu',
      5: 'Fri',
      6: 'Sat',
      7: 'Sun',
    };
    return days.map((d) => names[d] ?? '').join(', ');
  }

  Habit copyWith({
    String? id,
    String? name,
    String? description,
    String? scheduleType,
    String? scheduleDays,
    bool? isArchived,
    int? color,
    String? icon,
    String? reminderTime,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isCompletedToday,
  }) {
    return Habit(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      scheduleType: scheduleType ?? this.scheduleType,
      scheduleDays: scheduleDays ?? this.scheduleDays,
      isArchived: isArchived ?? this.isArchived,
      color: color ?? this.color,
      icon: icon ?? this.icon,
      reminderTime: reminderTime ?? this.reminderTime,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isCompletedToday: isCompletedToday ?? this.isCompletedToday,
    );
  }

  factory Habit.fromMap(
    Map<String, dynamic> map, {
    bool isCompletedToday = false,
  }) {
    return Habit(
      id: map['id'] as String,
      name: map['name'] as String,
      description: map['description'] as String?,
      scheduleType: map['schedule_type'] as String? ?? 'daily',
      scheduleDays: map['schedule_days'] as String?,
      isArchived: (map['is_archived'] as int? ?? 0) == 1,
      color: map['color'] as int?,
      icon: map['icon'] as String?,
      reminderTime: map['reminder_time'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'] as String)
          : null,
      isCompletedToday: isCompletedToday,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'schedule_type': scheduleType,
      'schedule_days': scheduleDays,
      'is_archived': isArchived ? 1 : 0,
      'color': color,
      'icon': icon,
      'reminder_time': reminderTime,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}
