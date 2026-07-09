import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'models/category.dart';
import 'models/planned_expense.dart';
import 'models/transaction.dart';
import 'models/transaction_type.dart';
import 'models/wallet.dart';
import 'providers/hive_providers.dart';
import 'screens/auth_gate.dart';
import 'sync/sync_providers.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  await dotenv.load();
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    publishableKey: dotenv.env['SUPABASE_PUBLISHABLE_KEY']!,
  );

  await Hive.initFlutter();
  Hive.registerAdapter(TransactionTypeAdapter());
  Hive.registerAdapter(CategoryAdapter());
  Hive.registerAdapter(TransactionAdapter());
  Hive.registerAdapter(WalletAdapter());
  Hive.registerAdapter(PlannedExpenseAdapter());

  final categoriesBox = await Hive.openBox<Category>('categories');
  final transactionsBox = await Hive.openBox<Transaction>('transactions');
  final walletsBox = await Hive.openBox<Wallet>('wallets');
  final pendingDeletesBox = await Hive.openBox<Map>('pending_deletes');
  final plannedExpensesBox = await Hive.openBox<PlannedExpense>('planned_expenses');
  // Defaults are seeded lazily by SyncService, only once a pull confirms the
  // signed-in account has no cloud data — seeding here unconditionally would
  // create a fresh, differently-ID'd set of "defaults" on every new device,
  // which then merges into the account as permanent duplicates.

  runApp(
    ProviderScope(
      overrides: [
        categoriesBoxProvider.overrideWithValue(categoriesBox),
        transactionsBoxProvider.overrideWithValue(transactionsBox),
        walletsBoxProvider.overrideWithValue(walletsBox),
        pendingDeletesBoxProvider.overrideWithValue(pendingDeletesBox),
        plannedExpensesBoxProvider.overrideWithValue(plannedExpensesBox),
      ],
      child: const CashApp(),
    ),
  );
  WidgetsBinding.instance.addPostFrameCallback((_) => FlutterNativeSplash.remove());
}

class CashApp extends StatelessWidget {
  const CashApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cash',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const AuthGate(),
    );
  }
}
