import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/live_activity/workout_live_activity_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('lifey/live_activity');
  final calls = <MethodCall>[];

  void setHandler(Future<Object?> Function(MethodCall) handler) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, handler);
  }

  setUp(() {
    calls.clear();
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('WorkoutLiveActivityService', () {
    test('no-ops when unavailable (non-iOS) — no channel calls made', () async {
      setHandler((call) async {
        calls.add(call);
        return null;
      });
      final service = WorkoutLiveActivityService(isAvailable: false);

      final id = await service.start(
        sessionClientId: 'session-1',
        title: 'Edzés',
        startedAt: DateTime(2026, 7, 10, 8),
        state: const LiveActivityContentState(
          exerciseName: 'Fekvenyomás',
          setsDone: 1,
          setsTotal: 3,
          totalSetsDone: 1,
          lastSetAtEpochMs: 1000,
        ),
      );
      await service.update(
        sessionClientId: 'session-1',
        state: const LiveActivityContentState(exerciseName: 'x', setsDone: 0, totalSetsDone: 0),
      );
      await service.end();
      await service.endAll();

      expect(id, isNull);
      expect(calls, isEmpty);
    });

    test('start sends sessionClientId/title/startedAtEpochMs + state and returns the activity id', () async {
      setHandler((call) async {
        calls.add(call);
        return 'native-activity-id';
      });
      final service = WorkoutLiveActivityService(isAvailable: true);

      final id = await service.start(
        sessionClientId: 'session-1',
        title: 'Edzés',
        startedAt: DateTime.fromMillisecondsSinceEpoch(1783075200000),
        state: const LiveActivityContentState(
          exerciseName: 'Fekvenyomás',
          setsDone: 1,
          setsTotal: 3,
          totalSetsDone: 1,
          lastSetAtEpochMs: 1783075260000,
        ),
      );

      expect(id, 'native-activity-id');
      expect(calls, hasLength(1));
      expect(calls.single.method, 'start');
      expect(calls.single.arguments, {
        'sessionClientId': 'session-1',
        'title': 'Edzés',
        'startedAtEpochMs': 1783075200000,
        'state': {
          'exerciseName': 'Fekvenyomás',
          'setsDone': 1,
          'setsTotal': 3,
          'totalSetsDone': 1,
          'lastSetAtEpochMs': 1783075260000,
        },
      });
    });

    test('update sends sessionClientId + state', () async {
      setHandler((call) async {
        calls.add(call);
        return null;
      });
      final service = WorkoutLiveActivityService(isAvailable: true);

      await service.update(
        sessionClientId: 'session-1',
        state: const LiveActivityContentState(
          exerciseName: 'Guggolás',
          setsDone: 2,
          setsTotal: null,
          totalSetsDone: 5,
          lastSetAtEpochMs: null,
        ),
      );

      expect(calls.single.method, 'update');
      expect(calls.single.arguments, {
        'sessionClientId': 'session-1',
        'state': {
          'exerciseName': 'Guggolás',
          'setsDone': 2,
          'setsTotal': null,
          'totalSetsDone': 5,
          'lastSetAtEpochMs': null,
        },
      });
    });

    test('end and endAll invoke their methods with no arguments', () async {
      setHandler((call) async {
        calls.add(call);
        return null;
      });
      final service = WorkoutLiveActivityService(isAvailable: true);

      await service.end();
      await service.endAll();

      expect(calls.map((c) => c.method), ['end', 'endAll']);
    });

    test('a full session call sequence: start -> update -> end', () async {
      setHandler((call) async {
        calls.add(call);
        return call.method == 'start' ? 'activity-1' : null;
      });
      final service = WorkoutLiveActivityService(isAvailable: true);

      await service.start(
        sessionClientId: 'session-1',
        title: 'Edzés',
        startedAt: DateTime(2026, 7, 10, 8),
        state: const LiveActivityContentState(exerciseName: 'Fekvenyomás', setsDone: 0, setsTotal: 3, totalSetsDone: 0),
      );
      await service.update(
        sessionClientId: 'session-1',
        state: const LiveActivityContentState(exerciseName: 'Fekvenyomás', setsDone: 1, setsTotal: 3, totalSetsDone: 1, lastSetAtEpochMs: 1000),
      );
      await service.end();

      expect(calls.map((c) => c.method), ['start', 'update', 'end']);
    });
  });
}
