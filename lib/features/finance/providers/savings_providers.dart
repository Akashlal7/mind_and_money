import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../home/providers/home_providers.dart';
import '../models/savings_contribution.dart';
import '../models/savings_goal.dart';
import '../repositories/savings_repository.dart';

/// Provider exposing the SavingsRepository
final savingsRepositoryProvider = Provider<SavingsRepository>((ref) {
  final database = ref.watch(appDatabaseProvider);
  return SavingsRepository(database);
});

/// Fetches all savings goals
final savingsGoalsProvider = FutureProvider.autoDispose<List<SavingsGoal>>((
  ref,
) async {
  final repo = ref.watch(savingsRepositoryProvider);
  return await repo.getSavingsGoals();
});

/// Fetches the contribution/withdrawal history for a specific savings goal
final goalContributionsProvider = FutureProvider.autoDispose
    .family<List<SavingsContribution>, String>((ref, goalId) async {
      final repo = ref.watch(savingsRepositoryProvider);
      return await repo.getContributions(goalId);
    });
