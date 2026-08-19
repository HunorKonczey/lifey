import '../../../core/format/cardio_formatter.dart';
import 'activity_type.dart';
import 'workout_session.dart';

/// The record types a finished CARDIO session can break
/// (docs/cardio/56-cardio-statistics-plan.md §5.2, extended by
/// docs/cardio/60 C6.7). Deliberately a separate engine from [PrType]
/// (`personal_record.dart`), not an extension of it — that engine is
/// set/rep-based and structurally cannot see a cardio session at all (a
/// cardio session never writes an `exerciseSets` row; see
/// docs/cardio/59-cardio-implementation-plan.md C3.5's kész-ha: "Cardio nem
/// termel erősítő PR-t és fordítva").
enum CardioPrType {
  /// DISTANCE + MACHINE family — running, walking, hiking, indoor bike share
  /// one combined record, matching how `stat_chart_data.dart`'s
  /// `StatMetric.cardioDistance` aggregates the same families together
  /// rather than splitting per exact activity type.
  longestDistance,

  /// Every cardio family tracks moving time, so this is the only record type
  /// with no family restriction.
  longestMovingTime,

  /// DISTANCE family only — an indoor bike gains no real elevation even
  /// though the column exists for it, matching
  /// `stat_chart_data.dart`'s `StatMetric.cardioElevationGain` gating.
  greatestElevationGain,

  /// The fastest continuous 1/5/10 km inside a single run (C6.1–C6.3's
  /// `best1kSeconds` … columns). **Running only** — see [appliesTo]: a walk
  /// or a hike would take the whole board with times nobody set out to beat,
  /// and 56 §5.2 keeps these to the one activity they mean something for.
  fastest1k,
  fastest5k,
  fastest10k,

  /// MACHINE family only (docs/cardio/60 C7.7): total work in kJ, derived the
  /// same way the summary card derives it
  /// ([CardioFormatter.totalWorkKj]) — never stored, so a session with no
  /// power reading has no value here and can neither set nor break this
  /// record (a 0 kJ session would otherwise silently "win" against every
  /// watt-less past ride).
  greatestTotalWork;

  /// True when a *smaller* number is the better one. The three best-effort
  /// types are times to beat downward; everything else is a maximum.
  bool get lowerIsBetter =>
      this == fastest1k || this == fastest5k || this == fastest10k;

  /// Whether this record type exists at all for [session]'s activity. A type
  /// that doesn't apply is not "no record yet" — it's not a concept for that
  /// activity, which is why the summary card omits those rows entirely
  /// rather than greying them (docs/cardio/61 §2 M34).
  bool appliesTo(WorkoutSession session) {
    final family = session.family;
    return switch (this) {
      longestDistance =>
        family == ActivityFamily.distance || family == ActivityFamily.machine,
      longestMovingTime => true,
      greatestElevationGain => family == ActivityFamily.distance,
      fastest1k || fastest5k || fastest10k => session.activityType == 'RUNNING',
      greatestTotalWork => family == ActivityFamily.machine,
    };
  }

  /// This session's value for the type, or null when it has none. Units are
  /// per-type: meters, seconds, meters of climb, seconds again.
  double? valueIn(WorkoutSession session) {
    if (!appliesTo(session)) return null;
    return switch (this) {
      longestDistance => session.cardio?.distanceMeters,
      longestMovingTime => session.movingSeconds?.toDouble(),
      greatestElevationGain => session.cardio?.elevationGainMeters,
      fastest1k => session.cardio?.best1kSeconds?.toDouble(),
      fastest5k => session.cardio?.best5kSeconds?.toDouble(),
      fastest10k => session.cardio?.best10kSeconds?.toDouble(),
      greatestTotalWork => CardioFormatter.totalWorkKj(
            session.cardio?.avgWatts, session.movingSeconds)?.toDouble(),
    };
  }
}

/// One "best so far" entry: the value and when it was set. The date is what
/// lets the celebration name the record it replaced ("előző: 24:36 · október
/// 12." — docs/cardio/61 §2 M36).
class CardioPrBest {
  const CardioPrBest({required this.value, required this.at});

  final double value;
  final DateTime at;
}

/// The "best so far" per [CardioPrType], derived from prior finished cardio
/// sessions — never includes the session being checked, never persisted.
/// Mirrors [PrBaseline]'s shape for the strength engine.
class CardioPrBaseline {
  const CardioPrBaseline({
    this.longestDistance,
    this.longestMovingTime,
    this.greatestElevationGain,
    this.fastest1k,
    this.fastest5k,
    this.fastest10k,
    this.greatestTotalWork,
  });

  final CardioPrBest? longestDistance;
  final CardioPrBest? longestMovingTime;
  final CardioPrBest? greatestElevationGain;
  final CardioPrBest? fastest1k;
  final CardioPrBest? fastest5k;
  final CardioPrBest? fastest10k;
  final CardioPrBest? greatestTotalWork;

  static const empty = CardioPrBaseline();

  /// The record to beat for [type], or null when nothing has set one yet.
  CardioPrBest? operator [](CardioPrType type) => switch (type) {
        CardioPrType.longestDistance => longestDistance,
        CardioPrType.longestMovingTime => longestMovingTime,
        CardioPrType.greatestElevationGain => greatestElevationGain,
        CardioPrType.fastest1k => fastest1k,
        CardioPrType.fastest5k => fastest5k,
        CardioPrType.fastest10k => fastest10k,
        CardioPrType.greatestTotalWork => greatestTotalWork,
      };

  double? get maxDistanceMeters => longestDistance?.value;
  int? get maxMovingSeconds => longestMovingTime?.value.round();
  double? get maxElevationGainMeters => greatestElevationGain?.value;
  int? get best1kSeconds => fastest1k?.value.round();
  int? get best5kSeconds => fastest5k?.value.round();
  int? get best10kSeconds => fastest10k?.value.round();
  int? get maxTotalWorkKj => greatestTotalWork?.value.round();

  /// Builds a baseline from prior sessions (order doesn't matter). Callers
  /// pass every past cardio session except the one about to be checked —
  /// non-cardio and not-yet-finished sessions are ignored automatically.
  factory CardioPrBaseline.fromSessions(Iterable<WorkoutSession> sessions) {
    var baseline = CardioPrBaseline.empty;
    for (final s in sessions) {
      baseline = baseline.extend(s);
    }
    return baseline;
  }

  /// Returns a new baseline with [session] folded in. A no-op for a
  /// non-cardio or not-yet-finished session.
  CardioPrBaseline extend(WorkoutSession session) {
    if (!session.isCardio || session.finishedAt == null) return this;
    final at = session.finishedAt!;

    CardioPrBest? better(CardioPrType type, CardioPrBest? current) {
      final value = type.valueIn(session);
      if (value == null) return current;
      if (current == null) return CardioPrBest(value: value, at: at);
      final wins = type.lowerIsBetter ? value < current.value : value > current.value;
      return wins ? CardioPrBest(value: value, at: at) : current;
    }

    return CardioPrBaseline(
      longestDistance: better(CardioPrType.longestDistance, longestDistance),
      longestMovingTime: better(CardioPrType.longestMovingTime, longestMovingTime),
      greatestElevationGain: better(CardioPrType.greatestElevationGain, greatestElevationGain),
      fastest1k: better(CardioPrType.fastest1k, fastest1k),
      fastest5k: better(CardioPrType.fastest5k, fastest5k),
      fastest10k: better(CardioPrType.fastest10k, fastest10k),
      greatestTotalWork: better(CardioPrType.greatestTotalWork, greatestTotalWork),
    );
  }
}

/// Detects which [CardioPrType]s [session] breaks against [baseline].
/// Strictly-better semantics, mirroring [detectPrs] — matching the existing
/// best is not a new record, and a type never fires without a baseline value
/// to beat (the first run of a distance sets the bar, it doesn't break one).
/// Always empty for a non-cardio or not-yet-finished session.
List<CardioPrType> detectCardioPrs(CardioPrBaseline baseline, WorkoutSession session) {
  if (!session.isCardio || session.finishedAt == null) return const [];
  final types = <CardioPrType>[];
  for (final type in CardioPrType.values) {
    final value = type.valueIn(session);
    final previous = baseline[type];
    if (value == null || previous == null) continue;
    final beaten = type.lowerIsBetter ? value < previous.value : value > previous.value;
    if (beaten) types.add(type);
  }
  return types;
}
