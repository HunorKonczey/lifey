import 'dart:math' as math;

import '../../../core/location/location_service.dart';

/// The gates and smoothing docs/cardio/54-cardio-gps-route-plan.md §4.2
/// applies to a raw GPS stream before it's trusted for distance/elevation —
/// a nyers stream 10-15%-kal is túlbecsülheti a távot szűrés nélkül. Pure,
/// dependency-free functions/state, so this is testable against fixed
/// sample tracks without any device or `LocationService` implementation
/// (docs/cardio/59-cardio-implementation-plan.md C4a.4's kész-ha: "Rögzített
/// minta-nyomvonalakon a táv ≤ 5% hibával").

/// Points closer together than this don't move the cumulative distance —
/// GPS jitter while stationary (§4.2 step 3).
const double kMinDisplacementMeters = 3;

/// Moving-average window for altitude smoothing (§4.2 step 4).
const int kAltitudeSmoothingWindow = 5;

/// Only a smoothed-altitude monotonic climb summing to more than this counts
/// toward elevation gain — otherwise a flat walk would show "200 m" of gain
/// from sensor noise alone (§4.2 step 4).
const double kElevationGainThresholdMeters = 1;

/// The accuracy/speed thresholds a DISTANCE-family activity type filters its
/// raw fixes against (§4.2's per-activity numbers).
class TrackFilterProfile {
  const TrackFilterProfile({
    required this.accuracyThresholdMeters,
    required this.maxSpeedMetersPerSecond,
  });

  final double accuracyThresholdMeters;
  final double maxSpeedMetersPerSecond;
}

/// §4.2's numbers, by activity type. Hiking's speed ceiling isn't given
/// explicitly in the doc — it reuses running's (30 km/h) rather than a
/// slower hiking-specific number, matching how `locationTrackingProfileFor`
/// (C4a.3) already groups hiking with running (both `precise`), not with
/// walking: a hiker descending or covering a runnable stretch shouldn't have
/// real motion rejected as an implausible jump.
TrackFilterProfile trackFilterProfileFor(String activityType) {
  return switch (activityType) {
    'WALKING' => const TrackFilterProfile(
        accuracyThresholdMeters: 20,
        maxSpeedMetersPerSecond: 8 * 1000 / 3600,
      ),
    'HIKING' => const TrackFilterProfile(
        accuracyThresholdMeters: 30,
        maxSpeedMetersPerSecond: 30 * 1000 / 3600,
      ),
    // RUNNING, and any other DISTANCE-family fallback.
    _ => const TrackFilterProfile(
        accuracyThresholdMeters: 20,
        maxSpeedMetersPerSecond: 30 * 1000 / 3600,
      ),
  };
}

/// Great-circle distance between two coordinates, meters (§4.2 step 5).
double haversineMeters(double lat1, double lon1, double lat2, double lon2) {
  const earthRadiusMeters = 6371000.0;
  final dLat = _degToRad(lat2 - lat1);
  final dLon = _degToRad(lon2 - lon1);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_degToRad(lat1)) *
          math.cos(_degToRad(lat2)) *
          math.sin(dLon / 2) *
          math.sin(dLon / 2);
  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return earthRadiusMeters * c;
}

double _degToRad(double deg) => deg * math.pi / 180;

/// Feeds a raw [LocationFix] stream through §4.2's gates one point at a
/// time, in the doc's own order (accuracy → speed → displacement), and
/// accumulates the results — a running haversine distance sum and a
/// smoothed elevation gain. Stateful and incremental on purpose: both the
/// live session screen (one fix at a time, as it arrives) and a cold-start
/// replay of an existing `CardioTrackPoints` log (C4a.3 — same points, fed
/// in the same seq order) need the identical result, so there's exactly one
/// code path for both.
class TrackFilterAccumulator {
  TrackFilterAccumulator(this.profile);

  final TrackFilterProfile profile;

  LocationFix? _lastAccepted;
  DateTime? _lastSignalAt;
  double _distanceMeters = 0;
  double _committedGain = 0;
  double _pendingAscent = 0;
  final List<double> _altitudeWindow = [];
  double? _lastSmoothedAltitude;

  double get distanceMeters => _distanceMeters;

  /// Committed monotonic climbs plus whatever's still accumulating in the
  /// current upward run — see [_applyAltitude]'s doc for why the pending
  /// part isn't dropped just because the track hasn't turned downward yet
  /// (or never does, if the session ends mid-climb).
  double get elevationGainMeters =>
      _committedGain + (_pendingAscent > kElevationGainThresholdMeters ? _pendingAscent : 0);

  /// When the last fix that passed the accuracy gate arrived — regardless of
  /// whether it moved the distance (speed/displacement gates) or not. This
  /// is the "is GPS actually alive right now" signal `CardioSessionScreen`'s
  /// weak-signal UI (M10) watches, deliberately looser than "did the
  /// distance change": a device sitting at a red light can pass minutes of
  /// perfectly good, perfectly stationary fixes.
  DateTime? get lastSignalAt => _lastSignalAt;

  /// Runs [fix] through the accuracy → speed → displacement gates and
  /// updates the running totals. Returns whether [fix] passed the accuracy
  /// gate — the caller's cue to treat this as "a signal was just received",
  /// even when the point didn't end up moving the distance.
  bool addFix(LocationFix fix) {
    final accuracy = fix.accuracy;
    if (accuracy != null && accuracy > profile.accuracyThresholdMeters) {
      return false;
    }
    _lastSignalAt = fix.recordedAt;
    _applyAltitude(fix.altitude);

    final prev = _lastAccepted;
    if (prev == null) {
      _lastAccepted = fix;
      return true;
    }

    final elapsedSeconds = fix.recordedAt.difference(prev.recordedAt).inMilliseconds / 1000;
    // A non-positive gap can't validate a speed (or would imply an infinite
    // one) — keep the old reference point rather than risk dividing by ~0.
    if (elapsedSeconds <= 0) return true;

    final rawDistance =
        haversineMeters(prev.latitude, prev.longitude, fix.latitude, fix.longitude);
    final impliedSpeed = rawDistance / elapsedSeconds;
    if (impliedSpeed > profile.maxSpeedMetersPerSecond) {
      // Implausible jump — rejected; the reference point is left unchanged
      // so the next fix is still judged against the last point actually
      // trusted, not against this rejected one.
      return true;
    }

    if (rawDistance >= kMinDisplacementMeters) {
      _distanceMeters += rawDistance;
      _lastAccepted = fix;
    }
    // else: GPS jitter while stationary — not added, and the reference
    // point deliberately isn't advanced either, so slow, genuine movement
    // spread across several sub-threshold fixes still accumulates against
    // the original reference instead of resetting on every fix.
    return true;
  }

  /// §4.2 step 4: a 5-point moving average, then only counts a smoothed
  /// climb toward [elevationGainMeters] once its *unbroken upward run*
  /// exceeds 1 m — not each individual step, which would let a string of
  /// sub-meter noisy upward wobbles slip through even after smoothing. A run
  /// still in progress when the track turns back down (or the session ends)
  /// is flushed by [elevationGainMeters]'s own getter, not stored here.
  void _applyAltitude(double? altitude) {
    if (altitude == null) return;
    _altitudeWindow.add(altitude);
    if (_altitudeWindow.length > kAltitudeSmoothingWindow) {
      _altitudeWindow.removeAt(0);
    }
    final smoothed = _altitudeWindow.reduce((a, b) => a + b) / _altitudeWindow.length;
    final prevSmoothed = _lastSmoothedAltitude;
    if (prevSmoothed != null) {
      final delta = smoothed - prevSmoothed;
      if (delta > 0) {
        _pendingAscent += delta;
      } else {
        if (_pendingAscent > kElevationGainThresholdMeters) {
          _committedGain += _pendingAscent;
        }
        _pendingAscent = 0;
      }
    }
    _lastSmoothedAltitude = smoothed;
  }
}
