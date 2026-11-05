/// Suggested habit template for quick user selection
class HabitTemplate {
  final String title;
  final String description;
  final String icon;
  final int color;
  final String scheduleType;
  final String? scheduleDays;

  const HabitTemplate({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    this.scheduleType = 'daily',
    this.scheduleDays,
  });

  /// Curated list of suggested mindful financial & wellness habits
  static const List<HabitTemplate> templates = [
    HabitTemplate(
      title: "Record today's expenses",
      description: 'Spend 2 minutes recording today’s purchases to maintain financial clarity.',
      icon: 'receipt_long_rounded',
      color: 0xFF4CAF50, // Green
      scheduleType: 'daily',
    ),
    HabitTemplate(
      title: 'Review my budget',
      description: 'Check category spending against monthly budget limits.',
      icon: 'pie_chart_outline_rounded',
      color: 0xFF2196F3, // Blue
      scheduleType: 'weekdays',
      scheduleDays: '1,5', // Mon & Fri
    ),
    HabitTemplate(
      title: 'Take a short breathing break',
      description: 'Practice 2 minutes of box breathing or calm breathing.',
      icon: 'air_rounded',
      color: 0xFF009688, // Teal
      scheduleType: 'daily',
    ),
    HabitTemplate(
      title: 'Write a journal entry',
      description:
          'Capture your thoughts, reflections, or mindful observations.',
      icon: 'book_outlined',
      color: 0xFF9C27B0, // Purple
      scheduleType: 'daily',
    ),
    HabitTemplate(
      title: 'Reflect on one positive event',
      description: 'Note one thing you are grateful for or appreciate today.',
      icon: 'favorite_border_rounded',
      color: 0xFFFF9800, // Orange
      scheduleType: 'daily',
    ),
    HabitTemplate(
      title: 'Review my savings progress',
      description:
          'Check progress on your savings targets and emergency funds.',
      icon: 'savings_outlined',
      color: 0xFF3F51B5, // Indigo
      scheduleType: 'weekdays',
      scheduleDays: '7', // Sunday
    ),
  ];
}
