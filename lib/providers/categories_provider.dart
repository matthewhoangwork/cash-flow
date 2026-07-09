import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/category.dart';
import '../models/transaction_type.dart';
import '../sync/sync_service.dart';
import 'hive_providers.dart';

const _uuid = Uuid();

class CategoriesNotifier extends Notifier<List<Category>> {
  @override
  List<Category> build() => ref.read(categoriesBoxProvider).values.toList();

  void _refresh() {
    state = ref.read(categoriesBoxProvider).values.toList();
  }

  Future<void> addCategory({
    required String name,
    required TransactionType type,
    required String iconKey,
    required int paletteIndex,
  }) async {
    final category = Category(
      id: _uuid.v4(),
      name: name,
      type: type,
      iconKey: iconKey,
      paletteIndex: paletteIndex,
      updatedAt: DateTime.now().toUtc(),
    );
    await ref.read(categoriesBoxProvider).put(category.id, category);
    _refresh();
    ref.read(syncServiceProvider).schedulePush();
  }

  Future<void> updateCategory(
    String id, {
    required String name,
    required String iconKey,
    required int paletteIndex,
  }) async {
    final category = ref.read(categoriesBoxProvider).get(id);
    if (category == null) return;
    category
      ..name = name
      ..iconKey = iconKey
      ..paletteIndex = paletteIndex
      ..updatedAt = DateTime.now().toUtc();
    await category.save();
    _refresh();
    ref.read(syncServiceProvider).schedulePush();
  }

  /// Categories still referenced by a transaction are archived instead of
  /// removed, so those transactions keep showing the original name/icon/color.
  /// Unused categories are deleted outright.
  Future<void> deleteCategory(String id) async {
    final categoriesBox = ref.read(categoriesBoxProvider);
    final inUse = ref.read(transactionsBoxProvider).values.any((t) => t.categoryId == id);
    if (inUse) {
      final category = categoriesBox.get(id);
      if (category == null) return;
      category.isArchived = true;
      category.updatedAt = DateTime.now().toUtc();
      await category.save();
      ref.read(syncServiceProvider).schedulePush();
    } else {
      await ref.read(syncServiceProvider).recordDelete('categories', id);
      await categoriesBox.delete(id);
    }
    _refresh();
  }
}

final categoriesProvider =
    NotifierProvider<CategoriesNotifier, List<Category>>(CategoriesNotifier.new);

final categoriesByTypeProvider = Provider.family<List<Category>, TransactionType>((ref, type) {
  return ref.watch(categoriesProvider).where((c) => c.type == type && !c.isArchived).toList();
});

Category? findCategory(List<Category> categories, String id) {
  final matches = categories.where((c) => c.id == id);
  return matches.isEmpty ? null : matches.first;
}
