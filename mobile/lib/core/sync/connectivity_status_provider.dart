import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

bool _isOffline(List<ConnectivityResult> results) =>
    results.every((r) => r == ConnectivityResult.none);

/// Whether the device currently has no connectivity at all. Drives the
/// global offline banner — separate from [ConnectivitySyncController], which
/// owns its own `Connectivity` subscription to trigger syncs.
final isOfflineProvider = StreamProvider<bool>((ref) async* {
  final connectivity = Connectivity();
  yield _isOffline(await connectivity.checkConnectivity());
  yield* connectivity.onConnectivityChanged.map(_isOffline);
});
