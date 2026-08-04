import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/watch/watch_workout_service.dart';
import 'package:lifey/core/workout_session_notifier/workout_session_notifier_service.dart';
import 'package:lifey/features/workouts/application/watch_template_sync.dart';

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
      await service.ackSetLogged(sessionClientId: 'session-1', eventId: 'event-1', accepted: true);
      await service.ackStandaloneSession('standalone-1');

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
          'restTotalSeconds': null,
          'restRemainingSeconds': null,
          'nextSetWeight': null,
          'nextSetReps': null,
          'setsDoneExerciseIndex': null,
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
          restTotalSeconds: 90,
          restRemainingSeconds: 47,
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
          'restTotalSeconds': 90,
          'restRemainingSeconds': 47,
          'nextSetWeight': null,
          'nextSetReps': null,
          'setsDoneExerciseIndex': null,
        },
      });
    });

    test('updateState carries the F5b adjust prefill when the phone has one', () async {
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
          nextSetWeight: 62.5,
          nextSetReps: 6,
        ),
      );

      final state = (calls.single.arguments as Map)['state'] as Map;
      expect(state['nextSetWeight'], 62.5);
      expect(state['nextSetReps'], 6);
    });

    test('updateState tags the set counts with the exercise the watch named', () async {
      // A watch-started session logs sets on both devices, but only the phone
      // sees both halves — the index is what lets the watch tell that this
      // count is about the exercise it is logging into.
      setHandler((call) async {
        calls.add(call);
        return null;
      });
      final service = WatchWorkoutService(isAvailable: true);

      await service.updateState(
        sessionClientId: 'session-1',
        state: const WorkoutSessionState(
          exerciseName: 'Guggolás',
          setsDone: 3,
          setsTotal: 4,
          totalSetsDone: 6,
          setsDoneExerciseIndex: 1,
        ),
      );

      final state = (calls.single.arguments as Map)['state'] as Map;
      expect(state['setsDoneExerciseIndex'], 1);
      expect(state['setsDone'], 3);
      expect(state['setsTotal'], 4);
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

    test('ackSetLogged sends sessionClientId + eventId + accepted', () async {
      setHandler((call) async {
        calls.add(call);
        return null;
      });
      final service = WatchWorkoutService(isAvailable: true);

      await service.ackSetLogged(sessionClientId: 'session-1', eventId: 'event-1', accepted: true);

      expect(calls.single.method, 'ackSetLogged');
      expect(calls.single.arguments, {
        'sessionClientId': 'session-1',
        'eventId': 'event-1',
        'accepted': true,
      });
    });

    test('ackSetLogged sends accepted: false', () async {
      setHandler((call) async {
        calls.add(call);
        return null;
      });
      final service = WatchWorkoutService(isAvailable: true);

      await service.ackSetLogged(sessionClientId: 'session-1', eventId: 'event-2', accepted: false);

      expect(calls.single.arguments, {
        'sessionClientId': 'session-1',
        'eventId': 'event-2',
        'accepted': false,
      });
    });

    test('ackStandaloneSession sends standaloneSessionId', () async {
      setHandler((call) async {
        calls.add(call);
        return null;
      });
      final service = WatchWorkoutService(isAvailable: true);

      await service.ackStandaloneSession('standalone-1');

      expect(calls.single.method, 'ackStandaloneSession');
      expect(calls.single.arguments, {'standaloneSessionId': 'standalone-1'});
    });

    test('syncTemplates sends the serialized templates + a phone-clock stamp', () async {
      setHandler((call) async {
        calls.add(call);
        return null;
      });
      final service = WatchWorkoutService(isAvailable: true);
      final before = DateTime.now().millisecondsSinceEpoch;

      await service.syncTemplates(const [
        WatchTemplatePayload(
          templateId: 'push',
          title: 'Push day',
          exercises: [
            WatchTemplateExercisePayload(
              exerciseId: 'bench',
              name: 'Bench Press',
              restSeconds: 90,
              targetSets: 4,
            ),
          ],
        ),
      ]);

      expect(calls.single.method, 'syncTemplates');
      final arguments = calls.single.arguments as Map;
      expect(arguments['templates'], [
        {
          'templateId': 'push',
          'title': 'Push day',
          'exercises': [
            {'exerciseId': 'bench', 'name': 'Bench Press', 'restSeconds': 90, 'targetSets': 4},
          ],
        },
      ]);
      expect(
        arguments['syncedAtEpochMs'],
        allOf(isA<int>(), greaterThanOrEqualTo(before)),
      );
    });

    test('syncTemplates sends an empty list rather than skipping the call', () async {
      // That's how a watch whose last template was just deleted is told to
      // clear its cache (§4.3).
      setHandler((call) async {
        calls.add(call);
        return null;
      });
      final service = WatchWorkoutService(isAvailable: true);

      await service.syncTemplates(const []);

      expect(calls.single.method, 'syncTemplates');
      expect((calls.single.arguments as Map)['templates'], isEmpty);
    });

    test('syncTemplates no-ops when unavailable', () async {
      setHandler((call) async {
        calls.add(call);
        return null;
      });
      final service = WatchWorkoutService(isAvailable: false);

      await service.syncTemplates(const [
        WatchTemplatePayload(templateId: 'push', title: 'Push day', exercises: []),
      ]);

      expect(calls, isEmpty);
    });

    test('syncTemplates swallows a missing native handler (none exists until T3)', () async {
      setHandler((call) async {
        calls.add(call);
        throw MissingPluginException('No implementation found for syncTemplates');
      });
      final service = WatchWorkoutService(isAvailable: true);

      await expectLater(service.syncTemplates(const []), completes);
      expect(calls.single.method, 'syncTemplates');
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

    test('decodes a setLogged event', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockStreamHandler(
        eventChannel,
        MockStreamHandler.inline(
          onListen: (arguments, events) {
            events.success({
              'type': 'setLogged',
              'sessionClientId': 'session-1',
              'eventId': 'event-1',
              'loggedAtEpochMs': 1783075260000,
            });
          },
        ),
      );
      final service = WatchWorkoutService(isAvailable: true);

      final event = await service.events.first;

      expect(event, isA<WatchSetLogged>());
      final setLogged = event as WatchSetLogged;
      expect(setLogged.sessionClientId, 'session-1');
      expect(setLogged.eventId, 'event-1');
      expect(setLogged.loggedAtEpochMs, 1783075260000);
      // F5a's plain one-tap flow sends no values (D-F5b.6).
      expect(setLogged.reps, isNull);
      expect(setLogged.weight, isNull);
      expect(setLogged.loggedValues, isNull);
    });

    test('decodes a setLogged event carrying the F5b adjust values', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockStreamHandler(
        eventChannel,
        MockStreamHandler.inline(
          onListen: (arguments, events) {
            events.success({
              'type': 'setLogged',
              'sessionClientId': 'session-1',
              'eventId': 'event-1',
              'loggedAtEpochMs': 1783075260000,
              'reps': 12,
              'weight': 62.5,
            });
          },
        ),
      );
      final service = WatchWorkoutService(isAvailable: true);

      final setLogged = await service.events.first as WatchSetLogged;

      expect(setLogged.reps, 12);
      expect(setLogged.weight, 62.5);
      expect(setLogged.loggedValues, (weight: 62.5, reps: 12));
    });

    test('a whole-number weight arriving as an int still decodes as double', () async {
      // The platform channel delivers 60, not 60.0 — `as double?` would throw.
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockStreamHandler(
        eventChannel,
        MockStreamHandler.inline(
          onListen: (arguments, events) {
            events.success({
              'type': 'setLogged',
              'sessionClientId': 'session-1',
              'eventId': 'event-1',
              'loggedAtEpochMs': 1783075260000,
              'reps': 10,
              'weight': 60,
            });
          },
        ),
      );
      final service = WatchWorkoutService(isAvailable: true);

      final setLogged = await service.events.first as WatchSetLogged;

      expect(setLogged.weight, 60.0);
      expect(setLogged.loggedValues, (weight: 60.0, reps: 10));
    });

    test('a half-filled payload counts as no values (§4.1: reps and weight travel together)', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockStreamHandler(
        eventChannel,
        MockStreamHandler.inline(
          onListen: (arguments, events) {
            events.success({
              'type': 'setLogged',
              'sessionClientId': 'session-1',
              'eventId': 'event-1',
              'loggedAtEpochMs': 1783075260000,
              'reps': 12, // weight hiányzik
            });
          },
        ),
      );
      final service = WatchWorkoutService(isAvailable: true);

      final setLogged = await service.events.first as WatchSetLogged;

      expect(setLogged.reps, 12);
      expect(setLogged.weight, isNull);
      expect(
        setLogged.loggedValues,
        isNull,
        reason: 'a hiányos pár nem írhat null-t egy tervezett érték fölé',
      );
    });

    test('decodes a standaloneSession event', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockStreamHandler(
        eventChannel,
        MockStreamHandler.inline(
          onListen: (arguments, events) {
            events.success({
              'type': 'standaloneSession',
              'payload': {
                'standaloneSessionId': 'standalone-1',
                'templateId': null,
                'startedAtEpochMs': 1783075200000,
                'endedAtEpochMs': 1783078800000,
                'rpe': 7,
                'sets': [
                  {'loggedAtEpochMs': 1783075260000, 'reps': 10, 'exerciseIndex': null},
                  {'loggedAtEpochMs': 1783075320000, 'reps': 10, 'exerciseIndex': null},
                ],
                'activeCalories': 214.0,
                'averageHeartRate': 126.0,
                'healthWorkoutId': 'watch-uuid-2',
              },
            });
          },
        ),
      );
      final service = WatchWorkoutService(isAvailable: true);

      final event = await service.events.first;

      expect(event, isA<WatchStandaloneSession>());
      final session = event as WatchStandaloneSession;
      expect(session.standaloneSessionId, 'standalone-1');
      expect(session.templateId, isNull);
      expect(session.startedAtEpochMs, 1783075200000);
      expect(session.endedAtEpochMs, 1783078800000);
      expect(session.rpe, 7);
      expect(session.sets, hasLength(2));
      expect(session.sets.first.loggedAtEpochMs, 1783075260000);
      expect(session.sets.first.reps, 10);
      expect(session.sets.first.exerciseIndex, isNull);
      expect(session.activeCalories, 214.0);
      expect(session.averageHeartRate, 126.0);
      expect(session.healthWorkoutId, 'watch-uuid-2');
    });

    test('decodes a standaloneSession event with empty sets and no optional fields', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockStreamHandler(
        eventChannel,
        MockStreamHandler.inline(
          onListen: (arguments, events) {
            events.success({
              'type': 'standaloneSession',
              'payload': {
                'standaloneSessionId': 'standalone-2',
                'startedAtEpochMs': 1783075200000,
                'endedAtEpochMs': 1783075200000,
                'sets': <Object?>[],
              },
            });
          },
        ),
      );
      final service = WatchWorkoutService(isAvailable: true);

      final event = await service.events.first;

      expect(event, isA<WatchStandaloneSession>());
      final session = event as WatchStandaloneSession;
      expect(session.standaloneSessionId, 'standalone-2');
      expect(session.templateId, isNull);
      expect(session.rpe, isNull);
      expect(session.sets, isEmpty);
      expect(session.activeCalories, isNull);
      expect(session.averageHeartRate, isNull);
      expect(session.healthWorkoutId, isNull);
    });

    test('decodes a standaloneSessionAdopted event, including the watch\'s current exercise',
        () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockStreamHandler(
        eventChannel,
        MockStreamHandler.inline(
          onListen: (arguments, events) {
            events.success({
              'type': 'standaloneSessionAdopted',
              'payload': {
                'standaloneSessionId': 'standalone-3',
                'templateId': 'template-1',
                'startedAtEpochMs': 1783075200000,
                'sets': [
                  {'loggedAtEpochMs': 1783075260000, 'reps': 10, 'weight': 60, 'exerciseIndex': 0},
                ],
                'activeCalories': 88.0,
                'averageHeartRate': 118.0,
                'currentExerciseIndex': 1,
              },
            });
          },
        ),
      );
      final service = WatchWorkoutService(isAvailable: true);

      final event = await service.events.first;

      expect(event, isA<WatchStandaloneAdoption>());
      final adoption = event as WatchStandaloneAdoption;
      expect(adoption.standaloneSessionId, 'standalone-3');
      expect(adoption.templateId, 'template-1');
      expect(adoption.startedAtEpochMs, 1783075200000);
      expect(adoption.sets, hasLength(1));
      expect(adoption.sets.first.exerciseIndex, 0);
      expect(adoption.activeCalories, 88.0);
      expect(adoption.averageHeartRate, 118.0);
      // The set above was logged against exercise 0; the watch has already
      // moved on to exercise 1 for the next one.
      expect(adoption.currentExerciseIndex, 1);
    });

    test('an adoption without a current exercise (quick start, or an older watch build) decodes',
        () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockStreamHandler(
        eventChannel,
        MockStreamHandler.inline(
          onListen: (arguments, events) {
            events.success({
              'type': 'standaloneSessionAdopted',
              'payload': {
                'standaloneSessionId': 'standalone-4',
                'startedAtEpochMs': 1783075200000,
                'sets': <Object?>[],
              },
            });
          },
        ),
      );
      final service = WatchWorkoutService(isAvailable: true);

      final event = await service.events.first;

      final adoption = event as WatchStandaloneAdoption;
      expect(adoption.currentExerciseIndex, isNull);
      expect(adoption.templateId, isNull);
      expect(adoption.sets, isEmpty);
    });

    test('an unknown event type falls back to its raw type string', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockStreamHandler(
        eventChannel,
        MockStreamHandler.inline(
          onListen: (arguments, events) {
            events.success({'type': 'somethingUnhandled'});
          },
        ),
      );
      final service = WatchWorkoutService(isAvailable: true);

      final event = await service.events.first;

      expect(event, 'somethingUnhandled');
    });
  });
}
