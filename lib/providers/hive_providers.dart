import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive.dart';

import '../models/category.dart';
import '../models/planned_expense.dart';
import '../models/transaction.dart';
import '../models/wallet.dart';

/// Overridden in main() with the boxes opened before runApp().
final categoriesBoxProvider = Provider<Box<Category>>((ref) {
  throw UnimplementedError('categoriesBoxProvider must be overridden in main()');
});

final transactionsBoxProvider = Provider<Box<Transaction>>((ref) {
  throw UnimplementedError('transactionsBoxProvider must be overridden in main()');
});

final walletsBoxProvider = Provider<Box<Wallet>>((ref) {
  throw UnimplementedError('walletsBoxProvider must be overridden in main()');
});

final plannedExpensesBoxProvider = Provider<Box<PlannedExpense>>((ref) {
  throw UnimplementedError('plannedExpensesBoxProvider must be overridden in main()');
});
