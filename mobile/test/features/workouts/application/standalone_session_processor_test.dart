import 'package:dio/dio.dart';
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
  late WatchWorkoutService watchService;
  final ackCalls = <MethodCall>[];
  const channel = MethodChannel('lifey/watch');

  WatchStandaloneSession sampleEvent({
    String standaloneSessionId = 'standalone-1',
    List<WatchStandaloneSet> sets = const [
      WatchStandaloneSet(loggedAtEpochMs: 1783075260000, reps: 10),
      WatchStandaloneSet(loggedAtEpochMs: 1783075320000, reps: 10),
    ],
    int? rpe,
    double? activeCalories,
    double? averageHeartRate,
    String? healthWorkoutId,
  }) =>
      WatchStandaloneSession(
        standaloneSessionId: standaloneSessionId,
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
      watchService: watchService,
      writeHealthWorkout: writeHealthWorkout ?? defaultWriteHealthWorkout,
    );
  }

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    sessionRepository = WorkoutSessionRepository(db, OutboxWriter(db, _NoopSyncEngine(db, Dio())));
    exerciseRepository = ExerciseRepository(db, OutboxWriter(db, _NoopSyncEngine(db, Dio())));
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
}

/// Prevents OutboxWriter's fire-and-forget kick from touching the network —
/// same pattern as workout_session_repository_update_test.
class _NoopSyncEngine extends SyncEngine {
  _NoopSyncEngine(super.db, super.dio);

  @override
  Future<void> sync() async {}
}
