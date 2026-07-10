import '../models/category.dart';
import '../models/planned_expense.dart';
import '../models/transaction.dart';
import '../models/transaction_type.dart';
import '../models/wallet.dart';

Map<String, dynamic> walletToRow(Wallet wallet, String userId) => {
  'id': wallet.id,
  'user_id': userId,
  'name': wallet.name,
  'is_default': wallet.isDefault,
  'is_archived': wallet.isArchived,
  'updated_at': wallet.updatedAt!.toIso8601String(),
};

Wallet walletFromRow(Map<String, dynamic> row) => Wallet(
  id: row['id'] as String,
  name: row['name'] as String,
  isDefault: row['is_default'] as bool,
  isArchived: row['is_archived'] as bool,
  updatedAt: DateTime.parse(row['updated_at'] as String),
);

Map<String, dynamic> categoryToRow(Category category, String userId) => {
  'id': category.id,
  'user_id': userId,
  'name': category.name,
  'type': category.type.name,
  'icon_key': category.iconKey,
  'palette_index': category.paletteIndex,
  'is_archived': category.isArchived,
  'updated_at': category.updatedAt!.toIso8601String(),
};

Category categoryFromRow(Map<String, dynamic> row) => Category(
  id: row['id'] as String,
  name: row['name'] as String,
  type: TransactionType.values.byName(row['type'] as String),
  iconKey: row['icon_key'] as String,
  paletteIndex: row['palette_index'] as int,
  isArchived: row['is_archived'] as bool,
  updatedAt: DateTime.parse(row['updated_at'] as String),
);

Map<String, dynamic> transactionToRow(Transaction transaction, String userId) => {
  'id': transaction.id,
  'user_id': userId,
  'type': transaction.type.name,
  'amount': transaction.amount,
  'category_id': transaction.categoryId,
  'wallet_id': transaction.walletId,
  'date': transaction.date.toIso8601String(),
  'note': transaction.note,
  'planned': transaction.planned,
  'updated_at': transaction.updatedAt!.toIso8601String(),
};

Transaction transactionFromRow(Map<String, dynamic> row) => Transaction(
  id: row['id'] as String,
  type: TransactionType.values.byName(row['type'] as String),
  amount: (row['amount'] as num).toDouble(),
  categoryId: row['category_id'] as String,
  date: DateTime.parse(row['date'] as String),
  note: row['note'] as String,
  walletId: row['wallet_id'] as String,
  planned: (row['planned'] as bool?) ?? false,
  updatedAt: DateTime.parse(row['updated_at'] as String),
);

Map<String, dynamic> plannedExpenseToRow(PlannedExpense item, String userId) => {
  'id': item.id,
  'user_id': userId,
  'name': item.name,
  'amount': item.amount,
  'year': item.year,
  'month': item.month,
  'category_id': item.categoryId,
  'note': item.note,
  'updated_at': item.updatedAt!.toIso8601String(),
};

PlannedExpense plannedExpenseFromRow(Map<String, dynamic> row) => PlannedExpense(
  id: row['id'] as String,
  name: row['name'] as String,
  amount: (row['amount'] as num).toDouble(),
  year: row['year'] as int,
  month: row['month'] as int,
  categoryId: row['category_id'] as String?,
  note: row['note'] as String,
  updatedAt: DateTime.parse(row['updated_at'] as String),
);
