import 'track_filter.dart';

/// One vertex of an [ElevationProfile] — a real GPS fix, plotted against how
/// far into the route it sits rather than a synthetic per-point index
/// (docs/cardio/60 C8.3: the whole point of this file is replacing the old
/// "one point per second" X axis with the actual cumulative distance).
class ElevationProfilePoint {
  const ElevationProfilePoint({
    required this.cumulativeDistanceMeters,
    required this.altitudeMeters,
    required this.elapsedSeconds,
  });

  final double cumulativeDistanceMeters;
  final double altitudeMeters;

  /// Time since the very first point of the whole trail — not per segment,
  /// so it reads as "how far into the hike" even for a point in the second
  /// or third gap-free stretch.
  final int elapsedSeconds;
}

/// A real signal gap between two segments (docs/cardio/54-cardio-gps-route-plan.md
/// §4.3) — nothing passed the filter gates for more than the threshold, so
/// what happened between [startDistanceMeters] and [endDistanceMeters] is
/// unknown, not flat. The width is the straight-line distance between the
/// last point before the gap and the first point after it — the same
/// approximation `route_painter.dart` already draws as a dashed bridge on
/// the map, carried over here as the gap band's proportional width (M40:
/// "a kieső szakasz szélessége arányos a távval").
class ElevationProfileGap {
  const ElevationProfileGap({required this.startDistanceMeters, required this.endDistanceMeters});

  final double startDistanceMeters;
  final double endDistanceMeters;

  double get widthMeters => endDistanceMeters - startDistanceMeters;
}

/// A full route's elevation profile: one or more gap-free [segments] (each a
/// polyline of real altitude readings), the [gaps] between them, and the
/// single highest point across the whole thing.
class ElevationProfile {
  const ElevationProfile({
    required this.segments,
    required this.gaps,
    required this.totalDistanceMeters,
    required this.peak,
  });

  final List<List<ElevationProfilePoint>> segments;
  final List<ElevationProfileGap> gaps;
  final double totalDistanceMeters;

  /// Null only when every point in the trail (across every segment) had no
  /// altitude reading — a device with no barometer/GPS-altitude source. The
  /// widget gates the whole card on this the same way it already gates on
  /// `elevationGainMeters` today.
  final ElevationProfilePoint? peak;

  /// Every vertex across every segment, in playback order — what the chart
  /// widget hit-tests a tap against (a tap always lands on the nearest real
  /// point, on whichever side of a gap it's closer to; there is no vertex
  /// *inside* a gap to select).
  List<ElevationProfilePoint> get allPoints => [for (final s in segments) ...s];
}

/// Builds an [ElevationProfile] from a session's filtered local track
/// [trail] (docs/cardio/60 C8.3) — the **local, still-on-device** points, not
/// the simplified/lossy `route_polyline` the old approximation used. Null
/// when there's nothing to build one from: fewer than two points, or no
/// point in the trail carries an altitude reading at all.
///
/// Gap detection mirrors `route_encoder.dart`'s `encodeRoute` and
/// `best_effort_calculator.dart`'s window search — same threshold, same
/// "cut the trail, don't bridge it with a straight line pretending to be
/// real motion" rule (docs/cardio/54 §4.3). Each of those three files keeps
/// its own copy of this split rather than sharing one: the codebase's own
/// precedent (this is the third), since each caller wants a differently
/// shaped result from the same three lines of logic.
///
/// A point with no altitude reading is simply left out of its segment's
/// vertex list — its horizontal distance still counts toward the running
/// total, so the segment's line just connects across it, the same "one
/// missing reading doesn't discard the rest" choice
/// `cardio_splits_calculator.dart`'s `_interpolateAltitude` makes.
ElevationProfile? buildElevationProfile(
  List<TrackFilterTrailPoint> trail, {
  Duration gapThreshold = const Duration(seconds: 60),
}) {
  if (trail.length < 2) return null;
  if (trail.every((p) => p.altitude == null)) return null;

  final rawSegments = _splitOnGaps(trail, gapThreshold);
  final segments = <List<ElevationProfilePoint>>[];
  final gaps = <ElevationProfileGap>[];
  ElevationProfilePoint? peak;

  final startTime = trail.first.recordedAt;
  var cumulativeDistance = 0.0;
  TrackFilterTrailPoint? previousSegmentEnd;

  for (final rawSegment in rawSegments) {
    if (previousSegmentEnd != null) {
      final bridgeStart = cumulativeDistance;
      cumulativeDistance += haversineMeters(
        previousSegmentEnd.latitude,
        previousSegmentEnd.longitude,
        rawSegment.first.latitude,
        rawSegment.first.longitude,
      );
      gaps.add(ElevationProfileGap(
        startDistanceMeters: bridgeStart,
        endDistanceMeters: cumulativeDistance,
      ));
    }

    final segmentPoints = <ElevationProfilePoint>[];
    for (var i = 0; i < rawSegment.length; i++) {
      final point = rawSegment[i];
      if (i > 0) {
        final prev = rawSegment[i - 1];
        cumulativeDistance +=
            haversineMeters(prev.latitude, prev.longitude, point.latitude, point.longitude);
      }
      final altitude = point.altitude;
      if (altitude == null) continue;
      final vertex = ElevationProfilePoint(
        cumulativeDistanceMeters: cumulativeDistance,
        altitudeMeters: altitude,
        elapsedSeconds: point.recordedAt.difference(startTime).inSeconds,
      );
      segmentPoints.add(vertex);
      if (peak == null || vertex.altitudeMeters > peak.altitudeMeters) peak = vertex;
    }
    segments.add(segmentPoints);
    previousSegmentEnd = rawSegment.last;
  }

  if (peak == null) return null;

  return ElevationProfile(
    segments: segments,
    gaps: gaps,
    totalDistanceMeters: cumulativeDistance,
    peak: peak,
  );
}

List<List<TrackFilterTrailPoint>> _splitOnGaps(
  List<TrackFilterTrailPoint> trail,
  Duration gapThreshold,
) {
  final segments = <List<TrackFilterTrailPoint>>[];
  var current = <TrackFilterTrailPoint>[trail.first];
  for (var i = 1; i < trail.length; i++) {
    final gap = trail[i].recordedAt.difference(trail[i - 1].recordedAt);
    if (gap > gapThreshold) {
      segments.add(current);
      current = [trail[i]];
    } else {
      current.add(trail[i]);
    }
  }
  segments.add(current);
  return segments;
}
