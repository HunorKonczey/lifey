import 'package:health/health.dart';

import 'health_cardio_track.dart';

/// A finished workout from the health store that qualifies for the cardio
/// import (docs/integrations/89 M1, G1.4). It has already been mapped to a
/// Lifey cardio [activityType], and Lifey's own records were filtered out
/// ([isLifeyHealthSource]).
///
/// Plain data. The importer (G1.5) turns it into a CARDIO workout session,
/// with [uuid] as the session's `healthWorkoutId`, the dedupe key (D-G3).
class HealthCardioWorkout {
  const HealthCardioWorkout({
    required this.uuid,
    required this.startDate,
    required this.endDate,
    required this.activityType,
    required this.sourceId,
    required this.sourceName,
    this.activeCalories,
    this.distanceMeters,
    this.steps,
    this.averageHeartRate,
    this.maxHeartRate,
    this.heartRateSamples = const [],
    this.route = const [],
  });

  /// The store's record id: an HKWorkout UUID on iOS, a Health Connect record
  /// id on Android.
  final String uuid;
  final DateTime startDate;
  final DateTime endDate;

  /// A code from `kActivityTypes` (activity_type.dart), never null: an
  /// unknown store type becomes OTHER_CARDIO (see [cardioActivityTypeFor]).
  final String activityType;

  /// The writing app's bundle id (iOS) or package name (Android), e.g.
  /// `com.garmin.android.apps.connectmobile`.
  final String sourceId;

  /// The writing app's display name, e.g. "Garmin Connect". The importer
  /// stores it as the session's `importAppName`.
  final String sourceName;

  /// Total energy burned (kcal), null when the source recorded none.
  final double? activeCalories;

  /// Total distance in meters, null when the source recorded none or used a
  /// unit we don't convert.
  final double? distanceMeters;

  final int? steps;

  /// Mean heart rate (bpm) over [startDate]–[endDate], null without samples.
  final double? averageHeartRate;

  /// Highest heart rate (bpm) over [startDate]–[endDate], null without samples.
  final double? maxHeartRate;

  /// The heart-rate readings over [startDate]–[endDate], the input of the
  /// zone times (docs/integrations/89 G1.8, [hrZoneSecondsFromSamples]).
  final List<HeartRateSample> heartRateSamples;

  /// The workout's GPS fixes, empty when it has no route or the app may not
  /// read it (Health Connect's *Exercise routes* permission). The importer
  /// turns them into the session's polyline ([routePolylineFromLocations]).
  final List<RouteLocation> route;

  /// This workout with its heart rate and route filled in. Both need further
  /// store queries, so the caller adds them after [cardioWorkoutFromPoint].
  /// The average and the maximum are derived from [heartRateSamples].
  HealthCardioWorkout withTrack({
    List<HeartRateSample> heartRateSamples = const [],
    List<RouteLocation> route = const [],
  }) {
    final bpms = [for (final s in heartRateSamples) s.bpm];
    return HealthCardioWorkout(
      uuid: uuid,
      startDate: startDate,
      endDate: endDate,
      activityType: activityType,
      sourceId: sourceId,
      sourceName: sourceName,
      activeCalories: activeCalories,
      distanceMeters: distanceMeters,
      steps: steps,
      averageHeartRate: bpms.isEmpty ? null : bpms.reduce((a, b) => a + b) / bpms.length,
      maxHeartRate: bpms.isEmpty ? null : bpms.reduce((a, b) => a > b ? a : b),
      heartRateSamples: heartRateSamples,
      route: route,
    );
  }
}

/// Lifey's own app id on both platforms (iOS bundle id, Android
/// applicationId; the Wear OS app shares it). The iOS watch app and widgets
/// are `com.khunor.lifey.<suffix>`.
const lifeyAppId = 'com.khunor.lifey';

/// Whether a health-store record was written by Lifey itself: by the phone
/// app, the watch app, or the widgets. Such records must never be imported
/// back as new sessions (docs/integrations/89 D-G4, risk R1). Every
/// Lifey-recorded workout that Lifey writes to the store would otherwise
/// return as a duplicate import.
bool isLifeyHealthSource(String sourceId) => sourceId == lifeyAppId || sourceId.startsWith('$lifeyAppId.');

/// Store workout types that are never imported as cardio. Strength work
/// belongs to Lifey's strength sessions. The rest are breathing / recovery
/// entries with no cardio meaning. Anything not listed here and not mapped
/// explicitly imports as OTHER_CARDIO, and the user can retype it
/// (docs/integrations/89 D-G6).
const _notCardio = {
  HealthWorkoutActivityType.TRADITIONAL_STRENGTH_TRAINING,
  HealthWorkoutActivityType.FUNCTIONAL_STRENGTH_TRAINING,
  HealthWorkoutActivityType.STRENGTH_TRAINING,
  HealthWorkoutActivityType.WEIGHTLIFTING,
  HealthWorkoutActivityType.GUIDED_BREATHING,
  HealthWorkoutActivityType.MIND_AND_BODY,
  HealthWorkoutActivityType.PREPARATION_AND_RECOVERY,
  HealthWorkoutActivityType.COOLDOWN,
  HealthWorkoutActivityType.FLEXIBILITY,
};

/// Maps a health-store workout type to a Lifey cardio activity type code
/// (docs/integrations/89 G1.4), or null when the type is never imported
/// ([_notCardio]).
///
/// Both platforms are covered. Health Connect has separate treadmill and
/// stationary types; HealthKit folds them into the outdoor ones. A treadmill
/// run maps to RUNNING. With no splits and no route, an import produces no
/// best efforts (docs/integrations/89 R3).
/// The G1.1 spike (LIF-195) checks this table against real Garmin Connect
/// data.
String? cardioActivityTypeFor(HealthWorkoutActivityType type) {
  if (_notCardio.contains(type)) return null;
  return switch (type) {
    HealthWorkoutActivityType.RUNNING || HealthWorkoutActivityType.RUNNING_TREADMILL => 'RUNNING',
    HealthWorkoutActivityType.WALKING || HealthWorkoutActivityType.WALKING_TREADMILL => 'WALKING',
    HealthWorkoutActivityType.HIKING => 'HIKING',
    HealthWorkoutActivityType.BIKING => 'CYCLING',
    HealthWorkoutActivityType.BIKING_STATIONARY => 'INDOOR_BIKE',
    HealthWorkoutActivityType.BASKETBALL => 'BASKETBALL',
    // Lifey's FOOTBALL is association football (soccer); American football stays OTHER_CARDIO.
    HealthWorkoutActivityType.SOCCER => 'FOOTBALL',
    _ => 'OTHER_CARDIO',
  };
}

/// Converts one store data point into a [HealthCardioWorkout], or returns
/// null when it is not an importable cardio workout:
/// - it is not a workout;
/// - Lifey wrote it ([isLifeyHealthSource]);
/// - its type is never imported ([cardioActivityTypeFor]).
///
/// Pure. The average heart rate needs another store query, so the caller
/// adds it ([HealthCardioWorkout.withAverageHeartRate]).
HealthCardioWorkout? cardioWorkoutFromPoint(HealthDataPoint point) {
  final value = point.value;
  if (value is! WorkoutHealthValue) return null;
  if (isLifeyHealthSource(point.sourceId)) return null;
  final activityType = cardioActivityTypeFor(value.workoutActivityType);
  if (activityType == null) return null;
  return HealthCardioWorkout(
    uuid: point.uuid,
    startDate: point.dateFrom,
    endDate: point.dateTo,
    activityType: activityType,
    sourceId: point.sourceId,
    sourceName: point.sourceName,
    activeCalories: _kilocalories(value.totalEnergyBurned, value.totalEnergyBurnedUnit),
    distanceMeters: _meters(value.totalDistance, value.totalDistanceUnit),
    steps: value.totalSteps,
  );
}

/// The plugin reports energy in kcal on both platforms. LARGE_CALORIE is
/// the same unit under another name; anything else is dropped rather than
/// guessed, because a wrong value would silently skew the day's calories
/// (docs/integrations/89 R2).
double? _kilocalories(int? amount, HealthDataUnit? unit) {
  if (amount == null) return null;
  return switch (unit) {
    null || HealthDataUnit.KILOCALORIE || HealthDataUnit.LARGE_CALORIE => amount.toDouble(),
    HealthDataUnit.SMALL_CALORIE => amount / 1000,
    _ => null,
  };
}

/// The plugin reports distance in meters on both platforms. Miles are
/// converted; any other unit is dropped rather than guessed.
double? _meters(int? amount, HealthDataUnit? unit) {
  if (amount == null) return null;
  return switch (unit) {
    null || HealthDataUnit.METER => amount.toDouble(),
    HealthDataUnit.MILE => amount * 1609.344,
    _ => null,
  };
}
