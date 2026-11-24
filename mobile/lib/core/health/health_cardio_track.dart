import '../../features/workouts/domain/hr_zones.dart';
import '../../features/workouts/domain/route_encoder.dart';
import '../../features/workouts/domain/track_filter.dart';

/// One heart-rate reading the health store recorded during an imported
/// workout (docs/integrations/89 G1.8).
class HeartRateSample {
  const HeartRateSample(this.at, this.bpm);

  final DateTime at;
  final double bpm;
}

/// One GPS fix of an imported workout's route, as the health store hands it
/// over (`WORKOUT_ROUTE`, docs/integrations/89 G1.8).
class RouteLocation {
  const RouteLocation({
    required this.latitude,
    required this.longitude,
    required this.at,
    this.altitude,
  });

  final double latitude;
  final double longitude;
  final DateTime at;
  final double? altitude;
}

/// The longest stretch of time one heart-rate sample may stand for. Garmin
/// writes a sample every few seconds while it has a reading. A longer silence
/// is a lost reading (watch off the wrist, a pause), and stretching the last
/// beat over it would invent zone time. That time is left out, so the zone
/// panel shows the session as partially measured instead
/// (`HrZoneBreakdown.isPartial`).
const kHeartRateSampleMaxSpan = Duration(seconds: 30);

/// Seconds spent in each heart-rate zone, Z1…Z5, from the samples between
/// [start] and [end] (docs/integrations/89 G1.8).
///
/// Each sample covers the time until the next one, capped at [maxSpan]. The
/// last sample covers until [end], with the same cap. The zones are measured
/// against [maxHeartRate] with the same bands as the live screen
/// ([heartRateZone]).
///
/// Every interval lies inside [start]–[end] and none overlap, and seconds are
/// floored, so the five values never add up to more than the session lasted
/// (the invariant `HrZoneBreakdown` checks).
///
/// Returns null without a maximum heart rate (no birth date in the profile)
/// or without any sample inside the window. A null keeps the zone panel
/// hidden; five zeroes would claim a measurement that never happened.
List<int>? hrZoneSecondsFromSamples(
  List<HeartRateSample> samples, {
  required DateTime start,
  required DateTime end,
  required int? maxHeartRate,
  Duration maxSpan = kHeartRateSampleMaxSpan,
}) {
  if (maxHeartRate == null || maxHeartRate <= 0) return null;
  final inside = [
    for (final s in samples)
      if (!s.at.isBefore(start) && !s.at.isAfter(end) && s.bpm > 0) s,
  ]..sort((a, b) => a.at.compareTo(b.at));
  if (inside.isEmpty) return null;

  final millis = List<int>.filled(kHeartRateZoneCount, 0);
  for (var i = 0; i < inside.length; i++) {
    final until = i + 1 < inside.length ? inside[i + 1].at : end;
    var span = until.difference(inside[i].at);
    if (span > maxSpan) span = maxSpan;
    millis[heartRateZone(inside[i].bpm, maxHeartRate) - 1] += span.inMilliseconds;
  }
  final seconds = [for (final ms in millis) ms ~/ 1000];
  if (seconds.every((s) => s == 0)) return null;
  return seconds;
}

/// The stored route string for an imported workout's GPS fixes, with the
/// number of points it kept, or null when there is nothing to draw (docs/integrations/89 G1.8).
///
/// This is the same closing step a Lifey-recorded session runs
/// ([encodeRoute], docs/cardio/54 §5): split at signal gaps, Douglas–Peucker
/// simplify each segment at 5 m, then encode with altitude. The §4.2 accuracy
/// and speed gates are not run again: the watch has already filtered its own
/// track, and Health Connect leaves out the accuracy that the gates need.
///
/// Fixes are sorted by time, and coordinates no GPS reports are dropped:
/// out-of-range values, and the 0,0 a broken fix reads as.
///
/// An empty list returns null. That is what Health Connect gives without the
/// *Exercise routes* permission. Such a session imports without a route, and
/// that is not an error.
({String polyline, int pointCount})? routePolylineFromLocations(List<RouteLocation> locations) {
  final trail = [
    for (final l in locations)
      if (_isValidFix(l))
        TrackFilterTrailPoint(
          latitude: l.latitude,
          longitude: l.longitude,
          altitude: l.altitude,
          recordedAt: l.at,
        ),
  ]..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
  if (trail.length < 2) return null;
  final route = encodeRoute(trail);
  return route.polyline.isEmpty ? null : route;
}

bool _isValidFix(RouteLocation l) =>
    l.latitude.abs() <= 90 &&
    l.longitude.abs() <= 180 &&
    !(l.latitude == 0 && l.longitude == 0);

/// A route the health store returned, before it is matched to its workout.
class HealthWorkoutRoute {
  const HealthWorkoutRoute({
    required this.workoutUuid,
    required this.start,
    required this.end,
    required this.locations,
  });

  /// The workout the route belongs to, when the store says so. Health Connect
  /// always does (a route is part of its exercise session). HealthKit only
  /// does for routes Lifey wrote itself, so a Garmin route on iOS arrives
  /// without it.
  final String? workoutUuid;
  final DateTime start;
  final DateTime end;
  final List<RouteLocation> locations;
}

/// The fixes of the route that belongs to the workout [workoutUuid], which ran
/// from [start] to [end]. Empty when no route belongs to it.
///
/// A route naming the workout wins. A route without a workout id (HealthKit)
/// goes to the workout it overlaps in time the most. A route naming a
/// different workout is never taken.
List<RouteLocation> routeForWorkout(
  List<HealthWorkoutRoute> routes, {
  required String workoutUuid,
  required DateTime start,
  required DateTime end,
}) {
  for (final r in routes) {
    if (r.workoutUuid == workoutUuid && r.locations.isNotEmpty) return r.locations;
  }
  HealthWorkoutRoute? best;
  var bestOverlap = Duration.zero;
  for (final r in routes) {
    if (r.workoutUuid != null || r.locations.isEmpty) continue;
    final from = r.start.isAfter(start) ? r.start : start;
    final to = r.end.isBefore(end) ? r.end : end;
    final overlap = to.difference(from);
    if (overlap > bestOverlap) {
      best = r;
      bestOverlap = overlap;
    }
  }
  return best?.locations ?? const [];
}
