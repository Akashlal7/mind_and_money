import 'package:flutter/material.dart';

import '../../../core/widgets/empty_state_card.dart';

/// Screen placeholder for Money tab (Transaction CRUD, Budgets, Savings to be built in Phase 2 & 3)
class MoneyPlaceholderScreen extends StatelessWidget {
  const MoneyPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Money Management')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            EmptyStateCard(
              icon: Icons.account_balance_wallet_outlined,
              title: 'Transactions & Budgets Ready in Phase 2',
              description: 'Your local SQLite database tables for categories, transactions, budgets, and savings goals have been initialized.\n\nTransaction management and budget tracking will be enabled next.',
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Initialized Features:',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildFeatureItem(
                      context,
                      '14 Default seeded categories (Food, Utilities, Salary, etc.)',
                    ),
                    _buildFeatureItem(
                      context,
                      'Integer minor unit currency engine (zero rounding error)',
                    ),
                    _buildFeatureItem(
                      context,
                      'Parameterized SQLite transactions schema',
                    ),
                    _buildFeatureItem(
                      context,
                      'Foreign key cascades and index optimizations',
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
