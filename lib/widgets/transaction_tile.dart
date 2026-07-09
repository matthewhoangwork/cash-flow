import 'package:flutter/material.dart';

import '../models/category.dart';
import '../models/transaction.dart';
import '../models/transaction_type.dart';
import '../theme/app_theme.dart';
import '../theme/category_style.dart';
import '../utils/currency_format.dart';

class TransactionTile extends StatelessWidget {
  const TransactionTile({
    super.key,
    required this.transaction,
    required this.category,
    required this.onTap,
    required this.onDismissed,
    this.walletName,
  });

  final Transaction transaction;
  final Category? category;
  final VoidCallback onTap;
  final VoidCallback onDismissed;

  /// Shown next to the date when the caller is displaying transactions from
  /// more than one wallet; null hides the tag.
  final String? walletName;

  @override
  Widget build(BuildContext context) {
    final palette = CategoryPalette.of(category?.paletteIndex ?? 7);
    final isIncome = transaction.type == TransactionType.income;
    final amountColor = isIncome ? AppColors.income : AppColors.expense;
    final sign = isIncome ? '+' : '-';

    return Dismissible(
      key: ValueKey(transaction.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDismissed(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        color: const Color(0xFFFDEBEC),
        child: const Icon(Icons.delete_outline, color: Color(0xFF9F2F2D)),
      ),
      child: InkWell(
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
                    if (transaction.note.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          transaction.note,
                          style: const TextStyle(color: AppColors.muted, fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$sign${vndFormat.format(transaction.amount)}',
                    style: TextStyle(fontWeight: FontWeight.w700, color: amountColor),
                  ),
                  if (walletName != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        walletName!,
                        style: const TextStyle(color: AppColors.muted, fontSize: 12),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
