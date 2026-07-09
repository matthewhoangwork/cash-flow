import 'package:intl/intl.dart';

/// Vietnamese dong formatter — no subunit, symbol trails the amount
/// (e.g. "1.234.567 ₫") per vi_VN convention.
final vndFormat = NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);
