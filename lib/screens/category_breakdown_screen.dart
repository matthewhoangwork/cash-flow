import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/transaction_type.dart';
import '../providers/categories_provider.dart';
import '../providers/summary_providers.dart';
import '../theme/app_theme.dart';
import '../theme/category_style.dart';
import '../utils/currency_format.dart';
import '../widgets/adaptive.dart';
import '../widgets/glass.dart';

class CategoryBreakdownScreen extends ConsumerStatefulWidget {
  const CategoryBreakdownScreen({super.key});

  @override
  ConsumerState<CategoryBreakdownScreen> createState() =>
      _CategoryBreakdownScreenState();
}

class _CategoryBreakdownScreenState
    extends ConsumerState<CategoryBreakdownScreen> {
  TransactionType _type = TransactionType.expense;

  @override
  Widget build(BuildContext context) {
    final breakdown = ref.watch(categoryBreakdownProvider(_type));
    final categories = ref.watch(categoriesProvider);
    final total = breakdown.fold<double>(0, (sum, item) => sum + item.amount);

    return AdaptiveSliverScaffold(
      title: 'Category breakdown',
      largeTitle: false,
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: AdaptiveSegmentedControl<TransactionType>(
              segments: const [
                (TransactionType.expense, 'Expense'),
                (TransactionType.income, 'Income'),
              ],
              value: _type,
              onChanged: (selected) => setState(() => _type = selected),
            ),
          ),
        ),
        if (breakdown.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Text(
                'No data yet',
                style: TextStyle(color: AppColors.muted),
              ),
            ),
          )
        else ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: SizedBox(
                height: 200,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 56,
                    sections: breakdown.map((item) {
                      final category = findCategory(
                        categories,
                        item.categoryId,
                      );
                      final palette = CategoryPalette.of(
                        category?.paletteIndex ?? 7,
                      );
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
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            sliver: SliverList.separated(
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
    );
  }
}
