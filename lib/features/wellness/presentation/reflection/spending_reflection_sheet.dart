import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/id_generator.dart';
import '../../models/spending_reflection.dart';
import '../../providers/wellness_providers.dart';

class SpendingReflectionSheet extends ConsumerStatefulWidget {
  final String transactionId;
  final String? transactionAmount;
  final SpendingReflection? existingReflection;

  const SpendingReflectionSheet({
    super.key,
    required this.transactionId,
    this.transactionAmount,
    this.existingReflection,
  });

  @override
  ConsumerState<SpendingReflectionSheet> createState() =>
      _SpendingReflectionSheetState();
}

class _SpendingReflectionSheetState
    extends ConsumerState<SpendingReflectionSheet> {
  late String _feeling;
  late bool _wasPlanned;
  late String _spendingNature;
  late final TextEditingController _notesController;
  bool _isSaving = false;

  static const List<String> _feelings = [
    'Calm',
    'Content',
    'Stressed',
    'Anxious',
    'Impulsive',
    'Bored',
    'Excited',
    'Neutral',
  ];

  @override
  void initState() {
    super.initState();
    final edit = widget.existingReflection;
    _feeling = edit?.feeling ?? 'Calm';
    _wasPlanned = edit?.wasPlanned ?? true;
    _spendingNature = edit?.spendingNature ?? 'necessary';
    _notesController = TextEditingController(text: edit?.notes ?? '');
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      final repo = ref.read(spendingReflectionRepositoryProvider);
      final now = DateTime.now();
      final notesText = _notesController.text.trim();

      if (widget.existingReflection != null) {
        final updated = widget.existingReflection!.copyWith(
          feeling: _feeling,
          wasPlanned: _wasPlanned,
          spendingNature: _spendingNature,
          notes: notesText.isEmpty ? null : notesText,
          updatedAt: now,
        );
        await repo.updateReflection(updated);
      } else {
        final newReflection = SpendingReflection(
          id: 'refl_${IdGenerator.generate()}',
          transactionId: widget.transactionId,
          feeling: _feeling,
          wasPlanned: _wasPlanned,
          spendingNature: _spendingNature,
          notes: notesText.isEmpty ? null : notesText,
          createdAt: now,
          updatedAt: now,
        );
        await repo.createReflection(newReflection);
      }

      ref.invalidate(transactionReflectionProvider(widget.transactionId));
      ref.invalidate(spendingReflectionSummaryProvider);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Spending reflection saved.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving reflection: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _delete() async {
    if (widget.existingReflection == null) return;
    try {
      await ref
          .read(spendingReflectionRepositoryProvider)
          .deleteReflection(widget.existingReflection!.id);
      ref.invalidate(transactionReflectionProvider(widget.transactionId));
      ref.invalidate(spendingReflectionSummaryProvider);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Reflection removed.')));
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isEditing = widget.existingReflection != null;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.tealContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.spa_rounded,
                        size: 18,
                        color: AppColors.onTealContainer,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isEditing
                          ? 'Edit Purchase Reflection'
                          : 'Mindful Spending Reflection',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: 'Dismiss',
                ),
              ],
            ),
            const SizedBox(height: 4),

            Text(
              'A brief, non-judgmental check-in to observe your emotional patterns around spending. This is optional.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),

            // Question 1: How did you feel around the purchase?
            Text(
              'How did you feel around the time of this purchase?',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: _feelings.map((f) {
                final isSelected = _feeling == f;
                return ChoiceChip(
                  label: Text(f),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) setState(() => _feeling = f);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Question 2: Was this planned?
            Text(
              'Was this purchase planned in advance?',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: true,
                  label: Text('Planned'),
                  icon: Icon(Icons.event_available_rounded),
                ),
                ButtonSegment(
                  value: false,
                  label: Text('Unplanned'),
                  icon: Icon(Icons.flash_on_rounded),
                ),
              ],
              selected: {_wasPlanned},
              onSelectionChanged: (set) {
                setState(() => _wasPlanned = set.first);
              },
            ),
            const SizedBox(height: 16),

            // Question 3: Spending Nature
            Text(
              'How would you describe the nature of this expense?',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'necessary', label: Text('Necessary')),
                ButtonSegment(value: 'optional', label: Text('Optional')),
                ButtonSegment(value: 'impulsive', label: Text('Impulsive')),
              ],
              selected: {_spendingNature},
              onSelectionChanged: (set) {
                setState(() => _spendingNature = set.first);
              },
            ),
            const SizedBox(height: 16),

            // Optional note
            TextField(
              controller: _notesController,
              maxLines: 2,
              maxLength: 150,
              decoration: const InputDecoration(
                labelText: 'Reflection Notes (Optional)',
                hintText: 'Any thoughts or context to keep in mind?',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // Action Buttons
            Row(
              children: [
                if (isEditing) ...[
                  TextButton.icon(
                    onPressed: _delete,
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    label: const Text(
                      'Remove',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                  const Spacer(),
                ] else ...[
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Skip'),
                  ),
                  const Spacer(),
                ],
                FilledButton.icon(
                  onPressed: _isSaving ? null : _save,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check_rounded),
                  label: Text(
                    isEditing ? 'Update Reflection' : 'Save Reflection',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
