import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/id_generator.dart';
import '../models/category.dart';
import '../providers/transaction_providers.dart';
import '../utils/category_icons.dart';

class CategoryManagementDialog extends ConsumerStatefulWidget {
  const CategoryManagementDialog({super.key});

  @override
  ConsumerState<CategoryManagementDialog> createState() =>
      _CategoryManagementDialogState();
}

class _CategoryManagementDialogState
    extends ConsumerState<CategoryManagementDialog> {
  static const List<int> _paletteColors = [
    0xFFE57373,
    0xFF81C784,
    0xFF64B5F6,
    0xFFFFB74D,
    0xFFBA68C8,
    0xFFF06292,
    0xFF4DB6AC,
    0xFF9575CD,
    0xFFFF8A65,
    0xFF4DD0E1,
    0xFF43A047,
    0xFF00ACC1,
    0xFF7CB342,
    0xFF90A4AE,
    0xFF5C6BC0,
    0xFF26A69A,
  ];

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider(null));
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Manage Categories',
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
              const Divider(height: 20),
              Expanded(
                child: categoriesAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Error: $e')),
                  data: (categories) {
                    if (categories.isEmpty) {
                      return const Center(child: Text('No categories found.'));
                    }
                    return ListView.separated(
                      itemCount: categories.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1),
                      itemBuilder: (ctx, idx) {
                        final cat = categories[idx];
                        final icon = CategoryIconHelper.getIcon(cat.icon);
                        final color = Color(cat.color);

                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: color.withValues(alpha: 0.18),
                            child: Icon(icon, color: color, size: 20),
                          ),
                          title: Text(
                            cat.name,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            cat.isDefault
                                ? 'Default (${cat.type})'
                                : 'Custom (${cat.type})',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          trailing: cat.isDefault
                              ? const Tooltip(
                                  message: 'Default category',
                                  child: Icon(
                                    Icons.lock_outline_rounded,
                                    size: 18,
                                    color: Colors.grey,
                                  ),
                                )
                              : IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline_rounded,
                                    color: Colors.red,
                                  ),
                                  onPressed: () => _confirmDeleteCategory(cat),
                                ),
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _showAddCategoryModal,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add New Category'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDeleteCategory(Category category) async {
    final repo = ref.read(transactionRepositoryProvider);
    final count = await repo.getTransactionCountForCategory(category.id);

    if (!mounted) return;

    if (count > 0) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Cannot Delete Category'),
          content: Text(
            'The category "${category.name}" is used by $count transaction(s).\n\nTo delete this category, please delete or reassign those transactions first.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Category?'),
        content: Text('Are you sure you want to delete "${category.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              final success = await repo.deleteCategory(category.id);
              if (mounted) {
                if (success) {
                  ref.invalidate(categoriesProvider);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Deleted "${category.name}"')),
                  );
                }
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showAddCategoryModal() {
    final nameController = TextEditingController();
    String selectedIcon = CategoryIconHelper.availableIcons.first;
    int selectedColor = _paletteColors.first;
    String selectedType = 'expense';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(modalCtx).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Create Category',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.of(modalCtx).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Category Name',
                      hintText: 'e.g. Subscriptions, Freelance',
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Category Type:',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'expense', label: Text('Expense')),
                      ButtonSegment(value: 'income', label: Text('Income')),
                      ButtonSegment(value: 'both', label: Text('Both')),
                    ],
                    selected: {selectedType},
                    onSelectionChanged: (val) {
                      setModalState(() => selectedType = val.first);
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Select Icon:',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 50,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: CategoryIconHelper.availableIcons.length,
                      separatorBuilder: (ctx, _) => const SizedBox(width: 8),
                      itemBuilder: (c, idx) {
                        final iconKey = CategoryIconHelper.availableIcons[idx];
                        final iconData = CategoryIconHelper.getIcon(iconKey);
                        final isSelected = selectedIcon == iconKey;
                        return InkWell(
                          onTap: () =>
                              setModalState(() => selectedIcon = iconKey),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.sageContainer
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.sagePrimary
                                    : Colors.grey.shade300,
                              ),
                            ),
                            child: Icon(
                              iconData,
                              color: isSelected
                                  ? AppColors.sagePrimary
                                  : Colors.grey.shade700,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Select Color:',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 44,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _paletteColors.length,
                      separatorBuilder: (ctx, _) => const SizedBox(width: 8),
                      itemBuilder: (c, idx) {
                        final colorVal = _paletteColors[idx];
                        final isSelected = selectedColor == colorVal;
                        return InkWell(
                          onTap: () =>
                              setModalState(() => selectedColor = colorVal),
                          customBorder: const CircleBorder(),
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: Color(colorVal),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected
                                    ? Colors.black87
                                    : Colors.transparent,
                                width: 2.5,
                              ),
                            ),
                            child: isSelected
                                ? const Icon(
                                    Icons.check,
                                    size: 18,
                                    color: Colors.white,
                                  )
                                : null,
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: () async {
                      final name = nameController.text.trim();
                      if (name.isEmpty) {
                        ScaffoldMessenger.of(modalCtx).showSnackBar(
                          const SnackBar(
                            content: Text('Please enter a category name'),
                          ),
                        );
                        return;
                      }

                      final newCat = Category(
                        id: 'cat_${IdGenerator.generate()}',
                        name: name,
                        icon: selectedIcon,
                        color: selectedColor,
                        type: selectedType,
                        isDefault: false,
                        createdAt: DateTime.now(),
                      );

                      await ref
                          .read(transactionRepositoryProvider)
                          .createCategory(newCat);
                      ref.invalidate(categoriesProvider);

                      if (modalCtx.mounted) {
                        Navigator.of(modalCtx).pop();
                      }
                    },
                    child: const Text('Save Category'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
