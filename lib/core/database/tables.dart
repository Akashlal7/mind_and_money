/// Defines SQLite table schemas, column names, and default category seeds
/// for Mind & Money.
class DbTables {
  DbTables._();

  // Table names
  static const String categories = 'categories';
  static const String transactions = 'transactions';
  static const String budgets = 'budgets';
  static const String savingsGoals = 'savings_goals';
  static const String savingsContributions = 'savings_contributions';
  static const String moodEntries = 'mood_entries';
  static const String journalEntries = 'journal_entries';
  static const String breathingSessions = 'breathing_sessions';
  static const String spendingReflections = 'spending_reflections';
  static const String habits = 'habits';
  static const String habitCompletions = 'habit_completions';
  static const String appMetadata = 'app_metadata';

  // Create Table Statements
  static const String createCategoriesTable =
      '''
    CREATE TABLE $categories (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      icon TEXT NOT NULL,
      color INTEGER NOT NULL,
      type TEXT NOT NULL,
      is_default INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL
    );
  ''';

  static const String createTransactionsTable =
      '''
    CREATE TABLE $transactions (
      id TEXT PRIMARY KEY,
      amount_cents INTEGER NOT NULL,
      type TEXT NOT NULL,
      category_id TEXT NOT NULL,
      transaction_date TEXT NOT NULL,
      description TEXT,
      payment_method TEXT,
      note TEXT,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      FOREIGN KEY (category_id) REFERENCES $categories (id) ON DELETE RESTRICT
    );
  ''';

  static const String createBudgetsTable =
      '''
    CREATE TABLE $budgets (
      id TEXT PRIMARY KEY,
      category_id TEXT,
      amount_cents INTEGER NOT NULL,
      month_year TEXT NOT NULL,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      FOREIGN KEY (category_id) REFERENCES $categories (id) ON DELETE CASCADE
    );
  ''';

  static const String createSavingsGoalsTable =
      '''
    CREATE TABLE $savingsGoals (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      target_amount_cents INTEGER NOT NULL,
      current_amount_cents INTEGER NOT NULL DEFAULT 0,
      target_date TEXT,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    );
  ''';

  static const String createSavingsContributionsTable =
      '''
    CREATE TABLE $savingsContributions (
      id TEXT PRIMARY KEY,
      goal_id TEXT NOT NULL,
      amount_cents INTEGER NOT NULL,
      date TEXT NOT NULL,
      note TEXT,
      created_at TEXT NOT NULL,
      FOREIGN KEY (goal_id) REFERENCES $savingsGoals (id) ON DELETE CASCADE
    );
  ''';

  static const String createMoodEntriesTable =
      '''
    CREATE TABLE $moodEntries (
      id TEXT PRIMARY KEY,
      entry_date TEXT NOT NULL,
      entry_time TEXT NOT NULL,
      rating INTEGER NOT NULL,
      emotion_labels TEXT,
      stress_rating INTEGER,
      energy_rating INTEGER,
      sleep_rating INTEGER,
      note TEXT,
      created_at TEXT NOT NULL,
      updated_at TEXT
    );
  ''';

  static const String createJournalEntriesTable =
      '''
    CREATE TABLE $journalEntries (
      id TEXT PRIMARY KEY,
      title TEXT,
      content TEXT NOT NULL,
      mood_rating INTEGER,
      entry_date TEXT NOT NULL,
      entry_type TEXT NOT NULL DEFAULT 'journal',
      prompt TEXT,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    );
  ''';

  static const String createBreathingSessionsTable =
      '''
    CREATE TABLE $breathingSessions (
      id TEXT PRIMARY KEY,
      technique TEXT NOT NULL,
      duration_seconds INTEGER NOT NULL,
      completed_at TEXT NOT NULL,
      cycles_completed INTEGER NOT NULL
    );
  ''';

  static const String createSpendingReflectionsTable =
      '''
    CREATE TABLE $spendingReflections (
      id TEXT PRIMARY KEY,
      transaction_id TEXT NOT NULL,
      feeling TEXT NOT NULL,
      was_planned INTEGER NOT NULL,
      spending_nature TEXT NOT NULL,
      notes TEXT,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      FOREIGN KEY (transaction_id) REFERENCES $transactions (id) ON DELETE CASCADE
    );
  ''';

  static const String createHabitsTable =
      '''
    CREATE TABLE $habits (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      description TEXT,
      schedule_type TEXT NOT NULL DEFAULT 'daily',
      schedule_days TEXT,
      is_archived INTEGER NOT NULL DEFAULT 0,
      color INTEGER,
      icon TEXT,
      reminder_time TEXT,
      created_at TEXT NOT NULL,
      updated_at TEXT
    );
  ''';

  static const String createHabitCompletionsTable =
      '''
    CREATE TABLE $habitCompletions (
      id TEXT PRIMARY KEY,
      habit_id TEXT NOT NULL,
      completion_date TEXT NOT NULL,
      completed_at TEXT NOT NULL,
      FOREIGN KEY (habit_id) REFERENCES $habits (id) ON DELETE CASCADE,
      UNIQUE (habit_id, completion_date)
    );
  ''';

  static const String createAppMetadataTable =
      '''
    CREATE TABLE $appMetadata (
      key TEXT PRIMARY KEY,
      value TEXT NOT NULL
    );
  ''';

  // Indexes for query performance
  static const List<String> createIndexes = [
    'CREATE INDEX idx_trans_date ON $transactions (transaction_date);',
    'CREATE INDEX idx_trans_cat ON $transactions (category_id);',
    'CREATE INDEX idx_trans_type ON $transactions (type);',
    'CREATE INDEX idx_budgets_month ON $budgets (month_year);',
    'CREATE INDEX idx_budgets_cat_month ON $budgets (category_id, month_year);',
    'CREATE INDEX idx_savings_contrib_goal ON $savingsContributions (goal_id);',
    'CREATE INDEX idx_savings_contrib_date ON $savingsContributions (date);',
    'CREATE INDEX idx_mood_date ON $moodEntries (entry_date);',
    'CREATE INDEX idx_journal_date ON $journalEntries (entry_date);',
    'CREATE INDEX idx_journal_type ON $journalEntries (entry_type);',
    'CREATE INDEX idx_breathing_date ON $breathingSessions (completed_at);',
    'CREATE INDEX idx_spending_reflections_tx ON $spendingReflections (transaction_id);',
    'CREATE INDEX idx_habit_comp_date ON $habitCompletions (completion_date);',
    'CREATE INDEX idx_habit_comp_habit ON $habitCompletions (habit_id);',
  ];

  /// Standard default categories seeded on first run
  static final List<Map<String, dynamic>> defaultCategories = [
    {
      'id': 'cat_food',
      'name': 'Food & Dining',
      'icon': 'restaurant',
      'color': 0xFFE57373,
      'type': 'expense',
      'is_default': 1,
      'created_at': DateTime.now().toIso8601String(),
    },
    {
      'id': 'cat_groceries',
      'name': 'Groceries',
      'icon': 'shopping_basket',
      'color': 0xFF81C784,
      'type': 'expense',
      'is_default': 1,
      'created_at': DateTime.now().toIso8601String(),
    },
    {
      'id': 'cat_transport',
      'name': 'Transport',
      'icon': 'directions_car',
      'color': 0xFF64B5F6,
      'type': 'expense',
      'is_default': 1,
      'created_at': DateTime.now().toIso8601String(),
    },
    {
      'id': 'cat_housing',
      'name': 'Housing & Rent',
      'icon': 'home',
      'color': 0xFFFFB74D,
      'type': 'expense',
      'is_default': 1,
      'created_at': DateTime.now().toIso8601String(),
    },
    {
      'id': 'cat_bills',
      'name': 'Bills & Utilities',
      'icon': 'receipt_long',
      'color': 0xFFBA68C8,
      'type': 'expense',
      'is_default': 1,
      'created_at': DateTime.now().toIso8601String(),
    },
    {
      'id': 'cat_health',
      'name': 'Health & Medical',
      'icon': 'favorite',
      'color': 0xFFF06292,
      'type': 'expense',
      'is_default': 1,
      'created_at': DateTime.now().toIso8601String(),
    },
    {
      'id': 'cat_education',
      'name': 'Education',
      'icon': 'school',
      'color': 0xFF4DB6AC,
      'type': 'expense',
      'is_default': 1,
      'created_at': DateTime.now().toIso8601String(),
    },
    {
      'id': 'cat_entertainment',
      'name': 'Entertainment',
      'icon': 'movie',
      'color': 0xFF9575CD,
      'type': 'expense',
      'is_default': 1,
      'created_at': DateTime.now().toIso8601String(),
    },
    {
      'id': 'cat_shopping',
      'name': 'Shopping',
      'icon': 'shopping_bag',
      'color': 0xFFFF8A65,
      'type': 'expense',
      'is_default': 1,
      'created_at': DateTime.now().toIso8601String(),
    },
    {
      'id': 'cat_personal',
      'name': 'Personal Care',
      'icon': 'spa',
      'color': 0xFF4DD0E1,
      'type': 'expense',
      'is_default': 1,
      'created_at': DateTime.now().toIso8601String(),
    },
    {
      'id': 'cat_salary',
      'name': 'Salary',
      'icon': 'work',
      'color': 0xFF43A047,
      'type': 'income',
      'is_default': 1,
      'created_at': DateTime.now().toIso8601String(),
    },
    {
      'id': 'cat_freelance',
      'name': 'Freelance Income',
      'icon': 'laptop',
      'color': 0xFF00ACC1,
      'type': 'income',
      'is_default': 1,
      'created_at': DateTime.now().toIso8601String(),
    },
    {
      'id': 'cat_other_income',
      'name': 'Other Income',
      'icon': 'add_circle',
      'color': 0xFF7CB342,
      'type': 'income',
      'is_default': 1,
      'created_at': DateTime.now().toIso8601String(),
    },
    {
      'id': 'cat_other_expense',
      'name': 'Other Expense',
      'icon': 'category',
      'color': 0xFF90A4AE,
      'type': 'expense',
      'is_default': 1,
      'created_at': DateTime.now().toIso8601String(),
    },
  ];
}
