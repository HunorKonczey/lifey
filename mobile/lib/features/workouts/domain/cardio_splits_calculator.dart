import 'track_filter.dart';
import 'workout_session.dart';

/// Per-km splits from a session's filtered GPS trail (docs/cardio/
/// 54-cardio-gps-route-plan.md §5 point 4: "a splitek is ekkor számolódnak, a
/// szűrt pontokból") — deliberately the **filtered**, not the further
/// Douglas-Peucker-simplified, trail: a split boundary needs the real
/// distance/time resolution the raw filtered points give, where
/// `route_encoder.dart`'s simplification is only about what looks
/// indistinguishable when drawn.
///
/// Walks the trail's cumulative haversine distance and linearly interpolates
/// the exact time/altitude at each 1000 m crossing, so split duration/
/// elevation aren't rounded to whichever trail point happened to land near
/// the boundary. The final, sub-1000m remainder (docs/cardio/
/// 52-cardio-domain-backend-plan.md §2.3: "az utolsó split rövidebb") is
/// always emitted as its own last split, even for a session shorter than one
/// km. [CardioSplit.avgHeartRate] is always null — this app has no
/// per-point heart-rate source yet.
List<CardioSplit> computeSplits(List<TrackFilterTrailPoint> trail) {
  if (trail.length < 2) return const [];
  const splitDistanceMeters = 1000.0;
  final splits = <CardioSplit>[];

  var cumulativeDistance = 0.0;
  var nextBoundary = splitDistanceMeters;
  var splitStartTime = trail.first.recordedAt;
  var splitStartAltitude = trail.first.altitude;
  var splitIndex = 0;

  for (var i = 1; i < trail.length; i++) {
    final prev = trail[i - 1];
    final curr = trail[i];
    final segmentDistance =
        haversineMeters(prev.latitude, prev.longitude, curr.latitude, curr.longitude);
    if (segmentDistance <= 0) continue;
    final segmentStartDistance = cumulativeDistance;

    // A while, not an if: a sparse trail's single segment could in theory
    // span more than one km boundary.
    while (nextBoundary <= segmentStartDistance + segmentDistance) {
      final ratio = ((nextBoundary - segmentStartDistance) / segmentDistance).clamp(0.0, 1.0);
      final elapsedMs = curr.recordedAt.difference(prev.recordedAt).inMilliseconds;
      final boundaryTime = prev.recordedAt.add(Duration(milliseconds: (elapsedMs * ratio).round()));
      final boundaryAltitude = _interpolateAltitude(prev.altitude, curr.altitude, ratio);

      splits.add(CardioSplit(
        splitIndex: splitIndex,
        distanceMeters: splitDistanceMeters,
        durationSeconds: boundaryTime.difference(splitStartTime).inSeconds,
        elevationDeltaM: _elevationDelta(splitStartAltitude, boundaryAltitude),
      ));

      splitIndex++;
      splitStartTime = boundaryTime;
      splitStartAltitude = boundaryAltitude;
      nextBoundary += splitDistanceMeters;
    }

    cumulativeDistance = segmentStartDistance + segmentDistance;
  }

  final remaining = cumulativeDistance - splitIndex * splitDistanceMeters;
  if (remaining > 0.5) {
    splits.add(CardioSplit(
      splitIndex: splitIndex,
      distanceMeters: remaining,
      durationSeconds: trail.last.recordedAt.difference(splitStartTime).inSeconds,
      elevationDeltaM: _elevationDelta(splitStartAltitude, trail.last.altitude),
    ));
  }

  return splits;
}

/// Null only when both ends are null — a single missing altitude reading
/// still lets the other one carry through, same "don't discard a whole
/// window over one gap" spirit as `TrackFilterAccumulator._applyAltitude`.
double? _interpolateAltitude(double? a, double? b, double ratio) {
  if (a == null || b == null) return a ?? b;
  return a + (b - a) * ratio;
}

double? _elevationDelta(double? start, double? end) {
  if (start == null || end == null) return null;
  return end - start;
}
