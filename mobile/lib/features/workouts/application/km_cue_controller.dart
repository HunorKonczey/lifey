/// Fires once per completed distance unit of a live DISTANCE session — the
/// kilometre (or mile) feedback of docs/cardio/61 §2 M35 / docs/cardio/60
/// C6.6.
///
/// Owns no session state and performs no effect itself: it converts a running
/// distance into "you just completed unit N" and hands that to [onCue], the
/// same shape `AutoPauseDetector` uses for its own signals. That keeps the
/// boundary maths testable without a vibrator, and keeps the decision about
/// *what* a cue does (buzz, chime, neither) with the screen that reads the
/// user's switches.
///
/// **The unit is whichever one the profile is set to**, passed in as
/// [unitMeters]. There is deliberately no second place to choose it — see
/// M35's closing line: two places to set a unit is a guaranteed bug report.
class KmCueController {
  KmCueController({required this.unitMeters, required this.onCue});

  /// 1000 for a metric profile, 1609.344 for an imperial one.
  final double unitMeters;

  /// Called with the 1-based unit just completed (`3` = the third kilometre)
  /// and the distance at that moment.
  final void Function(int unit, double distanceMeters) onCue;

  int _cuedUpTo = 0;

  /// Adopts [meters] as ground already covered **without announcing any of
  /// it** — used when a session is reopened after an app kill and its stored
  /// track is replayed back into the live distance (`CardioSessionScreen`'s
  /// `_seedTrackPointSeqAndSync`). Without this, resuming a 7 km run would
  /// buzz for kilometres one through seven in a single frame.
  void seed(double meters) {
    _cuedUpTo = _unitsIn(meters);
  }

  /// Feeds the current running distance. Fires [onCue] at most **once** per
  /// call: if a single update somehow spans more than one boundary (a long
  /// GPS gap, a coarse fix), the runner gets one cue for the unit they are
  /// actually on, not a burst of buzzes for each one behind them.
  ///
  /// The caller is responsible for not feeding a paused session — on
  /// `CardioSessionScreen` that falls out of `_onPositionFix`, which only
  /// advances the distance while genuinely running, so neither an auto-pause
  /// nor a manual one can produce a cue.
  void onDistance(double meters) {
    final units = _unitsIn(meters);
    if (units <= _cuedUpTo) return;
    _cuedUpTo = units;
    onCue(units, meters);
  }

  int _unitsIn(double meters) {
    if (unitMeters <= 0 || meters <= 0) return 0;
    return (meters / unitMeters).floor();
  }
}
