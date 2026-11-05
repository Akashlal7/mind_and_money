import 'package:flutter/material.dart';

import '../../../core/widgets/empty_state_card.dart';

/// Screen placeholder for Habits tab (Habit creation, Streaks, Statistics to be expanded in Phase 5)
class HabitsPlaceholderScreen extends StatelessWidget {
  const HabitsPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Habit Tracking')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            EmptyStateCard(
              icon: Icons.check_circle_outlined,
              title: 'Habit Tracker Ready in Phase 5',
              description: 'Habits and completion tracking tables have been prepared in your SQLite schema.\n\nCustom habits, daily streaks, and completion analytics will be built in Phase 5.',
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Habit Architecture:',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildFeatureItem(
                      context,
                      'Unique constraint on (habit_id, date) to prevent double records',
                    ),
                    _buildFeatureItem(
                      context,
                      'Daily & weekday customizable schedules',
                    ),
                    _buildFeatureItem(
                      context,
                      'Streak and consistency algorithms',
                    ),
                    _buildFeatureItem(
                      context,
                      'Quick completion toggles directly from the Home Dashboard',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureItem(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_outline, size: 18, color: Colors.green),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
