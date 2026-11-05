/// Curated, thoughtful gratitude and reflection prompts.
class GratitudePrompts {
  GratitudePrompts._();

  static const List<String> prompts = [
    'What went well today?',
    'What is one thing you appreciate today?',
    'What is one small step you can take tomorrow?',
    'What helped you feel calm today?',
    'Who brought a smile to your face recently?',
    'What is a challenge you handled better than expected?',
    'What is something beautiful you noticed today?',
    'What is a simple comfort you are thankful for right now?',
    'What is a boundary you set that protected your peace?',
    'What is something you learned about yourself recently?',
  ];

  /// Returns a prompt for the day of the year or random index
  static String promptForDay(DateTime date) {
    final dayOfYear = date.difference(DateTime(date.year, 1, 1)).inDays;
    return prompts[dayOfYear % prompts.length];
  }
}
