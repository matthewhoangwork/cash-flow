import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/transaction_type.dart';
import '../providers/categories_provider.dart';
import '../providers/summary_providers.dart';
import '../theme/app_theme.dart';
import '../theme/category_style.dart';
import '../utils/currency_format.dart';

class CategoryBreakdownScreen extends ConsumerStatefulWidget {
  const CategoryBreakdownScreen({super.key});

  @override
  ConsumerState<CategoryBreakdownScreen> createState() => _CategoryBreakdownScreenState();
}

class _CategoryBreakdownScreenState extends ConsumerState<CategoryBreakdownScreen> {
  TransactionType _type = TransactionType.expense;

  @override
  Widget build(BuildContext context) {
    final breakdown = ref.watch(categoryBreakdownProvider(_type));
    final categories = ref.watch(categoriesProvider);
    final total = breakdown.fold<double>(0, (sum, item) => sum + item.amount);

    return Scaffold(
      appBar: AppBar(title: const Text('Category breakdown')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            SegmentedButton<TransactionType>(
              segments: const [
                ButtonSegment(value: TransactionType.expense, label: Text('Expense')),
                ButtonSegment(value: TransactionType.income, label: Text('Income')),
              ],
              selected: {_type},
              onSelectionChanged: (selection) => setState(() => _type = selection.first),
            ),
            const SizedBox(height: 24),
            if (breakdown.isEmpty)
              const Expanded(
                child: Center(
                  child: Text('No data yet', style: TextStyle(color: AppColors.muted)),
                ),
              )
            else ...[
              SizedBox(
                height: 200,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 56,
                    sections: breakdown.map((item) {
                      final category = findCategory(categories, item.categoryId);
                      final palette = CategoryPalette.of(category?.paletteIndex ?? 7);
                      return PieChartSectionData(
                        value: item.amount,
                        color: palette.foreground,
                        radius: 24,
                        showTitle: false,
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: ListView.separated(
                  itemCount: breakdown.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = breakdown[index];
                    final category = findCategory(categories, item.categoryId);
                    final palette = CategoryPalette.of(category?.paletteIndex ?? 7);
                    final percent = total == 0 ? 0.0 : (item.amount / total * 100);
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: palette.background,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              categoryIcon(category?.iconKey ?? 'more_horiz'),
                              size: 16,
                              color: palette.foreground,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Text(category?.name ?? 'Uncategorized')),
                          Text(
                            '${percent.toStringAsFixed(0)}%',
                            style: const TextStyle(color: AppColors.muted),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            vndFormat.format(item.amount),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
