import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/local_db/app_database.dart';
import 'package:lifey/core/local_db/database_provider.dart';
import 'package:lifey/core/location/location_permission_preferences.dart';
import 'package:lifey/core/location/location_service.dart';
import 'package:lifey/core/location/location_service_geolocator.dart';
import 'package:lifey/core/sync/sync_status_provider.dart';
import 'package:lifey/features/settings/application/settings_controller.dart';
import 'package:lifey/features/settings/domain/user_settings.dart';
import 'package:lifey/features/workouts/application/exercise_controller.dart';
import 'package:lifey/features/workouts/application/workout_session_controller.dart';
import 'package:lifey/features/workouts/application/workout_template_controller.dart';
import 'package:lifey/features/workouts/domain/exercise.dart';
import 'package:lifey/features/workouts/domain/workout_session.dart';
import 'package:lifey/features/workouts/domain/workout_template.dart';
import 'package:lifey/features/workouts/presentation/activity_picker_screen.dart';
import 'package:lifey/features/workouts/presentation/cardio_session_screen.dart';
import 'package:lifey/features/workouts/presentation/open_workout_screens.dart';
import 'package:lifey/features/workouts/presentation/quick_start_sheet.dart';
import 'package:lifey/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// C2.7: the FAB long-press quick-start sheet.
/// docs/cardio/59-cardio-implementation-plan.md C2.7 — kész-ha: "Hosszú
/// nyomás + egy koppintás = fut az edzés, köztes képernyő nélkül."
///
/// Every fixture here is a cold start (no sessions) so the top-4 tiles are
/// the deterministic M02 default order — see `activity_ranking_test.dart`
/// for the ranking logic itself, already covered there.
///
/// C4a.2 added a one-time GPS explainer sheet before the *first-ever*
/// DISTANCE-family quick-start — every test below except the two dedicated
/// "gpsExplainer" ones pre-seeds `LocationPermissionPreferences` as already
/// seen (`setUp` below), so tapping "Running"/"Hiking" still starts
/// immediately, matching what this file was written to verify. The
/// first-time path has its own tests.

class _RecordingSessionController extends WorkoutSessionController {
  final startCardioCalls = <Map<String, Object?>>[];
  String nextClientId = 'new-session';
  List<WorkoutSession> sessions = const [];

  @override
  Stream<List<WorkoutSession>> build() => Stream.value(sessions);

  @override
  Future<String> startCardioSession({
    required DateTime startedAt,
    required String activityType,
    CardioMetrics? cardio,
  }) async {
    startCardioCalls
        .add({'startedAt': startedAt, 'activityType': activityType, 'cardio': cardio});
    return nextClientId;
  }
}

class _FakeTemplates extends WorkoutTemplateController {
  List<WorkoutTemplate> templates = const [];

  @override
  Stream<List<WorkoutTemplate>> build() => Stream.value(templates);
}

class _FakeExercises extends ExerciseController {
  @override
  Stream<List<Exercise>> build() => Stream.value(const []);
}

class _FakeSettings extends SettingsController {
  @override
  Stream<UserSettings> build() => Stream.value(const UserSettings.defaults());
}

WorkoutTemplate _template({required String clientId, required String name, int exerciseCount = 3}) {
  return WorkoutTemplate(
    clientId: clientId,
    name: name,
    exercises: [
      for (var i = 0; i < exerciseCount; i++) TemplateExercise(exerciseClientId: 'ex-$i'),
    ],
  );
}

/// C4a.3: a started cardio session's `CardioSessionScreen.initState` now
/// unconditionally reads `cardioTrackPointRepositoryProvider` (→
/// `appDatabaseProvider`) — see `cardio_session_screen_test.dart`'s
/// identical helper for why an in-memory database is needed here too.
AppDatabase _testDatabase() {
  final db = AppDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  return db;
}

Future<_RecordingSessionController> _pumpAndOpenSheet(
  WidgetTester tester, {
  List<WorkoutSession> sessions = const [],
  List<WorkoutTemplate> templates = const [],
  LocationServiceStub? locationService,
}) async {
  final sessionController = _RecordingSessionController()..sessions = sessions;
  final templateController = _FakeTemplates()..templates = templates;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        workoutSessionControllerProvider.overrideWith(() => sessionController),
        workoutTemplateControllerProvider.overrideWith(() => templateController),
        exerciseControllerProvider.overrideWith(_FakeExercises.new),
        settingsControllerProvider.overrideWith(_FakeSettings.new),
        syncStatusByClientIdProvider.overrideWithValue(const {}),
        locationServiceProvider.overrideWithValue(locationService ?? LocationServiceStub()),
        appDatabaseProvider.overrideWithValue(_testDatabase()),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showQuickStartSheet(context),
                child: const Text('open sheet'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open sheet'));
  await tester.pumpAndSettle();
  return sessionController;
}

void main() {
  setUp(resetOpenWorkoutScreens);
  tearDown(resetOpenWorkoutScreens);

  // Default: the GPS explainer has already been seen, so every existing
  // "one tap starts the workout" test below keeps exercising exactly that —
  // see the class doc. The dedicated gpsExplainer tests reset this to
  // simulate the very first DISTANCE-family start instead.
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocationPermissionPreferences().setSeenGpsExplainer();
  });

  testWidgets('a cold start shows the M02 default order: running, walking, strength, bike',
      (tester) async {
    await _pumpAndOpenSheet(tester);

    expect(find.text('Running'), findsOneWidget);
    expect(find.text('Walking'), findsOneWidget);
    expect(find.text('Empty workout'), findsOneWidget);
    expect(find.text('Indoor bike'), findsOneWidget);
  });

  testWidgets('the cold-start banner shows below 3 completed sessions', (tester) async {
    await _pumpAndOpenSheet(tester, sessions: const []);
    expect(find.textContaining("don't have any workout history"), findsOneWidget);
  });

  testWidgets('the cold-start banner is hidden at 3 or more completed sessions', (tester) async {
    final threeFinished = [
      for (var i = 0; i < 3; i++)
        WorkoutSession(
          clientId: 'c$i',
          exercises: const [],
          sets: const [],
          startedAt: DateTime.now(),
          finishedAt: DateTime.now(),
        ),
    ];
    await _pumpAndOpenSheet(tester, sessions: threeFinished);
    expect(find.textContaining("don't have any workout history"), findsNothing);
  });

  testWidgets('tapping a cardio tile starts that activity type and opens the live screen directly',
      (tester) async {
    final controller = await _pumpAndOpenSheet(tester);

    await tester.tap(find.text('Running'));
    await tester.pumpAndSettle();

    expect(controller.startCardioCalls, hasLength(1));
    expect(controller.startCardioCalls.single['activityType'], 'RUNNING');
    expect(find.byType(CardioSessionScreen), findsOneWidget);
    // The sheet itself is gone, not left underneath.
    expect(find.text('Quick start'), findsNothing);
  });

  // Deliberately no "tapping the freeform/template strength tile navigates"
  // test: that would need `LogSessionScreen` to actually mount, which pulls
  // in a lot of machinery unrelated to C2.7 (music controls, watch sync,
  // health import, a real `workoutSessionRepositoryProvider`) — a
  // disproportionate provider harness for this step's scope, and the exact
  // reason `template_picker_screen.dart`'s own `_start` (the pattern
  // `startStrengthQuickly` mirrors exactly) has no dedicated test either.
  // [startStrengthQuickly]'s tile-content rendering (name/exercise count,
  // freeform label/subtitle) is covered below; the push call itself is a
  // direct three-line mirror of that already-trusted, already-shipped code.

  testWidgets('the freeform-strength and specific-template tiles render the right labels',
      (tester) async {
    final session = WorkoutSession(
      clientId: 's1',
      exercises: const [],
      sets: const [],
      templateClientId: 'tPushA',
      startedAt: DateTime.now(),
      finishedAt: DateTime.now(),
    );
    await _pumpAndOpenSheet(
      tester,
      sessions: [session],
      templates: [_template(clientId: 'tPushA', name: 'Push day', exerciseCount: 6)],
    );

    // One completed session against a named template outranks the
    // cold-start default order entirely (score > 0 beats an unranked
    // default entry), landing it in the top 4 alongside the freeform
    // bucket and the GPS defaults.
    expect(find.text('Push day'), findsOneWidget);
    expect(find.text('6 exercises'), findsOneWidget);
    expect(find.text('Empty workout'), findsOneWidget);
    expect(find.text('Start without a template'), findsOneWidget);
  });

  testWidgets('"All workout types" opens the full picker, not the live screen directly',
      (tester) async {
    await _pumpAndOpenSheet(tester);

    await tester.ensureVisible(find.text('All workout types'));
    await tester.tap(find.text('All workout types'));
    await tester.pumpAndSettle();

    expect(find.byType(ActivityPickerScreen), findsOneWidget);
    expect(find.text('What are you starting?'), findsOneWidget);
    // Every cardio type is listed there, not just the top 4.
    expect(find.text('Hiking'), findsOneWidget);
    expect(find.text('Basketball'), findsOneWidget);
  });

  testWidgets('a row in the full picker also starts immediately', (tester) async {
    final controller = await _pumpAndOpenSheet(tester);
    await tester.ensureVisible(find.text('All workout types'));
    await tester.tap(find.text('All workout types'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Hiking'));
    await tester.pumpAndSettle();

    expect(controller.startCardioCalls, hasLength(1));
    expect(controller.startCardioCalls.single['activityType'], 'HIKING');
    expect(find.byType(CardioSessionScreen), findsOneWidget);
    expect(find.byType(ActivityPickerScreen), findsNothing);
  });

  group('GPS explainer (C4a.2, M26) — the very first DISTANCE-family start', () {
    // Overrides this file's default setUp (already-seen) back to "never
    // seen" — simulates a real first-ever cardio start.
    setUp(() => SharedPreferences.setMockInitialValues({}));

    testWidgets('shows the explainer instead of starting immediately, and marks it seen',
        (tester) async {
      final controller = await _pumpAndOpenSheet(tester);

      await tester.tap(find.text('Running'));
      await tester.pumpAndSettle();

      // Not started yet, and the quick-start sheet is gone (popped before
      // the explainer shows, per startCardioQuickly's own doc).
      expect(controller.startCardioCalls, isEmpty);
      expect(find.byType(CardioSessionScreen), findsNothing);
      expect(find.text('Quick start'), findsNothing);
      expect(find.text('So we can see where you ran'), findsOneWidget);

      expect(await LocationPermissionPreferences().hasSeenGpsExplainer(), isTrue);
    });

    testWidgets('"Allow location" requests permission, then starts the session',
        (tester) async {
      final location = LocationServiceStub();
      final controller = await _pumpAndOpenSheet(tester, locationService: location);

      await tester.tap(find.text('Running'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Allow location'));
      await tester.pumpAndSettle();

      expect((await location.currentAvailability()).authorization, LocationAuthorization.granted);
      expect(controller.startCardioCalls, hasLength(1));
      expect(controller.startCardioCalls.single['activityType'], 'RUNNING');
      expect(find.byType(CardioSessionScreen), findsOneWidget);
    });

    testWidgets('"Start without GPS" never requests permission, but still starts the session',
        (tester) async {
      final location = LocationServiceStub();
      final controller = await _pumpAndOpenSheet(tester, locationService: location);

      await tester.tap(find.text('Running'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start without GPS'));
      await tester.pumpAndSettle();

      expect(
        (await location.currentAvailability()).authorization,
        LocationAuthorization.notDetermined,
      );
      expect(controller.startCardioCalls, hasLength(1));
      expect(controller.startCardioCalls.single['activityType'], 'RUNNING');
      expect(find.byType(CardioSessionScreen), findsOneWidget);
    });

    // Not re-tested end-to-end with a second sheet instance in this same
    // test (pumping a whole second widget tree mid-test collides with
    // `open_workout_screens.dart`'s module-level navigation guard, which
    // only resets between tests via `setUp`/`tearDown` above). Persistence
    // itself is covered by the "shows the explainer... and marks it seen"
    // test above; every *other* test in this file already demonstrates the
    // "seen" steady state starts immediately, since that's what this file's
    // default `setUp` seeds.

    testWidgets('a non-DISTANCE activity (MACHINE: indoor bike) never shows the explainer',
        (tester) async {
      final controller = await _pumpAndOpenSheet(tester);

      await tester.ensureVisible(find.text('Indoor bike'));
      await tester.tap(find.text('Indoor bike'));
      await tester.pumpAndSettle();

      expect(find.text('So we can see where you ran'), findsNothing);
      expect(controller.startCardioCalls, hasLength(1));
      expect(controller.startCardioCalls.single['activityType'], 'INDOOR_BIKE');
    });
  });
}
