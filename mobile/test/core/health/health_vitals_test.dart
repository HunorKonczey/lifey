import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';
import 'package:lifey/core/health/health_service.dart';
import 'package:lifey/core/health/health_vitals.dart';
import 'package:lifey/features/vitals/domain/daily_vitals.dart';

/// docs/integrations/89 G3.3 (D-G8): store vitals grouped into one entry per
/// local day. The rule that matters most: an SDNN value and an RMSSD value are
/// never averaged together, and a value always carries the method of the type
/// it was read from (R6).
void main() {
  group('the method comes from the data type', () {
    test('SDNN and RMSSD map to their own method, anything else to none', () {
      expect(hrvMethodFor(HealthDataType.HEART_RATE_VARIABILITY_SDNN), HrvMethod.sdnn);
      expect(hrvMethodFor(HealthDataType.HEART_RATE_VARIABILITY_RMSSD), HrvMethod.rmssd);
      expect(hrvMethodFor(HealthDataType.RESTING_HEART_RATE), isNull);
      expect(hrvMethodFor(HealthDataType.HEART_RATE), isNull);
    });

    test('a point becomes a resting HR or an HRV sample with its method', () {
      final rhr = vitalsSampleFromPoint(_point(HealthDataType.RESTING_HEART_RATE, _at(21, 7), 52))!;
      final rmssd = vitalsSampleFromPoint(_point(HealthDataType.HEART_RATE_VARIABILITY_RMSSD, _at(21, 4), 48))!;
      final sdnn = vitalsSampleFromPoint(_point(HealthDataType.HEART_RATE_VARIABILITY_SDNN, _at(21, 4), 40))!;

      expect(rhr.isRestingHr, isTrue);
      expect(rhr.value, 52);
      expect(rmssd.hrvMethod, HrvMethod.rmssd);
      expect(sdnn.hrvMethod, HrvMethod.sdnn);
    });

    test('other types and Lifey-written points are not samples', () {
      expect(vitalsSampleFromPoint(_point(HealthDataType.HEART_RATE, _at(21, 7), 80)), isNull);
      expect(
        vitalsSampleFromPoint(_point(HealthDataType.RESTING_HEART_RATE, _at(21, 7), 52, sourceId: 'com.khunor.lifey')),
        isNull,
      );
    });
  });

  group('dailyVitalsFrom', () {
    test('resting HR is the day\'s newest value, HRV the day\'s average, one entry per day oldest first', () {
      final days = dailyVitalsFrom([
        _hrv(22, 3, 50, HrvMethod.rmssd),
        _rhr(21, 8, 55),
        _rhr(21, 20, 52.4),
        _hrv(21, 2, 40, HrvMethod.rmssd),
        _hrv(21, 3, 45, HrvMethod.rmssd),
        _hrv(21, 4, 47, HrvMethod.rmssd),
      ]);

      expect(days.map((d) => d.date), [DateTime(2026, 11, 21), DateTime(2026, 11, 22)]);
      final first = days.first;
      expect(first.restingHr, 52);
      expect(first.hrvMs, 44);
      expect(first.hrvMethod, HrvMethod.rmssd);
      expect(first.lastSampleAt, _at(21, 20));
      expect(days.last.restingHr, isNull);
      expect(days.last.hrvMs, 50);
    });

    test('the HRV average is rounded to 0.1 ms', () {
      final day = dailyVitalsFrom([
        _hrv(21, 1, 40, HrvMethod.sdnn),
        _hrv(21, 2, 41, HrvMethod.sdnn),
        _hrv(21, 3, 41, HrvMethod.sdnn),
      ]).single;

      expect(day.hrvMs, 40.7);
      expect(day.hrvMethod, HrvMethod.sdnn);
    });

    test('SDNN and RMSSD on one day are never averaged: the method with more readings wins alone', () {
      final day = dailyVitalsFrom([
        _hrv(21, 1, 30, HrvMethod.sdnn),
        _hrv(21, 2, 34, HrvMethod.sdnn),
        _hrv(21, 3, 90, HrvMethod.rmssd),
      ]).single;

      // (30 + 34) / 2, the RMSSD 90 left out; a mixed average would be 51.3.
      expect(day.hrvMs, 32);
      expect(day.hrvMethod, HrvMethod.sdnn);
    });

    test('with as many readings of each, the method read last wins, still unmixed', () {
      final day = dailyVitalsFrom([
        _hrv(21, 1, 30, HrvMethod.sdnn),
        _hrv(21, 5, 90, HrvMethod.rmssd),
      ]).single;

      expect(day.hrvMs, 90);
      expect(day.hrvMethod, HrvMethod.rmssd);
    });

    test('each day picks its method on its own, so a value never leaves its method', () {
      final days = dailyVitalsFrom([
        _hrv(21, 1, 30, HrvMethod.sdnn),
        _hrv(22, 1, 90, HrvMethod.rmssd),
      ]);

      expect([for (final d in days) (d.hrvMs, d.hrvMethod)], [(30.0, HrvMethod.sdnn), (90.0, HrvMethod.rmssd)]);
    });

    test('values outside what the backend accepts are dropped, and a day left empty is skipped', () {
      final days = dailyVitalsFrom([
        _rhr(21, 7, 0),
        _rhr(21, 8, 300),
        _hrv(21, 3, 0, HrvMethod.rmssd),
        _hrv(21, 4, 1500, HrvMethod.rmssd),
        _rhr(22, 7, 58),
        _hrv(22, 3, 1500, HrvMethod.rmssd),
      ]);

      final day = days.single;
      expect(day.date, DateTime(2026, 11, 22));
      expect(day.restingHr, 58);
      expect(day.hrvMs, isNull);
      expect(day.hrvMethod, isNull);
    });

    test('samples are grouped by the local day', () {
      final local = DateTime(2026, 11, 21, 23, 30);
      final day = dailyVitalsFrom([VitalsSample(at: local.toUtc(), value: 52)]).single;

      expect(day.date, DateTime(2026, 11, 21));
    });
  });

  group('HealthService.recentDailyVitals', () {
    test('reads from the given start and returns the grouped days', () async {
      final health = _FakeHealth([
        _point(HealthDataType.RESTING_HEART_RATE, _at(21, 7), 52),
        _point(HealthDataType.HEART_RATE_VARIABILITY_RMSSD, _at(21, 3), 48),
      ]);
      final service = _AvailableHealthService(health);

      final days = await service.recentDailyVitals(since: DateTime(2026, 11, 20));

      expect(health.queryStart, DateTime(2026, 11, 20));
      expect(days.single.restingHr, 52);
      expect(days.single.hrvMethod, HrvMethod.rmssd);
    });

    test('a store failure yields no days instead of throwing', () async {
      final service = _AvailableHealthService(_FakeHealth(const [], fail: true));

      expect(await service.recentDailyVitals(since: DateTime(2026, 11, 20)), isEmpty);
    });
  });
}

DateTime _at(int day, int hour) => DateTime(2026, 11, day, hour);

VitalsSample _rhr(int day, int hour, double bpm) => VitalsSample(at: _at(day, hour), value: bpm);

VitalsSample _hrv(int day, int hour, double ms, HrvMethod method) =>
    VitalsSample(at: _at(day, hour), value: ms, hrvMethod: method);

HealthDataPoint _point(HealthDataType type, DateTime at, num value, {String sourceId = ''}) => HealthDataPoint(
      uuid: '$type-$at',
      value: NumericHealthValue(numericValue: value),
      type: type,
      unit: type == HealthDataType.RESTING_HEART_RATE ? HealthDataUnit.BEATS_PER_MINUTE : HealthDataUnit.MILLISECOND,
      dateFrom: at,
      dateTo: at,
      sourcePlatform: HealthPlatformType.googleHealthConnect,
      sourceDeviceId: 'device',
      sourceId: sourceId,
      sourceName: sourceId.isEmpty ? 'com.garmin.android.apps.connectmobile' : sourceId,
    );

class _FakeHealth extends Health {
  _FakeHealth(this.points, {this.fail = false});

  final List<HealthDataPoint> points;
  final bool fail;
  DateTime? queryStart;

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
    queryStart = startTime;
    if (fail) throw StateError('store gone');
    return points;
  }
}

/// The test host has no health store, so [HealthService.isAvailable] is false there.
class _AvailableHealthService extends HealthService {
  _AvailableHealthService(super.health);

  @override
  bool get isAvailable => true;
}
