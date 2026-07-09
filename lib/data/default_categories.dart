import 'package:hive_ce/hive.dart';
import 'package:uuid/uuid.dart';

import '../models/category.dart';
import '../models/transaction_type.dart';

const _uuid = Uuid();

const _defaultExpenseCategories = [
  ('Food & Drink', 'restaurant', 0),
  ('Transport', 'directions_car', 1),
  ('Health', 'local_hospital', 2),
  ('Education', 'school', 3),
  ('Shopping', 'shopping_bag', 4),
  ('Housing', 'home', 5),
  ('Entertainment', 'movie', 6),
  ('Other', 'more_horiz', 7),
];

const _defaultIncomeCategories = [
  ('Investment', 'trending_up', 1),
  ('Salary', 'work', 2),
  ('Bonus', 'card_giftcard', 3),
  ('Other', 'savings', 7),
];

Future<void> seedDefaultCategoriesIfNeeded(Box<Category> box) async {
  if (box.isNotEmpty) return;

  for (final (name, iconKey, paletteIndex) in _defaultExpenseCategories) {
    final category = Category(
      id: _uuid.v4(),
      name: name,
      type: TransactionType.expense,
      iconKey: iconKey,
      paletteIndex: paletteIndex,
    );
    await box.put(category.id, category);
  }

  for (final (name, iconKey, paletteIndex) in _defaultIncomeCategories) {
    final category = Category(
      id: _uuid.v4(),
      name: name,
      type: TransactionType.income,
      iconKey: iconKey,
      paletteIndex: paletteIndex,
    );
    await box.put(category.id, category);
  }
}
