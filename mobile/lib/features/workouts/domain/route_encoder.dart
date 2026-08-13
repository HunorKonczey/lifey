import 'polyline_codec.dart';
import 'track_filter.dart';
import 'track_simplify.dart';

/// The glue between a session's filtered GPS trail
/// ([TrackFilterAccumulator.trail]) and the single `cardio_details.route_polyline`
/// string (docs/cardio/54-cardio-gps-route-plan.md §5, C4a.6) — this is the
/// "záró feldolgozás" the plan assigns to this step.
///
/// The stored string is **not** a plain Google encoded polyline. Two things
/// this app needs that the plain format can't express on its own:
///
/// 1. **Signal-gap markers** (§4.3: "a rajzon szaggatott vonallal jelezzük").
///    A gap of more than [gapThreshold] between two consecutive trail points
///    means nothing passed the filter gates in between — real motion during
///    that stretch is unknown, so it must render dashed, not as a straight
///    line. Encoded as **separate segments**, joined by `;` — a character
///    the polyline alphabet (ASCII 63-126) never produces, so it's a safe,
///    unambiguous delimiter. `RoutePainter` draws each segment solid and
///    bridges consecutive segments with a dashed line.
/// 2. **Durable altitude** (D-C4.2: the polyline is the one thing every
///    device — and a re-opened session, once `CardioTrackPoints` are pruned
///    after 90 days — can read back). [encodePolyline3]/[decodePolyline3]
///    carry a third (altitude) channel per point precisely so the elevation
///    profile survives exactly as long as the route line does.
///
/// Each segment is independently Douglas-Peucker simplified
/// ([simplifyTrail]) before encoding — simplifying across a gap boundary
/// would compare spatially unrelated points, which isn't meaningful.
({String polyline, int pointCount}) encodeRoute(
  List<TrackFilterTrailPoint> trail, {
  double simplifyToleranceMeters = 5,
  Duration gapThreshold = const Duration(seconds: 60),
}) {
  if (trail.isEmpty) return (polyline: '', pointCount: 0);

  final segments = _splitOnGaps(trail, gapThreshold);
  final encodedSegments = <String>[];
  var pointCount = 0;
  for (final segment in segments) {
    final simplified = simplifyTrail(segment, toleranceMeters: simplifyToleranceMeters);
    pointCount += simplified.length;
    encodedSegments.add(encodePolyline3([
      for (final p in simplified) (p.latitude, p.longitude, p.altitude ?? 0),
    ]));
  }
  return (polyline: encodedSegments.join(';'), pointCount: pointCount);
}

/// Decodes a string produced by [encodeRoute] back into its segments —
/// `RoutePainter`'s input. An empty [polyline] (a session that never got any
/// GPS trail) decodes to an empty list, not a list containing one empty
/// segment.
List<List<(double lat, double lng, double alt)>> decodeRouteSegments(String polyline) {
  if (polyline.isEmpty) return const [];
  return [
    for (final segment in polyline.split(';'))
      if (segment.isNotEmpty) decodePolyline3(segment),
  ];
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
