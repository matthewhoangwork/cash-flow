import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/category.dart';
import '../models/planned_expense.dart';
import '../models/transaction_type.dart';
import '../providers/categories_provider.dart';
import '../providers/planned_expenses_provider.dart';
import '../theme/app_theme.dart';
import '../theme/category_style.dart';
import '../utils/currency_format.dart';
import '../widgets/adaptive.dart';
import '../widgets/glass.dart';

/// "Danh sách cần chi mỗi tháng" — a per-month checklist of planned/recurring
/// expenses (rent, internet, ...). These are drafts only: they never become
/// [Transaction]s and never affect balance or income/expense totals. Each
/// month starts empty; "Clone to next month" copies the current month's
/// items forward so you don't retype the same list every month.
class MonthlyExpensesScreen extends ConsumerStatefulWidget {
  const MonthlyExpensesScreen({super.key});

  @override
  ConsumerState<MonthlyExpensesScreen> createState() =>
      _MonthlyExpensesScreenState();
}

class _MonthlyExpensesScreenState extends ConsumerState<MonthlyExpensesScreen> {
  late int _year;
  late int _month;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _year = now.year;
    _month = now.month;
  }

  void _shiftMonth(int delta) {
    setState(() {
      final shifted = DateTime(_year, _month + delta);
      _year = shifted.year;
      _month = shifted.month;
    });
  }

  Future<void> _cloneToNextMonth() async {
    final target = DateTime(_year, _month + 1);
    final copied = await ref
        .read(plannedExpensesProvider.notifier)
        .cloneMonth(
          fromYear: _year,
          fromMonth: _month,
          toYear: target.year,
          toMonth: target.month,
        );
    if (!mounted) return;
    setState(() {
      _year = target.year;
      _month = target.month;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Copied $copied item${copied == 1 ? '' : 's'} to ${DateFormat.yMMMM().format(target)}',
        ),
      ),
    );
  }

  void _openForm({PlannedExpense? item}) {
    showAdaptiveModalBottomSheet(
      context: context,
      builder: (_) =>
          _PlannedExpenseFormSheet(year: _year, month: _month, item: item),
    );
  }

  Future<bool> _confirmDelete(PlannedExpense item) async {
    final confirmed = await showAdaptiveDialog<bool>(
      context: context,
      builder: (context) => AlertDialog.adaptive(
        title: Text('Delete "${item.name}"?'),
        content: const Text(
          'This planned expense will be permanently deleted.',
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
    return confirmed ?? false;
  }

  Future<void> _delete(PlannedExpense item) async {
    await ref.read(plannedExpensesProvider.notifier).deleteItem(item.id);
  }

  @override
  Widget build(BuildContext context) {
    final allItems = ref.watch(plannedExpensesProvider);
    final categories = ref.watch(categoriesProvider);
    final items = plannedExpensesForMonth(allItems, _year, _month);
    final total = items.fold<double>(0, (sum, item) => sum + item.amount);
    final monthLabel = DateFormat.yMMMM().format(DateTime(_year, _month));

    final isApple = isApplePlatform(context);

    return AdaptiveSliverScaffold(
      title: 'Monthly expenses',
      largeTitle: false,
      actions: [
        if (items.isNotEmpty)
          AdaptiveNavAction(
            materialIcon: Icons.copy_all_outlined,
            cupertinoIcon: CupertinoIcons.doc_on_doc,
            tooltip: 'Clone to next month',
            onPressed: _cloneToNextMonth,
          ),
      ],
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: Icon(
                        isApple
                            ? CupertinoIcons.chevron_left
                            : Icons.chevron_left,
                      ),
                      iconSize: isApple ? 20 : 24,
                      onPressed: () => _shiftMonth(-1),
                    ),
                    SizedBox(
                      width: 160,
                      child: Text(
                        monthLabel,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        isApple
                            ? CupertinoIcons.chevron_right
                            : Icons.chevron_right,
                      ),
                      iconSize: isApple ? 20 : 24,
                      onPressed: () => _shiftMonth(1),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  compactVnd(total),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Text(
                  'Planned total — not counted in balance',
                  style: TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
        const SliverToBoxAdapter(child: Divider(height: 1)),
        if (items.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  'No planned expenses yet. Add one below, or open a month '
                  'that has items and clone it forward.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.muted),
                ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.only(top: 8, bottom: 96),
            sliver: SliverList.separated(
              itemCount: items.length,
              separatorBuilder: (_, _) =>
                  const Divider(height: 1, indent: 20, endIndent: 20),
              itemBuilder: (context, index) {
                final item = items[index];
                final category = item.categoryId == null
                    ? null
                    : findCategory(categories, item.categoryId!);
                return Dismissible(
                  key: ValueKey(item.id),
                  direction: DismissDirection.endToStart,
                  confirmDismiss: (_) => _confirmDelete(item),
                  onDismissed: (_) => _delete(item),
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    color: const Color(0xFFFDEBEC),
                    child: Icon(
                      isApple ? CupertinoIcons.trash : Icons.delete_outline,
                      size: 20,
                      color: const Color(0xFF9F2F2D),
                    ),
                  ),
                  child: _PlannedExpenseTile(
                    item: item,
                    category: category,
                    onTap: () => _openForm(item: item),
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

class _PlannedExpenseTile extends StatelessWidget {
  const _PlannedExpenseTile({
    required this.item,
    required this.category,
    required this.onTap,
  });

  final PlannedExpense item;
  final Category? category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = CategoryPalette.of(category?.paletteIndex ?? 7);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: palette.background,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                categoryIcon(category?.iconKey ?? 'more_horiz'),
                size: 20,
                color: palette.foreground,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  if (item.note.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        item.note,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              compactVnd(item.amount),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlannedExpenseFormSheet extends ConsumerStatefulWidget {
  const _PlannedExpenseFormSheet({
    required this.year,
    required this.month,
    this.item,
  });

  final int year;
  final int month;
  final PlannedExpense? item;

  @override
  ConsumerState<_PlannedExpenseFormSheet> createState() =>
      _PlannedExpenseFormSheetState();
}

class _PlannedExpenseFormSheetState
    extends ConsumerState<_PlannedExpenseFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _amountController;
  late final TextEditingController _noteController;
  String? _categoryId;

  bool get _isEditing => widget.item != null;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _nameController = TextEditingController(text: item?.name ?? '');
    _amountController = TextEditingController(
      text: item?.amount.toStringAsFixed(0) ?? '',
    );
    _noteController = TextEditingController(text: item?.note ?? '');
    _categoryId = item?.categoryId;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final notifier = ref.read(plannedExpensesProvider.notifier);
    final name = _nameController.text.trim();
    final amount = double.parse(_amountController.text);
    final note = _noteController.text.trim();
    if (_isEditing) {
      await notifier.updateItem(
        widget.item!.id,
        name: name,
        amount: amount,
        categoryId: _categoryId,
        note: note,
      );
    } else {
      await notifier.addItem(
        name: name,
        amount: amount,
        year: widget.year,
        month: widget.month,
        categoryId: _categoryId,
        note: note,
      );
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(
      categoriesByTypeProvider(TransactionType.expense),
    );

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
              _isEditing ? 'Edit planned expense' : 'New planned expense',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Name'),
              textCapitalization: TextCapitalization.sentences,
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'Enter a name'
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Amount (₫)'),
              validator: (value) {
                final parsed = double.tryParse(value ?? '');
                if (parsed == null || parsed <= 0) {
                  return 'Enter a valid amount';
                }
                return null;
              },
            ),
            if (categories.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'CATEGORY (OPTIONAL)',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppColors.muted,
                  letterSpacing: 0.06,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: categories.map((category) {
                  final selected = category.id == _categoryId;
                  final palette = CategoryPalette.of(category.paletteIndex);
                  return ChoiceChip(
                    selected: selected,
                    onSelected: (_) => setState(
                      () => _categoryId = selected ? null : category.id,
                    ),
                    label: Text(category.name),
                    labelStyle: TextStyle(
                      color: selected ? palette.foreground : AppColors.ink,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                    avatar: Icon(
                      categoryIcon(category.iconKey),
                      size: 16,
                      color: palette.foreground,
                    ),
                    selectedColor: palette.background,
                    backgroundColor: AppColors.surface,
                    checkmarkColor: palette.foreground,
                    side: BorderSide(
                      color: selected ? palette.foreground : AppColors.border,
                    ),
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 16),
            TextFormField(
              controller: _noteController,
              decoration: const InputDecoration(labelText: 'Note (optional)'),
            ),
            const SizedBox(height: 24),
            AdaptivePrimaryButton(
              onPressed: _save,
              child: Text(_isEditing ? 'Save changes' : 'Add item'),
            ),
          ],
        ),
      ),
    );
  }
}
