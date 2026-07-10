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

  /// Newest first; a planned transaction with no due date yet sorts above
  /// everything else since it still needs attention.
  List<Transaction> _sorted(List<Transaction> list) {
    list.sort((a, b) {
      if (a.date == null) return b.date == null ? 0 : -1;
      if (b.date == null) return 1;
      return b.date!.compareTo(a.date!);
    });
    return list;
  }

  void _refresh() {
    state = _sorted(ref.read(transactionsBoxProvider).values.toList());
  }

  Future<void> addTransaction({
    required TransactionType type,
    required double amount,
    required String categoryId,
    DateTime? date,
    String note = '',
    required String walletId,
    bool planned = false,
  }) async {
    final transaction = Transaction(
      id: _uuid.v4(),
      type: type,
      amount: amount,
      categoryId: categoryId,
      date: date,
      note: note,
      walletId: walletId,
      planned: planned,
      updatedAt: DateTime.now().toUtc(),
    );
    await ref.read(transactionsBoxProvider).put(transaction.id, transaction);
    _refresh();
    ref.read(syncServiceProvider).schedulePush();
  }

  /// Marks a planned transaction as paid: clears the planned flag and stamps
  /// today's date, so it settles into the list as an actual transaction.
  Future<void> markPaid(String id) async {
    final transaction = ref.read(transactionsBoxProvider).get(id);
    if (transaction == null || !transaction.planned) return;
    transaction.planned = false;
    transaction.date = DateTime.now();
    transaction.updatedAt = DateTime.now().toUtc();
    await transaction.save();
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
