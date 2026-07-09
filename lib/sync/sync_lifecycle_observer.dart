import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'sync_service.dart';

/// Wraps the authenticated app. Triggers a sync once on mount — covering
/// both "just signed in" and "app start with an already-persisted session"
/// — again whenever the app resumes from the background, and on a periodic
/// backstop timer.
class SyncLifecycleObserver extends ConsumerStatefulWidget {
  const SyncLifecycleObserver({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<SyncLifecycleObserver> createState() => _SyncLifecycleObserverState();
}

class _SyncLifecycleObserverState extends ConsumerState<SyncLifecycleObserver>
    with WidgetsBindingObserver {
  Timer? _periodic;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(ref.read(syncServiceProvider).syncNow());
    _periodic = Timer.periodic(const Duration(minutes: 10), (_) {
      unawaited(ref.read(syncServiceProvider).syncNow());
    });
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
  Widget build(BuildContext context) => widget.child;
}
