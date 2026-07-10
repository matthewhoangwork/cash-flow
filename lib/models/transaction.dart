import 'package:hive_ce/hive.dart';

import 'transaction_type.dart';

part 'transaction.g.dart';

@HiveType(typeId: 2)
class Transaction extends HiveObject {
  Transaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.categoryId,
    this.date,
    this.note = '',
    required this.walletId,
    this.planned = false,
    this.updatedAt,
  });

  @HiveField(0)
  String id;

  @HiveField(1)
  TransactionType type;

  @HiveField(2)
  double amount;

  @HiveField(3)
  String categoryId;

  /// When to pay/settle. Required for a real (non-[planned]) transaction, but
  /// optional while [planned] is true — a planned item may not have a known
  /// due date yet. Stamped with today's date by [markPaid] on settlement.
  @HiveField(4)
  DateTime? date;

  @HiveField(5)
  String note;

  /// Empty string means "not yet migrated" — transactions written before
  /// wallets existed. main() backfills these to the default wallet at
  /// startup, so app code can treat this as always-populated.
  @HiveField(6, defaultValue: '')
  String walletId;

  /// True while this is a planned ("need to pay") transaction that hasn't been
  /// paid yet. It still counts toward balance and income/expense totals — like
  /// a real transaction — so the wallet reflects money already committed. The
  /// home/wallet lists show a checkbox to mark it paid, which clears this flag.
  @HiveField(8, defaultValue: false)
  bool planned;

  /// Last local modification time, used by the Supabase sync layer for
  /// last-write-wins conflict resolution. Null means never synced.
  @HiveField(7)
  DateTime? updatedAt;
}
