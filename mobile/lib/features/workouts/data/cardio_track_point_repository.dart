import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/local_db/app_database.dart';
import '../../../core/local_db/database_provider.dart';
import '../../../core/location/location_service.dart';
import '../domain/cardio_track_point.dart';

/// Raw GPS track-point storage for a live cardio session
/// (docs/cardio/54-cardio-gps-route-plan.md §4.1, C4a.3) — deliberately its
/// own small repository, not folded into `WorkoutSessionRepository`: this
/// table never syncs and never appears in a create/update payload, so it
/// has nothing in common with that repository's outbox-driven write model.
/// Its own write pattern is the opposite shape too — frequent, tiny,
/// immediate inserts from a live position stream, not an occasional
/// full-session upsert.
class CardioTrackPointRepository {
  CardioTrackPointRepository(this._db);

  final AppDatabase _db;

  /// Writes [fix] immediately — not buffered — so a killed app loses at
  /// most one point. [seq] is the caller's responsibility (see
  /// `CardioSessionScreenState._nextTrackPointSeq`): the natural place to
  /// track "next sequence number" is the one live subscriber processing the
  /// position stream in order, not a query-then-insert race here.
  Future<void> addPoint(String sessionClientId, int seq, LocationFix fix) {
    return _db.into(_db.cardioTrackPoints).insert(
          CardioTrackPointsCompanion.insert(
            sessionClientId: sessionClientId,
            seq: seq,
            latitude: fix.latitude,
            longitude: fix.longitude,
            recordedAt: fix.recordedAt,
            altitude: Value(fix.altitude),
            accuracy: Value(fix.accuracy),
            speed: Value(fix.speed),
          ),
        );
  }

  /// How many points [sessionClientId] already has — used once, at
  /// `CardioSessionScreen.initState`, to resume `seq` numbering correctly
  /// after an app kill mid-session (never polled repeatedly; the live
  /// screen tracks the running count itself from then on).
  Future<int> pointCount(String sessionClientId) async {
    final countExp = _db.cardioTrackPoints.seq.count();
    final query = _db.selectOnly(_db.cardioTrackPoints)
      ..addColumns([countExp])
      ..where(_db.cardioTrackPoints.sessionClientId.equals(sessionClientId));
    final row = await query.getSingle();
    return row.read(countExp) ?? 0;
  }

  /// All points for [sessionClientId], oldest first (`seq` order) — the
  /// shape `track_filter.dart` (C4a.4) and the closing polyline/`RoutePainter`
  /// pipeline (C4a.6) both need.
  Future<List<CardioTrackPoint>> pointsForSession(String sessionClientId) async {
    final rows = await (_db.select(_db.cardioTrackPoints)
          ..where((t) => t.sessionClientId.equals(sessionClientId))
          ..orderBy([(t) => OrderingTerm.asc(t.seq)]))
        .get();
    return [for (final row in rows) _fromRow(row)];
  }

  /// Deletes every point for [sessionClientId] — called from
  /// `WorkoutSessionRepository.delete` (immediate, never-synced session) and
  /// `entity_sync_config.dart`'s `_cleanupWorkoutSessionChildren` (once a
  /// synced session's server-side delete is confirmed).
  Future<void> deleteForSession(String sessionClientId) {
    return (_db.delete(_db.cardioTrackPoints)
          ..where((t) => t.sessionClientId.equals(sessionClientId)))
        .go();
  }

  CardioTrackPoint _fromRow(CardioTrackPointRow row) => CardioTrackPoint(
        seq: row.seq,
        latitude: row.latitude,
        longitude: row.longitude,
        recordedAt: row.recordedAt,
        altitude: row.altitude,
        accuracy: row.accuracy,
        speed: row.speed,
      );
}

final cardioTrackPointRepositoryProvider = Provider<CardioTrackPointRepository>((ref) {
  return CardioTrackPointRepository(ref.watch(appDatabaseProvider));
});
