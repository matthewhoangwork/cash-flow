import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/wallet.dart';
import '../sync/sync_service.dart';
import 'hive_providers.dart';

const _uuid = Uuid();

enum DeleteWalletResult { deleted, archived, blockedIsDefault, blockedLastWallet }

class WalletsNotifier extends Notifier<List<Wallet>> {
  @override
  List<Wallet> build() => ref.read(walletsBoxProvider).values.toList();

  void _refresh() {
    state = ref.read(walletsBoxProvider).values.toList();
  }

  Future<void> addWallet(String name) async {
    final wallet = Wallet(id: _uuid.v4(), name: name, updatedAt: DateTime.now().toUtc());
    await ref.read(walletsBoxProvider).put(wallet.id, wallet);
    _refresh();
    ref.read(syncServiceProvider).schedulePush();
  }

  Future<void> updateWallet(String id, {required String name}) async {
    final wallet = ref.read(walletsBoxProvider).get(id);
    if (wallet == null) return;
    wallet.name = name;
    wallet.updatedAt = DateTime.now().toUtc();
    await wallet.save();
    _refresh();
    ref.read(syncServiceProvider).schedulePush();
  }

  Future<void> setDefaultWallet(String id) async {
    final box = ref.read(walletsBoxProvider);
    for (final wallet in box.values) {
      final shouldBeDefault = wallet.id == id;
      if (wallet.isDefault != shouldBeDefault) {
        wallet.isDefault = shouldBeDefault;
        wallet.updatedAt = DateTime.now().toUtc();
        await wallet.save();
      }
    }
    _refresh();
    ref.read(syncServiceProvider).schedulePush();
  }

  /// Wallets still referenced by a transaction are archived instead of
  /// removed, so those transactions keep showing the original name.
  /// Unused wallets are deleted outright. The default wallet, and the last
  /// remaining active wallet, can't be removed — there must always be
  /// exactly one active default wallet.
  Future<DeleteWalletResult> deleteWallet(String id) async {
    final box = ref.read(walletsBoxProvider);
    final wallet = box.get(id);
    if (wallet == null) return DeleteWalletResult.deleted;
    if (wallet.isDefault) return DeleteWalletResult.blockedIsDefault;

    final activeCount = box.values.where((w) => !w.isArchived).length;
    if (activeCount <= 1) return DeleteWalletResult.blockedLastWallet;

    final inUse = ref.read(transactionsBoxProvider).values.any((t) => t.walletId == id);
    if (inUse) {
      wallet.isArchived = true;
      wallet.updatedAt = DateTime.now().toUtc();
      await wallet.save();
      _refresh();
      ref.read(syncServiceProvider).schedulePush();
      return DeleteWalletResult.archived;
    } else {
      await ref.read(syncServiceProvider).recordDelete('wallets', id);
      await box.delete(id);
      _refresh();
      return DeleteWalletResult.deleted;
    }
  }
}

final walletsProvider = NotifierProvider<WalletsNotifier, List<Wallet>>(WalletsNotifier.new);

final activeWalletsProvider = Provider<List<Wallet>>((ref) {
  return ref.watch(walletsProvider).where((w) => !w.isArchived).toList();
});

final defaultWalletProvider = Provider<Wallet>((ref) {
  final wallets = ref.watch(walletsProvider);
  return wallets.firstWhere((w) => w.isDefault, orElse: () => wallets.first);
});

Wallet? findWallet(List<Wallet> wallets, String id) {
  final matches = wallets.where((w) => w.id == id);
  return matches.isEmpty ? null : matches.first;
}
