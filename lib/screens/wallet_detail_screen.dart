import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/transaction.dart';
import '../providers/categories_provider.dart';
import '../providers/summary_providers.dart';
import '../providers/transactions_provider.dart';
import '../providers/wallets_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/adaptive.dart';
import '../widgets/balance_with_planned.dart';
import '../widgets/glass.dart';
import '../widgets/grouped_transaction_list.dart';
import 'add_edit_transaction_screen.dart';

/// A single wallet's balance plus its own transactions, grouped by date.
/// Reached by tapping a wallet on the Wallets page.
class WalletDetailScreen extends ConsumerStatefulWidget {
  const WalletDetailScreen({super.key, required this.walletId});

  final String walletId;

  @override
  ConsumerState<WalletDetailScreen> createState() => _WalletDetailScreenState();
}

class _WalletDetailScreenState extends ConsumerState<WalletDetailScreen> {
  bool _selecting = false;
  final Set<String> _selectedIds = {};

  void _toggleSelected(Transaction transaction) {
    setState(() {
      if (!_selectedIds.remove(transaction.id)) {
        _selectedIds.add(transaction.id);
      }
    });
  }

  void _cancelSelection() {
    setState(() {
      _selecting = false;
      _selectedIds.clear();
    });
  }

  Future<void> _confirmBulkDelete() async {
    final count = _selectedIds.length;
    final confirmed = await showAdaptiveDialog<bool>(
      context: context,
      builder: (context) => AlertDialog.adaptive(
        title: Text('Delete $count transaction${count == 1 ? '' : 's'}?'),
        content: const Text(
          'This will permanently delete the selected transactions.',
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
    await ref.read(transactionsProvider.notifier).deleteTransactions(_selectedIds);
    if (!mounted) return;
    _cancelSelection();
  }

  @override
  Widget build(BuildContext context) {
    final walletId = widget.walletId;
    final wallet = findWallet(ref.watch(walletsProvider), walletId);
    final categories = ref.watch(categoriesProvider);
    final balance = ref.watch(walletBalanceProvider(walletId));
    final plannedOutstanding = ref.watch(walletPlannedOutstandingProvider(walletId));
    final transactions =
        ref.watch(transactionsProvider).where((t) => t.walletId == walletId).toList();

    return AdaptiveSliverScaffold(
      title: wallet?.name ?? 'Wallet',
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
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: SurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'BALANCE',
                    style: TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.06,
                    ),
                  ),
                  const SizedBox(height: 6),
                  BalanceWithPlanned(
                    balance: balance,
                    planned: plannedOutstanding,
                    amountStyle: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.02,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SliverToBoxAdapter(child: Divider(height: 1)),
        if (transactions.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Text('No transactions yet', style: TextStyle(color: AppColors.muted)),
            ),
          )
        else
          GroupedTransactionList(
            transactions: transactions,
            onTap: (transaction) => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => AddEditTransactionScreen(transaction: transaction),
              ),
            ),
            onDismissed: (transaction) =>
                ref.read(transactionsProvider.notifier).deleteTransaction(transaction.id),
            onTogglePlanned: (transaction) =>
                ref.read(transactionsProvider.notifier).markPaid(transaction.id),
            findCategory: (categoryId) => findCategory(categories, categoryId),
            selecting: _selecting,
            selectedIds: _selectedIds,
            onToggleSelected: _toggleSelected,
          ),
      ],
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => AddEditTransactionScreen(initialWalletId: walletId),
          ),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }
}
