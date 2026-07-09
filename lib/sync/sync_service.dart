import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/category.dart';
import '../models/transaction.dart';
import '../models/wallet.dart';
import '../providers/categories_provider.dart';
import '../providers/hive_providers.dart';
import '../providers/transactions_provider.dart';
import '../providers/wallets_provider.dart';
import 'supabase_mappers.dart';
import 'sync_providers.dart';

/// Push = full re-upsert of every local box on each cycle; pull = full fetch
/// + last-write-wins merge by `updatedAt`. Both trigger off small amounts of
/// personal data, so no dirty-tracking/outbox or pull cursor is needed — see
/// the sync plan for the full rationale.
class SyncService {
  SyncService(this._ref);

  final Ref _ref;
  Timer? _debounce;

  String? get _userId => _ref.read(supabaseClientProvider).auth.currentUser?.id;

  /// Debounces rapid successive local writes into one push.
  void schedulePush() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 2), () {
      unawaited(pushAll());
    });
  }

  Future<void> recordDelete(String table, String id) async {
    final box = _ref.read(pendingDeletesBoxProvider);
    await box.put('$table:$id', {'id': id, 'table': table, 'deletedAt': DateTime.now().toUtc()});
    schedulePush();
  }

  Future<void> syncNow() async {
    if (_userId == null) return;
    await pushAll();
    await pullAll();
  }

  Future<void> pushAll() async {
    final userId = _userId;
    if (userId == null) return;
    final client = _ref.read(supabaseClientProvider);
    try {
      final walletsBox = _ref.read(walletsBoxProvider);
      final categoriesBox = _ref.read(categoriesBoxProvider);
      final transactionsBox = _ref.read(transactionsBoxProvider);

      await _backfillUpdatedAt<Wallet>(walletsBox, (w) => w.updatedAt, (w, t) => w.updatedAt = t);
      await _backfillUpdatedAt<Category>(
        categoriesBox,
        (c) => c.updatedAt,
        (c, t) => c.updatedAt = t,
      );
      await _backfillUpdatedAt<Transaction>(
        transactionsBox,
        (tx) => tx.updatedAt,
        (tx, t) => tx.updatedAt = t,
      );

      if (walletsBox.values.isNotEmpty) {
        await client.from(
          'wallets',
        ).upsert([for (final w in walletsBox.values) walletToRow(w, userId)]);
      }
      if (categoriesBox.values.isNotEmpty) {
        await client.from(
          'categories',
        ).upsert([for (final c in categoriesBox.values) categoryToRow(c, userId)]);
      }
      if (transactionsBox.values.isNotEmpty) {
        await client.from(
          'transactions',
        ).upsert([for (final t in transactionsBox.values) transactionToRow(t, userId)]);
      }

      await _flushPendingDeletes(client);
    } catch (_) {
      // Offline or transient failure — silently retried on the next trigger
      // (next local write, app resume, periodic timer, or manual "Sync now").
    }
  }

  Future<void> _backfillUpdatedAt<T extends HiveObject>(
    Box<T> box,
    DateTime? Function(T) updatedAtOf,
    void Function(T, DateTime) setUpdatedAt,
  ) async {
    for (final value in box.values) {
      if (updatedAtOf(value) == null) {
        setUpdatedAt(value, DateTime.now().toUtc());
        await value.save();
      }
    }
  }

  Future<void> _flushPendingDeletes(SupabaseClient client) async {
    final box = _ref.read(pendingDeletesBoxProvider);
    for (final key in box.keys.toList()) {
      final entry = box.get(key);
      if (entry == null) continue;
      final table = entry['table'] as String;
      final id = entry['id'] as String;
      final deletedAt = entry['deletedAt'] as DateTime;
      await client
          .from(table)
          .update({'is_deleted': true, 'updated_at': deletedAt.toIso8601String()})
          .eq('id', id);
      await box.delete(key);
    }
  }

  Future<void> pullAll() async {
    if (_userId == null) return;
    final client = _ref.read(supabaseClientProvider);
    try {
      final walletRows = await client.from('wallets').select();
      final categoryRows = await client.from('categories').select();
      final transactionRows = await client.from('transactions').select();

      await _mergeRows<Wallet>(
        rows: walletRows,
        box: _ref.read(walletsBoxProvider),
        fromRow: walletFromRow,
        updatedAtOf: (w) => w.updatedAt,
      );
      await _mergeRows<Category>(
        rows: categoryRows,
        box: _ref.read(categoriesBoxProvider),
        fromRow: categoryFromRow,
        updatedAtOf: (c) => c.updatedAt,
      );
      await _mergeRows<Transaction>(
        rows: transactionRows,
        box: _ref.read(transactionsBoxProvider),
        fromRow: transactionFromRow,
        updatedAtOf: (t) => t.updatedAt,
      );

      _ref.invalidate(walletsProvider);
      _ref.invalidate(categoriesProvider);
      _ref.invalidate(transactionsProvider);
    } catch (_) {
      // Offline or transient failure — silently retried on the next trigger.
    }
  }

  Future<void> _mergeRows<T extends HiveObject>({
    required List<Map<String, dynamic>> rows,
    required Box<T> box,
    required T Function(Map<String, dynamic>) fromRow,
    required DateTime? Function(T) updatedAtOf,
  }) async {
    for (final row in rows) {
      final id = row['id'] as String;
      if (row['is_deleted'] == true) {
        if (box.containsKey(id)) await box.delete(id);
        continue;
      }
      final remoteUpdatedAt = DateTime.parse(row['updated_at'] as String);
      final local = box.get(id);
      final localUpdatedAt = local == null ? null : updatedAtOf(local);
      if (local == null || localUpdatedAt == null || remoteUpdatedAt.isAfter(localUpdatedAt)) {
        await box.put(id, fromRow(row));
      }
    }
  }
}

final syncServiceProvider = Provider<SyncService>((ref) => SyncService(ref));
