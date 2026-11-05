import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/responsive_layout.dart';
import '../../../../core/utils/id_generator.dart';
import '../../../home/providers/home_providers.dart';
import '../../models/habit.dart';
import '../../models/habit_template.dart';
import '../../providers/habit_providers.dart';

class HabitFormSheet extends ConsumerStatefulWidget {
  final Habit? habitToEdit;

  const HabitFormSheet({super.key, this.habitToEdit});

  @override
  ConsumerState<HabitFormSheet> createState() => _HabitFormSheetState();
}

class _HabitFormSheetState extends ConsumerState<HabitFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descController;

  String _scheduleType = 'daily';
  final Set<int> _selectedWeekdays = {1, 2, 3, 4, 5, 6, 7};
  int _selectedColor = 0xFF4CAF50;
  String _selectedIcon = 'check_circle_rounded';
  TimeOfDay? _reminderTime;

  static const List<({String name, int day})> _weekdays = [
    (name: 'Mon', day: 1),
    (name: 'Tue', day: 2),
    (name: 'Wed', day: 3),
    (name: 'Thu', day: 4),
    (name: 'Fri', day: 5),
    (name: 'Sat', day: 6),
    (name: 'Sun', day: 7),
  ];

  static const List<int> _colorPalette = [
    0xFF4CAF50, // Green
    0xFF2196F3, // Blue
    0xFF9C27B0, // Purple
    0xFFFF9800, // Orange
    0xFF009688, // Teal
    0xFFE91E63, // Pink
    0xFF3F51B5, // Indigo
    0xFF607D8B, // Slate
  ];

  @override
  void initState() {
    super.initState();
    final h = widget.habitToEdit;
    _nameController = TextEditingController(text: h?.name ?? '');
    _descController = TextEditingController(text: h?.description ?? '');

    if (h != null) {
      _scheduleType = h.scheduleType;
      _selectedWeekdays.clear();
      _selectedWeekdays.addAll(h.scheduledDayNumbers);
      _selectedColor = h.color ?? 0xFF4CAF50;
      _selectedIcon = h.icon ?? 'check_circle_rounded';
      if (h.reminderTime != null) {
        final parts = h.reminderTime!.split(':');
        if (parts.length == 2) {
          _reminderTime = TimeOfDay(
            hour: int.tryParse(parts[0]) ?? 8,
            minute: int.tryParse(parts[1]) ?? 0,
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _applyTemplate(HabitTemplate t) {
    setState(() {
      _nameController.text = t.title;
      _descController.text = t.description;
      _selectedIcon = t.icon;
      _selectedColor = t.color;
      _scheduleType = t.scheduleType;
      _selectedWeekdays.clear();
      if (t.scheduleType == 'daily') {
        _selectedWeekdays.addAll({1, 2, 3, 4, 5, 6, 7});
      } else if (t.scheduleDays != null) {
        final parsed = t.scheduleDays!
            .split(',')
            .map((s) => int.tryParse(s.trim()))
            .whereType<int>();
        _selectedWeekdays.addAll(parsed);
      }
    });
  }

  void _showTemplatesModal() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Suggested Habits',
                style: Theme.of(ctx).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              ...HabitTemplate.templates.map((tpl) {
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Color(tpl.color).withValues(alpha: 0.15),
                    child: Icon(
                      Icons.star_outline_rounded,
                      color: Color(tpl.color),
                    ),
                  ),
                  title: Text(
                    tpl.title,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    tpl.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _applyTemplate(tpl);
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Future<void> _saveHabit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_scheduleType == 'weekdays' && _selectedWeekdays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one day for scheduled habits.'),
        ),
      );
      return;
    }

    final repo = ref.read(habitRepositoryProvider);
    final isEditing = widget.habitToEdit != null;
    final now = DateTime.now();

    final scheduleDaysStr = _scheduleType == 'daily'
        ? null
        : (_selectedWeekdays.toList()..sort()).join(',');

    final reminderStr = _reminderTime != null
        ? '${_reminderTime!.hour.toString().padLeft(2, '0')}:${_reminderTime!.minute.toString().padLeft(2, '0')}'
        : null;

    final habit = Habit(
      id: isEditing ? widget.habitToEdit!.id : 'hab_${IdGenerator.generate()}',
      name: _nameController.text.trim(),
      description: _descController.text.trim().isEmpty
          ? null
          : _descController.text.trim(),
      scheduleType: _scheduleType,
      scheduleDays: scheduleDaysStr,
      isArchived: isEditing ? widget.habitToEdit!.isArchived : false,
      color: _selectedColor,
      icon: _selectedIcon,
      reminderTime: reminderStr,
      createdAt: isEditing ? widget.habitToEdit!.createdAt : now,
      updatedAt: now,
    );

    if (isEditing) {
      await repo.updateHabit(habit);
    } else {
      await repo.createHabit(habit);
    }

    ref.invalidate(activeHabitsProvider);
    ref.invalidate(todayScheduledHabitsProvider);
    ref.invalidate(todayHabitProgressProvider);
    ref.invalidate(homeSummaryProvider);

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEditing
                ? 'Habit updated successfully'
                : 'Habit created successfully',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isEditing = widget.habitToEdit != null;

    return ResponsiveContentWrapper(
      maxWidth: 600,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.88,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          isEditing ? 'Edit Habit' : 'New Habit',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!isEditing)
                        TextButton.icon(
                          icon: const Icon(
                            Icons.auto_awesome_rounded,
                            size: 16,
                          ),
                          label: const Text('Suggestions'),
                          onPressed: _showTemplatesModal,
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Name input
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Habit Name *',
                      hintText: 'e.g. Morning reflection, Check budget',
                      border: OutlineInputBorder(),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Please enter a habit name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  // Description input
                  TextFormField(
                    controller: _descController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Description (Optional)',
                      hintText: 'Why is this habit important to you?',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Schedule Type Selection
                  Text(
                    'Frequency',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                        value: 'daily',
                        label: Text('Daily'),
                        icon: Icon(Icons.today_rounded),
                      ),
                      ButtonSegment(
                        value: 'weekdays',
                        label: Text('Specific Days'),
                        icon: Icon(Icons.calendar_view_week_rounded),
                      ),
                    ],
                    selected: {_scheduleType},
                    onSelectionChanged: (val) {
                      setState(() {
                        _scheduleType = val.first;
                      });
                    },
                  ),
                  const SizedBox(height: 12),

                  // Weekday selection chips if 'weekdays'
                  if (_scheduleType == 'weekdays') ...[
                    Text(
                      'Select Active Days',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: _weekdays.map((item) {
                        final isSelected = _selectedWeekdays.contains(item.day);
                        return FilterChip(
                          label: Text(item.name),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedWeekdays.add(item.day);
                              } else {
                                _selectedWeekdays.remove(item.day);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Color Selection
                  Text(
                    'Color Tag',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: _colorPalette.map((col) {
                      final isSelected = _selectedColor == col;
                      return InkWell(
                        onTap: () => setState(() => _selectedColor = col),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Color(col),
                            shape: BoxShape.circle,
                            border: isSelected
                                ? Border.all(color: Colors.white, width: 3)
                                : null,
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: Color(col).withValues(alpha: 0.5),
                                      blurRadius: 8,
                                      spreadRadius: 2,
                                    ),
                                  ]
                                : null,
                          ),
                          child: isSelected
                              ? const Icon(
                                  Icons.check,
                                  color: Colors.white,
                                  size: 18,
                                )
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // Optional Reminder Time
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      _reminderTime != null
                          ? Icons.notifications_active_outlined
                          : Icons.notifications_none_outlined,
                      color: colorScheme.primary,
                    ),
                    title: const Text('Daily Reminder (Optional)'),
                    subtitle: Text(
                      _reminderTime != null
                          ? 'Preferred time: ${_reminderTime!.format(context)}'
                          : 'No reminder set',
                    ),
                    trailing: _reminderTime != null
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded),
                            onPressed: () =>
                                setState(() => _reminderTime = null),
                          )
                        : OutlinedButton(
                            onPressed: () async {
                              final picked = await showTimePicker(
                                context: context,
                                initialTime:
                                    _reminderTime ??
                                    const TimeOfDay(hour: 8, minute: 0),
                              );
                              if (picked != null) {
                                setState(() => _reminderTime = picked);
                              }
                            },
                            child: const Text('Set Time'),
                          ),
                  ),
                  const SizedBox(height: 20),

                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      onPressed: _saveHabit,
                      child: Text(
                        isEditing ? 'Save Changes' : 'Create Habit',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
