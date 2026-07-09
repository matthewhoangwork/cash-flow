import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/category.dart';
import '../models/transaction.dart';
import '../models/transaction_type.dart';
import '../providers/categories_provider.dart';
import '../providers/transactions_provider.dart';
import '../providers/wallets_provider.dart';
import '../theme/app_theme.dart';
import '../theme/category_style.dart';
import '../utils/currency_format.dart';
import 'add_edit_transaction_screen.dart';

/// Shows every expense logged in a given month ("Danh sách cần chi mỗi
/// tháng") with a per-item Clone action that re-logs a recurring expense
/// (same amount/category/wallet/note, dated today) without retyping it.
class MonthlyExpensesScreen extends ConsumerStatefulWidget {
  const MonthlyExpensesScreen({super.key});

  @override
  ConsumerState<MonthlyExpensesScreen> createState() => _MonthlyExpensesScreenState();
}

class _MonthlyExpensesScreenState extends ConsumerState<MonthlyExpensesScreen> {
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
  }

  void _shiftMonth(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta));
  }

  void _clone(Transaction transaction) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AddEditTransactionScreen(cloneFrom: transaction)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final transactions = ref.watch(transactionsProvider);
    final categories = ref.watch(categoriesProvider);
    final wallets = ref.watch(walletsProvider);
    final showWalletTag = ref.watch(activeWalletsProvider).length > 1;

    final expenses = transactions
        .where((t) =>
            t.type == TransactionType.expense &&
            t.date.year == _month.year &&
            t.date.month == _month.month)
        .toList();
    final total = expenses.fold<double>(0, (sum, t) => sum + t.amount);

    return Scaffold(
      appBar: AppBar(title: const Text('Monthly expenses')),
      body: Column(
        children: [
          _MonthHeader(month: _month, total: total, onPrevious: () => _shiftMonth(-1),
              onNext: () => _shiftMonth(1)),
          const Divider(height: 1),
          Expanded(
            child: expenses.isEmpty
                ? const Center(
                    child: Text('No expenses this month', style: TextStyle(color: AppColors.muted)),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: expenses.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1, indent: 20, endIndent: 20),
                    itemBuilder: (context, index) {
                      final transaction = expenses[index];
                      return _MonthlyExpenseTile(
                        transaction: transaction,
                        category: findCategory(categories, transaction.categoryId),
                        walletName:
                            showWalletTag ? findWallet(wallets, transaction.walletId)?.name : null,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => AddEditTransactionScreen(transaction: transaction),
                          ),
                        ),
                        onClone: () => _clone(transaction),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _MonthHeader extends StatelessWidget {
  const _MonthHeader({
    required this.month,
    required this.total,
    required this.onPrevious,
    required this.onNext,
  });

  final DateTime month;
  final double total;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(icon: const Icon(Icons.chevron_left), onPressed: onPrevious),
              SizedBox(
                width: 160,
                child: Text(
                  DateFormat.yMMMM().format(month),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(icon: const Icon(Icons.chevron_right), onPressed: onNext),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            vndFormat.format(total),
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.expense),
          ),
          const Text('Total expenses', style: TextStyle(color: AppColors.muted, fontSize: 12)),
        ],
      ),
    );
  }
}

class _MonthlyExpenseTile extends StatelessWidget {
  const _MonthlyExpenseTile({
    required this.transaction,
    required this.category,
    required this.onTap,
    required this.onClone,
    this.walletName,
  });

  final Transaction transaction;
  final Category? category;
  final VoidCallback onTap;
  final VoidCallback onClone;
  final String? walletName;

  @override
  Widget build(BuildContext context) {
    final palette = CategoryPalette.of(category?.paletteIndex ?? 7);
    final subtitle = [
      DateFormat.MMMd().format(transaction.date),
      if (walletName != null) walletName!,
      if (transaction.note.isNotEmpty) transaction.note,
    ].join(' · ');

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
                    category?.name ?? 'Uncategorized',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(color: AppColors.muted, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '-${vndFormat.format(transaction.amount)}',
              style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.expense),
            ),
            IconButton(
              icon: const Icon(Icons.copy_outlined, size: 18, color: AppColors.muted),
              tooltip: 'Clone',
              onPressed: onClone,
            ),
          ],
        ),
      ),
    );
  }
}
