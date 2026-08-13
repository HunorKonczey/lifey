import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/cardio_track_point_repository.dart';

const _lastRunKey = 'cardio.trackPointMaintenance.lastRunAtEpochMs';

/// Prunes raw `CardioTrackPoints` older than 90 days (docs/cardio/
/// 54-cardio-gps-route-plan.md §5 point 5, C4a.6) — the closing polyline
/// each of those sessions already produced (C4a.6's own route-encoding step)
/// is safely on the server by then, so the raw fixes are pure local disk
/// weight with nothing left to feed (`route_encoder.dart`'s pipeline only
/// ever reads a session's trail once, right at `_finish()`).
///
/// [runIfDue] is meant to be called from every sync trigger
/// (`ConnectivitySyncController._refresh()` — startup, connectivity
/// restore, app resume, and its 60 s timer), same as the sync/pull calls
/// already made there. A plain `shared_preferences` timestamp — the same
/// device-local, non-secret, non-synced convention as `AutoPausePreferences`
/// — gates the actual delete to once a day, so the 60 s timer doesn't run a
/// full-table scan on every tick.
class TrackPointMaintenance {
  TrackPointMaintenance(this._repo);

  final CardioTrackPointRepository _repo;

  static const retention = Duration(days: 90);
  static const _minInterval = Duration(days: 1);

  Future<void> runIfDue() async {
    final prefs = await SharedPreferences.getInstance();
    final lastRunMs = prefs.getInt(_lastRunKey);
    final now = DateTime.now();
    if (lastRunMs != null &&
        now.difference(DateTime.fromMillisecondsSinceEpoch(lastRunMs)) < _minInterval) {
      return;
    }
    await _repo.deleteOlderThan(now.subtract(retention));
    await prefs.setInt(_lastRunKey, now.millisecondsSinceEpoch);
  }
}

final trackPointMaintenanceProvider = Provider<TrackPointMaintenance>((ref) {
  return TrackPointMaintenance(ref.watch(cardioTrackPointRepositoryProvider));
});
