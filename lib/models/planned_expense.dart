import 'package:hive_ce/hive.dart';

part 'planned_expense.g.dart';

/// A planned/"need to pay" line item for a given calendar month — e.g. rent,
/// internet, subscriptions. Purely a checklist: it never becomes a
/// [Transaction] and is never counted in balance or income/expense totals.
@HiveType(typeId: 4)
class PlannedExpense extends HiveObject {
  PlannedExpense({
    required this.id,
    required this.name,
    required this.amount,
    required this.year,
    required this.month,
    this.categoryId,
    this.note = '',
    this.updatedAt,
  });

  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  double amount;

  /// Together with [month], scopes this item to one calendar month — lists
  /// start empty for a new month unless cloned from another month.
  @HiveField(3)
  int year;

  @HiveField(4)
  int month;

  @HiveField(5)
  String? categoryId;

  @HiveField(6)
  String note;

  @HiveField(7)
  DateTime? updatedAt;
}
