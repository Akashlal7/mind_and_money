import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../data/home_repository.dart';

/// AppDatabase singleton provider
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

/// HomeRepository provider
final homeRepositoryProvider = Provider<HomeRepository>((ref) {
  final database = ref.watch(appDatabaseProvider);
  return HomeRepository(database);
});

/// Selected month notifier for dashboard calculations
class SelectedMonthNotifier extends Notifier<DateTime> {
  @override
  DateTime build() => DateTime.now();

  void setMonth(DateTime month) {
    state = month;
  }
}

final selectedDashboardMonthProvider =
    NotifierProvider<SelectedMonthNotifier, DateTime>(
      SelectedMonthNotifier.new,
    );

/// Async provider for Home dashboard summary data
final homeSummaryProvider = FutureProvider.autoDispose<HomeSummary>((
  ref,
) async {
  final repository = ref.watch(homeRepositoryProvider);
  final targetMonth = ref.watch(selectedDashboardMonthProvider);
  return repository.getHomeSummary(targetMonth);
});
