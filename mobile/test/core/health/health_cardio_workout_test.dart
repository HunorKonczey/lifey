import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';
import 'package:lifey/core/health/health_cardio_workout.dart';
import 'package:lifey/core/health/health_service.dart';
import 'package:lifey/features/workouts/domain/activity_type.dart';

/// docs/integrations/89 G1.4: which store workouts qualify for the cardio
/// import, as which Lifey activity type, and that Lifey's own records never
/// come back as imports (D-G4, risk R1).
void main() {
  group('cardioActivityTypeFor', () {
    test('maps the dedicated Lifey types on both platforms', () {
      const expected = {
        HealthWorkoutActivityType.RUNNING: 'RUNNING',
        HealthWorkoutActivityType.RUNNING_TREADMILL: 'RUNNING',
        HealthWorkoutActivityType.WALKING: 'WALKING',
        HealthWorkoutActivityType.WALKING_TREADMILL: 'WALKING',
        HealthWorkoutActivityType.HIKING: 'HIKING',
        HealthWorkoutActivityType.BIKING: 'CYCLING',
        HealthWorkoutActivityType.BIKING_STATIONARY: 'INDOOR_BIKE',
        HealthWorkoutActivityType.BASKETBALL: 'BASKETBALL',
        HealthWorkoutActivityType.SOCCER: 'FOOTBALL',
      };
      expected.forEach((store, lifey) => expect(cardioActivityTypeFor(store), lifey, reason: '$store'));
    });

    test('strength and recovery workouts are never imported as cardio', () {
      for (final type in [
        HealthWorkoutActivityType.TRADITIONAL_STRENGTH_TRAINING,
        HealthWorkoutActivityType.FUNCTIONAL_STRENGTH_TRAINING,
        HealthWorkoutActivityType.STRENGTH_TRAINING,
        HealthWorkoutActivityType.WEIGHTLIFTING,
        HealthWorkoutActivityType.GUIDED_BREATHING,
        HealthWorkoutActivityType.MIND_AND_BODY,
        HealthWorkoutActivityType.PREPARATION_AND_RECOVERY,
        HealthWorkoutActivityType.COOLDOWN,
        HealthWorkoutActivityType.FLEXIBILITY,
      ]) {
        expect(cardioActivityTypeFor(type), isNull, reason: '$type');
      }
    });

    test('anything else imports as OTHER_CARDIO, never an unknown code', () {
      expect(cardioActivityTypeFor(HealthWorkoutActivityType.ROWING_MACHINE), 'OTHER_CARDIO');
      expect(cardioActivityTypeFor(HealthWorkoutActivityType.AMERICAN_FOOTBALL), 'OTHER_CARDIO');
      expect(cardioActivityTypeFor(HealthWorkoutActivityType.OTHER), 'OTHER_CARDIO');
      // Every result must be a code activityFamilyOf accepts (it throws on an unknown one).
      for (final type in HealthWorkoutActivityType.values) {
        final code = cardioActivityTypeFor(type);
        if (code != null) expect(kActivityTypes, contains(code), reason: '$type');
      }
    });
  });

  group('isLifeyHealthSource', () {
    test('the phone app, the Wear app and every iOS extension are Lifey', () {
      expect(isLifeyHealthSource('com.khunor.lifey'), isTrue);
      expect(isLifeyHealthSource('com.khunor.lifey.watchkitapp'), isTrue);
      expect(isLifeyHealthSource('com.khunor.lifey.LifeyWidgets'), isTrue);
    });

    test('other apps, including look-alike ids, are not', () {
      expect(isLifeyHealthSource('com.garmin.android.apps.connectmobile'), isFalse);
      expect(isLifeyHealthSource('com.apple.health'), isFalse);
      expect(isLifeyHealthSource('com.khunor.lifeyclone'), isFalse);
      expect(isLifeyHealthSource(''), isFalse);
    });
  });

  group('cardioWorkoutFromPoint', () {
    test('maps a Garmin run with its metrics', () {
      final workout = cardioWorkoutFromPoint(_workoutPoint())!;

      expect(workout.uuid, 'hc-run-1');
      expect(workout.activityType, 'RUNNING');
      expect(workout.sourceId, 'com.garmin.android.apps.connectmobile');
      expect(workout.sourceName, 'Garmin Connect');
      expect(workout.activeCalories, 512);
      expect(workout.distanceMeters, 8120);
      expect(workout.steps, 7400);
      expect(workout.averageHeartRate, isNull);
      expect(workout.withAverageHeartRate(151).averageHeartRate, 151);
    });

    test('drops Lifey-written records, non-cardio types and non-workout points', () {
      expect(cardioWorkoutFromPoint(_workoutPoint(sourceId: 'com.khunor.lifey')), isNull);
      expect(
        cardioWorkoutFromPoint(_workoutPoint(type: HealthWorkoutActivityType.TRADITIONAL_STRENGTH_TRAINING)),
        isNull,
      );
      expect(cardioWorkoutFromPoint(_stepsPoint()), isNull);
    });

    test('converts miles and small calories, and drops units it does not know', () {
      final miles = cardioWorkoutFromPoint(_workoutPoint(distance: 5, distanceUnit: HealthDataUnit.MILE))!;
      expect(miles.distanceMeters, closeTo(8046.72, 0.01));

      final small = cardioWorkoutFromPoint(_workoutPoint(energy: 512000, energyUnit: HealthDataUnit.SMALL_CALORIE))!;
      expect(small.activeCalories, 512);

      final odd = cardioWorkoutFromPoint(
          _workoutPoint(distanceUnit: HealthDataUnit.FOOT, energyUnit: HealthDataUnit.KILOGRAM))!;
      expect(odd.distanceMeters, isNull);
      expect(odd.activeCalories, isNull);
    });

    test('missing metrics stay null rather than zero', () {
      final bare = cardioWorkoutFromPoint(_workoutPoint(distance: null, energy: null, steps: null))!;
      expect(bare.distanceMeters, isNull);
      expect(bare.activeCalories, isNull);
      expect(bare.steps, isNull);
    });
  });

  group('HealthService.recentCardioWorkouts', () {
    test('returns importable workouts ending at or after since, oldest end first, with heart rate', () async {
      final since = DateTime(2026, 11, 20, 6);
      final health = _FakeHealth(
        workouts: [
          _workoutPoint(
              uuid: 'late', from: since.add(const Duration(hours: 5)), to: since.add(const Duration(hours: 6))),
          _workoutPoint(
              uuid: 'early', from: since.add(const Duration(hours: 1)), to: since.add(const Duration(hours: 2))),
          _workoutPoint(
              uuid: 'before-cursor',
              from: since.subtract(const Duration(hours: 3)),
              to: since.subtract(const Duration(hours: 2))),
          _workoutPoint(
              uuid: 'lifey', sourceId: 'com.khunor.lifey', from: since, to: since.add(const Duration(hours: 1))),
          _workoutPoint(
            uuid: 'strength',
            type: HealthWorkoutActivityType.STRENGTH_TRAINING,
            from: since,
            to: since.add(const Duration(hours: 1)),
          ),
        ],
        heartRates: [140, 160],
      );

      final result = await _AvailableHealthService(health).recentCardioWorkouts(since: since);

      expect(result.map((w) => w.uuid), ['early', 'late']);
      expect(result.map((w) => w.averageHeartRate), [150, 150]);
      // One heart-rate query per imported workout only, none for the dropped ones.
      expect(health.heartRateQueries, 2);
      expect(health.workoutQueryStart, since.subtract(const Duration(hours: 12)));
    });

    test('returns nothing where the platform has no health store', () async {
      final result = await HealthService(_FakeHealth(workouts: [_workoutPoint()]))
          .recentCardioWorkouts(since: DateTime(2026, 11, 20));
      expect(result, isEmpty);
    });
  });
}

HealthDataPoint _workoutPoint({
  String uuid = 'hc-run-1',
  String sourceId = 'com.garmin.android.apps.connectmobile',
  HealthWorkoutActivityType type = HealthWorkoutActivityType.RUNNING,
  int? distance = 8120,
  HealthDataUnit? distanceUnit = HealthDataUnit.METER,
  int? energy = 512,
  HealthDataUnit? energyUnit = HealthDataUnit.KILOCALORIE,
  int? steps = 7400,
  DateTime? from,
  DateTime? to,
}) =>
    HealthDataPoint(
      uuid: uuid,
      value: WorkoutHealthValue(
        workoutActivityType: type,
        totalDistance: distance,
        totalDistanceUnit: distanceUnit,
        totalEnergyBurned: energy,
        totalEnergyBurnedUnit: energyUnit,
        totalSteps: steps,
      ),
      type: HealthDataType.WORKOUT,
      unit: HealthDataUnit.NO_UNIT,
      dateFrom: from ?? DateTime(2026, 11, 20, 6),
      dateTo: to ?? DateTime(2026, 11, 20, 6, 42),
      sourcePlatform: HealthPlatformType.googleHealthConnect,
      sourceDeviceId: 'device',
      sourceId: sourceId,
      sourceName: sourceId == 'com.khunor.lifey' ? 'Lifey' : 'Garmin Connect',
    );

HealthDataPoint _stepsPoint() => HealthDataPoint(
      uuid: 'steps-1',
      value: NumericHealthValue(numericValue: 1200),
      type: HealthDataType.STEPS,
      unit: HealthDataUnit.COUNT,
      dateFrom: DateTime(2026, 11, 20, 6),
      dateTo: DateTime(2026, 11, 20, 7),
      sourcePlatform: HealthPlatformType.googleHealthConnect,
      sourceDeviceId: 'device',
      sourceId: 'com.garmin.android.apps.connectmobile',
      sourceName: 'Garmin Connect',
    );

/// Serves WORKOUT reads from [workouts] and every HEART_RATE read as all of
/// [heartRates] (one sample each), so the service has something to average.
/// Counts the reads.
class _FakeHealth extends Health {
  _FakeHealth({required this.workouts, this.heartRates = const []});

  final List<HealthDataPoint> workouts;
  final List<double> heartRates;
  int heartRateQueries = 0;
  DateTime? workoutQueryStart;

  @override
  Future<void> configure() async {}

  @override
  Future<List<HealthDataPoint>> getHealthDataFromTypes({
    required List<HealthDataType> types,
    Map<HealthDataType, HealthDataUnit>? preferredUnits,
    required DateTime startTime,
    required DateTime endTime,
    List<RecordingMethod> recordingMethodsToFilter = const [],
    int? limit,
  }) async {
    if (types.contains(HealthDataType.WORKOUT)) {
      workoutQueryStart = startTime;
      return workouts;
    }
    heartRateQueries++;
    return [
      for (final bpm in heartRates)
        HealthDataPoint(
          uuid: 'hr-$heartRateQueries-$bpm',
          value: NumericHealthValue(numericValue: bpm),
          type: HealthDataType.HEART_RATE,
          unit: HealthDataUnit.BEATS_PER_MINUTE,
          dateFrom: startTime,
          dateTo: startTime,
          sourcePlatform: HealthPlatformType.googleHealthConnect,
          sourceDeviceId: 'device',
          sourceId: 'com.garmin.android.apps.connectmobile',
          sourceName: 'Garmin Connect',
        ),
    ];
  }
}

/// The test host (Windows/Linux CI) has no health store, so [HealthService.isAvailable] is false there.
class _AvailableHealthService extends HealthService {
  _AvailableHealthService(super.health);

  @override
  bool get isAvailable => true;
}
