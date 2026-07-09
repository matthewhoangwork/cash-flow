import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'data/default_categories.dart';
import 'data/default_wallet.dart';
import 'models/category.dart';
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

  final categoriesBox = await Hive.openBox<Category>('categories');
  final transactionsBox = await Hive.openBox<Transaction>('transactions');
  final walletsBox = await Hive.openBox<Wallet>('wallets');
  final pendingDeletesBox = await Hive.openBox<Map>('pending_deletes');
  await seedDefaultCategoriesIfNeeded(categoriesBox);
  await seedDefaultWalletIfNeeded(walletsBox, transactionsBox);

  runApp(
    ProviderScope(
      overrides: [
        categoriesBoxProvider.overrideWithValue(categoriesBox),
        transactionsBoxProvider.overrideWithValue(transactionsBox),
        walletsBoxProvider.overrideWithValue(walletsBox),
        pendingDeletesBoxProvider.overrideWithValue(pendingDeletesBox),
      ],
      child: const CashFlowApp(),
    ),
  );
  WidgetsBinding.instance.addPostFrameCallback((_) => FlutterNativeSplash.remove());
}

class CashFlowApp extends StatelessWidget {
  const CashFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cash Flow',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const AuthGate(),
    );
  }
}
