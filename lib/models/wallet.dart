import 'package:hive_ce/hive.dart';

part 'wallet.g.dart';

@HiveType(typeId: 3)
class Wallet extends HiveObject {
  Wallet({
    required this.id,
    required this.name,
    this.isDefault = false,
    this.isArchived = false,
    this.updatedAt,
  });

  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  bool isDefault;

  /// True once the wallet is deleted while transactions still reference it —
  /// keeps its name resolvable for historical transactions without letting
  /// it be picked for new ones. Mirrors Category.isArchived.
  @HiveField(3, defaultValue: false)
  bool isArchived;

  /// Last local modification time, used by the Supabase sync layer for
  /// last-write-wins conflict resolution. Null means never synced.
  @HiveField(4)
  DateTime? updatedAt;
}
