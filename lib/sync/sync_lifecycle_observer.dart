import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/hive_providers.dart';
import '../screens/home_skeleton.dart';
import 'sync_service.dart';

/// Wraps the authenticated app. Triggers a sync once on mount — covering
/// both "just signed in" and "app start with an already-persisted session"
/// — again whenever the app resumes from the background, and on a periodic
/// backstop timer.
///
/// A device that already has local data (the common case) shows [child]
/// immediately and syncs in the background, same as before. A device with
/// an empty local wallets box — e.g. a fresh install signing into an
/// existing account — holds [child] behind [HomeSkeleton] until that first
/// sync (pull, then seed-if-still-empty, then push) completes. Rendering
/// eagerly there would both crash on the empty-wallets lookup in
/// [HomeScreen] and reintroduce the duplicate-defaults bug this ordering
/// exists to prevent — see [SyncService.syncNow].
class SyncLifecycleObserver extends ConsumerStatefulWidget {
  const SyncLifecycleObserver({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<SyncLifecycleObserver> createState() => _SyncLifecycleObserverState();
}

class _SyncLifecycleObserverState extends ConsumerState<SyncLifecycleObserver>
    with WidgetsBindingObserver {
  Timer? _periodic;
  late bool _initialSyncDone;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final syncService = ref.read(syncServiceProvider);
    _initialSyncDone = ref.read(walletsBoxProvider).isNotEmpty;
    if (_initialSyncDone) {
      unawaited(syncService.syncNow());
    } else {
      unawaited(_runInitialSync(syncService));
    }
    _periodic = Timer.periodic(const Duration(minutes: 10), (_) {
      unawaited(ref.read(syncServiceProvider).syncNow());
    });
  }

  Future<void> _runInitialSync(SyncService syncService) async {
    await syncService.syncNow();
    if (mounted) setState(() => _initialSyncDone = true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _periodic?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(ref.read(syncServiceProvider).syncNow());
    }
  }

  @override
  Widget build(BuildContext context) => _initialSyncDone ? widget.child : const HomeSkeleton();
}
