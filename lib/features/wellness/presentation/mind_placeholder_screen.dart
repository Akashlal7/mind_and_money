import 'package:flutter/material.dart';

import '../../../core/widgets/empty_state_card.dart';

/// Screen placeholder for Mind tab (Mood check-in, Journal, Breathing to be expanded in Phase 4)
class MindPlaceholderScreen extends StatelessWidget {
  const MindPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Mental Wellness')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            EmptyStateCard(
              icon: Icons.spa_outlined,
              title: 'Wellness Hub Ready in Phase 4',
              description: 'Private daily mood check-ins, local offline journaling, and guided breathing exercises will be expanded here.\n\nAll reflections remain 100% strictly on your device.',
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Privacy & Architecture Principles:',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildFeatureItem(
                      context,
                      'Zero cloud sync, telemetry, or remote transmission',
                    ),
                    _buildFeatureItem(
                      context,
                      'Private journal contents are stored locally in SQLite',
                    ),
                    _buildFeatureItem(
                      context,
                      'Quick mood check-ins active from the Home Dashboard',
                    ),
                    _buildFeatureItem(
                      context,
                      'Gentle, non-judgmental spending reflections',
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
