import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/transaction.dart';
import '../models/transaction_type.dart';
import '../sync/sync_service.dart';
import 'hive_providers.dart';

const _uuid = Uuid();

class TransactionsNotifier extends Notifier<List<Transaction>> {
  @override
  List<Transaction> build() => _sorted(ref.read(transactionsBoxProvider).values.toList());

  List<Transaction> _sorted(List<Transaction> list) {
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  void _refresh() {
    state = _sorted(ref.read(transactionsBoxProvider).values.toList());
  }

  Future<void> addTransaction({
    required TransactionType type,
    required double amount,
    required String categoryId,
    required DateTime date,
    String note = '',
    required String walletId,
  }) async {
    final transaction = Transaction(
      id: _uuid.v4(),
      type: type,
      amount: amount,
      categoryId: categoryId,
      date: date,
      note: note,
      walletId: walletId,
      updatedAt: DateTime.now().toUtc(),
    );
    await ref.read(transactionsBoxProvider).put(transaction.id, transaction);
    _refresh();
    ref.read(syncServiceProvider).schedulePush();
  }

  Future<void> updateTransaction(Transaction transaction) async {
    transaction.updatedAt = DateTime.now().toUtc();
    await ref.read(transactionsBoxProvider).put(transaction.id, transaction);
    _refresh();
    ref.read(syncServiceProvider).schedulePush();
  }

  Future<void> deleteTransaction(String id) async {
    await ref.read(syncServiceProvider).recordDelete('transactions', id);
    await ref.read(transactionsBoxProvider).delete(id);
    _refresh();
  }
}

final transactionsProvider =
    NotifierProvider<TransactionsNotifier, List<Transaction>>(TransactionsNotifier.new);
