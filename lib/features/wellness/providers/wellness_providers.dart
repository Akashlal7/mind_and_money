import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../home/providers/home_providers.dart';
import '../data/breathing_repository.dart';
import '../data/journal_repository.dart';
import '../data/mood_repository.dart';
import '../data/spending_reflection_repository.dart';
import '../models/breathing_session.dart';
import '../models/journal_entry.dart';
import '../models/mood_entry.dart';
import '../models/spending_reflection.dart';

/// Repository Providers
final moodRepositoryProvider = Provider<MoodRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return MoodRepository(db);
});

final journalRepositoryProvider = Provider<JournalRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return JournalRepository(db);
});

final breathingRepositoryProvider = Provider<BreathingRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return BreathingRepository(db);
});

final spendingReflectionRepositoryProvider =
    Provider<SpendingReflectionRepository>((ref) {
      final db = ref.watch(appDatabaseProvider);
      return SpendingReflectionRepository(db);
    });

/// Mood Providers
class MoodMonthNotifier extends Notifier<String> {
  @override
  String build() {
    final now = DateTime.now();
    return "${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}";
  }

  void setMonth(String monthYear) => state = monthYear;
  void previousMonth() {
    final parts = state.split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    final prev = DateTime(year, month - 1);
    state =
        "${prev.year.toString().padLeft(4, '0')}-${prev.month.toString().padLeft(2, '0')}";
  }

  void nextMonth() {
    final parts = state.split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    final next = DateTime(year, month + 1);
    state =
        "${next.year.toString().padLeft(4, '0')}-${next.month.toString().padLeft(2, '0')}";
  }
}

final moodMonthProvider = NotifierProvider<MoodMonthNotifier, String>(
  MoodMonthNotifier.new,
);

final recentMoodEntriesProvider = FutureProvider.autoDispose<List<MoodEntry>>((
  ref,
) async {
  final repo = ref.watch(moodRepositoryProvider);
  return repo.getRecentEntries();
});

final monthlyMoodSummariesProvider = FutureProvider.autoDispose
    .family<List<DailyMoodSummary>, String>((ref, monthYear) async {
      final repo = ref.watch(moodRepositoryProvider);
      return repo.getDailySummariesForMonth(monthYear);
    });

final moodWeeklySummaryProvider = FutureProvider.autoDispose<MoodPeriodSummary>(
  (ref) async {
    final repo = ref.watch(moodRepositoryProvider);
    return repo.getPeriodSummary(days: 7);
  },
);

final moodMonthlySummaryProvider =
    FutureProvider.autoDispose<MoodPeriodSummary>((ref) async {
      final repo = ref.watch(moodRepositoryProvider);
      return repo.getPeriodSummary(days: 30);
    });

/// Journal Providers
class JournalSearchNotifier extends Notifier<String> {
  @override
  String build() => '';
  void setQuery(String q) => state = q;
}

final journalSearchQueryProvider =
    NotifierProvider<JournalSearchNotifier, String>(JournalSearchNotifier.new);

class JournalTypeFilterNotifier extends Notifier<String?> {
  @override
  String? build() => null; // null = all, 'journal', 'reflection'
  void setFilter(String? filter) => state = filter;
}

final journalTypeFilterProvider =
    NotifierProvider<JournalTypeFilterNotifier, String?>(
      JournalTypeFilterNotifier.new,
    );

final journalEntriesProvider = FutureProvider.autoDispose<List<JournalEntry>>((
  ref,
) async {
  final repo = ref.watch(journalRepositoryProvider);
  final query = ref.watch(journalSearchQueryProvider);
  final type = ref.watch(journalTypeFilterProvider);
  return repo.getEntries(query: query, entryType: type);
});

/// Breathing Providers
final breathingStatsProvider =
    FutureProvider.autoDispose<({int totalSessions, int totalMinutes})>((
      ref,
    ) async {
      final repo = ref.watch(breathingRepositoryProvider);
      return repo.getBreathingStats();
    });

final recentBreathingSessionsProvider =
    FutureProvider.autoDispose<List<BreathingSession>>((ref) async {
      final repo = ref.watch(breathingRepositoryProvider);
      return repo.getRecentSessions();
    });

/// Spending Reflection Providers
final spendingReflectionSummaryProvider =
    FutureProvider.autoDispose<SpendingReflectionSummary>((ref) async {
      final repo = ref.watch(spendingReflectionRepositoryProvider);
      return repo.getSummary();
    });

final transactionReflectionProvider = FutureProvider.autoDispose
    .family<SpendingReflection?, String>((ref, transactionId) async {
      final repo = ref.watch(spendingReflectionRepositoryProvider);
      return repo.getReflectionForTransaction(transactionId);
    });
