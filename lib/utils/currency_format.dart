import 'package:intl/intl.dart';

/// Vietnamese dong formatter — no subunit, symbol trails the amount
/// (e.g. "1.234.567 ₫") per vi_VN convention. Kept for the few places that
/// still need the full, exact figure.
final vndFormat = NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);

/// Compact amount display: 164.000 → "164k", 1.500.000 → "1.5M",
/// 2.000.000.000 → "2B". Up to one decimal, trailing ".0" trimmed.
/// The sign is preserved so callers can prefix "+"/"-" as before.
String compactVnd(num value) {
  final negative = value < 0;
  final abs = value.abs();

  String body;
  if (abs >= 1000000000) {
    body = '${_trim(abs / 1000000000)}B';
  } else if (abs >= 1000000) {
    body = '${_trim(abs / 1000000)}M';
  } else if (abs >= 1000) {
    body = '${_trim(abs / 1000)}k';
  } else {
    body = abs.toStringAsFixed(0);
  }

  return negative ? '-$body' : body;
}

String _trim(num value) {
  final text = value.toStringAsFixed(1);
  return text.endsWith('.0') ? text.substring(0, text.length - 2) : text;
}
