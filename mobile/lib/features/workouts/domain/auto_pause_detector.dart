import 'dart:async';

import '../../../core/location/location_service.dart';

/// GPS-driven auto-pause (docs/cardio/53-cardio-mobile-plan.md §4.3): "Ha 15
/// másodpercig a sebesség < 0,5 m/s (és van GPS-jel), automatikus szünet;
/// mozgásra automatikus folytatás." Timer-driven — armed on a trustworthy
/// slow fix, fires unless cancelled by a faster one — for the same reason
/// `CardioSessionScreenState`'s weak-signal timer is (C4a.4): deterministic
/// under `flutter_test`'s fake-async clock, not a `DateTime.now()` poll.
/// Owns no session state itself; [onSustainedStop]/[onMotion] just report
/// what the raw fix stream implies, and the caller decides what to do with
/// that (docs/cardio/59-cardio-implementation-plan.md C4a.5a, Q-D3 —
/// on by default, uniformly across every DISTANCE activity type).
class AutoPauseDetector {
  AutoPauseDetector({
    required this.accuracyThresholdMeters,
    required this.onSustainedStop,
    required this.onMotion,
    this.speedThresholdMetersPerSecond = 0.5,
    this.delay = const Duration(seconds: 15),
  });

  final double accuracyThresholdMeters;
  final double speedThresholdMetersPerSecond;
  final Duration delay;

  /// Fires once speed has stayed under [speedThresholdMetersPerSecond] for
  /// [delay] straight, uninterrupted by a faster accepted fix. The caller
  /// decides what "stop" means here — e.g. a no-op if already paused for
  /// some other reason.
  final void Function() onSustainedStop;

  /// Fires on every accepted fix at/over the threshold, including the very
  /// first one after a stop (so a resume can be immediate) and even while
  /// nothing is currently paused — a harmless, idempotent signal either way.
  final void Function() onMotion;

  Timer? _timer;

  /// Feeds one raw fix through the same "és van GPS-jel" accuracy gate
  /// `track_filter.dart` uses (§4.2) — an inaccurate fix's speed reading
  /// isn't trustworthy enough to act on. A `null` speed (geolocator can't
  /// always report one) is ignored entirely rather than guessed at, same as
  /// a `null` accuracy is never rejected there.
  void addFix(LocationFix fix) {
    final accuracy = fix.accuracy;
    if (accuracy != null && accuracy > accuracyThresholdMeters) return;
    final speed = fix.speed;
    if (speed == null) return;

    if (speed >= speedThresholdMetersPerSecond) {
      _timer?.cancel();
      _timer = null;
      onMotion();
      return;
    }
    if (_timer != null) return; // already counting down toward onSustainedStop
    _timer = Timer(delay, () {
      _timer = null;
      onSustainedStop();
    });
  }

  /// Stops any pending countdown without firing — tracking itself stopped
  /// (manual pause, GPS lost, session finished), so there's nothing left to
  /// detect until it resumes.
  void reset() {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() => _timer?.cancel();
}
