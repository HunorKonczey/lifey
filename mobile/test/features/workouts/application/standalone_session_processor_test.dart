import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/local_db/app_database.dart';
import 'package:lifey/core/sync/outbox_writer.dart';
import 'package:lifey/core/sync/sync_engine.dart';
import 'package:lifey/core/watch/watch_workout_service.dart';
import 'package:lifey/features/settings/domain/user_settings.dart';
import 'package:lifey/features/workouts/application/standalone_session_processor.dart';
import 'package:lifey/features/workouts/data/exercise_repository.dart';
import 'package:lifey/features/workouts/data/workout_session_repository.dart';
import 'package:lifey/features/workouts/data/workout_template_repository.dart';
import 'package:lifey/features/workouts/domain/workout_template.dart';

/// [StandaloneSessionProcessor] turns a finished watch-only session into a
/// normal, already-closed [WorkoutSession] (docs/watch/
/// 44-watch-f6-standalone-plan.md §1, §4.1, §6/3). These tests run its full
/// create path against a real (in-memory) Drift database so the generic
/// exercise resolution and the `WorkoutSession`/`ExerciseSet` rows it writes
/// are checked end to end, not just which methods it calls.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late WorkoutSessionRepository sessionRepository;
  late ExerciseRepository exerciseRepository;
  late WorkoutTemplateRepository templateRepository;
  late WatchWorkoutService watchService;
  final ackCalls = <MethodCall>[];
  const channel = MethodChannel('lifey/watch');

  WatchStandaloneSession sampleEvent({
    String standaloneSessionId = 'standalone-1',
    List<WatchStandaloneSet> sets = const [
      WatchStandaloneSet(loggedAtEpochMs: 1783075260000, reps: 10),
      WatchStandaloneSet(loggedAtEpochMs: 1783075320000, reps: 10),
    ],
    String? templateId,
    int? rpe,
    double? activeCalories,
    double? averageHeartRate,
    String? healthWorkoutId,
  }) =>
      WatchStandaloneSession(
        standaloneSessionId: standaloneSessionId,
        templateId: templateId,
        startedAtEpochMs: 1783075200000,
        endedAtEpochMs: 1783078800000,
        rpe: rpe,
        sets: sets,
        activeCalories: activeCalories,
        averageHeartRate: averageHeartRate,
        healthWorkoutId: healthWorkoutId,
      );

  Future<String?> defaultWriteHealthWorkout({
    required DateTime start,
    required DateTime end,
    double? activeCalories,
    String? title,
  }) async =>
      null;

  StandaloneSessionProcessor buildProcessor({WriteHealthWorkout? writeHealthWorkout}) {
    return StandaloneSessionProcessor(
      sessionRepository: sessionRepository,
      exerciseRepository: exerciseRepository,
      templateRepository: templateRepository,
      watchService: watchService,
      writeHealthWorkout: writeHealthWorkout ?? defaultWriteHealthWorkout,
    );
  }

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    sessionRepository = WorkoutSessionRepository(db, OutboxWriter(db, _NoopSyncEngine(db, Dio())));
    exerciseRepository = ExerciseRepository(db, OutboxWriter(db, _NoopSyncEngine(db, Dio())));
    templateRepository = WorkoutTemplateRepository(db, OutboxWriter(db, _NoopSyncEngine(db, Dio())));
    ackCalls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (call) async {
        ackCalls.add(call);
        return null;
      },
    );
    watchService = WatchWorkoutService(isAvailable: true);
  });

  tearDown(() {
    db.close();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('creates an already-closed session with the localized generic exercise', () async {
    final processor = buildProcessor();

    await processor.process(sampleEvent(), language: LanguagePreference.english);

    final row = await db.select(db.workoutSessions).getSingle();
    expect(row.clientId, 'standalone-1');
    // Drift round-trips DateTimeColumn as local time, so compare the moment
    // rather than `==` (which also requires a matching isUtc flag).
    expect(
      row.startedAt!.isAtSameMomentAs(DateTime.fromMillisecondsSinceEpoch(1783075200000, isUtc: true)),
      isTrue,
    );
    expect(
      row.finishedAt!.isAtSameMomentAs(DateTime.fromMillisecondsSinceEpoch(1783078800000, isUtc: true)),
      isTrue,
    );
    expect(row.templateName, 'Quick strength');

    final exercises = await db.select(db.exercises).get();
    expect(exercises, hasLength(1));
    expect(exercises.single.name, 'Quick strength');

    final sets = await db.select(db.exerciseSets).get();
    expect(sets, hasLength(2));
    expect(sets.every((s) => s.reps == 10), isTrue);
    expect(sets.every((s) => s.weight == 0), isTrue);
    expect(sets.every((s) => s.exerciseClientId == exercises.single.clientId), isTrue);

    expect(ackCalls, hasLength(1));
    expect(ackCalls.single.method, 'ackStandaloneSession');
    expect(ackCalls.single.arguments, {'standaloneSessionId': 'standalone-1'});
  });

  test('carries the working weight forward to a set the stepper was not used for', () async {
    final processor = buildProcessor();

    await processor.process(
      sampleEvent(
        sets: const [
          WatchStandaloneSet(loggedAtEpochMs: 1783075260000, reps: 8, weight: 62.5),
          WatchStandaloneSet(loggedAtEpochMs: 1783075320000, reps: 10),
        ],
      ),
      language: LanguagePreference.english,
    );

    final sets = await db.select(db.exerciseSets).get();
    expect(sets, hasLength(2));
    final adjusted = sets.singleWhere((s) => s.reps == 8);
    expect(adjusted.weight, 62.5);
    // A plain "+1" tap carries no weight of its own; it used to be persisted
    // as a literal 0 kg even mid-session at a known working weight.
    final plain = sets.singleWhere((s) => s.reps == 10);
    expect(plain.weight, 62.5);
  });

  test('seeds a weightless set from the last session that trained the exercise', () async {
    final processor = buildProcessor();
    // A previous standalone session at 80/85 kg for the same generic
    // exercise — the positional hint each of this session's sets should pick
    // up, exactly like the phone's own "+1" prefill does.
    await processor.process(
      sampleEvent(
        standaloneSessionId: 'standalone-earlier',
        sets: const [
          WatchStandaloneSet(loggedAtEpochMs: 1782975260000, reps: 8, weight: 85),
          WatchStandaloneSet(loggedAtEpochMs: 1782975320000, reps: 8, weight: 80),
        ],
      ),
      language: LanguagePreference.english,
    );

    await processor.process(
      sampleEvent(
        sets: const [
          WatchStandaloneSet(loggedAtEpochMs: 1783075260000, reps: 10),
          WatchStandaloneSet(loggedAtEpochMs: 1783075320000, reps: 11),
          // Past the end of the hints — carries the previous row forward.
          WatchStandaloneSet(loggedAtEpochMs: 1783075380000, reps: 12),
        ],
      ),
      language: LanguagePreference.english,
    );

    final sets = await (db.select(db.exerciseSets)
          ..where((t) => t.sessionClientId.equals('standalone-1')))
        .get();
    expect(sets, hasLength(3));
    // getPreviousPerformance sorts by weight descending.
    expect(sets.singleWhere((s) => s.reps == 10).weight, 85);
    expect(sets.singleWhere((s) => s.reps == 11).weight, 80);
    expect(sets.singleWhere((s) => s.reps == 12).weight, 80);
  });

  test('resolves the Hungarian title when language is hungarian', () async {
    final processor = buildProcessor();

    await processor.process(
      sampleEvent(standaloneSessionId: 'standalone-hu'),
      language: LanguagePreference.hungarian,
    );

    final row = await (db.select(db.workoutSessions)
          ..where((t) => t.clientId.equals('standalone-hu')))
        .getSingle();
    expect(row.templateName, 'Gyors erőedzés');
    final exercises = await db.select(db.exercises).get();
    expect(exercises.single.name, 'Gyors erőedzés');
  });

  test('idempotent: a retried delivery for an already-processed session only acks again', () async {
    final processor = buildProcessor();
    await processor.process(sampleEvent(), language: LanguagePreference.english);
    ackCalls.clear();

    await processor.process(sampleEvent(), language: LanguagePreference.english);

    final sessions = await db.select(db.workoutSessions).get();
    expect(sessions, hasLength(1));
    expect(ackCalls, hasLength(1));
    expect(ackCalls.single.method, 'ackStandaloneSession');
    expect(ackCalls.single.arguments, {'standaloneSessionId': 'standalone-1'});
  });

  test('a second standalone session reuses the same generic exercise, no duplicate', () async {
    final processor = buildProcessor();
    await processor.process(sampleEvent(standaloneSessionId: 's1'), language: LanguagePreference.english);

    await processor.process(sampleEvent(standaloneSessionId: 's2'), language: LanguagePreference.english);

    final exercises = await db.select(db.exercises).get();
    expect(exercises, hasLength(1));
    final sessions = await db.select(db.workoutSessions).get();
    expect(sessions, hasLength(2));
    expect(ackCalls, hasLength(2));
  });

  test('calls writeHealthWorkout when healthWorkoutId is absent and fills it in (Android path)', () async {
    var called = false;
    DateTime? capturedStart;
    DateTime? capturedEnd;
    double? capturedActiveCalories;
    Future<String?> fakeWrite({
      required DateTime start,
      required DateTime end,
      double? activeCalories,
      String? title,
    }) async {
      called = true;
      capturedStart = start;
      capturedEnd = end;
      capturedActiveCalories = activeCalories;
      return 'hc-uuid-1';
    }

    final processor = buildProcessor(writeHealthWorkout: fakeWrite);

    await processor.process(sampleEvent(activeCalories: 214), language: LanguagePreference.english);

    expect(called, isTrue);
    expect(capturedStart, DateTime.fromMillisecondsSinceEpoch(1783075200000, isUtc: true));
    expect(capturedEnd, DateTime.fromMillisecondsSinceEpoch(1783078800000, isUtc: true));
    expect(capturedActiveCalories, 214);
    final row = await db.select(db.workoutSessions).getSingle();
    expect(row.healthWorkoutId, 'hc-uuid-1');
  });

  test('does not call writeHealthWorkout when the event already carries one (iOS path)', () async {
    var called = false;
    Future<String?> fakeWrite({
      required DateTime start,
      required DateTime end,
      double? activeCalories,
      String? title,
    }) async {
      called = true;
      return 'should-not-be-used';
    }

    final processor = buildProcessor(writeHealthWorkout: fakeWrite);

    await processor.process(
      sampleEvent(healthWorkoutId: 'ios-uuid-1'),
      language: LanguagePreference.english,
    );

    expect(called, isFalse);
    final row = await db.select(db.workoutSessions).getSingle();
    expect(row.healthWorkoutId, 'ios-uuid-1');
  });

  test('an empty sets list still creates a closed session with no ExerciseSet rows', () async {
    final processor = buildProcessor();

    await processor.process(sampleEvent(sets: const []), language: LanguagePreference.english);

    final sets = await db.select(db.exerciseSets).get();
    expect(sets, isEmpty);
    final row = await db.select(db.workoutSessions).getSingle();
    expect(row.clientId, 'standalone-1');
  });

  test('carries rpe and averageHeartRate through to the created session', () async {
    final processor = buildProcessor();

    await processor.process(
      sampleEvent(rpe: 7, averageHeartRate: 126),
      language: LanguagePreference.english,
    );

    final row = await db.select(db.workoutSessions).getSingle();
    expect(row.rpe, 7);
    expect(row.averageHeartRate, 126);
  });

  group('template resolution (docs/watch/49-watch-f6b-template-sync-plan.md D-F6b.5, T5)', () {
    Future<String> makeExercise(String name) => exerciseRepository.create(name);

    Future<String> makeTemplate(String name, List<TemplateExercise> exercises) =>
        templateRepository.create(name: name, exercises: exercises);

    test('resolves exerciseIndex to the real template exercises, not the generic one', () async {
      final benchId = await makeExercise('Bench Press');
      final squatId = await makeExercise('Back Squat');
      final templateId = await makeTemplate('Push day', [
        TemplateExercise(exerciseClientId: benchId, targetSets: 4),
        TemplateExercise(exerciseClientId: squatId),
      ]);
      final processor = buildProcessor();

      await processor.process(
        sampleEvent(
          templateId: templateId,
          sets: const [
            WatchStandaloneSet(loggedAtEpochMs: 1783075260000, reps: 10, exerciseIndex: 0),
            WatchStandaloneSet(loggedAtEpochMs: 1783075320000, reps: 10, exerciseIndex: 1),
            WatchStandaloneSet(loggedAtEpochMs: 1783075380000, reps: 10, exerciseIndex: 0),
          ],
        ),
        language: LanguagePreference.english,
      );

      // No generic "Quick strength" exercise created — every set resolved.
      final exercises = await db.select(db.exercises).get();
      expect(exercises.map((e) => e.name), unorderedEquals(['Bench Press', 'Back Squat']));

      final sets = await db.select(db.exerciseSets).get();
      expect(sets, hasLength(3));
      expect(sets.where((s) => s.exerciseClientId == benchId), hasLength(2));
      expect(sets.where((s) => s.exerciseClientId == squatId), hasLength(1));

      final row = await db.select(db.workoutSessions).getSingle();
      expect(row.templateClientId, templateId);
      expect(row.templateName, 'Push day');
    });

    test('the session carries the template\'s full planned exercise list, including targetSets', () async {
      final benchId = await makeExercise('Bench Press');
      final flyId = await makeExercise('Cable Fly');
      final templateId = await makeTemplate('Push day', [
        TemplateExercise(exerciseClientId: benchId, targetSets: 4),
        TemplateExercise(exerciseClientId: flyId),
      ]);
      final processor = buildProcessor();

      // Logs against exercise 0 only — exercise 1 (fly) never gets a set.
      await processor.process(
        sampleEvent(
          templateId: templateId,
          sets: const [WatchStandaloneSet(loggedAtEpochMs: 1783075260000, reps: 10, exerciseIndex: 0)],
        ),
        language: LanguagePreference.english,
      );

      // Planned list mirrors the template regardless of what was actually
      // logged — the session looks the same on the phone as the plan.
      final plannedLinks = await (db.select(db.workoutSessionExercises)).get();
      expect(plannedLinks, hasLength(2));
      final byExerciseId = {for (final l in plannedLinks) l.exerciseClientId: l};
      expect(byExerciseId[benchId]?.targetSets, 4);
      expect(byExerciseId[flyId]?.targetSets, isNull);
    });

    test('falls back to the generic exercise when templateId is null (F6a path, unaffected)', () async {
      final processor = buildProcessor();

      await processor.process(
        sampleEvent(templateId: null),
        language: LanguagePreference.english,
      );

      final row = await db.select(db.workoutSessions).getSingle();
      expect(row.templateClientId, isNull);
      expect(row.templateName, 'Quick strength');
      final exercises = await db.select(db.exercises).get();
      expect(exercises.single.name, 'Quick strength');
    });

    test('falls back to the generic exercise when the template was deleted', () async {
      final processor = buildProcessor();

      await processor.process(
        sampleEvent(templateId: 'never-existed'),
        language: LanguagePreference.english,
      );

      final row = await db.select(db.workoutSessions).getSingle();
      expect(row.templateClientId, isNull);
      expect(row.templateName, 'Quick strength');
    });

    test('an exerciseIndex past the end of a since-shrunk template falls back per-set', () async {
      final benchId = await makeExercise('Bench Press');
      final templateId = await makeTemplate('Push day', [
        TemplateExercise(exerciseClientId: benchId),
      ]);
      final processor = buildProcessor();

      await processor.process(
        sampleEvent(
          templateId: templateId,
          sets: const [
            WatchStandaloneSet(loggedAtEpochMs: 1783075260000, reps: 10, exerciseIndex: 0),
            // The watch cached a longer template than the phone now has.
            WatchStandaloneSet(loggedAtEpochMs: 1783075320000, reps: 10, exerciseIndex: 3),
          ],
        ),
        language: LanguagePreference.english,
      );

      final exercises = await db.select(db.exercises).get();
      expect(exercises.map((e) => e.name), unorderedEquals(['Bench Press', 'Quick strength']));

      final sets = await db.select(db.exerciseSets).get();
      final generic = exercises.firstWhere((e) => e.name == 'Quick strength');
      expect(sets.where((s) => s.exerciseClientId == benchId), hasLength(1));
      expect(sets.where((s) => s.exerciseClientId == generic.clientId), hasLength(1));

      // The session is still template-linked — only the one unresolvable
      // set fell back, not the whole session.
      final row = await db.select(db.workoutSessions).getSingle();
      expect(row.templateClientId, templateId);
    });

    test('a null exerciseIndex against a valid template falls back to the generic exercise', () async {
      final benchId = await makeExercise('Bench Press');
      final templateId = await makeTemplate('Push day', [
        TemplateExercise(exerciseClientId: benchId),
      ]);
      final processor = buildProcessor();

      await processor.process(
        sampleEvent(
          templateId: templateId,
          sets: const [WatchStandaloneSet(loggedAtEpochMs: 1783075260000, reps: 10)],
        ),
        language: LanguagePreference.english,
      );

      final exercises = await db.select(db.exercises).get();
      final generic = exercises.firstWhere((e) => e.name == 'Quick strength');
      final sets = await db.select(db.exerciseSets).get();
      expect(sets.single.exerciseClientId, generic.clientId);
    });
  });

  group('live bridging (watch-started session adopted mid-workout)', () {
    Future<String> makeExercise(String name) => exerciseRepository.create(name);

    Future<String> makeTemplate(String name, List<TemplateExercise> exercises) =>
        templateRepository.create(name: name, exercises: exercises);

    WatchStandaloneAdoption sampleAdoptionEvent({
      String standaloneSessionId = 'standalone-1',
      List<WatchStandaloneSet> sets = const [
        WatchStandaloneSet(loggedAtEpochMs: 1783075260000, reps: 10),
      ],
      String? templateId,
      double? activeCalories,
      double? averageHeartRate,
    }) =>
        WatchStandaloneAdoption(
          standaloneSessionId: standaloneSessionId,
          templateId: templateId,
          startedAtEpochMs: 1783075200000,
          sets: sets,
          activeCalories: activeCalories,
          averageHeartRate: averageHeartRate,
        );

    test('creates a running (not-yet-finished) mirror session and acks adoption', () async {
      final processor = buildProcessor();

      await processor.processAdoption(sampleAdoptionEvent(), language: LanguagePreference.english);

      final row = await db.select(db.workoutSessions).getSingle();
      expect(row.clientId, 'standalone-1');
      expect(row.finishedAt, isNull);
      final sets = await db.select(db.exerciseSets).get();
      expect(sets, hasLength(1));

      expect(ackCalls, hasLength(1));
      expect(ackCalls.single.method, 'ackAdoption');
      expect(ackCalls.single.arguments, {'standaloneSessionId': 'standalone-1'});
    });

    test('a resent adoption for an already-adopted session refreshes its set list, not a duplicate row', () async {
      final processor = buildProcessor();
      await processor.processAdoption(sampleAdoptionEvent(), language: LanguagePreference.english);
      ackCalls.clear();

      // The watch resends this snapshot after every set it logs (live sync,
      // not just at the initial handshake) — a resend with more sets than
      // last time must update the existing running row's set list, not
      // leave it stale or create a second session.
      await processor.processAdoption(
        sampleAdoptionEvent(sets: const [
          WatchStandaloneSet(loggedAtEpochMs: 1783075260000, reps: 10),
          WatchStandaloneSet(loggedAtEpochMs: 1783075320000, reps: 10),
        ]),
        language: LanguagePreference.english,
      );

      final sessions = await db.select(db.workoutSessions).get();
      expect(sessions, hasLength(1));
      expect(sessions.single.finishedAt, isNull);
      final sets = await db.select(db.exerciseSets).get();
      expect(sets, hasLength(2));
      expect(ackCalls, hasLength(1));
      expect(ackCalls.single.method, 'ackAdoption');
    });

    test('the final event finishes an already-adopted session instead of creating a duplicate', () async {
      final processor = buildProcessor();
      await processor.processAdoption(sampleAdoptionEvent(), language: LanguagePreference.english);

      await processor.process(
        sampleEvent(
          sets: const [
            WatchStandaloneSet(loggedAtEpochMs: 1783075260000, reps: 10),
            WatchStandaloneSet(loggedAtEpochMs: 1783075320000, reps: 12, weight: 40),
          ],
          rpe: 7,
        ),
        language: LanguagePreference.english,
      );

      final sessions = await db.select(db.workoutSessions).get();
      expect(sessions, hasLength(1));
      expect(sessions.single.finishedAt, isNotNull);
      expect(sessions.single.rpe, 7);

      final sets = await db.select(db.exerciseSets).get();
      expect(sets, hasLength(2));

      expect(ackCalls, hasLength(2));
      expect(ackCalls[0].method, 'ackAdoption');
      expect(ackCalls[1].method, 'ackStandaloneSession');
    });

    test('a late adoption resend after the session already finished is a no-op besides the ack', () async {
      final processor = buildProcessor();
      await processor.processAdoption(sampleAdoptionEvent(), language: LanguagePreference.english);
      await processor.process(sampleEvent(rpe: 7), language: LanguagePreference.english);
      ackCalls.clear();

      // A resend that raced behind the final event and arrived late must not
      // reopen (clear finishedAt on) an already-closed session.
      await processor.processAdoption(
        sampleAdoptionEvent(sets: const [
          WatchStandaloneSet(loggedAtEpochMs: 1783075260000, reps: 10),
        ]),
        language: LanguagePreference.english,
      );

      final row = await db.select(db.workoutSessions).getSingle();
      expect(row.finishedAt, isNotNull);
      expect(row.rpe, 7);
      expect(ackCalls, hasLength(1));
      expect(ackCalls.single.method, 'ackAdoption');
    });

    /// Ending a watch-started workout from the *phone* stamps finishedAt
    /// immediately, so the watch's final payload — the only carrier of the
    /// health metrics and the HealthKit workout id — lands on a session that is
    /// already closed. That branch used to ack and write nothing.
    group('the final payload arriving after the phone already closed the session', () {
      /// What LogSessionScreen's Finish button leaves behind.
      Future<void> finishOnPhone() async {
        final stored = await sessionRepository.findByClientId('standalone-1');
        await sessionRepository.update(
          'standalone-1',
          startedAt: stored!.startedAt!,
          finishedAt: DateTime.fromMillisecondsSinceEpoch(1783078000000, isUtc: true),
          exercises: [
            for (final e in stored.exercises)
              PlannedExerciseInput(exerciseClientId: e.exerciseClientId, targetSets: e.targetSets),
          ],
          sets: [
            for (final s in stored.sets)
              ExerciseSetInput(
                exerciseClientId: s.exerciseClientId,
                reps: s.reps,
                weight: s.weight,
                performedAt: s.performedAt,
              ),
          ],
          rpe: const Value(6),
        );
      }

      test('still applies the calories, heart rate and health workout id', () async {
        final processor = buildProcessor();
        await processor.processAdoption(sampleAdoptionEvent(), language: LanguagePreference.english);
        await finishOnPhone();

        await processor.process(
          sampleEvent(
            activeCalories: 412,
            averageHeartRate: 129,
            healthWorkoutId: 'hk-uuid-9',
          ),
          language: LanguagePreference.english,
        );

        final row = await db.select(db.workoutSessions).getSingle();
        expect(row.activeCalories, 412);
        expect(row.averageHeartRate, 129);
        // Drives the ⌚ badge in the sessions list and on the details screen
        // (WorkoutSession.enrichedFromWatch) — without it there is no sign
        // anywhere that the watch measured this workout.
        expect(row.healthWorkoutId, 'hk-uuid-9');
      });

      test('keeps what the phone already decided', () async {
        final processor = buildProcessor();
        await processor.processAdoption(sampleAdoptionEvent(), language: LanguagePreference.english);
        await finishOnPhone();
        final finishedAt = (await db.select(db.workoutSessions).getSingle()).finishedAt;

        await processor.process(sampleEvent(rpe: 9), language: LanguagePreference.english);

        final row = await db.select(db.workoutSessions).getSingle();
        // The phone closed the session and collected its own rating; the
        // watch's effort selector never ran for this one.
        expect(row.finishedAt, finishedAt);
        expect(row.rpe, 6);
      });

      test('a set the watch never managed to deliver still lands', () async {
        final processor = buildProcessor();
        await processor.processAdoption(sampleAdoptionEvent(), language: LanguagePreference.english);
        await finishOnPhone();

        await processor.process(
          sampleEvent(sets: const [
            WatchStandaloneSet(loggedAtEpochMs: 1783075260000, reps: 10),
            WatchStandaloneSet(loggedAtEpochMs: 1783075320000, reps: 10),
          ]),
          language: LanguagePreference.english,
        );

        expect(await db.select(db.exerciseSets).get(), hasLength(2));
      });

      test('a plain retry of an already-applied payload writes nothing new', () async {
        final processor = buildProcessor();
        await processor.process(
          sampleEvent(activeCalories: 412, healthWorkoutId: 'hk-uuid-9'),
          language: LanguagePreference.english,
        );
        final before = await db.select(db.workoutSessions).getSingle();

        await processor.process(
          sampleEvent(activeCalories: 412, healthWorkoutId: 'hk-uuid-9'),
          language: LanguagePreference.english,
        );

        final after = await db.select(db.workoutSessions).getSingle();
        expect(after, before);
        expect(ackCalls.where((c) => c.method == 'ackStandaloneSession'), hasLength(2));
      });
    });

    /// While the phone app isn't running, the watch's deliveries queue up
    /// (`WatchEventBuffer` on iOS) and the whole backlog is emitted at once the
    /// moment Dart starts listening. `Stream.listen` doesn't await an async
    /// handler, so these arrive genuinely concurrently — which is how a
    /// finished workout ended up sitting on the phone as still running.
    group('a backlog delivered in one go', () {
      test('adoption + completion together still finish the session', () async {
        final processor = buildProcessor();

        // Deliberately not awaited in between — this is what the drain does.
        final adoption =
            processor.processAdoption(sampleAdoptionEvent(), language: LanguagePreference.english);
        final completion = processor.process(sampleEvent(), language: LanguagePreference.english);
        await Future.wait([adoption, completion]);

        final row = await db.select(db.workoutSessions).getSingle();
        expect(row.finishedAt, isNotNull,
            reason: 'the completion must land on the row the adoption created');
        // Neither delivery may be lost: an unacked one is retried by the watch
        // for as long as it takes, which is what used to paper over this.
        expect(ackCalls.map((c) => c.method), containsAll(['ackAdoption', 'ackStandaloneSession']));
      });

      test('completion before adoption (reverse order) also ends up finished', () async {
        final processor = buildProcessor();

        final completion = processor.process(sampleEvent(), language: LanguagePreference.english);
        final adoption =
            processor.processAdoption(sampleAdoptionEvent(), language: LanguagePreference.english);
        await Future.wait([completion, adoption]);

        final row = await db.select(db.workoutSessions).getSingle();
        // The late adoption must not reopen an already-closed session.
        expect(row.finishedAt, isNotNull);
      });

      test('two adoptions together create a single row', () async {
        final processor = buildProcessor();

        await Future.wait([
          processor.processAdoption(sampleAdoptionEvent(), language: LanguagePreference.english),
          processor.processAdoption(
            sampleAdoptionEvent(sets: const [
              WatchStandaloneSet(loggedAtEpochMs: 1783075260000, reps: 10),
              WatchStandaloneSet(loggedAtEpochMs: 1783075320000, reps: 10),
            ]),
            language: LanguagePreference.english,
          ),
        ]);

        expect(await db.select(db.workoutSessions).get(), hasLength(1));
        expect(await db.select(db.exerciseSets).get(), hasLength(2));
      });
    });

    /// A watch-started session's mirror screen stays editable on the phone, so
    /// sets get logged there too — and the watch's snapshot knows nothing about
    /// them. Writing it straight over the row (as this used to) deleted them.
    group('sets logged on the phone during a watch-mastered session', () {
      /// What LogSessionScreen's autosave writes: the whole session as the
      /// screen currently holds it — the watch's set plus one logged here.
      Future<void> logOnPhone({
        required String exerciseClientId,
        required int atEpochMs,
        int reps = 12,
        double weight = 40,
      }) async {
        final stored = await sessionRepository.findByClientId('standalone-1');
        // The screen persists one planned entry per block it shows, so logging
        // into an exercise the session didn't plan means it was added there
        // too ("+ Add exercise").
        final planned = [
          for (final e in stored!.exercises)
            PlannedExerciseInput(exerciseClientId: e.exerciseClientId, targetSets: e.targetSets),
        ];
        if (!planned.any((e) => e.exerciseClientId == exerciseClientId)) {
          planned.add(PlannedExerciseInput(exerciseClientId: exerciseClientId, targetSets: 1));
        }
        await sessionRepository.update(
          'standalone-1',
          startedAt: stored.startedAt!,
          finishedAt: null,
          exercises: planned,
          sets: [
            for (final s in stored.sets)
              ExerciseSetInput(
                exerciseClientId: s.exerciseClientId,
                reps: s.reps,
                weight: s.weight,
                performedAt: s.performedAt,
              ),
            ExerciseSetInput(
              exerciseClientId: exerciseClientId,
              reps: reps,
              weight: weight,
              performedAt: DateTime.fromMillisecondsSinceEpoch(atEpochMs, isUtc: true),
            ),
          ],
        );
      }

      test('survives the next set logged on the watch', () async {
        final processor = buildProcessor();
        await processor.processAdoption(sampleAdoptionEvent(), language: LanguagePreference.english);
        final exerciseClientId =
            (await db.select(db.exercises).getSingle()).clientId;

        await logOnPhone(exerciseClientId: exerciseClientId, atEpochMs: 1783075290000);

        // The watch taps again and resends its own list, which has never heard
        // of the phone's set.
        await processor.processAdoption(
          sampleAdoptionEvent(sets: const [
            WatchStandaloneSet(loggedAtEpochMs: 1783075260000, reps: 10),
            WatchStandaloneSet(loggedAtEpochMs: 1783075320000, reps: 10),
          ]),
          language: LanguagePreference.english,
        );

        final sets = await db.select(db.exerciseSets).get()
          ..sort((a, b) => a.performedAt.compareTo(b.performedAt));
        expect(sets, hasLength(3));
        expect(sets[1].reps, 12, reason: 'the phone-logged set, still there');
        expect(sets[1].weight, 40);
      });

      test('survives the workout being ended on the watch', () async {
        // The last write a session gets: a set logged after the watch's final
        // tap is only ever seen by this one.
        final processor = buildProcessor();
        await processor.processAdoption(sampleAdoptionEvent(), language: LanguagePreference.english);
        final exerciseClientId =
            (await db.select(db.exercises).getSingle()).clientId;

        await logOnPhone(exerciseClientId: exerciseClientId, atEpochMs: 1783075290000);

        await processor.process(
          sampleEvent(sets: const [
            WatchStandaloneSet(loggedAtEpochMs: 1783075260000, reps: 10),
          ]),
          language: LanguagePreference.english,
        );

        final row = await db.select(db.workoutSessions).getSingle();
        expect(row.finishedAt, isNotNull);
        final sets = await db.select(db.exerciseSets).get();
        expect(sets, hasLength(2));
        expect(sets.where((s) => s.reps == 12), hasLength(1));
      });

      test('a resend does not duplicate the watch\'s own sets', () async {
        final processor = buildProcessor();
        await processor.processAdoption(sampleAdoptionEvent(), language: LanguagePreference.english);

        await processor.processAdoption(sampleAdoptionEvent(), language: LanguagePreference.english);

        expect(await db.select(db.exerciseSets).get(), hasLength(1));
      });

      test('an exercise added on the phone is not dropped', () async {
        final benchId = await makeExercise('Bench Press');
        final templateId = await makeTemplate('Push day', [
          TemplateExercise(exerciseClientId: benchId, targetSets: 3),
        ]);
        final curlId = await makeExercise('Curl');
        final processor = buildProcessor();
        await processor.processAdoption(
          sampleAdoptionEvent(
            templateId: templateId,
            sets: const [
              WatchStandaloneSet(loggedAtEpochMs: 1783075260000, reps: 10, exerciseIndex: 0),
            ],
          ),
          language: LanguagePreference.english,
        );

        await logOnPhone(exerciseClientId: curlId, atEpochMs: 1783075290000);

        await processor.processAdoption(
          sampleAdoptionEvent(
            templateId: templateId,
            sets: const [
              WatchStandaloneSet(loggedAtEpochMs: 1783075260000, reps: 10, exerciseIndex: 0),
              WatchStandaloneSet(loggedAtEpochMs: 1783075320000, reps: 10, exerciseIndex: 0),
            ],
          ),
          language: LanguagePreference.english,
        );

        // Without the exercise link the session screen can't render the curl
        // set at all, even though the merge kept the set itself.
        final links = await db.select(db.workoutSessionExercises).get();
        expect(links.map((l) => l.exerciseClientId), containsAll([benchId, curlId]));
        final sets = await db.select(db.exerciseSets).get();
        expect(sets.where((s) => s.exerciseClientId == curlId), hasLength(1));
      });
    });

    test('adoption and the final event resolve template exercises the same way', () async {
      final benchId = await makeExercise('Bench Press');
      final templateId = await makeTemplate('Push day', [
        TemplateExercise(exerciseClientId: benchId),
      ]);
      final processor = buildProcessor();
      await processor.processAdoption(
        sampleAdoptionEvent(
          templateId: templateId,
          sets: const [WatchStandaloneSet(loggedAtEpochMs: 1783075260000, reps: 10, exerciseIndex: 0)],
        ),
        language: LanguagePreference.english,
      );

      await processor.process(
        sampleEvent(
          templateId: templateId,
          sets: const [WatchStandaloneSet(loggedAtEpochMs: 1783075260000, reps: 10, exerciseIndex: 0)],
        ),
        language: LanguagePreference.english,
      );

      final row = await db.select(db.workoutSessions).getSingle();
      expect(row.templateClientId, templateId);
      final sets = await db.select(db.exerciseSets).get();
      expect(sets.single.exerciseClientId, benchId);
    });
  });
}

/// Prevents OutboxWriter's fire-and-forget kick from touching the network —
/// same pattern as workout_session_repository_update_test.
class _NoopSyncEngine extends SyncEngine {
  _NoopSyncEngine(super.db, super.dio);

  @override
  Future<void> sync() async {}
}
