import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/transaction.dart';
import '../models/transaction_type.dart';
import 'transactions_provider.dart';
import 'wallets_provider.dart';

/// The home page's balance card, income/expense totals, category breakdown,
/// and dashboard chart all reflect only the default wallet. The transaction
/// list itself is not scoped to this — see [transactionsProvider] — so it
/// shows every wallet's activity.
final walletScopedTransactionsProvider = Provider<List<Transaction>>((ref) {
  final walletId = ref.watch(defaultWalletProvider).id;
  return ref.watch(transactionsProvider).where((t) => t.walletId == walletId).toList();
});

final totalIncomeProvider = Provider<double>((ref) {
  return ref
      .watch(walletScopedTransactionsProvider)
      .where((t) => t.type == TransactionType.income)
      .fold(0.0, (sum, t) => sum + t.amount);
});

final totalExpenseProvider = Provider<double>((ref) {
  return ref
      .watch(walletScopedTransactionsProvider)
      .where((t) => t.type == TransactionType.expense)
      .fold(0.0, (sum, t) => sum + t.amount);
});

final balanceProvider = Provider<double>((ref) {
  return ref.watch(totalIncomeProvider) - ref.watch(totalExpenseProvider);
});

class CategoryTotal {
  const CategoryTotal({required this.categoryId, required this.amount});

  final String categoryId;
  final double amount;
}

final categoryBreakdownProvider =
    Provider.family<List<CategoryTotal>, TransactionType>((ref, type) {
  final totals = <String, double>{};
  for (final t in ref.watch(walletScopedTransactionsProvider).where((t) => t.type == type)) {
    totals.update(t.categoryId, (value) => value + t.amount, ifAbsent: () => t.amount);
  }
  final list = totals.entries
      .map((e) => CategoryTotal(categoryId: e.key, amount: e.value))
      .toList()
    ..sort((a, b) => b.amount.compareTo(a.amount));
  return list;
});

class DailyTotal {
  const DailyTotal({
    required this.date,
    required this.income,
    required this.expense,
    required this.balance,
  });

  final DateTime date;
  final double income;
  final double expense;

  /// Running balance of the default wallet as of the end of this day —
  /// counts every default-wallet transaction ever recorded, not just ones
  /// within the visible chart window. Null for days after today: nothing's
  /// been paid yet, so there's no balance to show.
  final double? balance;
}

/// The default wallet's balance across all of its transactions strictly
/// before [endExclusive].
double _balanceBefore(List<Transaction> walletTransactions, DateTime endExclusive) {
  return walletTransactions.where((t) => t.date.isBefore(endExclusive)).fold(
      0.0, (sum, t) => sum + (t.type == TransactionType.income ? t.amount : -t.amount));
}

/// Monday-through-Sunday totals for the current week, default-wallet scoped.
final weeklyBreakdownProvider = Provider<List<DailyTotal>>((ref) {
  final transactions = ref.watch(walletScopedTransactionsProvider);
  final today = DateTime.now();
  final todayDate = DateTime(today.year, today.month, today.day);
  final monday = todayDate.subtract(Duration(days: today.weekday - 1));

  return List.generate(7, (i) {
    final day = monday.add(Duration(days: i));
    final dayTransactions = transactions.where(
      (t) => t.date.year == day.year && t.date.month == day.month && t.date.day == day.day,
    );
    final income = dayTransactions
        .where((t) => t.type == TransactionType.income)
        .fold(0.0, (sum, t) => sum + t.amount);
    final expense = dayTransactions
        .where((t) => t.type == TransactionType.expense)
        .fold(0.0, (sum, t) => sum + t.amount);
    final balance = day.isAfter(todayDate)
        ? null
        : _balanceBefore(transactions, day.add(const Duration(days: 1)));
    return DailyTotal(date: day, income: income, expense: expense, balance: balance);
  });
});

class WeeklyTotal {
  const WeeklyTotal({
    required this.weekStart,
    required this.weekEnd,
    required this.income,
    required this.expense,
    required this.balance,
  });

  final DateTime weekStart;
  final DateTime weekEnd;
  final double income;
  final double expense;

  /// Running balance of the default wallet as of the end of this week.
  final double balance;
}

/// Totals for the last 6 Monday-through-Sunday weeks (oldest to newest,
/// current week last), default-wallet scoped.
final weeklyOverWeeksProvider = Provider<List<WeeklyTotal>>((ref) {
  final transactions = ref.watch(walletScopedTransactionsProvider);
  final today = DateTime.now();
  final thisMonday = DateTime(today.year, today.month, today.day)
      .subtract(Duration(days: today.weekday - 1));
  final firstMonday = thisMonday.subtract(const Duration(days: 7 * 5));

  return List.generate(6, (i) {
    final weekStart = firstMonday.add(Duration(days: 7 * i));
    final weekEnd = weekStart.add(const Duration(days: 6));
    final nextWeekStart = weekStart.add(const Duration(days: 7));
    final weekTransactions = transactions.where(
      (t) => !t.date.isBefore(weekStart) && t.date.isBefore(nextWeekStart),
    );
    final income = weekTransactions
        .where((t) => t.type == TransactionType.income)
        .fold(0.0, (sum, t) => sum + t.amount);
    final expense = weekTransactions
        .where((t) => t.type == TransactionType.expense)
        .fold(0.0, (sum, t) => sum + t.amount);
    final balance = _balanceBefore(transactions, nextWeekStart);
    return WeeklyTotal(
      weekStart: weekStart,
      weekEnd: weekEnd,
      income: income,
      expense: expense,
      balance: balance,
    );
  });
});
