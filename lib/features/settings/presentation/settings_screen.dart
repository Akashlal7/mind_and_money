import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/backup_service.dart';
import '../../../core/services/csv_service.dart';
import '../../../core/theme/responsive_layout.dart';
import '../../finance/providers/budget_providers.dart';
import '../../finance/providers/reports_providers.dart';
import '../../finance/providers/savings_providers.dart';
import '../../finance/providers/transaction_providers.dart';
import '../../habits/providers/habit_providers.dart';
import '../../home/providers/home_providers.dart';
import '../../insights/providers/insights_providers.dart';
import '../../wellness/providers/wellness_providers.dart';
import '../providers/settings_provider.dart';

final backupServiceProvider = Provider<BackupService>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return BackupService(db);
});

final csvExportServiceProvider = Provider<CsvExportService>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return CsvExportService(db);
});

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ResponsiveContentWrapper(
        maxWidth: 720,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            // Preferences Section
            _buildSectionHeader(context, 'Preferences'),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.currency_rupee_rounded),
                    title: const Text('Default Currency'),
                    subtitle: Text(
                      AppCurrency.supported
                          .firstWhere(
                            (c) => c.code == settings.currencyCode,
                            orElse: () => AppCurrency.defaultCurrency,
                          )
                          .name,
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => _showCurrencyDialog(
                      context,
                      ref,
                      settings.currencyCode,
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.palette_outlined),
                    title: const Text('Theme Mode'),
                    subtitle: Text(_themeModeName(settings.themeMode)),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () =>
                        _showThemeDialog(context, ref, settings.themeMode),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.calendar_today_outlined),
                    title: const Text('First Day of Week'),
                    subtitle: Text(
                      settings.firstDayOfWeek == 1 ? 'Monday' : 'Sunday',
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => _showFirstDayDialog(
                      context,
                      ref,
                      settings.firstDayOfWeek,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Local Privacy & Storage
            _buildSectionHeader(context, 'Local Storage & Privacy'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.shield_outlined,
                          color: colorScheme.primary,
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '100% Offline & Private',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Mind & Money runs entirely on this device. Your financial logs, journal entries, mood scores, and habits are stored in a local database.\n\nNo accounts, no third-party telemetry, no cloud servers, and no advertising trackers are included in this application.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.storage_rounded, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Local Database: mind_and_money.db',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontFamily: 'NotoSansMono',
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Backup & Export Section
            _buildSectionHeader(context, 'Backup & Export'),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(
                      Icons.file_download_outlined,
                      color: colorScheme.primary,
                    ),
                    title: const Text('Export Local JSON Backup'),
                    subtitle: const Text(
                      'Save a complete offline backup of your transactions, budgets, reflections, and habits',
                    ),
                    onTap: () => _exportBackup(context, ref),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: Icon(
                      Icons.table_chart_outlined,
                      color: colorScheme.primary,
                    ),
                    title: const Text('Export Transactions to CSV'),
                    subtitle: const Text(
                      'Generate RFC 4180 spreadsheet-ready CSV with formatted amounts and categories',
                    ),
                    onTap: () => _exportCsv(context, ref),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: Icon(
                      Icons.file_upload_outlined,
                      color: colorScheme.primary,
                    ),
                    title: const Text('Restore from JSON Backup'),
                    subtitle: const Text(
                      'Safely restore records with atomic transaction rollback protection',
                    ),
                    onTap: () => _showRestoreDialog(context, ref),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Danger Zone
            _buildSectionHeader(context, 'Data Management'),
            Card(
              child: ListTile(
                leading: Icon(
                  Icons.delete_outline_rounded,
                  color: colorScheme.error,
                ),
                title: Text(
                  'Clear All Application Data',
                  style: TextStyle(
                    color: colorScheme.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: const Text(
                  'Permanently reset SQLite database and local preferences',
                ),
                onTap: () => _showClearDataConfirmation(context, ref),
              ),
            ),
            const SizedBox(height: 20),

            // About Section
            _buildSectionHeader(context, 'About'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mind & Money',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Version 1.0.0',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'A personal financial awareness and mental wellness companion.',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontFamily: 'NotoSansMono',
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  String _themeModeName(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return 'Follow System';
      case ThemeMode.light:
        return 'Light Theme';
      case ThemeMode.dark:
        return 'Dark Theme';
    }
  }

  void _showCurrencyDialog(
    BuildContext context,
    WidgetRef ref,
    String currentCode,
  ) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Select Currency'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: AppCurrency.supported.length,
            itemBuilder: (ctx, index) {
              final currency = AppCurrency.supported[index];
              final isSelected = currency.code == currentCode;
              return ListTile(
                leading: Text(
                  currency.symbol,
                  style: const TextStyle(
                    fontFamily: 'NotoSansMono',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                title: Text(currency.name),
                subtitle: Text(currency.code),
                trailing: isSelected
                    ? Icon(
                        Icons.check_rounded,
                        color: Theme.of(context).colorScheme.primary,
                      )
                    : null,
                onTap: () {
                  ref
                      .read(settingsProvider.notifier)
                      .setCurrency(currency.code);
                  ref.invalidate(homeSummaryProvider);
                  Navigator.of(dialogCtx).pop();
                },
              );
            },
          ),
        ),
      ),
    );
  }

  void _showThemeDialog(
    BuildContext context,
    WidgetRef ref,
    ThemeMode currentMode,
  ) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Select Theme Mode'),
        content: RadioGroup<ThemeMode>(
          groupValue: currentMode,
          onChanged: (val) {
            if (val != null) {
              ref.read(settingsProvider.notifier).setThemeMode(val);
              Navigator.of(dialogCtx).pop();
            }
          },
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<ThemeMode>(
                title: Text('Follow System'),
                value: ThemeMode.system,
              ),
              RadioListTile<ThemeMode>(
                title: Text('Light Theme'),
                value: ThemeMode.light,
              ),
              RadioListTile<ThemeMode>(
                title: Text('Dark Theme'),
                value: ThemeMode.dark,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFirstDayDialog(
    BuildContext context,
    WidgetRef ref,
    int currentDay,
  ) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('First Day of Week'),
        content: RadioGroup<int>(
          groupValue: currentDay,
          onChanged: (val) {
            if (val != null) {
              ref.read(settingsProvider.notifier).setFirstDayOfWeek(val);
              Navigator.of(dialogCtx).pop();
            }
          },
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<int>(title: Text('Monday'), value: 1),
              RadioListTile<int>(title: Text('Sunday'), value: 7),
            ],
          ),
        ),
      ),
    );
  }

  void _showClearDataConfirmation(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Permanently Reset All Data?'),
        content: const Text(
          'This will delete all local SQLite tables (transactions, categories, budgets, savings goals, mood logs, journals, and habits) and reset application settings.\n\nThis action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () async {
              Navigator.of(dialogCtx).pop();
              final db = ref.read(appDatabaseProvider);
              await db.deleteDatabaseFile();

              // Invalidate all providers
              _invalidateAllProviders(ref);

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'All local database records have been reset.',
                    ),
                  ),
                );
              }
            },
            child: const Text('Reset Everything'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportBackup(BuildContext context, WidgetRef ref) async {
    final backupService = ref.read(backupServiceProvider);
    final jsonStr = await backupService.exportBackupToJson();

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Local JSON Backup Exported'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your entire Mind & Money database has been exported into JSON format v1.0.',
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Size: ${(jsonStr.length / 1024).toStringAsFixed(1)} KB',
                style: const TextStyle(
                  fontFamily: 'NotoSansMono',
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Close'),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.copy_rounded, size: 16),
            label: const Text('Copy to Clipboard'),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: jsonStr));
              Navigator.of(dialogCtx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Backup JSON copied to clipboard!'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _exportCsv(BuildContext context, WidgetRef ref) async {
    final csvService = ref.read(csvExportServiceProvider);
    final csvStr = await csvService.exportTransactionsToCsv();
    final lineCount = csvStr.trim().split('\n').length;
    final txCount = lineCount > 1 ? lineCount - 1 : 0;

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('CSV Export Ready'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Exported $txCount transaction(s) using RFC 4180 format with decimal amounts and resolved category names.',
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Size: ${(csvStr.length / 1024).toStringAsFixed(1)} KB ($txCount rows)',
                style: const TextStyle(
                  fontFamily: 'NotoSansMono',
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Close'),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.copy_rounded, size: 16),
            label: const Text('Copy CSV'),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: csvStr));
              Navigator.of(dialogCtx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Transactions CSV copied to clipboard!'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showRestoreDialog(BuildContext context, WidgetRef ref) {
    final textController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Restore from JSON Backup'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Paste your Mind & Money JSON backup below.\n\n'
                '• Conflict Policy: Merges records by unique ID. Existing matching records are updated to backup data; other distinct records are preserved.\n'
                '• Safety: Executed within an atomic SQLite transaction. If validation fails, all changes are rolled back automatically.',
                style: TextStyle(height: 1.35),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: textController,
                maxLines: 6,
                decoration: const InputDecoration(
                  hintText:
                      '{"app": "Mind & Money", "format_version": "1.0", ...}',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final text = textController.text.trim();
              if (text.isEmpty) return;

              Navigator.of(dialogCtx).pop();
              final backupService = ref.read(backupServiceProvider);
              final result = await backupService.restoreBackupFromJson(text);

              if (result.success) {
                _invalidateAllProviders(ref);
              }

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(result.message),
                    backgroundColor: result.success
                        ? null
                        : Theme.of(context).colorScheme.error,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: const Text('Restore Database'),
          ),
        ],
      ),
    );
  }

  void _invalidateAllProviders(WidgetRef ref) {
    ref.invalidate(homeSummaryProvider);
    ref.invalidate(filteredTransactionsProvider);
    ref.invalidate(periodTotalsProvider);
    ref.invalidate(monthlyBudgetsProvider);
    ref.invalidate(overallBudgetStatusProvider);
    ref.invalidate(savingsGoalsProvider);
    ref.invalidate(financialReportProvider);
    ref.invalidate(activeHabitsProvider);
    ref.invalidate(todayScheduledHabitsProvider);
    ref.invalidate(todayHabitProgressProvider);
    ref.invalidate(deterministicInsightsProvider);
    ref.invalidate(journalEntriesProvider);
  }
}
