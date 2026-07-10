import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../models/category.dart';
import '../models/transaction.dart';
import '../models/transaction_type.dart';
import '../theme/app_theme.dart';
import '../theme/category_style.dart';
import '../utils/currency_format.dart';
import 'adaptive.dart';

class TransactionTile extends StatelessWidget {
  const TransactionTile({
    super.key,
    required this.transaction,
    required this.category,
    required this.onTap,
    required this.onDismissed,
    this.walletName,
    this.onTogglePlanned,
  });

  final Transaction transaction;
  final Category? category;
  final VoidCallback onTap;
  final VoidCallback onDismissed;

  /// Shown next to the date when the caller is displaying transactions from
  /// more than one wallet; null hides the tag.
  final String? walletName;

  /// When set and the transaction is planned, a checkbox is shown that marks
  /// it paid on tap. Null hides the checkbox.
  final VoidCallback? onTogglePlanned;

  Future<bool> _confirmDelete(BuildContext context) async {
    final sign = transaction.type == TransactionType.income ? '+' : '-';
    final confirmed = await showAdaptiveDialog<bool>(
      context: context,
      builder: (context) => AlertDialog.adaptive(
        title: const Text('Delete transaction?'),
        content: Text(
          'This will permanently delete "${category?.name ?? 'Uncategorized'}" '
          '$sign${compactVnd(transaction.amount)}.',
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

  @override
  Widget build(BuildContext context) {
    final palette = CategoryPalette.of(category?.paletteIndex ?? 7);
    final isIncome = transaction.type == TransactionType.income;
    final amountColor = isIncome ? AppColors.income : AppColors.expense;
    final sign = isIncome ? '+' : '-';
    final isPlanned = transaction.planned;
    final showPlannedCheckbox = isPlanned && onTogglePlanned != null;

    return Dismissible(
      key: ValueKey(transaction.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _confirmDelete(context),
      onDismissed: (_) => onDismissed(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        color: const Color(0xFFFDEBEC),
        child: Icon(
          isApplePlatform(context)
              ? CupertinoIcons.trash
              : Icons.delete_outline,
          size: 20,
          color: const Color(0xFF9F2F2D),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              if (showPlannedCheckbox) ...[
                GestureDetector(
                  onTap: onTogglePlanned,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Icon(
                      isApplePlatform(context)
                          ? CupertinoIcons.circle
                          : Icons.check_box_outline_blank,
                      size: 24,
                      color: AppColors.muted,
                    ),
                  ),
                ),
              ],
              Opacity(
                opacity: isPlanned ? 0.55 : 1,
                child: Container(
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
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            category?.name ?? 'Uncategorized',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isPlanned) ...[
                          const SizedBox(width: 8),
                          const _PlannedPill(),
                        ],
                      ],
                    ),
                    if (transaction.note.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          transaction.note,
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$sign${compactVnd(transaction.amount)}',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: amountColor,
                    ),
                  ),
                  if (walletName != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        walletName!,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                        ),
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

class _PlannedPill extends StatelessWidget {
  const _PlannedPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.border),
      ),
      child: const Text(
        'PLANNED',
        style: TextStyle(
          color: AppColors.muted,
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.06,
        ),
      ),
    );
  }
}
