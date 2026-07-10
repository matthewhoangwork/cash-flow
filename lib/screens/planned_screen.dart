import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/category.dart';
import '../models/transaction.dart';
import '../models/transaction_type.dart';
import '../models/wallet.dart';
import '../providers/categories_provider.dart';
import '../providers/transactions_provider.dart';
import '../providers/wallets_provider.dart';
import '../theme/app_theme.dart';
import '../utils/currency_format.dart';
import '../widgets/adaptive.dart';
import '../widgets/transaction_tile.dart';
import 'add_edit_transaction_screen.dart';

/// All planned ("need to pay") transactions — the same ones toggled from the
/// transaction form's "Planned" switch. Ones with a due date are shown under
/// the month they're due in; ones without a due date yet show under "No due
/// date" regardless of which month is selected, since there's nothing to
/// place them by until a date is set.
class PlannedScreen extends ConsumerStatefulWidget {
  const PlannedScreen({super.key});

  @override
  ConsumerState<PlannedScreen> createState() => _PlannedScreenState();
}

class _PlannedScreenState extends ConsumerState<PlannedScreen> {
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

  @override
  Widget build(BuildContext context) {
    final planned = ref.watch(transactionsProvider).where((t) => t.planned).toList();
    final noDateItems = planned.where((t) => t.date == null).toList();
    final monthItems = planned
        .where((t) => t.date != null && t.date!.year == _year && t.date!.month == _month)
        .toList();
    final categories = ref.watch(categoriesProvider);
    final wallets = ref.watch(walletsProvider);
    final showWalletTag = ref.watch(activeWalletsProvider).length > 1;

    final visible = [...noDateItems, ...monthItems];
    final total = visible.fold<double>(
      0,
      (sum, t) => sum + (t.type == TransactionType.expense ? t.amount : -t.amount),
    );
    final monthLabel = DateFormat.yMMMM().format(DateTime(_year, _month));
    final isApple = isApplePlatform(context);

    return AdaptiveSliverScaffold(
      title: 'Planned',
      largeTitle: false,
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
                        isApple ? CupertinoIcons.chevron_left : Icons.chevron_left,
                      ),
                      iconSize: isApple ? 20 : 24,
                      onPressed: () => _shiftMonth(-1),
                    ),
                    SizedBox(
                      width: 160,
                      child: Text(
                        monthLabel,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        isApple ? CupertinoIcons.chevron_right : Icons.chevron_right,
                      ),
                      iconSize: isApple ? 20 : 24,
                      onPressed: () => _shiftMonth(1),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  compactVnd(total),
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                ),
                const Text(
                  'Planned total — still counts toward your balance',
                  style: TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
        const SliverToBoxAdapter(child: Divider(height: 1)),
        if (visible.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  'No planned transactions for this month. Add one below, or toggle '
                  '"Planned" when adding a transaction.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.muted),
                ),
              ),
            ),
          )
        else ...[
          if (noDateItems.isNotEmpty)
            _PlannedSection(
              label: 'No due date',
              items: noDateItems,
              categories: categories,
              wallets: wallets,
              showWalletTag: showWalletTag,
            ),
          if (monthItems.isNotEmpty)
            _PlannedSection(
              label: monthLabel,
              items: monthItems,
              categories: categories,
              wallets: wallets,
              showWalletTag: showWalletTag,
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 96)),
        ],
      ],
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const AddEditTransactionScreen(initialPlanned: true),
          ),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _PlannedSection extends ConsumerWidget {
  const _PlannedSection({
    required this.label,
    required this.items,
    required this.categories,
    required this.wallets,
    required this.showWalletTag,
  });

  final String label;
  final List<Transaction> items;
  final List<Category> categories;
  final List<Wallet> wallets;
  final bool showWalletTag;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.04,
              ),
            ),
          ),
        ),
        SliverList.separated(
          itemCount: items.length,
          separatorBuilder: (_, _) => const Divider(height: 1, indent: 20, endIndent: 20),
          itemBuilder: (context, index) {
            final transaction = items[index];
            return TransactionTile(
              transaction: transaction,
              category: findCategory(categories, transaction.categoryId),
              walletName: showWalletTag ? findWallet(wallets, transaction.walletId)?.name : null,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => AddEditTransactionScreen(transaction: transaction),
                ),
              ),
              onDismissed: () =>
                  ref.read(transactionsProvider.notifier).deleteTransaction(transaction.id),
              onTogglePlanned: () =>
                  ref.read(transactionsProvider.notifier).markPaid(transaction.id),
            );
          },
        ),
      ],
    );
  }
}
