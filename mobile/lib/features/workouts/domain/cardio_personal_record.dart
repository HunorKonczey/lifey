import 'activity_type.dart';
import 'workout_session.dart';

/// The three record types a finished CARDIO session can break
/// (docs/cardio/56-cardio-statistics-plan.md §5.2). Deliberately a separate
/// engine from [PrType] (`personal_record.dart`), not an extension of it —
/// that engine is set/rep-based and structurally cannot see a cardio session
/// at all (a cardio session never writes an `exerciseSets` row; see
/// docs/cardio/59-cardio-implementation-plan.md C3.5's kész-ha: "Cardio nem
/// termel erősítő PR-t és fordítva"). Fastest 1/5/10km (needs a GPS track)
/// and cycling total work (kJ) are explicitly out of scope here — deferred
/// to C6/C7 per D-C3.8.
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
}

/// The "best so far" value per [CardioPrType], derived from prior finished
/// cardio sessions — never includes the session being checked, never
/// persisted. Mirrors [PrBaseline]'s shape for the strength engine.
class CardioPrBaseline {
  const CardioPrBaseline({
    this.maxDistanceMeters,
    this.maxMovingSeconds,
    this.maxElevationGainMeters,
  });

  final double? maxDistanceMeters;
  final int? maxMovingSeconds;
  final double? maxElevationGainMeters;

  static const empty = CardioPrBaseline();

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
    final family = session.family;

    var nextDistance = maxDistanceMeters;
    if (family == ActivityFamily.distance || family == ActivityFamily.machine) {
      final d = session.cardio?.distanceMeters;
      if (d != null && (nextDistance == null || d > nextDistance)) nextDistance = d;
    }

    var nextMoving = maxMovingSeconds;
    final moving = session.movingSeconds;
    if (moving != null && (nextMoving == null || moving > nextMoving)) nextMoving = moving;

    var nextElevation = maxElevationGainMeters;
    if (family == ActivityFamily.distance) {
      final e = session.cardio?.elevationGainMeters;
      if (e != null && (nextElevation == null || e > nextElevation)) nextElevation = e;
    }

    return CardioPrBaseline(
      maxDistanceMeters: nextDistance,
      maxMovingSeconds: nextMoving,
      maxElevationGainMeters: nextElevation,
    );
  }
}

/// Detects which [CardioPrType]s [session] breaks against [baseline].
/// Strictly-greater semantics, mirroring [detectPrs] — matching the existing
/// best is not a new record, and a type never fires without a baseline value
/// to beat. Always empty for a non-cardio or not-yet-finished session.
List<CardioPrType> detectCardioPrs(CardioPrBaseline baseline, WorkoutSession session) {
  if (!session.isCardio || session.finishedAt == null) return const [];
  final family = session.family;
  final types = <CardioPrType>[];

  if (family == ActivityFamily.distance || family == ActivityFamily.machine) {
    final d = session.cardio?.distanceMeters;
    if (d != null && baseline.maxDistanceMeters != null && d > baseline.maxDistanceMeters!) {
      types.add(CardioPrType.longestDistance);
    }
  }

  final moving = session.movingSeconds;
  if (moving != null &&
      baseline.maxMovingSeconds != null &&
      moving > baseline.maxMovingSeconds!) {
    types.add(CardioPrType.longestMovingTime);
  }

  if (family == ActivityFamily.distance) {
    final e = session.cardio?.elevationGainMeters;
    if (e != null &&
        baseline.maxElevationGainMeters != null &&
        e > baseline.maxElevationGainMeters!) {
      types.add(CardioPrType.greatestElevationGain);
    }
  }

  return types;
}
