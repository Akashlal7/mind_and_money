enum InsightCategory { habits, spending, budget, savings, wellness }

enum InsightType { observation, recommendation }

/// Structured, evidence-backed deterministic insight object
class DeterministicInsight {
  final String id;
  final InsightCategory category;
  final InsightType type;
  final String title;
  final String message;
  final String icon;
  final int? color;

  const DeterministicInsight({
    required this.id,
    required this.category,
    required this.type,
    required this.title,
    required this.message,
    required this.icon,
    this.color,
  });
}
