import 'track_filter.dart';
import 'workout_session.dart';

/// One waypoint, enriched with the distance/elapsed-time it doesn't itself
/// carry (docs/cardio/60 C8.4) — computed by matching it against the
/// session's own local track, the same source the elevation profile (C8.3)
/// reads from. [distanceMeters]/[elapsedSeconds] are null when [trail] is
/// empty (the local track is gone — pruned after 90 days, or a different
/// device); [altitudeMeters] falls back to the waypoint's own stored value
/// in that case, since that one *is* always synced (docs/cardio/60 C8.1).
class MatchedWaypoint {
  const MatchedWaypoint({
    required this.waypoint,
    this.distanceMeters,
    this.elapsedSeconds,
    this.altitudeMeters,
  });

  final CardioWaypoint waypoint;
  final double? distanceMeters;
  final int? elapsedSeconds;
  final double? altitudeMeters;
}

/// Matches each of [waypoints] against the nearest point (by straight-line
/// distance) in [trail], reading that point's cumulative distance and
/// elapsed time — a waypoint has no track-point reference of its own (V71
/// stores only the lat/lng/altitude of the moment it was marked), so the
/// nearest local fix is the closest honest answer. Returns the waypoints in
/// their own [CardioWaypoint.waypointIndex] order regardless of [trail]'s
/// order (a waypoint marked mid-hike can be geographically nearest to a
/// track point recorded before a later one, e.g. an out-and-back route).
List<MatchedWaypoint> matchWaypointsToTrail(
  List<CardioWaypoint> waypoints,
  List<TrackFilterTrailPoint> trail,
) {
  if (waypoints.isEmpty) return const [];
  final ordered = [...waypoints]..sort((a, b) => a.waypointIndex.compareTo(b.waypointIndex));
  if (trail.isEmpty) {
    return [for (final w in ordered) MatchedWaypoint(waypoint: w, altitudeMeters: w.altitudeMeters)];
  }

  final startTime = trail.first.recordedAt;
  final cumulativeDistance = List<double>.filled(trail.length, 0);
  for (var i = 1; i < trail.length; i++) {
    cumulativeDistance[i] = cumulativeDistance[i - 1] +
        haversineMeters(
          trail[i - 1].latitude,
          trail[i - 1].longitude,
          trail[i].latitude,
          trail[i].longitude,
        );
  }

  return [
    for (final w in ordered)
      _matchOne(w, trail, cumulativeDistance, startTime),
  ];
}

MatchedWaypoint _matchOne(
  CardioWaypoint waypoint,
  List<TrackFilterTrailPoint> trail,
  List<double> cumulativeDistance,
  DateTime startTime,
) {
  var bestIndex = 0;
  var bestDelta = haversineMeters(
    waypoint.latitude,
    waypoint.longitude,
    trail[0].latitude,
    trail[0].longitude,
  );
  for (var i = 1; i < trail.length; i++) {
    final delta = haversineMeters(
      waypoint.latitude,
      waypoint.longitude,
      trail[i].latitude,
      trail[i].longitude,
    );
    if (delta < bestDelta) {
      bestDelta = delta;
      bestIndex = i;
    }
  }
  final nearest = trail[bestIndex];
  return MatchedWaypoint(
    waypoint: waypoint,
    distanceMeters: cumulativeDistance[bestIndex],
    elapsedSeconds: nearest.recordedAt.difference(startTime).inSeconds,
    altitudeMeters: nearest.altitude ?? waypoint.altitudeMeters,
  );
}
