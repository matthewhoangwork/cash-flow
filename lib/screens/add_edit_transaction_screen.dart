import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/transaction.dart' as model;
import '../models/transaction_type.dart';
import '../providers/categories_provider.dart';
import '../providers/transactions_provider.dart';
import '../providers/wallets_provider.dart';
import '../theme/app_theme.dart';
import '../theme/category_style.dart';
import '../utils/currency_format.dart';
import '../widgets/adaptive.dart';
import '../widgets/glass.dart';

class AddEditTransactionScreen extends ConsumerStatefulWidget {
  const AddEditTransactionScreen({
    super.key,
    this.transaction,
    this.initialWalletId,
    this.initialPlanned = false,
  });

  final model.Transaction? transaction;

  /// Pre-selects this wallet when adding a new transaction (e.g. opened from a
  /// wallet's detail page). Ignored when editing an existing transaction.
  final String? initialWalletId;

  /// Pre-checks "Planned" when adding a new transaction (e.g. opened from the
  /// Planned page). Ignored when editing an existing transaction.
  final bool initialPlanned;

  @override
  ConsumerState<AddEditTransactionScreen> createState() =>
      _AddEditTransactionScreenState();
}

class _AddEditTransactionScreenState
    extends ConsumerState<AddEditTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  late TransactionType _type;
  String? _categoryId;
  late String _walletId;
  DateTime? _date;
  late bool _planned;

  bool get _isEditing => widget.transaction != null;

  @override
  void initState() {
    super.initState();
    final transaction = widget.transaction;
    _type = transaction?.type ?? TransactionType.expense;
    _categoryId = transaction?.categoryId;
    _walletId =
        transaction?.walletId ?? widget.initialWalletId ?? ref.read(defaultWalletProvider).id;
    _planned = transaction?.planned ?? widget.initialPlanned;
    // A real (non-planned) transaction always needs a date; a planned one
    // may not have a due date yet, so leave it unset for a fresh planned add.
    _date = transaction != null ? transaction.date : (_planned ? null : DateTime.now());
    if (transaction != null) {
      _amountController.text = _amountToThousands(transaction.amount);
      _noteController.text = transaction.note;
    }
  }

  /// The amount field is entered in thousands (type 164 → 164.000 ₫), so map a
  /// stored amount back to that unit, trimming a redundant trailing ".0".
  String _amountToThousands(double amount) {
    final thousands = amount / 1000;
    return thousands == thousands.roundToDouble()
        ? thousands.toStringAsFixed(0)
        : thousands.toString();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _submit() {
    final formValid = _formKey.currentState!.validate();
    if (!formValid || _categoryId == null || (!_planned && _date == null)) {
      if (_categoryId == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Pick a category')));
      } else if (!_planned && _date == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Pick a date')));
      }
      return;
    }

    // Field is in thousands (164 → 164.000 ₫), so scale back to full dong.
    final amount = double.parse(_amountController.text) * 1000;
    final notifier = ref.read(transactionsProvider.notifier);

    if (_isEditing) {
      notifier.updateTransaction(
        model.Transaction(
          id: widget.transaction!.id,
          type: _type,
          amount: amount,
          categoryId: _categoryId!,
          date: _date,
          note: _noteController.text.trim(),
          walletId: _walletId,
          planned: _planned,
        ),
      );
    } else {
      notifier.addTransaction(
        type: _type,
        amount: amount,
        categoryId: _categoryId!,
        date: _date,
        note: _noteController.text.trim(),
        walletId: _walletId,
        planned: _planned,
      );
    }
    Navigator.of(context).pop();
  }

  Future<void> _pickDate() async {
    final picked = await showAdaptiveDatePicker(
      context: context,
      initialDate: _date ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesByTypeProvider(_type));
    // Archived categories are hidden from picking, but if this transaction
    // already uses one, keep showing it so editing doesn't look uncategorized.
    final currentCategory = _categoryId == null
        ? null
        : findCategory(ref.watch(categoriesProvider), _categoryId!);
    final displayedCategories =
        currentCategory != null &&
            currentCategory.isArchived &&
            !categories.any((c) => c.id == currentCategory.id)
        ? [currentCategory, ...categories]
        : categories;

    // Live preview of the thousands input as a full compact figure ("= 164k").
    final enteredThousands = double.tryParse(_amountController.text);
    final amountHint = (enteredThousands == null || enteredThousands <= 0)
        ? null
        : '= ${compactVnd(enteredThousands * 1000)}';

    final activeWallets = ref.watch(activeWalletsProvider);
    final currentWallet = findWallet(ref.watch(walletsProvider), _walletId);
    final displayedWallets =
        currentWallet != null &&
            currentWallet.isArchived &&
            !activeWallets.any((w) => w.id == currentWallet.id)
        ? [currentWallet, ...activeWallets]
        : activeWallets;

    return Form(
      key: _formKey,
      child: AdaptiveSliverScaffold(
        title: _isEditing ? 'Edit transaction' : 'Add transaction',
        largeTitle: false,
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            sliver: SliverList.list(
              children: [
                AdaptiveSegmentedControl<TransactionType>(
                  segments: const [
                    (TransactionType.expense, 'Expense'),
                    (TransactionType.income, 'Income'),
                  ],
                  value: _type,
                  onChanged: (selected) {
                    setState(() {
                      _type = selected;
                      _categoryId = null;
                    });
                  },
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Amount (thousands ₫)',
                    helperText: amountHint,
                    suffixText: 'k',
                  ),
                  onChanged: (_) => setState(() {}),
                  validator: (value) {
                    final parsed = double.tryParse(value ?? '');
                    if (parsed == null || parsed <= 0) {
                      return 'Enter a valid amount';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                Text(
                  'CATEGORY',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppColors.muted,
                    letterSpacing: 0.06,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: displayedCategories.map((category) {
                    final selected = category.id == _categoryId;
                    final palette = CategoryPalette.of(category.paletteIndex);
                    final label = category.isArchived
                        ? '${category.name} (archived)'
                        : category.name;
                    return ChoiceChip(
                      selected: selected,
                      onSelected: (_) =>
                          setState(() => _categoryId = category.id),
                      label: Text(label),
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
                const SizedBox(height: 20),
                Text(
                  'WALLET',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppColors.muted,
                    letterSpacing: 0.06,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: displayedWallets.map((wallet) {
                    final selected = wallet.id == _walletId;
                    final label = wallet.isArchived
                        ? '${wallet.name} (archived)'
                        : wallet.name;
                    return ChoiceChip(
                      selected: selected,
                      onSelected: (_) => setState(() => _walletId = wallet.id),
                      label: Text(label),
                      labelStyle: TextStyle(
                        color: selected ? Colors.white : AppColors.ink,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                      selectedColor: AppColors.ink,
                      backgroundColor: AppColors.surface,
                      checkmarkColor: Colors.white,
                      side: BorderSide(
                        color: selected ? AppColors.ink : AppColors.border,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _noteController,
                  decoration: const InputDecoration(
                    labelText: 'Note (optional)',
                  ),
                ),
                const SizedBox(height: 12),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Planned (not paid yet)'),
                  subtitle: const Text(
                    'Still counts against your balance until you mark it paid.',
                  ),
                  value: _planned,
                  onChanged: (value) => setState(() {
                    _planned = value;
                    // A real transaction always needs a date.
                    if (!value && _date == null) _date = DateTime.now();
                  }),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(_planned ? 'Due date (optional)' : 'Date'),
                  subtitle: Text(
                    _date == null ? 'No due date set' : DateFormat.yMMMd().format(_date!),
                  ),
                  trailing: _planned && _date != null
                      ? IconButton(
                          icon: Icon(
                            isApplePlatform(context)
                                ? CupertinoIcons.clear_circled
                                : Icons.clear,
                            size: 18,
                          ),
                          tooltip: 'Clear date',
                          onPressed: () => setState(() => _date = null),
                        )
                      : Icon(
                          isApplePlatform(context)
                              ? CupertinoIcons.calendar
                              : Icons.calendar_today_outlined,
                          size: 18,
                        ),
                  onTap: _pickDate,
                ),
                const SizedBox(height: 24),
                AdaptivePrimaryButton(
                  onPressed: _submit,
                  child: Text(_isEditing ? 'Save changes' : 'Add transaction'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
