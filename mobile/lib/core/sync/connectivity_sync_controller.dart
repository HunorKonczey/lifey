import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/token_storage.dart';
import 'pull_engine.dart';
import 'sync_engine.dart';
import 'sync_engine_provider.dart';

/// Keeps the local cache in sync without the user having to pull-to-refresh.
///
/// Both halves of sync run on every trigger — startup, connectivity restore,
/// app foreground, and a lightweight periodic timer while the app stays
/// open:
/// - Draining the outbox ([SyncEngine.sync]).
/// - Refreshing from the server ([PullEngine.pullAll]), always *after* a
///   drain so a just-created row already carries its serverId before the
///   pull runs.
///
/// The periodic timer must also pull, not just push: after the first pull,
/// [PullEngine.pullAll] is a cheap delta query per entity (cursor-based), so
/// the cost is small — and without it, a change made on another client (e.g.
/// the web app) while this device stays foregrounded the whole time would
/// never show up until the app backgrounds/resumes or connectivity drops.
///
/// True background sync (while the app is fully closed) is out of scope
/// for this phase.
class ConnectivitySyncController with WidgetsBindingObserver {
  ConnectivitySyncController(
    this._syncEngine,
    this._pullEngine,
    this._tokenStorage, [
    Connectivity? connectivity,
  ]) : _connectivity = connectivity ?? Connectivity() {
    WidgetsBinding.instance.addObserver(this);
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(_onConnectivityChanged);
    _timer = Timer.periodic(_pollInterval, (_) => _refresh());
    unawaited(_refresh());
  }

  static const _pollInterval = Duration(seconds: 60);

  final SyncEngine _syncEngine;
  final PullEngine _pullEngine;
  final TokenStorage _tokenStorage;
  final Connectivity _connectivity;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  Timer? _timer;

  /// Starts `false` (unknown) — harmless either way, since the constructor
  /// already kicks off a refresh directly above regardless of this flag.
  bool _wasOffline = false;

  /// Every trigger (startup, connectivity restore, app resume, the periodic
  /// timer) fires unconditionally, logged in or not — there's no session to
  /// sync against until a token exists, so every one of these would just be
  /// a guaranteed batch of 401s (and, worse, a stale one landing after a
  /// fresh login can race the session — see AuthInterceptor). Skip outright
  /// while signed out.
  Future<bool> get _isSignedIn async => await _tokenStorage.readAccessToken() != null;

  Future<void> _refresh() async {
    if (!await _isSignedIn) return;
    try {
      await _syncEngine.sync();
      await _pullEngine.pullAll();
    } catch (_) {
      // Best-effort: a failed refresh (no connectivity, backend error) just
      // means the cache stays as-is until the next trigger.
    }
  }

  void _onConnectivityChanged(List<ConnectivityResult> results) {
    final isOffline = results.every((r) => r == ConnectivityResult.none);
    if (_wasOffline && !isOffline) {
      unawaited(_refresh());
    }
    _wasOffline = isOffline;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refresh());
    }
  }

  /// Drains the outbox and pulls everything from the server on demand —
  /// used right after login/register, since signing in doesn't itself fire
  /// a connectivity-restore or app-resume event.
  Future<void> refreshNow() => _refresh();

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _connectivitySubscription?.cancel();
    _timer?.cancel();
  }
}

/// Plain (non-autoDispose) provider: instantiated once via [LifeyApp] and
/// kept alive for the app's lifetime, same as [syncEngineProvider].
final connectivitySyncControllerProvider = Provider<ConnectivitySyncController>((ref) {
  final controller = ConnectivitySyncController(
    ref.watch(syncEngineProvider),
    ref.watch(pullEngineProvider),
    ref.watch(tokenStorageProvider),
  );
  ref.onDispose(controller.dispose);
  return controller;
});
