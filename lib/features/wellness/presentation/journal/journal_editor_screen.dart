import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/responsive_layout.dart';
import '../../../../core/widgets/retro_paper.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/id_generator.dart';
import '../../models/journal_entry.dart';
import '../../providers/wellness_providers.dart';
import '../prompts/gratitude_prompts.dart';

class JournalEditorScreen extends ConsumerStatefulWidget {
  final JournalEntry? entryToEdit;
  final String? initialPrompt;
  final String entryType; // 'journal' or 'reflection'

  const JournalEditorScreen({
    super.key,
    this.entryToEdit,
    this.initialPrompt,
    this.entryType = 'journal',
  });

  @override
  ConsumerState<JournalEditorScreen> createState() =>
      _JournalEditorScreenState();
}

class _JournalEditorScreenState extends ConsumerState<JournalEditorScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  int? _selectedMoodRating;
  String? _currentPrompt;
  late final String _entryType;
  bool _isSaving = false;

  late final String _initialTitle;
  late final String _initialContent;

  static const List<Map<String, dynamic>> _moodRatings = [
    {'rating': 1, 'emoji': '😔', 'label': 'Difficult'},
    {'rating': 2, 'emoji': '🙁', 'label': 'Low'},
    {'rating': 3, 'emoji': '😐', 'label': 'Neutral'},
    {'rating': 4, 'emoji': '🙂', 'label': 'Good'},
    {'rating': 5, 'emoji': '😊', 'label': 'Thriving'},
  ];

  @override
  void initState() {
    super.initState();
    final edit = widget.entryToEdit;
    _initialTitle = edit?.title ?? '';
    _initialContent = edit?.content ?? '';
    _titleController = TextEditingController(text: _initialTitle);
    _contentController = TextEditingController(text: _initialContent);
    _selectedMoodRating = edit?.moodRating;
    _entryType = edit?.entryType ?? widget.entryType;
    _currentPrompt = edit?.prompt ?? widget.initialPrompt;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  bool get _hasUnsavedChanges {
    final titleChanged = _titleController.text != _initialTitle;
    final contentChanged = _contentController.text != _initialContent;
    return titleChanged || contentChanged;
  }

  Future<bool> _onWillPop() async {
    if (!_hasUnsavedChanges) return true;

    final shouldDiscard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard Unsaved Changes?'),
        content: const Text(
          'You have unsaved edits in your journal entry. Are you sure you want to discard them?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep Editing'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return shouldDiscard ?? false;
  }

  Future<void> _saveEntry() async {
    final content = _contentController.text.trim();
    if (content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please write something in your entry.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final repo = ref.read(journalRepositoryProvider);
      final now = DateTime.now();
      final title = _titleController.text.trim();
      final dateStr = AppDateUtils.toIsoDate(now);

      if (widget.entryToEdit != null) {
        final updated = widget.entryToEdit!.copyWith(
          title: title.isEmpty ? null : title,
          content: content,
          moodRating: _selectedMoodRating,
          entryType: _entryType,
          prompt: _currentPrompt,
          updatedAt: now,
        );
        await repo.updateEntry(updated);
      } else {
        final newEntry = JournalEntry(
          id: 'jrn_${IdGenerator.generate()}',
          title: title.isEmpty ? null : title,
          content: content,
          moodRating: _selectedMoodRating,
          entryDate: dateStr,
          entryType: _entryType,
          prompt: _currentPrompt,
          createdAt: now,
          updatedAt: now,
        );
        await repo.createEntry(newEntry);
      }

      ref.invalidate(journalEntriesProvider);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _entryType == 'reflection'
                  ? 'Reflection saved.'
                  : 'Journal entry saved.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error saving entry: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _cyclePrompt() {
    final currentIndex = GratitudePrompts.prompts.indexOf(_currentPrompt ?? '');
    final nextIndex = (currentIndex + 1) % GratitudePrompts.prompts.length;
    setState(() {
      _currentPrompt = GratitudePrompts.prompts[nextIndex];
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isEditing = widget.entryToEdit != null;
    final isReflection = _entryType == 'reflection';

    return PopScope(
      canPop: !_hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            isEditing
                ? (isReflection ? 'Edit Reflection' : 'Edit Entry')
                : (isReflection ? 'New Reflection' : 'Private Journal'),
          ),
          actions: [
            IconButton(
              icon: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check_rounded),
              tooltip: 'Save',
              onPressed: _isSaving ? null : _saveEntry,
            ),
          ],
        ),
        body: RetroPaperBackground(
          child: ResponsiveContentWrapper(
            maxWidth: 720,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Reflection prompt banner (if reflection)
                if (isReflection && _currentPrompt != null) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer.withValues(
                        alpha: 0.5,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: colorScheme.primary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.lightbulb_outline_rounded,
                          color: colorScheme.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _currentPrompt!,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.shuffle_rounded, size: 18),
                          tooltip: 'Try another prompt',
                          visualDensity: VisualDensity.compact,
                          onPressed: _cyclePrompt,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Mood Association Bar
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.3,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Text(
                        'Mood today:',
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: _moodRatings.map((opt) {
                              final rating = opt['rating'] as int;
                              final emoji = opt['emoji'] as String;
                              final label = opt['label'] as String;
                              final isSelected = _selectedMoodRating == rating;
                              return Semantics(
                                label: '$label mood',
                                button: true,
                                selected: isSelected,
                                child: InkWell(
                                  onTap: () {
                                    setState(() {
                                      _selectedMoodRating = isSelected
                                          ? null
                                          : rating;
                                    });
                                  },
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    constraints: const BoxConstraints(
                                      minWidth: 44,
                                      minHeight: 44,
                                    ),
                                    alignment: Alignment.center,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    margin: const EdgeInsets.only(right: 4),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? colorScheme.primaryContainer
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(8),
                                      border: isSelected
                                          ? Border.all(
                                              color: colorScheme.primary,
                                            )
                                          : null,
                                    ),
                                    child: Text(
                                      emoji,
                                      style: TextStyle(
                                        fontSize: 22,
                                        color: isSelected
                                            ? null
                                            : Colors.grey.withValues(
                                                alpha: 0.5,
                                              ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Title input
                TextField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    hintText: isReflection
                        ? 'Reflection title (optional)...'
                        : 'Entry title (optional)...',
                    border: InputBorder.none,
                    hintStyle: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.7,
                      ),
                    ),
                  ),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Divider(height: 16),

                // Content body editor (multiline, preserves all line breaks)
                TextField(
                  controller: _contentController,
                  maxLines: null,
                  minLines: 12,
                  keyboardType: TextInputType.multiline,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: isReflection ? 'Write your reflection here...' : 'What is on your mind? Everything written here stays strictly on this device.',
                    border: InputBorder.none,
                    hintStyle: TextStyle(
                      color: colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.6,
                      ),
                    ),
                  ),
                  style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
