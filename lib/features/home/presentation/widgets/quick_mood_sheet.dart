import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../providers/home_providers.dart';

class QuickMoodSheet extends ConsumerStatefulWidget {
  const QuickMoodSheet({super.key});

  @override
  ConsumerState<QuickMoodSheet> createState() => _QuickMoodSheetState();
}

class _QuickMoodSheetState extends ConsumerState<QuickMoodSheet> {
  int _selectedRating = 3;
  final TextEditingController _noteController = TextEditingController();
  bool _isSaving = false;

  final List<Map<String, dynamic>> _moodOptions = const [
    {'rating': 1, 'emoji': '😔', 'label': 'Difficult'},
    {'rating': 2, 'emoji': '🙁', 'label': 'Low'},
    {'rating': 3, 'emoji': '😐', 'label': 'Neutral'},
    {'rating': 4, 'emoji': '🙂', 'label': 'Good'},
    {'rating': 5, 'emoji': '😊', 'label': 'Thriving'},
  ];

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _saveMood() async {
    setState(() => _isSaving = true);
    try {
      final repo = ref.read(homeRepositoryProvider);
      final note = _noteController.text.trim();
      await repo.recordQuickMood(_selectedRating, note.isEmpty ? null : note);
      ref.invalidate(homeSummaryProvider);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mood check-in recorded.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error saving mood: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'How are you feeling right now?',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 5-scale mood selector
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: _moodOptions.map((opt) {
              final rating = opt['rating'] as int;
              final emoji = opt['emoji'] as String;
              final label = opt['label'] as String;
              final isSelected = _selectedRating == rating;

              return InkWell(
                onTap: () => setState(() => _selectedRating = rating),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.sageContainer
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.sagePrimary
                          : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(emoji, style: const TextStyle(fontSize: 28)),
                      const SizedBox(height: 4),
                      Text(
                        label,
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: isSelected
                              ? AppColors.onSageContainer
                              : colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // Optional short note
          TextField(
            controller: _noteController,
            maxLines: 2,
            decoration: const InputDecoration(
              hintText: 'Add an optional note (e.g. what is on your mind?)...',
            ),
          ),
          const SizedBox(height: 20),

          FilledButton(
            onPressed: _isSaving ? null : _saveMood,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Save Check-in'),
          ),
        ],
      ),
    );
  }
}
