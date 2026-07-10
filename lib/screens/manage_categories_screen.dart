import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/category.dart';
import '../models/transaction_type.dart';
import '../providers/categories_provider.dart';
import '../providers/transactions_provider.dart';
import '../theme/app_theme.dart';
import '../theme/category_style.dart';
import '../widgets/adaptive.dart';
import '../widgets/glass.dart';

class ManageCategoriesScreen extends ConsumerStatefulWidget {
  const ManageCategoriesScreen({super.key});

  @override
  ConsumerState<ManageCategoriesScreen> createState() =>
      _ManageCategoriesScreenState();
}

class _ManageCategoriesScreenState
    extends ConsumerState<ManageCategoriesScreen> {
  TransactionType _type = TransactionType.expense;
  bool _selecting = false;
  final Set<String> _selectedIds = {};

  void _openForm({Category? category}) {
    showAdaptiveModalBottomSheet(
      context: context,
      builder: (_) => _CategoryFormSheet(type: _type, category: category),
    );
  }

  void _cancelSelection() {
    setState(() {
      _selecting = false;
      _selectedIds.clear();
    });
  }

  Future<void> _confirmDelete(Category category) async {
    final inUse = ref
        .read(transactionsProvider)
        .any((t) => t.categoryId == category.id);
    final confirmed = await showAdaptiveDialog<bool>(
      context: context,
      builder: (context) => AlertDialog.adaptive(
        title: Text('Delete "${category.name}"?'),
        content: Text(
          inUse
              ? 'This category is used by existing transactions. It will be archived '
                    'so those transactions keep showing "${category.name}", but it will '
                    'no longer be available for new transactions.'
              : 'This category isn\'t used by any transaction and will be removed permanently.',
        ),
        actions: [
          adaptiveDialogAction(
            context: context,
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          adaptiveDialogAction(
            context: context,
            onPressed: () => Navigator.pop(context, true),
            isDestructive: true,
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(categoriesProvider.notifier).deleteCategory(category.id);
    }
  }

  Future<void> _confirmBulkDelete() async {
    final count = _selectedIds.length;
    final confirmed = await showAdaptiveDialog<bool>(
      context: context,
      builder: (context) => AlertDialog.adaptive(
        title: Text('Delete $count categor${count == 1 ? 'y' : 'ies'}?'),
        content: const Text(
          'Categories still used by existing transactions are archived '
          'instead of removed, so those transactions keep showing their name.',
        ),
        actions: [
          adaptiveDialogAction(
            context: context,
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          adaptiveDialogAction(
            context: context,
            onPressed: () => Navigator.pop(context, true),
            isDestructive: true,
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(categoriesProvider.notifier).deleteCategories(_selectedIds);
    if (!mounted) return;
    _cancelSelection();
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesByTypeProvider(_type));

    return AdaptiveSliverScaffold(
      title: 'Manage categories',
      largeTitle: false,
      actions: [
        SelectionToggleAction(
          selecting: _selecting,
          onPressed: () {
            if (_selecting) {
              _cancelSelection();
            } else {
              setState(() => _selecting = true);
            }
          },
        ),
      ],
      bottomBar: _selecting
          ? SelectionBar(
              count: _selectedIds.length,
              onCancel: _cancelSelection,
              onDelete: _selectedIds.isEmpty ? null : _confirmBulkDelete,
            )
          : null,
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: AdaptiveSegmentedControl<TransactionType>(
              segments: const [
                (TransactionType.expense, 'Expense'),
                (TransactionType.income, 'Income'),
              ],
              value: _type,
              onChanged: (selected) => setState(() => _type = selected),
            ),
          ),
        ),
        if (categories.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Text(
                'No categories yet',
                style: TextStyle(color: AppColors.muted),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.only(top: 8, bottom: 96),
            sliver: SliverList.separated(
              itemCount: categories.length,
              separatorBuilder: (_, _) =>
                  const Divider(height: 1, indent: 20, endIndent: 20),
              itemBuilder: (context, index) {
                final category = categories[index];
                final palette = CategoryPalette.of(category.paletteIndex);
                final selected = _selectedIds.contains(category.id);
                return ListTile(
                  onTap: _selecting
                      ? () => setState(() {
                          if (!_selectedIds.remove(category.id)) {
                            _selectedIds.add(category.id);
                          }
                        })
                      : () => _openForm(category: category),
                  leading: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_selecting) ...[
                        Icon(
                          selected
                              ? (isApplePlatform(context)
                                    ? CupertinoIcons.checkmark_circle_fill
                                    : Icons.check_circle)
                              : (isApplePlatform(context)
                                    ? CupertinoIcons.circle
                                    : Icons.radio_button_unchecked),
                          size: 24,
                          color: selected ? AppColors.ink : AppColors.muted,
                        ),
                        const SizedBox(width: 12),
                      ],
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: palette.background,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          categoryIcon(category.iconKey),
                          size: 20,
                          color: palette.foreground,
                        ),
                      ),
                    ],
                  ),
                  title: Text(
                    category.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  trailing: _selecting
                      ? null
                      : IconButton(
                          icon: Icon(
                            isApplePlatform(context)
                                ? CupertinoIcons.trash
                                : Icons.delete_outline,
                            size: 20,
                            color: AppColors.muted,
                          ),
                          tooltip: 'Delete',
                          onPressed: () => _confirmDelete(category),
                        ),
                );
              },
            ),
          ),
      ],
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _CategoryFormSheet extends ConsumerStatefulWidget {
  const _CategoryFormSheet({required this.type, this.category});

  final TransactionType type;
  final Category? category;

  @override
  ConsumerState<_CategoryFormSheet> createState() => _CategoryFormSheetState();
}

class _CategoryFormSheetState extends ConsumerState<_CategoryFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late TransactionType _type;
  late String _iconKey;
  late int _paletteIndex;

  bool get _isEditing => widget.category != null;

  @override
  void initState() {
    super.initState();
    final category = widget.category;
    _nameController = TextEditingController(text: category?.name ?? '');
    _type = category?.type ?? widget.type;
    _iconKey = category?.iconKey ?? kCategoryIcons.keys.first;
    _paletteIndex = category?.paletteIndex ?? 0;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final notifier = ref.read(categoriesProvider.notifier);
    if (_isEditing) {
      await notifier.updateCategory(
        widget.category!.id,
        name: _nameController.text.trim(),
        iconKey: _iconKey,
        paletteIndex: _paletteIndex,
      );
    } else {
      await notifier.addCategory(
        name: _nameController.text.trim(),
        type: _type,
        iconKey: _iconKey,
        paletteIndex: _paletteIndex,
      );
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final previewPalette = CategoryPalette.of(_paletteIndex);

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isEditing ? 'Edit category' : 'New category',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            if (!_isEditing) ...[
              AdaptiveSegmentedControl<TransactionType>(
                segments: const [
                  (TransactionType.expense, 'Expense'),
                  (TransactionType.income, 'Income'),
                ],
                value: _type,
                onChanged: (selected) => setState(() => _type = selected),
              ),
              const SizedBox(height: 16),
            ],
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Name'),
              textCapitalization: TextCapitalization.words,
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'Enter a name'
                  : null,
            ),
            const SizedBox(height: 20),
            Text(
              'ICON',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: AppColors.muted,
                letterSpacing: 0.06,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: kCategoryIcons.entries.map((entry) {
                final selected = entry.key == _iconKey;
                return InkWell(
                  onTap: () => setState(() => _iconKey = entry.key),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: selected
                          ? previewPalette.background
                          : AppColors.canvas,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selected
                            ? previewPalette.foreground
                            : AppColors.border,
                      ),
                    ),
                    child: Icon(
                      entry.value,
                      size: 18,
                      color: selected
                          ? previewPalette.foreground
                          : AppColors.muted,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            Text(
              'COLOR',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: AppColors.muted,
                letterSpacing: 0.06,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(CategoryPalette.values.length, (index) {
                final palette = CategoryPalette.values[index];
                final selected = index == _paletteIndex;
                return InkWell(
                  onTap: () => setState(() => _paletteIndex = index),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: palette.background,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected
                            ? palette.foreground
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: selected
                        ? Icon(Icons.check, size: 16, color: palette.foreground)
                        : null,
                  ),
                );
              }),
            ),
            const SizedBox(height: 24),
            AdaptivePrimaryButton(
              onPressed: _save,
              child: Text(_isEditing ? 'Save changes' : 'Add category'),
            ),
          ],
        ),
      ),
    );
  }
}
