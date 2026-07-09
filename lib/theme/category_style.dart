import 'package:flutter/material.dart';

/// Muted pastel pairs (background, foreground) — the only accent colors
/// categories may use. Keeps every category tag inside the app's warm
/// monochrome + spot-pastel palette instead of arbitrary saturated colors.
class CategoryPalette {
  const CategoryPalette._(this.background, this.foreground);

  final Color background;
  final Color foreground;

  static const List<CategoryPalette> values = [
    CategoryPalette._(Color(0xFFFDEBEC), Color(0xFF9F2F2D)), // pale red
    CategoryPalette._(Color(0xFFE1F3FE), Color(0xFF1F6C9F)), // pale blue
    CategoryPalette._(Color(0xFFEDF3EC), Color(0xFF346538)), // pale green
    CategoryPalette._(Color(0xFFFBF3DB), Color(0xFF956400)), // pale yellow
    CategoryPalette._(Color(0xFFF3EBFD), Color(0xFF6B3F9F)), // pale purple
    CategoryPalette._(Color(0xFFE7F5F3), Color(0xFF1F7A6C)), // pale teal
    CategoryPalette._(Color(0xFFFBEBE1), Color(0xFF9F5A1F)), // pale orange
    CategoryPalette._(Color(0xFFEFEFEF), Color(0xFF4B4B4B)), // neutral gray
  ];

  static CategoryPalette of(int index) => values[index % values.length];
}

/// Fixed icon set categories can pick from. Using a lookup keeps IconData
/// references const, so Flutter's icon tree-shaker can still strip unused
/// glyphs from release builds — dynamically-built IconData would break that.
const Map<String, IconData> kCategoryIcons = {
  'restaurant': Icons.restaurant_outlined,
  'shopping_bag': Icons.shopping_bag_outlined,
  'directions_car': Icons.directions_car_outlined,
  'home': Icons.home_outlined,
  'movie': Icons.movie_outlined,
  'local_hospital': Icons.local_hospital_outlined,
  'school': Icons.school_outlined,
  'flight': Icons.flight_outlined,
  'fitness_center': Icons.fitness_center_outlined,
  'pets': Icons.pets_outlined,
  'work': Icons.work_outline,
  'trending_up': Icons.trending_up_outlined,
  'card_giftcard': Icons.card_giftcard_outlined,
  'savings': Icons.savings_outlined,
  'attach_money': Icons.attach_money_outlined,
  'receipt_long': Icons.receipt_long_outlined,
  'more_horiz': Icons.more_horiz_outlined,
};

IconData categoryIcon(String key) =>
    kCategoryIcons[key] ?? Icons.category_outlined;
