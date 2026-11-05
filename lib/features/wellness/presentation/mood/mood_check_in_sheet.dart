import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/responsive_layout.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/id_generator.dart';
import '../../../home/providers/home_providers.dart';
import '../../models/mood_entry.dart';
import '../../providers/wellness_providers.dart';

class MoodCheckInSheet extends ConsumerStatefulWidget {
  final MoodEntry? entryToEdit;

  const MoodCheckInSheet({super.key, this.entryToEdit});

  @override
  ConsumerState<MoodCheckInSheet> createState() => _MoodCheckInSheetState();
}

class _MoodCheckInSheetState extends ConsumerState<MoodCheckInSheet> {
  late int _rating;
  late final TextEditingController _noteController;
  late final TextEditingController _customTagController;
  late final Set<String> _selectedTags;
  int? _stressRating;
  int? _energyRating;
  int? _sleepRating;
  late DateTime _selectedDateTime;
  bool _isSaving = false;

  static const List<Map<String, dynamic>> _moodOptions = [
    {'rating': 1, 'emoji': '😔', 'label': 'Difficult'},
    {'rating': 2, 'emoji': '🙁', 'label': 'Low'},
    {'rating': 3, 'emoji': '😐', 'label': 'Neutral'},
    {'rating': 4, 'emoji': '🙂', 'label': 'Good'},
    {'rating': 5, 'emoji': '😊', 'label': 'Thriving'},
  ];

  static const List<String> _standardTags = [
    'Calm',
    'Grateful',
    'Energized',
    'Content',
    'Optimistic',
    'Anxious',
    'Stressed',
    'Tired',
    'Overwhelmed',
    'Reflective',
    'Restless',
    'Peaceful',
  ];

  @override
  void initState() {
    super.initState();
    final edit = widget.entryToEdit;
    _rating = edit?.rating ?? 3;
    _noteController = TextEditingController(text: edit?.note ?? '');
    _customTagController = TextEditingController();
    _selectedTags = edit != null ? edit.tags.toSet() : <String>{};
    _stressRating = edit?.stressRating;
    _energyRating = edit?.energyRating;
    _sleepRating = edit?.sleepRating;

    if (edit != null) {
      final dateParts = edit.entryDate.split('-');
      final timeParts = edit.entryTime.split(':');
      _selectedDateTime = DateTime(
        int.parse(dateParts[0]),
        int.parse(dateParts[1]),
        int.parse(dateParts[2]),
        int.parse(timeParts[0]),
        int.parse(timeParts[1]),
      );
    } else {
      _selectedDateTime = DateTime.now();
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    _customTagController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDateTime,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDateTime),
    );
    if (pickedTime == null || !mounted) return;

    setState(() {
      _selectedDateTime = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
  }

  void _addCustomTag() {
    final text = _customTagController.text.trim();
    if (text.isNotEmpty && !_selectedTags.contains(text)) {
      setState(() {
        _selectedTags.add(text);
        _customTagController.clear();
      });
    }
  }

  Future<void> _saveMood() async {
    setState(() => _isSaving = true);
    try {
      final repo = ref.read(moodRepositoryProvider);
      final now = DateTime.now();
      final dateStr = AppDateUtils.toIsoDate(_selectedDateTime);
      final timeStr =
          "${_selectedDateTime.hour.toString().padLeft(2, '0')}:${_selectedDateTime.minute.toString().padLeft(2, '0')}:${_selectedDateTime.second.toString().padLeft(2, '0')}";
      final noteText = _noteController.text.trim();
      final tagsStr = _selectedTags.isNotEmpty ? _selectedTags.join(',') : null;

      if (widget.entryToEdit != null) {
        final updated = widget.entryToEdit!.copyWith(
          entryDate: dateStr,
          entryTime: timeStr,
          rating: _rating,
          emotionLabels: tagsStr,
          stressRating: _stressRating,
          energyRating: _energyRating,
          sleepRating: _sleepRating,
          note: noteText.isEmpty ? null : noteText,
          updatedAt: now,
        );
        await repo.updateMoodEntry(updated);
      } else {
        final newEntry = MoodEntry(
          id: 'mood_${IdGenerator.generate()}',
          entryDate: dateStr,
          entryTime: timeStr,
          rating: _rating,
          emotionLabels: tagsStr,
          stressRating: _stressRating,
          energyRating: _energyRating,
          sleepRating: _sleepRating,
          note: noteText.isEmpty ? null : noteText,
          createdAt: now,
          updatedAt: now,
        );
        await repo.createMoodEntry(newEntry);
      }

      // Refresh providers
      ref.invalidate(recentMoodEntriesProvider);
      ref.invalidate(moodWeeklySummaryProvider);
      ref.invalidate(moodMonthlySummaryProvider);
      ref.invalidate(homeSummaryProvider);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.entryToEdit != null
                  ? 'Mood entry updated.'
                  : 'Mood check-in recorded.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error saving mood: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isEditing = widget.entryToEdit != null;

    return ResponsiveContentWrapper(
      maxWidth: 600,
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
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
                  Expanded(
                    child: Text(
                      isEditing
                          ? 'Edit Mood Check-in'
                          : 'How are you feeling right now?',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Date & Time Picker Button
              InkWell(
                onTap: _pickDateTime,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.5,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.access_time_rounded,
                        size: 16,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${AppDateUtils.toIsoDate(_selectedDateTime)}  at  ${_selectedDateTime.hour.toString().padLeft(2, '0')}:${_selectedDateTime.minute.toString().padLeft(2, '0')}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Change',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 5-scale mood selector
              Row(
                children: _moodOptions.map((opt) {
                  final rating = opt['rating'] as int;
                  final emoji = opt['emoji'] as String;
                  final label = opt['label'] as String;
                  final isSelected = _rating == rating;

                  return Expanded(
                    child: Semantics(
                      label: '$label mood',
                      button: true,
                      selected: isSelected,
                      child: InkWell(
                        onTap: () => setState(() => _rating = rating),
                        borderRadius: BorderRadius.circular(12),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 2,
                            vertical: 8,
                          ),
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? colorScheme.primaryContainer
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? colorScheme.primary
                                  : colorScheme.outlineVariant.withValues(
                                      alpha: 0.5,
                                    ),
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(emoji, style: const TextStyle(fontSize: 26)),
                              const SizedBox(height: 4),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  label,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    fontSize: 10,
                                    fontWeight: isSelected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: isSelected
                                        ? colorScheme.onPrimaryContainer
                                        : colorScheme.onSurfaceVariant,
                                  ),
                                  maxLines: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              // Emotion Tags
              Text(
                'Emotions & Feelings (Optional)',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: _standardTags.map((tag) {
                  final isSelected = _selectedTags.contains(tag);
                  return FilterChip(
                    label: Text(tag),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedTags.add(tag);
                        } else {
                          _selectedTags.remove(tag);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _customTagController,
                      decoration: const InputDecoration(
                        hintText: 'Add custom emotion tag...',
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _addCustomTag(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    onPressed: _addCustomTag,
                    icon: const Icon(Icons.add_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Optional Ratings: Stress, Energy, Sleep
              _buildRatingScale(
                label: 'Stress Level',
                value: _stressRating,
                lowLabel: 'Low',
                highLabel: 'High',
                onChanged: (val) => setState(() => _stressRating = val),
              ),
              const SizedBox(height: 12),
              _buildRatingScale(
                label: 'Energy Level',
                value: _energyRating,
                lowLabel: 'Drained',
                highLabel: 'Vibrant',
                onChanged: (val) => setState(() => _energyRating = val),
              ),
              const SizedBox(height: 12),
              _buildRatingScale(
                label: 'Sleep Quality',
                value: _sleepRating,
                lowLabel: 'Poor',
                highLabel: 'Restful',
                onChanged: (val) => setState(() => _sleepRating = val),
              ),
              const SizedBox(height: 16),

              // Optional Short Note
              TextField(
                controller: _noteController,
                maxLines: 2,
                maxLength: 200,
                decoration: const InputDecoration(
                  labelText: 'Quick Note (Optional)',
                  hintText: 'What is contributing to how you feel?',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              // Save Button
              FilledButton.icon(
                onPressed: _isSaving ? null : _saveMood,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_rounded),
                label: Text(
                  isEditing ? 'Update Check-in' : 'Save Mood Check-in',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRatingScale({
    required String label,
    required int? value,
    required String lowLabel,
    required String highLabel,
    required ValueChanged<int?> onChanged,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (value != null)
                TextButton(
                  onPressed: () => onChanged(null),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                  ),
                  child: const Text('Clear', style: TextStyle(fontSize: 12)),
                )
              else
                Text(
                  'Optional',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(5, (index) {
              final score = index + 1;
              final isSelected = value == score;
              return InkWell(
                onTap: () => onChanged(score),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 44,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? colorScheme.primary
                        : colorScheme.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected
                          ? colorScheme.primary
                          : colorScheme.outlineVariant,
                    ),
                  ),
                  child: Text(
                    '$score',
                    style: TextStyle(
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: isSelected
                          ? colorScheme.onPrimary
                          : colorScheme.onSurface,
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '1 ($lowLabel)',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                '5 ($highLabel)',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
