import 'package:flutter_test/flutter_test.dart';
import 'package:mind_and_money/core/utils/money.dart';
import 'package:mind_and_money/features/finance/models/budget.dart';
import 'package:mind_and_money/features/finance/models/savings_goal.dart';
import 'package:mind_and_money/features/finance/models/transaction.dart';
import 'package:mind_and_money/features/habits/models/habit.dart';
import 'package:mind_and_money/features/habits/models/habit_stats.dart';
import 'package:mind_and_money/features/insights/models/deterministic_insight.dart';
import 'package:mind_and_money/features/insights/services/insights_engine.dart';

void main() {
  group('InsightsEngine Deterministic Tests', () {
    const engine = InsightsEngine();

    test('Habit consistency: enforces 7-day minimum threshold before generating insight', () {
      final habit = Habit(
        id: 'hab_inst_1',
        name: 'Morning Walk',
        scheduleType: 'daily',
        createdAt: DateTime(2026, 10, 20),
      );

      // Only 5 scheduled days elapsed (< 7)
      final lowSampleStats = {
        'hab_inst_1': const HabitStats(
          habitId: 'hab_inst_1',
          currentStreak: 5,
          longestStreak: 5,
          totalCompletions: 5,
          totalScheduledDays: 5,
          completionRate: 1.0,
        ),
      };

      final lowInsights = engine.evaluateHabits(
        habits: [habit],
        statsMap: lowSampleStats,
      );
      // Only streak observation should fire if streak >= 3, but NO consistency observation
      expect(
        lowInsights.any((i) => i.id == 'habit_consistency_hab_inst_1'),
        isFalse,
      );

      // Sufficient sample: 10 scheduled days with >= 70% rate
      final sufficientStats = {
        'hab_inst_1': const HabitStats(
          habitId: 'hab_inst_1',
          currentStreak: 4,
          longestStreak: 5,
          totalCompletions: 8,
          totalScheduledDays: 10,
          completionRate: 0.8,
        ),
      };

      final sufficientInsights = engine.evaluateHabits(
        habits: [habit],
        statsMap: sufficientStats,
      );
      final consistency = sufficientInsights.firstWhere(
        (i) => i.id == 'habit_consistency_hab_inst_1',
      );
      expect(consistency.message, contains('8 of 10 scheduled days (80%)'));
      expect(consistency.type, InsightType.observation);
    });

    test('Expense tracking consistency requires at least 5 distinct days in 14 days', () {
      final asOf = DateTime(2026, 10, 28);

      // Only 3 distinct days
      final lowTransactions = [
        FinancialTransaction(
          id: 'tx_1',
          amount: const Money(1000),
          type: TransactionType.expense,
          categoryId: 'cat_food',
          description: 'Lunch',
          paymentMethod: 'upi',
          transactionDate: DateTime(2026, 10, 25),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        FinancialTransaction(
          id: 'tx_2',
          amount: const Money(1500),
          type: TransactionType.expense,
          categoryId: 'cat_food',
          description: 'Dinner',
          paymentMethod: 'upi',
          transactionDate: DateTime(2026, 10, 26),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        FinancialTransaction(
          id: 'tx_3',
          amount: const Money(500),
          type: TransactionType.expense,
          categoryId: 'cat_food',
          description: 'Snack',
          paymentMethod: 'upi',
          transactionDate: DateTime(2026, 10, 27),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      expect(
        engine.evaluateExpenseConsistency(
          recentExpenses: lowTransactions,
          asOfDate: asOf,
        ),
        isEmpty,
      );

      // 5 distinct days
      final sufficientTransactions = [
        ...lowTransactions,
        FinancialTransaction(
          id: 'tx_4',
          amount: const Money(2000),
          type: TransactionType.expense,
          categoryId: 'cat_transport',
          description: 'Bus',
          paymentMethod: 'cash',
          transactionDate: DateTime(2026, 10, 22),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        FinancialTransaction(
          id: 'tx_5',
          amount: const Money(800),
          type: TransactionType.expense,
          categoryId: 'cat_bills',
          description: 'Tea',
          paymentMethod: 'cash',
          transactionDate: DateTime(2026, 10, 21),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      final insights = engine.evaluateExpenseConsistency(
        recentExpenses: sufficientTransactions,
        asOfDate: asOf,
      );
      expect(insights.length, 1);
      expect(
        insights.first.message,
        'You recorded expenses on 5 of the last 14 days.',
      );
    });

    test('Month-over-month spending comparison requires at least 3 expenses in each month', () {
      final currentExpenses = [
        FinancialTransaction(
          id: 'c1',
          amount: const Money(10000),
          type: TransactionType.expense,
          categoryId: 'cat_food',
          description: 'Grocery',
          paymentMethod: 'upi',
          transactionDate: DateTime(2026, 10, 5),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        FinancialTransaction(
          id: 'c2',
          amount: const Money(20000),
          type: TransactionType.expense,
          categoryId: 'cat_food',
          description: 'Grocery',
          paymentMethod: 'upi',
          transactionDate: DateTime(2026, 10, 10),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        // Only 2 expenses in current month
      ];

      final prevExpenses = [
        FinancialTransaction(
          id: 'p1',
          amount: const Money(15000),
          type: TransactionType.expense,
          categoryId: 'cat_food',
          description: 'Grocery',
          paymentMethod: 'upi',
          transactionDate: DateTime(2026, 9, 5),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        FinancialTransaction(
          id: 'p2',
          amount: const Money(15000),
          type: TransactionType.expense,
          categoryId: 'cat_food',
          description: 'Grocery',
          paymentMethod: 'upi',
          transactionDate: DateTime(2026, 9, 15),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        FinancialTransaction(
          id: 'p3',
          amount: const Money(15000),
          type: TransactionType.expense,
          categoryId: 'cat_food',
          description: 'Grocery',
          paymentMethod: 'upi',
          transactionDate: DateTime(2026, 9, 25),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      // Fails threshold because current month has only 2 records
      expect(
        engine.evaluateSpendingComparison(
          currentMonthExpenses: currentExpenses,
          previousMonthExpenses: prevExpenses,
          currencySymbol: '₹',
        ),
        isEmpty,
      );

      // Add 3rd expense to current month
      currentExpenses.add(
        FinancialTransaction(
          id: 'c3',
          amount: const Money(30000), // total = 60000 vs prev 45000
          type: TransactionType.expense,
          categoryId: 'cat_food',
          description: 'Grocery',
          paymentMethod: 'upi',
          transactionDate: DateTime(2026, 10, 15),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      final momInsights = engine.evaluateSpendingComparison(
        currentMonthExpenses: currentExpenses,
        previousMonthExpenses: prevExpenses,
        currencySymbol: '₹',
      );
      expect(momInsights.length, 1);
      expect(momInsights.first.message, contains('higher than last month'));
    });

    test('Savings goal milestone fires at >= 25% funded', () {
      final goal = SavingsGoal(
        id: 'sg_car',
        name: 'New Laptop',
        targetAmount: const Money(10000000), // ₹100,000
        currentAmount: const Money(3000000), // ₹30,000 = 30%
        targetDate: DateTime(2026, 12, 31),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final insights = engine.evaluateSavingsGoals(
        goals: [goal],
        currencySymbol: '₹',
      );
      expect(insights.length, 1);
      expect(
        insights.first.message,
        contains('funded 30% of your "New Laptop"'),
      );
    });

    test('Budget limit alert fires at >= 85% utilization', () {
      final budget = Budget(
        id: 'bgt_food',
        categoryId: 'cat_food',
        categoryName: 'Food',
        amount: const Money(1000000), // ₹10,000
        monthYear: '2026-10',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final status = BudgetStatus(
        budget: budget,
        spent: const Money(900000), // ₹9,000 = 90%
      );

      final insights = engine.evaluateBudgets(
        budgetStatuses: [status],
        currencySymbol: '₹',
      );
      expect(insights.length, 1);
      expect(
        insights.first.message,
        contains('reached 90% of your monthly Food budget limit'),
      );
    });
  });
}
