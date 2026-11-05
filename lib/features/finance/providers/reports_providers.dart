import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/date_utils.dart';
import '../../home/providers/home_providers.dart';
import '../models/report_data.dart';
import '../repositories/reports_repository.dart';

/// Provider exposing the ReportsRepository
final reportsRepositoryProvider = Provider<ReportsRepository>((ref) {
  final database = ref.watch(appDatabaseProvider);
  return ReportsRepository(database);
});

/// Notifier holding the selected report month (defaults to current month)
class ReportMonthNotifier extends Notifier<DateTime> {
  @override
  DateTime build() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, 1);
  }

  void setMonth(DateTime month) {
    state = DateTime(month.year, month.month, 1);
  }

  void previousMonth() {
    state = DateTime(state.year, state.month - 1, 1);
  }

  void nextMonth() {
    state = DateTime(state.year, state.month + 1, 1);
  }
}

final selectedReportMonthProvider =
    NotifierProvider<ReportMonthNotifier, DateTime>(ReportMonthNotifier.new);

/// Fetches the comprehensive financial report for the selected month
final financialReportProvider =
    FutureProvider.autoDispose<FinancialReportSummary>((ref) async {
      final repo = ref.watch(reportsRepositoryProvider);
      final targetMonth = ref.watch(selectedReportMonthProvider);

      final startOfMonth = AppDateUtils.startOfMonth(targetMonth);
      final endOfMonth = AppDateUtils.endOfMonth(targetMonth);

      return await repo.getFinancialReport(
        startDate: startOfMonth,
        endDate: endOfMonth,
      );
    });
