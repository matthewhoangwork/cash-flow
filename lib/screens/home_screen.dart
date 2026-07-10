import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/categories_provider.dart';
import '../providers/summary_providers.dart';
import '../providers/transactions_provider.dart';
import '../providers/wallets_provider.dart';
import '../sync/sync_service.dart';
import '../theme/app_theme.dart';
import '../utils/currency_format.dart';
import '../widgets/adaptive.dart';
import '../widgets/balance_with_planned.dart';
import '../widgets/glass.dart';
import '../widgets/grouped_transaction_list.dart';
import '../widgets/period_bar_chart.dart';
import 'add_edit_transaction_screen.dart';
import 'category_breakdown_screen.dart';
import 'manage_categories_screen.dart';
import 'manage_wallets_screen.dart';
import 'monthly_expenses_screen.dart';

enum _ChartGranularity { daily, weekly }

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactions = ref.watch(transactionsProvider);
    final categories = ref.watch(categoriesProvider);
    final balance = ref.watch(balanceProvider);
    final plannedOutstanding = ref.watch(plannedOutstandingProvider);
    final income = ref.watch(totalIncomeProvider);
    final expense = ref.watch(totalExpenseProvider);
    final defaultWallet = ref.watch(defaultWalletProvider);
    final wallets = ref.watch(walletsProvider);
    final showWalletTag = ref.watch(activeWalletsProvider).length > 1;
    return AdaptiveSliverScaffold(
      title: 'Cash',
      actions: [
        AdaptiveNavAction(
          materialIcon: Icons.pie_chart_outline,
          cupertinoIcon: CupertinoIcons.chart_pie,
          tooltip: 'Category breakdown',
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const CategoryBreakdownScreen()),
          ),
        ),
        AdaptiveNavAction(
          materialIcon: Icons.calendar_month_outlined,
          cupertinoIcon: CupertinoIcons.calendar,
          tooltip: 'Monthly expenses',
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const MonthlyExpensesScreen()),
          ),
        ),
        AdaptiveMenuButton(
          tooltip: 'Manage',
          items: [
            AdaptiveMenuItem(
              label: 'Manage categories',
              onSelected: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const ManageCategoriesScreen(),
                ),
              ),
            ),
            AdaptiveMenuItem(
              label: 'Wallets',
              onSelected: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ManageWalletsScreen()),
              ),
            ),
            AdaptiveMenuItem(
              label: 'Sync now',
              onSelected: () => ref.read(syncServiceProvider).syncNow(),
            ),
            AdaptiveMenuItem(
              label: 'Sign out',
              onSelected: () => Supabase.instance.client.auth.signOut(),
            ),
          ],
        ),
      ],
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: SurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'BALANCE',
                        style: TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.06,
                        ),
                      ),
                      InkWell(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const ManageWalletsScreen(),
                          ),
                        ),
                        borderRadius: BorderRadius.circular(20),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 2,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.account_balance_wallet_outlined,
                                size: 14,
                                color: AppColors.muted,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                defaultWallet.name,
                                style: const TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  BalanceWithPlanned(
                    balance: balance,
                    planned: plannedOutstanding,
                    amountStyle: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.02,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _SummaryStat(
                        label: 'Income',
                        amount: income,
                        color: AppColors.income,
                      ),
                      const SizedBox(width: 28),
                      _SummaryStat(
                        label: 'Expense',
                        amount: expense,
                        color: AppColors.expense,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        const SliverToBoxAdapter(child: _DashboardChart()),
        const SliverToBoxAdapter(child: Divider(height: 1)),
        if (transactions.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Text(
                'No transactions yet',
                style: TextStyle(color: AppColors.muted),
              ),
            ),
          )
        else
          GroupedTransactionList(
            transactions: transactions,
            onTap: (transaction) => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    AddEditTransactionScreen(transaction: transaction),
              ),
            ),
            onDismissed: (transaction) => ref
                .read(transactionsProvider.notifier)
                .deleteTransaction(transaction.id),
            onTogglePlanned: (transaction) =>
                ref.read(transactionsProvider.notifier).markPaid(transaction.id),
            findCategory: (categoryId) => findCategory(categories, categoryId),
            findWalletName: showWalletTag
                ? (walletId) => findWallet(wallets, walletId)?.name
                : null,
          ),
      ],
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AddEditTransactionScreen()),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _DashboardChart extends ConsumerStatefulWidget {
  const _DashboardChart();

  @override
  ConsumerState<_DashboardChart> createState() => _DashboardChartState();
}

class _DashboardChartState extends ConsumerState<_DashboardChart> {
  _ChartGranularity _granularity = _ChartGranularity.daily;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();

    final bars = _granularity == _ChartGranularity.daily
        ? ref.watch(weeklyBreakdownProvider).map((d) {
            final isToday =
                d.date.year == today.year &&
                d.date.month == today.month &&
                d.date.day == today.day;
            return PeriodBar(
              label: DateFormat.E().format(d.date),
              income: d.income,
              expense: d.expense,
              balance: d.balance,
              highlighted: isToday,
            );
          }).toList()
        : ref.watch(weeklyOverWeeksProvider).map((w) {
            final isCurrentWeek =
                !today.isBefore(w.weekStart) && !today.isAfter(w.weekEnd);
            return PeriodBar(
              label: DateFormat.Md().format(w.weekStart),
              income: w.income,
              expense: w.expense,
              balance: w.balance,
              highlighted: isCurrentWeek,
            );
          }).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: SurfaceCard(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'OVERVIEW',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.06,
                  ),
                ),
                _GranularityToggle(
                  value: _granularity,
                  onChanged: (value) => setState(() => _granularity = value),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(height: 190, child: PeriodBarChart(bars: bars)),
          ],
        ),
      ),
    );
  }
}

class _GranularityToggle extends StatelessWidget {
  const _GranularityToggle({required this.value, required this.onChanged});

  final _ChartGranularity value;
  final void Function(_ChartGranularity) onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ToggleOption(
            label: 'Daily',
            selected: value == _ChartGranularity.daily,
            onTap: () => onChanged(_ChartGranularity.daily),
          ),
          _ToggleOption(
            label: 'Weekly',
            selected: value == _ChartGranularity.weekly,
            onTap: () => onChanged(_ChartGranularity.weekly),
          ),
        ],
      ),
    );
  }
}

class _ToggleOption extends StatelessWidget {
  const _ToggleOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? AppColors.ink : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppColors.muted,
          ),
        ),
      ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  const _SummaryStat({
    required this.label,
    required this.amount,
    required this.color,
  });

  final String label;
  final double amount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.muted, fontSize: 12),
        ),
        const SizedBox(height: 2),
        Text(
          compactVnd(amount),
          style: TextStyle(color: color, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
