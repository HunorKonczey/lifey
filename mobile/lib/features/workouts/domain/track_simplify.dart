import 'dart:math' as math;

import 'track_filter.dart';

/// Douglas–Peucker simplification of a filtered GPS trail
/// (docs/cardio/54-cardio-gps-route-plan.md §5 point 1: "~5 m tűrés",
/// "jellemzően a pontok 10-20%-a marad, a rajz szemre azonos") — part of
/// C4a.6's closing pipeline, run once per gap-segment by `route_encoder.dart`
/// (never across a segment boundary, since points on either side of a gap
/// aren't spatially continuous anyway).
///
/// Operates on [TrackFilterTrailPoint] (not raw lat/lng) and keeps every
/// field of the points it decides to keep — the surviving points still need
/// their [TrackFilterTrailPoint.altitude] (elevation profile) and
/// [TrackFilterTrailPoint.recordedAt] (nothing downstream reads this off the
/// *simplified* list today, but keeping the full type avoids yet another
/// lossy conversion step).
///
/// Distances are computed in a local, planar meters projection (not
/// haversine-per-candidate — that would be both slower and not what
/// "perpendicular distance from a line" even means on a sphere at this
/// tolerance). One degree of longitude is scaled by `cos(latitude)` relative
/// to one degree of latitude — accurate enough at track-length scales
/// (kilometers), zero new dependency, matching `track_filter.dart`'s own
/// haversine-only approach.
List<TrackFilterTrailPoint> simplifyTrail(
  List<TrackFilterTrailPoint> points, {
  double toleranceMeters = 5,
}) {
  if (points.length < 3) return points;

  final projector = _LocalProjector(points);
  final projected = [for (final p in points) projector.project(p)];
  final keep = List<bool>.filled(points.length, false);
  keep[0] = true;
  keep[points.length - 1] = true;
  _simplifyRange(projected, 0, points.length - 1, toleranceMeters, keep);

  return [
    for (var i = 0; i < points.length; i++)
      if (keep[i]) points[i],
  ];
}

void _simplifyRange(
  List<_Point2D> projected,
  int startIndex,
  int endIndex,
  double toleranceMeters,
  List<bool> keep,
) {
  if (endIndex <= startIndex + 1) return;

  final start = projected[startIndex];
  final end = projected[endIndex];
  var maxDistance = -1.0;
  var maxIndex = -1;
  for (var i = startIndex + 1; i < endIndex; i++) {
    final distance = _perpendicularDistance(projected[i], start, end);
    if (distance > maxDistance) {
      maxDistance = distance;
      maxIndex = i;
    }
  }

  if (maxDistance > toleranceMeters) {
    keep[maxIndex] = true;
    _simplifyRange(projected, startIndex, maxIndex, toleranceMeters, keep);
    _simplifyRange(projected, maxIndex, endIndex, toleranceMeters, keep);
  }
}

/// Perpendicular distance from [point] to the infinite line through [start]
/// and [end] — the classic Douglas-Peucker metric. Falls back to the
/// straight-line distance to [start] when [start] and [end] coincide (a
/// degenerate, zero-length "line").
double _perpendicularDistance(_Point2D point, _Point2D start, _Point2D end) {
  final dx = end.x - start.x;
  final dy = end.y - start.y;
  final lengthSquared = dx * dx + dy * dy;
  if (lengthSquared == 0) {
    return math.sqrt(
      (point.x - start.x) * (point.x - start.x) + (point.y - start.y) * (point.y - start.y),
    );
  }
  // |cross product| / |line vector| = perpendicular distance.
  final cross = (point.x - start.x) * dy - (point.y - start.y) * dx;
  return cross.abs() / math.sqrt(lengthSquared);
}

class _Point2D {
  const _Point2D(this.x, this.y);
  final double x;
  final double y;
}

/// Equirectangular local projection centered on [points]' average latitude —
/// good enough at track-length scales, and only ever compared against other
/// points from the same projector, so a small, constant systematic distortion
/// cancels out.
class _LocalProjector {
  _LocalProjector(List<TrackFilterTrailPoint> points)
      : _metersPerDegreeLon = _metersPerDegreeLat *
            math.cos(_averageLatitude(points) * math.pi / 180);

  static const _metersPerDegreeLat = 111320.0;
  final double _metersPerDegreeLon;

  static double _averageLatitude(List<TrackFilterTrailPoint> points) {
    var sum = 0.0;
    for (final p in points) {
      sum += p.latitude;
    }
    return sum / points.length;
  }

  _Point2D project(TrackFilterTrailPoint point) => _Point2D(
        point.longitude * _metersPerDegreeLon,
        point.latitude * _metersPerDegreeLat,
      );
}
