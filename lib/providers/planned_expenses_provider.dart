import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/planned_expense.dart';
import 'hive_providers.dart';

const _uuid = Uuid();

class PlannedExpensesNotifier extends Notifier<List<PlannedExpense>> {
  @override
  List<PlannedExpense> build() => ref.read(plannedExpensesBoxProvider).values.toList();

  void _refresh() {
    state = ref.read(plannedExpensesBoxProvider).values.toList();
  }

  Future<void> addItem({
    required String name,
    required double amount,
    required int year,
    required int month,
    String? categoryId,
    String note = '',
  }) async {
    final item = PlannedExpense(
      id: _uuid.v4(),
      name: name,
      amount: amount,
      year: year,
      month: month,
      categoryId: categoryId,
      note: note,
      updatedAt: DateTime.now().toUtc(),
    );
    await ref.read(plannedExpensesBoxProvider).put(item.id, item);
    _refresh();
  }

  Future<void> updateItem(
    String id, {
    required String name,
    required double amount,
    String? categoryId,
    String note = '',
  }) async {
    final item = ref.read(plannedExpensesBoxProvider).get(id);
    if (item == null) return;
    item
      ..name = name
      ..amount = amount
      ..categoryId = categoryId
      ..note = note
      ..updatedAt = DateTime.now().toUtc();
    await item.save();
    _refresh();
  }

  Future<void> deleteItem(String id) async {
    await ref.read(plannedExpensesBoxProvider).delete(id);
    _refresh();
  }

  /// Copies every item from one month into another, leaving the source
  /// month untouched. Returns how many items were copied.
  Future<int> cloneMonth({
    required int fromYear,
    required int fromMonth,
    required int toYear,
    required int toMonth,
  }) async {
    final box = ref.read(plannedExpensesBoxProvider);
    final source =
        box.values.where((item) => item.year == fromYear && item.month == fromMonth).toList();
    for (final item in source) {
      final clone = PlannedExpense(
        id: _uuid.v4(),
        name: item.name,
        amount: item.amount,
        year: toYear,
        month: toMonth,
        categoryId: item.categoryId,
        note: item.note,
        updatedAt: DateTime.now().toUtc(),
      );
      await box.put(clone.id, clone);
    }
    _refresh();
    return source.length;
  }
}

final plannedExpensesProvider =
    NotifierProvider<PlannedExpensesNotifier, List<PlannedExpense>>(PlannedExpensesNotifier.new);

List<PlannedExpense> plannedExpensesForMonth(List<PlannedExpense> items, int year, int month) {
  return items.where((item) => item.year == year && item.month == month).toList();
}
