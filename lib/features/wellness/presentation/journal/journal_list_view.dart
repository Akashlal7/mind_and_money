import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/empty_state_card.dart';
import '../../models/journal_entry.dart';
import '../../providers/wellness_providers.dart';
import 'journal_detail_screen.dart';
import 'journal_editor_screen.dart';

class JournalListView extends ConsumerStatefulWidget {
  const JournalListView({super.key});

  @override
  ConsumerState<JournalListView> createState() => _JournalListViewState();
}

class _JournalListViewState extends ConsumerState<JournalListView> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(
      text: ref.read(journalSearchQueryProvider),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entriesAsync = ref.watch(journalEntriesProvider);
    final currentFilter = ref.watch(journalTypeFilterProvider);

    return Scaffold(
      body: Column(
        children: [
          // Search & Filter Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  onChanged: (val) {
                    ref.read(journalSearchQueryProvider.notifier).setQuery(val);
                  },
                  decoration: InputDecoration(
                    hintText: 'Search private entries...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded),
                            onPressed: () {
                              _searchController.clear();
                              ref
                                  .read(journalSearchQueryProvider.notifier)
                                  .setQuery('');
                            },
                          )
                        : null,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Type Filter Chips
                Row(
                  children: [
                    FilterChip(
                      label: const Text('All'),
                      selected: currentFilter == null,
                      onSelected: (_) {
                        ref
                            .read(journalTypeFilterProvider.notifier)
                            .setFilter(null);
                      },
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('Journal'),
                      selected: currentFilter == 'journal',
                      onSelected: (_) {
                        ref
                            .read(journalTypeFilterProvider.notifier)
                            .setFilter('journal');
                      },
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('Reflections'),
                      selected: currentFilter == 'reflection',
                      onSelected: (_) {
                        ref
                            .read(journalTypeFilterProvider.notifier)
                            .setFilter('reflection');
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Entries List
          Expanded(
            child: entriesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Error: $err')),
              data: (entries) {
                if (entries.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: EmptyStateCard(
                        icon: Icons.book_outlined,
                        title: 'No Entries Yet',
                        description: 'Capture your thoughts, celebrate small wins, or write a private gratitude reflection.\n\nAll entries stay 100% on your device.',
                        actionLabel: 'Write Entry',
                        onAction: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (ctx) => const JournalEditorScreen(),
                            ),
                          );
                        },
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  itemCount: entries.length,
                  itemBuilder: (context, index) {
                    final entry = entries[index];
                    return _JournalEntryCard(entry: entry);
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _showNewEntrySheet(context);
        },
        icon: const Icon(Icons.edit_note_rounded),
        label: const Text('Write'),
      ),
    );
  }

  void _showNewEntrySheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.menu_book_rounded),
                title: const Text('Freeform Journal Entry'),
                subtitle: const Text('Write whatever is on your mind'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (c) =>
                          const JournalEditorScreen(entryType: 'journal'),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.lightbulb_outline_rounded),
                title: const Text('Gratitude & Reflection'),
                subtitle: const Text('Answer a guided reflection prompt'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (c) => const JournalEditorScreen(
                        entryType: 'reflection',
                        initialPrompt: 'What went well today?',
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _JournalEntryCard extends StatelessWidget {
  final JournalEntry entry;

  const _JournalEntryCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isReflection = entry.isReflection;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (ctx) => JournalDetailScreen(entry: entry),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Badge & Date
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: isReflection
                              ? colorScheme.primaryContainer
                              : colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isReflection ? 'Reflection' : 'Journal',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: isReflection
                                ? colorScheme.onPrimaryContainer
                                : colorScheme.onSecondaryContainer,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        entry.entryDate,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  if (entry.moodRating != null)
                    Text(
                      _moodEmoji(entry.moodRating!),
                      style: const TextStyle(fontSize: 18),
                    ),
                ],
              ),
              const SizedBox(height: 8),

              // Reflection Prompt or Title
              if (isReflection && entry.prompt != null) ...[
                Text(
                  entry.prompt!,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colorScheme.primary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
              ],

              if (entry.title != null && entry.title!.trim().isNotEmpty) ...[
                Text(
                  entry.title!,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
              ],

              // Excerpt
              Text(
                entry.content,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _moodEmoji(int rating) {
    switch (rating) {
      case 1:
        return '😔';
      case 2:
        return '🙁';
      case 3:
        return '😐';
      case 4:
        return '🙂';
      case 5:
        return '😊';
      default:
        return '😐';
    }
  }
}
