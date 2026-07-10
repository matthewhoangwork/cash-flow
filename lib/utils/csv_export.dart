import 'package:intl/intl.dart';

import '../models/category.dart';
import '../models/transaction.dart';
import '../models/transaction_type.dart';
import '../models/wallet.dart';
import '../providers/categories_provider.dart';
import '../providers/wallets_provider.dart';

final _dateFormat = DateFormat('yyyy-MM-dd');

const _csvHeader = ['Date', 'Type', 'Category', 'Amount', 'Wallet', 'Note', 'Planned'];

/// Renders transactions as CSV text (oldest first), resolving category and
/// wallet names so the export reads standalone without needing the app's ids.
String transactionsToCsv(
  List<Transaction> transactions, {
  required List<Category> categories,
  required List<Wallet> wallets,
}) {
  final sorted = transactions.toList()..sort((a, b) => a.date.compareTo(b.date));
  final buffer = StringBuffer()..writeln(_csvRow(_csvHeader));
  for (final transaction in sorted) {
    buffer.writeln(
      _csvRow([
        _dateFormat.format(transaction.date),
        transaction.type == TransactionType.income ? 'Income' : 'Expense',
        findCategory(categories, transaction.categoryId)?.name ?? '',
        transaction.amount.round().toString(),
        findWallet(wallets, transaction.walletId)?.name ?? '',
        transaction.note,
        transaction.planned ? 'Yes' : 'No',
      ]),
    );
  }
  return buffer.toString();
}

String _csvRow(List<String> fields) => fields.map(_csvField).join(',');

String _csvField(String field) {
  if (field.contains(',') || field.contains('"') || field.contains('\n') || field.contains('\r')) {
    return '"${field.replaceAll('"', '""')}"';
  }
  return field;
}
