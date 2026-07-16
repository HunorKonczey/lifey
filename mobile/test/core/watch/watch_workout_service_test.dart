import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/watch/watch_workout_service.dart';
import 'package:lifey/core/workout_session_notifier/workout_session_notifier_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WatchWorkoutService — MethodChannel calls', () {
    const channel = MethodChannel('lifey/watch');
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

    test('no-ops when unavailable — no channel calls made', () async {
      setHandler((call) async {
        calls.add(call);
        return null;
      });
      final service = WatchWorkoutService(isAvailable: false);

      final available = await service.isWatchAppAvailable();
      await service.startWorkout(
        sessionClientId: 'session-1',
        title: 'Push Day',
        startedAt: DateTime(2026, 7, 10, 8),
        state: const WorkoutSessionState(exerciseName: 'x', setsDone: 0, totalSetsDone: 0),
      );
      await service.updateState(
        sessionClientId: 'session-1',
        state: const WorkoutSessionState(exerciseName: 'x', setsDone: 0, totalSetsDone: 0),
      );
      await service.endWorkout('session-1');

      expect(available, isFalse);
      expect(calls, isEmpty);
    });

    test('a native call throwing MissingPluginException is swallowed, not rethrown', () async {
      // No handler registered at all — mirrors the real state before the
      // native watch targets exist (docs/40-watch-app-plan.md phases F2/F3).
      final service = WatchWorkoutService(isAvailable: true);

      await expectLater(
        service.startWorkout(
          sessionClientId: 'session-1',
          title: 'Push Day',
          startedAt: DateTime(2026, 7, 10, 8),
          state: const WorkoutSessionState(exerciseName: 'x', setsDone: 0, totalSetsDone: 0),
        ),
        completes,
      );
      expect(await service.isWatchAppAvailable(), isFalse);
    });

    test('startWorkout sends sessionClientId/title/startedAtEpochMs + state', () async {
      setHandler((call) async {
        calls.add(call);
        return null;
      });
      final service = WatchWorkoutService(isAvailable: true);

      await service.startWorkout(
        sessionClientId: 'session-1',
        title: 'Push Day',
        startedAt: DateTime.fromMillisecondsSinceEpoch(1783075200000),
        state: const WorkoutSessionState(
          exerciseName: 'Fekvenyomás',
          setsDone: 1,
          setsTotal: 3,
          totalSetsDone: 1,
          lastSetAtEpochMs: 1783075260000,
        ),
      );

      expect(calls, hasLength(1));
      expect(calls.single.method, 'startWorkout');
      expect(calls.single.arguments, {
        'sessionClientId': 'session-1',
        'title': 'Push Day',
        'startedAtEpochMs': 1783075200000,
        'state': {
          'exerciseName': 'Fekvenyomás',
          'setsDone': 1,
          'setsTotal': 3,
          'totalSetsDone': 1,
          'lastSetAtEpochMs': 1783075260000,
          'restEndsAtEpochMs': null,
        },
      });
    });

    test('updateState sends sessionClientId + state', () async {
      setHandler((call) async {
        calls.add(call);
        return null;
      });
      final service = WatchWorkoutService(isAvailable: true);

      await service.updateState(
        sessionClientId: 'session-1',
        state: const WorkoutSessionState(
          exerciseName: 'Guggolás',
          setsDone: 2,
          totalSetsDone: 5,
          restEndsAtEpochMs: 1783075350000,
        ),
      );

      expect(calls.single.method, 'updateState');
      expect(calls.single.arguments, {
        'sessionClientId': 'session-1',
        'state': {
          'exerciseName': 'Guggolás',
          'setsDone': 2,
          'setsTotal': null,
          'totalSetsDone': 5,
          'lastSetAtEpochMs': null,
          'restEndsAtEpochMs': 1783075350000,
        },
      });
    });

    test('endWorkout sends sessionClientId', () async {
      setHandler((call) async {
        calls.add(call);
        return null;
      });
      final service = WatchWorkoutService(isAvailable: true);

      await service.endWorkout('session-1');

      expect(calls.single.method, 'endWorkout');
      expect(calls.single.arguments, {'sessionClientId': 'session-1'});
    });

    test('isWatchAppAvailable returns the native answer', () async {
      setHandler((call) async {
        calls.add(call);
        return true;
      });
      final service = WatchWorkoutService(isAvailable: true);

      expect(await service.isWatchAppAvailable(), isTrue);
      expect(calls.single.method, 'isWatchAppAvailable');
    });
  });

  group('WatchWorkoutService — events', () {
    const eventChannel = EventChannel('lifey/watch/events');

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockStreamHandler(eventChannel, null);
    });

    test('an empty (no-op) stream when unavailable — never emits', () async {
      final service = WatchWorkoutService(isAvailable: false);
      final events = await service.events.toList().timeout(
            const Duration(milliseconds: 50),
            onTimeout: () => const [],
          );
      expect(events, isEmpty);
    });

    test('decodes a summary event', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockStreamHandler(
        eventChannel,
        MockStreamHandler.inline(
          onListen: (arguments, events) {
            events.success({
              'type': 'summary',
              'payload': {
                'sessionClientId': 'session-1',
                'activeCalories': 410.0,
                'averageHeartRate': 128.0,
                'healthWorkoutId': 'watch-uuid-1',
              },
            });
          },
        ),
      );
      final service = WatchWorkoutService(isAvailable: true);

      final event = await service.events.first;

      expect(event, isA<WatchWorkoutSummary>());
      final summary = event as WatchWorkoutSummary;
      expect(summary.sessionClientId, 'session-1');
      expect(summary.activeCalories, 410.0);
      expect(summary.averageHeartRate, 128.0);
      expect(summary.healthWorkoutId, 'watch-uuid-1');
    });

    test('decodes a startRejected event', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockStreamHandler(
        eventChannel,
        MockStreamHandler.inline(
          onListen: (arguments, events) {
            events.success({'type': 'startRejected', 'sessionClientId': 'session-1'});
          },
        ),
      );
      final service = WatchWorkoutService(isAvailable: true);

      final event = await service.events.first;

      expect(event, isA<WatchStartRejected>());
      expect((event as WatchStartRejected).sessionClientId, 'session-1');
    });

    test('decodes an endRequested event', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockStreamHandler(
        eventChannel,
        MockStreamHandler.inline(
          onListen: (arguments, events) {
            events.success({'type': 'endRequested', 'sessionClientId': 'session-1'});
          },
        ),
      );
      final service = WatchWorkoutService(isAvailable: true);

      final event = await service.events.first;

      expect(event, isA<WatchEndRequested>());
      expect((event as WatchEndRequested).sessionClientId, 'session-1');
    });
  });
}
