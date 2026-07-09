import 'package:hive_ce/hive.dart';
import 'package:uuid/uuid.dart';

import '../models/transaction.dart';
import '../models/wallet.dart';

const _uuid = Uuid();

/// Seeds a single default wallet on first launch, and backfills any
/// transaction written before wallets existed (walletId == '') to point at it.
Future<void> seedDefaultWalletIfNeeded(Box<Wallet> walletsBox, Box<Transaction> transactionsBox) async {
  if (walletsBox.isEmpty) {
    final wallet = Wallet(id: _uuid.v4(), name: 'Cash', isDefault: true);
    await walletsBox.put(wallet.id, wallet);
  }

  final defaultWallet = walletsBox.values.firstWhere(
    (w) => w.isDefault,
    orElse: () => walletsBox.values.first,
  );

  for (final transaction in transactionsBox.values.where((t) => t.walletId.isEmpty)) {
    transaction.walletId = defaultWallet.id;
    await transaction.save();
  }
}
