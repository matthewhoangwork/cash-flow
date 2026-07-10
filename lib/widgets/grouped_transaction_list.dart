import 'package:flutter/material.dart';

import '../models/category.dart';
import '../models/transaction.dart';
import '../models/transaction_type.dart';
import '../theme/app_theme.dart';
import '../utils/currency_format.dart';
import '../utils/relative_date.dart';
import 'transaction_tile.dart';

/// Groups the (already date-descending) transaction list by calendar day and
/// renders a relative-date header before each group. The transactions shown
/// are never filtered here — this only changes how the given list is grouped,
/// so both the home page (all wallets) and a single-wallet view can share it.
class GroupedTransactionList extends StatelessWidget {
  const GroupedTransactionList({
    super.key,
    required this.transactions,
    required this.onTap,
    required this.onDismissed,
    required this.findCategory,
    this.findWalletName,
    this.onTogglePlanned,
  });

  final List<Transaction> transactions;
  final void Function(Transaction) onTap;
  final void Function(Transaction) onDismissed;
  final Category? Function(String) findCategory;

  /// Null when there's only one active wallet, so tiles skip the tag.
  final String? Function(String)? findWalletName;

  /// Called when a planned transaction's checkbox is ticked to mark it paid.
  /// Null hides the checkbox (e.g. contexts where paying isn't offered).
  final void Function(Transaction)? onTogglePlanned;

  @override
  Widget build(BuildContext context) {
    final groups = <_DayGroup>[];
    for (final transaction in transactions) {
      final day = DateTime(transaction.date.year, transaction.date.month, transaction.date.day);
      if (groups.isEmpty || groups.last.day != day) {
        groups.add(_DayGroup(day));
      }
      groups.last.transactions.add(transaction);
    }

    final items = <_ListItem>[];
    for (final group in groups) {
      items.add(_ListItem.header(group));
      for (final transaction in group.transactions) {
        items.add(_ListItem.transaction(transaction));
      }
    }

    return SliverPadding(
      padding: const EdgeInsets.only(bottom: 96),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          final item = items[index];
          if (item.header != null) {
            final group = item.header!;
            return Padding(
              padding: EdgeInsets.fromLTRB(20, index == 0 ? 8 : 20, 20, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    relativeDayLabel(group.day),
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.04,
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        '+${vndFormat.format(group.income)}',
                        style: TextStyle(
                          color: group.income > 0 ? AppColors.income : AppColors.muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '-${vndFormat.format(group.expense)}',
                        style: TextStyle(
                          color: group.expense > 0 ? AppColors.expense : AppColors.muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }
          final transaction = item.transaction!;
          return TransactionTile(
            transaction: transaction,
            category: findCategory(transaction.categoryId),
            walletName: findWalletName?.call(transaction.walletId),
            onTap: () => onTap(transaction),
            onDismissed: () => onDismissed(transaction),
            onTogglePlanned:
                onTogglePlanned == null ? null : () => onTogglePlanned!(transaction),
          );
        }, childCount: items.length),
      ),
    );
  }
}

class _DayGroup {
  _DayGroup(this.day);

  final DateTime day;
  final List<Transaction> transactions = [];

  double get income => transactions
      .where((t) => t.type == TransactionType.income)
      .fold(0.0, (sum, t) => sum + t.amount);

  double get expense => transactions
      .where((t) => t.type == TransactionType.expense)
      .fold(0.0, (sum, t) => sum + t.amount);
}

class _ListItem {
  const _ListItem._({this.header, this.transaction});
  factory _ListItem.header(_DayGroup group) => _ListItem._(header: group);
  factory _ListItem.transaction(Transaction transaction) => _ListItem._(transaction: transaction);

  final _DayGroup? header;
  final Transaction? transaction;
}
