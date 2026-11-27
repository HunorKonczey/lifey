import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';
import 'package:lifey/core/health/health_service.dart';
import 'package:lifey/core/health/health_sleep.dart';

/// docs/integrations/89 G2.3 (D-G7): sleep data from both stores merged into
/// one row per session. The fixtures mirror what the `health` plugin returns:
/// - Health Connect: a SLEEP_SESSION record plus stages carrying its id;
/// - HealthKit: stage samples only, each with its own id, plus the iPhone's
///   "in bed" from the bedtime schedule.
void main() {
  group('Health Connect style (session + stages)', () {
    test('a session and its stages become one row with the stage minutes', () {
      final nights = _merge(_healthConnectNight());

      final night = nights.single;
      expect(night.healthRecordId, 'hc-session-1');
      expect(night.start, DateTime.utc(2026, 11, 20, 22, 40));
      expect(night.end, DateTime.utc(2026, 11, 21, 6, 10));
      expect(night.sourceName, 'com.garmin.android.apps.connectmobile');
      expect(night.lightMinutes, 230);
      expect(night.deepMinutes, 80);
      expect(night.remMinutes, 110);
      // Awake in bed and out of bed both count as awake.
      expect(night.awakeMinutes, 30);
      expect(night.asleepMinutes, 420);
    });

    test('a session without stages imports with its duration only', () {
      final night = _merge([_hc(HealthDataType.SLEEP_SESSION, 'hc-2', _t(20, 23), _t(21, 7))]).single;

      expect(night.healthRecordId, 'hc-2');
      expect(night.asleepMinutes, isNull);
      expect(night.deepMinutes, isNull);
      expect(night.awakeMinutes, isNull);
    });

    test('stages of a session that started before the read window are dropped, not imported alone', () {
      final nights = _merge([
        _hc(HealthDataType.SLEEP_DEEP, 'hc-earlier', _t(20, 1), _t(20, 2)),
        _hc(HealthDataType.SLEEP_LIGHT, 'hc-earlier', _t(20, 2), _t(20, 5)),
      ]);

      expect(nights, isEmpty);
    });

    test('two sessions on one day (night and nap) stay two rows, sorted by end', () {
      final nights = _merge([
        _hc(HealthDataType.SLEEP_SESSION, 'nap', _t(21, 14), _t(21, 14, 40)),
        ..._healthConnectNight(),
        _hc(HealthDataType.SLEEP_LIGHT, 'nap', _t(21, 14, 5), _t(21, 14, 35)),
      ]);

      expect(nights.map((n) => n.healthRecordId), ['hc-session-1', 'nap']);
      expect(nights.last.lightMinutes, 30);
    });
  });

  group('HealthKit style (stages only)', () {
    test('contiguous Apple Watch samples become one session keyed by the earliest sample', () {
      final night = _merge(_appleWatchNight()).single;

      expect(night.healthRecordId, 'aw-1');
      expect(night.start, DateTime.utc(2026, 11, 20, 22, 30));
      expect(night.end, DateTime.utc(2026, 11, 21, 6, 30));
      expect(night.sourceName, 'Apple Watch');
      expect(night.deepMinutes, 90);
      expect(night.lightMinutes, 240);
      expect(night.remMinutes, 120);
      expect(night.awakeMinutes, 15);
      expect(night.asleepMinutes, 450);
    });

    test("the iPhone's in-bed-only schedule is not a session", () {
      final nights = _merge([
        ..._appleWatchNight(),
        _hk(HealthDataType.SLEEP_IN_BED, 'phone-bed', _t(20, 22), _t(21, 7), source: 'iPhone'),
      ]);

      expect(nights.map((n) => n.healthRecordId), ['aw-1']);
    });

    test('a gap longer than 30 minutes starts a new session (the afternoon nap)', () {
      final nights = _merge([
        ..._appleWatchNight(),
        // HealthKit's "core" sleep arrives as SLEEP_LIGHT.
        _hk(HealthDataType.SLEEP_LIGHT, 'nap-1', _t(21, 14), _t(21, 14, 25)),
      ]);

      expect(nights, hasLength(2));
      expect(nights.last.healthRecordId, 'nap-1');
      expect(nights.last.lightMinutes, 25);
    });

    test('a night with only "asleep" has no stage minutes, just the total', () {
      final night = _merge([
        _hk(HealthDataType.SLEEP_ASLEEP, 'old-1', _t(20, 23), _t(21, 3)),
        _hk(HealthDataType.SLEEP_ASLEEP, 'old-2', _t(21, 3, 10), _t(21, 6, 40)),
      ]).single;

      expect(night.asleepMinutes, 450);
      expect(night.deepMinutes, isNull);
      expect(night.remMinutes, isNull);
      expect(night.awakeMinutes, isNull);
      expect(night.end, DateTime.utc(2026, 11, 21, 6, 40));
    });

    test('the same night from two sources stays two sessions', () {
      final nights = _merge([
        ..._appleWatchNight(),
        _hk(HealthDataType.SLEEP_ASLEEP, 'oura-1', _t(20, 22, 45), _t(21, 6, 20), source: 'Oura'),
      ]);

      expect(nights.map((n) => n.sourceName), unorderedEquals(['Apple Watch', 'Oura']));
    });
  });

  test('a point Lifey wrote, a zero-length point and a non-sleep point are ignored', () {
    final lifey = HealthDataPoint(
      uuid: 'lifey-1',
      value: NumericHealthValue(numericValue: 60),
      type: HealthDataType.SLEEP_DEEP,
      unit: HealthDataUnit.MINUTE,
      dateFrom: _t(20, 23),
      dateTo: _t(21, 0),
      sourcePlatform: HealthPlatformType.appleHealth,
      sourceDeviceId: 'device',
      sourceId: 'com.khunor.lifey',
      sourceName: 'Lifey',
    );

    expect(sleepRecordFromPoint(lifey), isNull);
    expect(sleepRecordFromPoint(_hk(HealthDataType.SLEEP_DEEP, 'zero', _t(20, 23), _t(20, 23))), isNull);
    expect(sleepRecordFromPoint(_hk(HealthDataType.STEPS, 'steps', _t(20, 23), _t(21, 0))), isNull);
  });

  group('HealthService.recentSleepSessions', () {
    test('reads from 24 hours before the cursor and keeps the nights that end at or after it', () async {
      final health = _FakeHealth([
        ..._appleWatchNight(),
        _hk(HealthDataType.SLEEP_DEEP, 'older', _t(19, 23), _t(20, 1)),
      ]);
      final service = _AvailableHealthService(health);
      final since = DateTime.utc(2026, 11, 20, 12);

      final nights = await service.recentSleepSessions(since: since);

      expect(health.queryStart, since.subtract(const Duration(hours: 24)));
      expect(nights.map((n) => n.healthRecordId), ['aw-1']);
    });

    test('a store failure yields no nights instead of throwing', () async {
      final service = _AvailableHealthService(_FakeHealth(const [], fail: true));

      expect(await service.recentSleepSessions(since: DateTime.utc(2026, 11, 20)), isEmpty);
    });
  });
}

List<HealthSleepSession> _merge(List<HealthDataPoint> points) {
  final sessions = <SleepSessionRecord>[];
  final stages = <SleepStageSample>[];
  for (final point in points) {
    switch (sleepRecordFromPoint(point)) {
      case final SleepSessionRecord s:
        sessions.add(s);
      case final SleepStageSample s:
        stages.add(s);
    }
  }
  return mergeSleep(sessions: sessions, stages: stages);
}

DateTime _t(int day, int hour, [int minute = 0]) => DateTime.utc(2026, 11, day, hour, minute);

/// 22:40–06:10: 230 light, 80 deep, 110 REM, 20 awake in bed, 10 out of bed.
List<HealthDataPoint> _healthConnectNight() => [
      _hc(HealthDataType.SLEEP_SESSION, 'hc-session-1', _t(20, 22, 40), _t(21, 6, 10)),
      _hc(HealthDataType.SLEEP_AWAKE_IN_BED, 'hc-session-1', _t(20, 22, 40), _t(20, 23)),
      _hc(HealthDataType.SLEEP_LIGHT, 'hc-session-1', _t(20, 23), _t(21, 1)),
      _hc(HealthDataType.SLEEP_DEEP, 'hc-session-1', _t(21, 1), _t(21, 2, 20)),
      _hc(HealthDataType.SLEEP_REM, 'hc-session-1', _t(21, 2, 20), _t(21, 4, 10)),
      _hc(HealthDataType.SLEEP_OUT_OF_BED, 'hc-session-1', _t(21, 4, 10), _t(21, 4, 20)),
      _hc(HealthDataType.SLEEP_LIGHT, 'hc-session-1', _t(21, 4, 20), _t(21, 6, 10)),
    ];

/// 22:30–06:30 from the Apple Watch, with a 10-minute gap at 02:00 (kept in
/// one session): 240 light ("core"), 90 deep, 120 REM, 15 awake.
List<HealthDataPoint> _appleWatchNight() => [
      _hk(HealthDataType.SLEEP_LIGHT, 'aw-1', _t(20, 22, 30), _t(21, 0, 30)),
      _hk(HealthDataType.SLEEP_DEEP, 'aw-2', _t(21, 0, 30), _t(21, 2)),
      _hk(HealthDataType.SLEEP_REM, 'aw-3', _t(21, 2, 10), _t(21, 4, 10)),
      _hk(HealthDataType.SLEEP_AWAKE, 'aw-4', _t(21, 4, 10), _t(21, 4, 25)),
      _hk(HealthDataType.SLEEP_LIGHT, 'aw-5', _t(21, 4, 30), _t(21, 6, 30)),
    ];

HealthDataPoint _hc(HealthDataType type, String uuid, DateTime from, DateTime to) => HealthDataPoint(
      uuid: uuid,
      value: NumericHealthValue(numericValue: to.difference(from).inMinutes),
      type: type,
      unit: HealthDataUnit.MINUTE,
      dateFrom: from,
      dateTo: to,
      sourcePlatform: HealthPlatformType.googleHealthConnect,
      sourceDeviceId: 'device',
      sourceId: '',
      sourceName: 'com.garmin.android.apps.connectmobile',
    );

HealthDataPoint _hk(HealthDataType type, String uuid, DateTime from, DateTime to, {String source = 'Apple Watch'}) =>
    HealthDataPoint(
      uuid: uuid,
      value: NumericHealthValue(numericValue: to.difference(from).inMinutes),
      type: type,
      unit: HealthDataUnit.MINUTE,
      dateFrom: from,
      dateTo: to,
      sourcePlatform: HealthPlatformType.appleHealth,
      sourceDeviceId: 'device',
      sourceId: 'com.apple.health.${source.toLowerCase().replaceAll(' ', '')}',
      sourceName: source,
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
