import 'package:hive_ce/hive.dart';

import 'transaction_type.dart';

part 'category.g.dart';

@HiveType(typeId: 1)
class Category extends HiveObject {
  Category({
    required this.id,
    required this.name,
    required this.type,
    required this.iconKey,
    required this.paletteIndex,
    this.isArchived = false,
    this.updatedAt,
  });

  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  TransactionType type;

  @HiveField(3)
  String iconKey;

  @HiveField(4)
  int paletteIndex;

  /// True once the category is deleted while transactions still reference it —
  /// keeps its name/icon/color resolvable for historical transactions without
  /// letting it be picked for new ones.
  @HiveField(5, defaultValue: false)
  bool isArchived;

  /// Last local modification time, used by the Supabase sync layer for
  /// last-write-wins conflict resolution. Null means never synced.
  @HiveField(6)
  DateTime? updatedAt;
}
