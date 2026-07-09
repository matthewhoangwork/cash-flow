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
    required this.date,
    this.note = '',
    required this.walletId,
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

  @HiveField(4)
  DateTime date;

  @HiveField(5)
  String note;

  /// Empty string means "not yet migrated" — transactions written before
  /// wallets existed. main() backfills these to the default wallet at
  /// startup, so app code can treat this as always-populated.
  @HiveField(6, defaultValue: '')
  String walletId;

  /// Last local modification time, used by the Supabase sync layer for
  /// last-write-wins conflict resolution. Null means never synced.
  @HiveField(7)
  DateTime? updatedAt;
}
