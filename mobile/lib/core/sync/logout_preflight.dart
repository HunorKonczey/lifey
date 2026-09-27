import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../local_db/database_provider.dart';
import 'sync_engine_provider.dart';

/// What logging out would do to the changes that have not reached the server.
class LogoutPlan {
  const LogoutPlan({required this.unsynced, required this.online});

  /// Queued changes in the outbox (of any status: pending, failed, in flight).
  final int unsynced;

  /// Whether the device can reach the network right now.
  final bool online;

  /// Everything is already on the server — nothing to upload, nothing to lose.
  bool get isClean => unsynced == 0;

  /// There are queued changes and they can be sent before the data is wiped.
  bool get willUpload => unsynced > 0 && online;

  /// There are queued changes and no connection to send them over: logging out
  /// now loses them.
  bool get willLose => unsynced > 0 && !online;
}

/// Tries to save the outbox before a logout wipes the local database
/// (docs/redesign/77-mobile-redesign-plan.md R5.6), and tells the dialog the
/// truth about what is about to happen.
///
/// Logging out clears the whole local database, unsynced changes included, so
/// "your data is removed" used to be the only warning. Now, when the device is
/// online, one drain of the outbox runs first — bounded by [timeout], so a bad
/// connection cannot hold the logout hostage — and when it is not, the person
/// is told how many changes would be lost.
///
/// The three collaborators are functions so the rules are unit-testable
/// without a database or a network.
class LogoutPreflight {
  LogoutPreflight({
    required this.pendingCount,
    required this.isOnline,
    required this.sync,
    this.timeout = const Duration(seconds: 10),
  });

  final Future<int> Function() pendingCount;
  final Future<bool> Function() isOnline;
  final Future<void> Function() sync;
  final Duration timeout;

  Future<LogoutPlan> plan() async => LogoutPlan(unsynced: await pendingCount(), online: await isOnline());

  /// One drain of the outbox when online; how many changes are still queued
  /// afterwards (0 = everything went up). Never throws: whatever is left is
  /// reported, not raised — the logout goes on either way.
  Future<int> flush() async {
    if (await pendingCount() == 0) return 0;
    if (await isOnline()) {
      try {
        await sync().timeout(timeout);
      } catch (_) {
        // A slow or failing upload does not block the logout; what remains is
        // counted below.
      }
    }
    return pendingCount();
  }
}

final logoutPreflightProvider = Provider<LogoutPreflight>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final engine = ref.watch(syncEngineProvider);
  return LogoutPreflight(
    pendingCount: () async {
      final rows = await db.select(db.pendingOperations).get();
      return rows.length;
    },
    isOnline: () async {
      final results = await Connectivity().checkConnectivity();
      return !results.every((r) => r == ConnectivityResult.none);
    },
    sync: engine.sync,
  );
});
