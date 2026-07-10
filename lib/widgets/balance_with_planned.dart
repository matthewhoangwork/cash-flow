import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/currency_format.dart';

/// The balance amount with an inline "(planned …)" annotation when there are
/// still-unpaid planned transactions. The amount itself already nets out the
/// planned total, so this makes the pending part explicit — e.g.
/// "120.000 ₫ (planned 500.000 ₫)" reads as "120k left once the 500k of
/// planned items are paid". The annotation is hidden when nothing is pending.
class BalanceWithPlanned extends StatelessWidget {
  const BalanceWithPlanned({
    super.key,
    required this.balance,
    required this.planned,
    required this.amountStyle,
    this.plannedStyle,
  });

  final double balance;
  final double planned;
  final TextStyle amountStyle;
  final TextStyle? plannedStyle;

  @override
  Widget build(BuildContext context) {
    if (planned == 0) {
      return Text(vndFormat.format(balance), style: amountStyle);
    }
    final annotationStyle = plannedStyle ??
        const TextStyle(color: AppColors.muted, fontSize: 14, fontWeight: FontWeight.w600);
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: vndFormat.format(balance)),
          TextSpan(
            text: '  (planned ${vndFormat.format(planned)})',
            style: annotationStyle,
          ),
        ],
      ),
      style: amountStyle,
    );
  }
}
