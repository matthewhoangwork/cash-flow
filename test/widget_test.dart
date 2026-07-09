import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

import 'package:money_tracking/models/category.dart';
import 'package:money_tracking/models/transaction.dart';
import 'package:money_tracking/models/transaction_type.dart';
import 'package:money_tracking/providers/hive_providers.dart';
import 'package:money_tracking/screens/home_screen.dart';
import 'package:money_tracking/theme/app_theme.dart';

void main() {
  testWidgets('Home screen shows balance and empty state', (tester) async {
    final dir = Directory.systemTemp.createTempSync('money_tracking_test');
    Hive.init(dir.path);
    Hive.registerAdapter(TransactionTypeAdapter());
    Hive.registerAdapter(CategoryAdapter());
    Hive.registerAdapter(TransactionAdapter());

    final categoriesBox = await Hive.openBox<Category>('categories_test');
    final transactionsBox = await Hive.openBox<Transaction>('transactions_test');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          categoriesBoxProvider.overrideWithValue(categoriesBox),
          transactionsBoxProvider.overrideWithValue(transactionsBox),
        ],
        child: MaterialApp(theme: buildAppTheme(), home: const HomeScreen()),
      ),
    );

    expect(find.text('No transactions yet'), findsOneWidget);
    expect(find.text('\$0.00'), findsOneWidget);

    await categoriesBox.close();
    await transactionsBox.close();
    await dir.delete(recursive: true);
  });
}
