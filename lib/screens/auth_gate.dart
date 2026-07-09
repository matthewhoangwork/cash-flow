import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';
import '../sync/sync_lifecycle_observer.dart';
import 'auth_screen.dart';
import 'home_screen.dart';
import 'home_skeleton.dart';

/// Shows [AuthScreen] until a Supabase session exists, then the app itself
/// wrapped in [SyncLifecycleObserver] — covers both a fresh sign-in and app
/// start with an already-persisted session, since both surface as the same
/// `AuthState` stream event.
///
/// Local data (Hive, Supabase session) is already loaded by the time this
/// mounts, so [authStateProvider] resolves almost instantly and the skeleton
/// would otherwise flash for a single frame. [_minSkeletonDuration] holds
/// the skeleton up for a beat on cold start so it actually reads as loading.
class AuthGate extends ConsumerStatefulWidget {
  const AuthGate({super.key});

  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate> {
  static const _minSkeletonDuration = Duration(milliseconds: 1200);

  bool _minDurationElapsed = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(_minSkeletonDuration, () {
      if (mounted) setState(() => _minDurationElapsed = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    if (!_minDurationElapsed) return const HomeSkeleton();
    return authState.when(
      data: (state) => state.session != null
          ? const SyncLifecycleObserver(child: HomeScreen())
          : const AuthScreen(),
      loading: () => const HomeSkeleton(),
      error: (_, _) => const AuthScreen(),
    );
  }
}
