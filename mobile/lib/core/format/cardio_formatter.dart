import '../../features/settings/domain/user_settings.dart';

/// Formats cardio metrics (distance, pace, speed, elevation, duration) for
/// display, respecting the Settings metric/imperial toggle
/// (docs/cardio/53-cardio-mobile-plan.md §7).
///
/// Every function is a pure function of its numeric inputs plus
/// [UnitSystem] — no `BuildContext`/Riverpod dependency — so the same code
/// path can build a Live Activity payload string on a background isolate,
/// not just widget text (docs/cardio/53 §5 D-C2.3). This is a deliberate
/// departure from `core/utils/unit_converters.dart`'s bare-conversion style:
/// here the metric/imperial branch is centralized once, rather than
/// repeated at every future call site (active-session screen, stats, watch
/// bridge, ...).
abstract final class CardioFormatter {
  static const double _metersPerKm = 1000;
  static const double _metersPerMile = 1609.344;
  static const double _metersPerFoot = 0.3048;

  /// "5.23 km" or "3.25 mi".
  static String distance(double meters, UnitSystem unitSystem) {
    if (unitSystem == UnitSystem.imperial) {
      return '${(meters / _metersPerMile).toStringAsFixed(2)} mi';
    }
    return '${(meters / _metersPerKm).toStringAsFixed(2)} km';
  }

  /// "42 m" or "138 ft" — whole units only, elevation is never precise
  /// enough to warrant decimals.
  static String elevation(double meters, UnitSystem unitSystem) {
    if (unitSystem == UnitSystem.imperial) {
      return '${(meters / _metersPerFoot).round()} ft';
    }
    return '${meters.round()} m';
  }

  /// "5:12 /km" or "8:22 /mi". Null when there's no distance to derive a
  /// pace from (avoids a divide-by-zero rather than surfacing "0:00").
  static String? pace(double meters, Duration duration, UnitSystem unitSystem) {
    if (meters <= 0) return null;
    final unitMeters = unitSystem == UnitSystem.imperial ? _metersPerMile : _metersPerKm;
    final secondsPerUnit = duration.inSeconds / (meters / unitMeters);
    if (!secondsPerUnit.isFinite) return null;
    final minutes = secondsPerUnit ~/ 60;
    final seconds = (secondsPerUnit % 60).round();
    final suffix = unitSystem == UnitSystem.imperial ? '/mi' : '/km';
    return '$minutes:${seconds.toString().padLeft(2, '0')} $suffix';
  }

  /// "11.4 km/h" or "7.1 mph" — the DISTANCE/MACHINE alternative to pace,
  /// used for walking/hiking/the indoor bike (docs/cardio/51 §3). Null when
  /// there's no elapsed time to derive a speed from.
  static String? speed(double meters, Duration duration, UnitSystem unitSystem) {
    if (duration.inSeconds <= 0) return null;
    final hours = duration.inSeconds / 3600;
    if (unitSystem == UnitSystem.imperial) {
      return '${((meters / _metersPerMile) / hours).toStringAsFixed(1)} mph';
    }
    return '${((meters / _metersPerKm) / hours).toStringAsFixed(1)} km/h';
  }

  /// "5:12" under an hour, "1:05:12" from an hour up — a moving/elapsed
  /// duration, tabular enough for a live, second-ticking display.
  static String duration(Duration duration) {
    final totalSeconds = duration.inSeconds;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    final ss = seconds.toString().padLeft(2, '0');
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:$ss';
    }
    return '$minutes:$ss';
  }
}
