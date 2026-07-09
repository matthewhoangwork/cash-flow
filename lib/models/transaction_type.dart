import 'package:hive_ce/hive.dart';

part 'transaction_type.g.dart';

@HiveType(typeId: 0)
enum TransactionType {
  @HiveField(0)
  income,
  @HiveField(1)
  expense,
}
