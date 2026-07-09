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

class AddEditTransactionScreen extends ConsumerStatefulWidget {
  const AddEditTransactionScreen({super.key, this.transaction});

  final model.Transaction? transaction;

  @override
  ConsumerState<AddEditTransactionScreen> createState() => _AddEditTransactionScreenState();
}

class _AddEditTransactionScreenState extends ConsumerState<AddEditTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  late TransactionType _type;
  String? _categoryId;
  late String _walletId;
  late DateTime _date;

  bool get _isEditing => widget.transaction != null;

  @override
  void initState() {
    super.initState();
    final transaction = widget.transaction;
    _type = transaction?.type ?? TransactionType.expense;
    _categoryId = transaction?.categoryId;
    _walletId = transaction?.walletId ?? ref.read(defaultWalletProvider).id;
    _date = transaction?.date ?? DateTime.now();
    if (transaction != null) {
      _amountController.text = transaction.amount.toStringAsFixed(0);
      _noteController.text = transaction.note;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _submit() {
    final formValid = _formKey.currentState!.validate();
    if (!formValid || _categoryId == null) {
      if (_categoryId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pick a category')),
        );
      }
      return;
    }

    final amount = double.parse(_amountController.text);
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
      );
    }
    Navigator.of(context).pop();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
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
    final displayedCategories = currentCategory != null &&
            currentCategory.isArchived &&
            !categories.any((c) => c.id == currentCategory.id)
        ? [currentCategory, ...categories]
        : categories;

    final activeWallets = ref.watch(activeWalletsProvider);
    final currentWallet = findWallet(ref.watch(walletsProvider), _walletId);
    final displayedWallets = currentWallet != null &&
            currentWallet.isArchived &&
            !activeWallets.any((w) => w.id == currentWallet.id)
        ? [currentWallet, ...activeWallets]
        : activeWallets;

    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit transaction' : 'Add transaction')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            SegmentedButton<TransactionType>(
              segments: const [
                ButtonSegment(value: TransactionType.expense, label: Text('Expense')),
                ButtonSegment(value: TransactionType.income, label: Text('Income')),
              ],
              selected: {_type},
              onSelectionChanged: (selection) {
                setState(() {
                  _type = selection.first;
                  _categoryId = null;
                });
              },
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Amount (₫)'),
              validator: (value) {
                final parsed = double.tryParse(value ?? '');
                if (parsed == null || parsed <= 0) return 'Enter a valid amount';
                return null;
              },
            ),
            const SizedBox(height: 20),
            Text(
              'CATEGORY',
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(color: AppColors.muted, letterSpacing: 0.06),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: displayedCategories.map((category) {
                final selected = category.id == _categoryId;
                final palette = CategoryPalette.of(category.paletteIndex);
                final label = category.isArchived ? '${category.name} (archived)' : category.name;
                return ChoiceChip(
                  selected: selected,
                  onSelected: (_) => setState(() => _categoryId = category.id),
                  label: Text(label),
                  labelStyle: TextStyle(
                    color: selected ? palette.foreground : AppColors.ink,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                  avatar: Icon(categoryIcon(category.iconKey), size: 16, color: palette.foreground),
                  selectedColor: palette.background,
                  backgroundColor: AppColors.surface,
                  checkmarkColor: palette.foreground,
                  side: BorderSide(color: selected ? palette.foreground : AppColors.border),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            Text(
              'WALLET',
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(color: AppColors.muted, letterSpacing: 0.06),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: displayedWallets.map((wallet) {
                final selected = wallet.id == _walletId;
                final label = wallet.isArchived ? '${wallet.name} (archived)' : wallet.name;
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
                  side: BorderSide(color: selected ? AppColors.ink : AppColors.border),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _noteController,
              decoration: const InputDecoration(labelText: 'Note (optional)'),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Date'),
              subtitle: Text(DateFormat.yMMMd().format(_date)),
              trailing: const Icon(Icons.calendar_today_outlined, size: 18),
              onTap: _pickDate,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _submit,
              child: Text(_isEditing ? 'Save changes' : 'Add transaction'),
            ),
          ],
        ),
      ),
    );
  }
}
