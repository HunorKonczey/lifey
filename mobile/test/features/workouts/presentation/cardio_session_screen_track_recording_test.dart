import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/entitlements/entitlement_providers.dart';
import 'package:lifey/core/local_db/app_database.dart';
import 'package:lifey/core/local_db/database_provider.dart';
import 'package:lifey/core/location/location_service.dart';
import 'package:lifey/core/location/location_service_geolocator.dart';
import 'package:lifey/features/settings/application/settings_controller.dart';
import 'package:lifey/features/settings/domain/user_settings.dart';
import 'package:lifey/features/workouts/application/workout_session_controller.dart';
import 'package:lifey/features/workouts/data/cardio_track_point_repository.dart';
import 'package:lifey/features/workouts/domain/workout_session.dart';
import 'package:lifey/features/workouts/presentation/cardio_session_screen.dart';
import 'package:lifey/l10n/app_localizations.dart';

/// C4a.3: `CardioSessionScreen` actually consuming `LocationService.positionStream`
/// and writing to `CardioTrackPoints` — the live-wiring half of the step,
/// distinct from `cardio_track_point_repository_test.dart`'s pure
/// repository coverage. Kész-ha: "Kilőtt app legfeljebb egy pontot veszít" —
/// every fix must reach the DB immediately, and only while the session is
/// actually running and GPS is actually available.

class _RecordingSessionController extends WorkoutSessionController {
  @override
  Stream<List<WorkoutSession>> build() => Stream.value(const []);

  @override
  Future<void> pauseCardioSession(String clientId,
      {required DateTime startedAt, required int movingSeconds}) async {}

  @override
  Future<void> resumeCardioSession(String clientId,
      {required DateTime startedAt, required DateTime resumedAt}) async {}

  @override
  Future<void> finishCardioSession(String clientId,
      {required DateTime startedAt,
      required DateTime finishedAt,
      required int movingSeconds,
      Value<CardioMetrics?> cardio = const Value.absent(),
      Value<List<CardioSplit>> splits = const Value.absent()}) async {}

  @override
  Future<void> updateLiveCardioMetrics(String clientId,
      {required DateTime startedAt, required CardioMetrics cardio}) async {}
}

class _MetricSettings extends SettingsController {
  @override
  Stream<UserSettings> build() => Stream.value(const UserSettings.defaults());
}

WorkoutSession _runningSession({String clientId = 'live-1'}) {
  final since = DateTime.now().subtract(const Duration(minutes: 5));
  return WorkoutSession(
    clientId: clientId,
    exercises: const [],
    sets: const [],
    startedAt: since,
    sessionKind: 'CARDIO',
    activityType: 'RUNNING',
    movingSeconds: 0,
    movingSinceEpochMs: since.millisecondsSinceEpoch,
  );
}

LocationServiceStub _grantedLocationStub() => LocationServiceStub(
      initial: const LocationAvailability(
        authorization: LocationAuthorization.granted,
        precise: true,
        serviceEnabled: true,
      ),
    );

LocationFix _fixAt(int n) => LocationFix(
      latitude: 47.5 + n * 0.001,
      longitude: 19.05 + n * 0.001,
      recordedAt: DateTime.now(),
    );

void main() {
  late AppDatabase db;
  late LocationServiceStub location;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    location = _grantedLocationStub();
  });

  tearDown(() => db.close());

  Future<void> pump(WidgetTester tester, {WorkoutSession? session}) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // See cardio_session_screen_machine_test.dart's own comment on
          // this override — InterstitialManager (67 Prompt 10) needs it
          // here too.
          adsEnabledProvider.overrideWithValue(false),
          workoutSessionControllerProvider.overrideWith(_RecordingSessionController.new),
          settingsControllerProvider.overrideWith(_MetricSettings.new),
          locationServiceProvider.overrideWithValue(location),
          appDatabaseProvider.overrideWithValue(db),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: CardioSessionScreen(session: session ?? _runningSession()),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('a fix emitted while running and GPS-available is written immediately', (tester) async {
    await pump(tester);

    location.emitFix(_fixAt(0));
    await tester.pump();

    final points = await CardioTrackPointRepository(db).pointsForSession('live-1');
    expect(points, hasLength(1));
    expect(points.single.seq, 0);
    expect(points.single.latitude, 47.5);
  });

  testWidgets('multiple fixes get sequential, increasing seq numbers', (tester) async {
    await pump(tester);

    location.emitFix(_fixAt(0));
    await tester.pump();
    location.emitFix(_fixAt(1));
    await tester.pump();
    location.emitFix(_fixAt(2));
    await tester.pump();

    final points = await CardioTrackPointRepository(db).pointsForSession('live-1');
    expect(points.map((p) => p.seq), [0, 1, 2]);
  });

  testWidgets('no write happens while location is not yet granted', (tester) async {
    location = LocationServiceStub(); // defaults to notDetermined
    await pump(tester);

    location.emitFix(_fixAt(0));
    await tester.pump();

    expect(await CardioTrackPointRepository(db).pointsForSession('live-1'), isEmpty);
  });

  testWidgets('pausing stops recording; resuming restarts it', (tester) async {
    await pump(tester);

    location.emitFix(_fixAt(0));
    await tester.pump();

    await tester.tap(find.text('Pause'));
    await tester.pumpAndSettle();

    // Emitted while paused — must not be recorded.
    location.emitFix(_fixAt(1));
    await tester.pump();

    var points = await CardioTrackPointRepository(db).pointsForSession('live-1');
    expect(points, hasLength(1)); // only the pre-pause fix

    await tester.tap(find.text('Resume'));
    await tester.pumpAndSettle();

    location.emitFix(_fixAt(2));
    await tester.pump();

    points = await CardioTrackPointRepository(db).pointsForSession('live-1');
    expect(points, hasLength(2));
    // seq counts actual writes, not observed fixes: the pause fully cancels
    // the subscription (the skipped fix is never delivered at all), so it
    // doesn't consume a seq number — the next write continues from 1, not 2.
    expect(points.map((p) => p.seq), [0, 1]);
  });

  testWidgets('seq resumes from the existing count after reopening a session with prior points',
      (tester) async {
    final repo = CardioTrackPointRepository(db);
    await repo.addPoint('live-1', 0, _fixAt(0));
    await repo.addPoint('live-1', 1, _fixAt(1));

    await pump(tester);
    // Let the async seed (pointCount query) resolve before emitting.
    await tester.pump();

    location.emitFix(_fixAt(2));
    await tester.pump();

    final points = await repo.pointsForSession('live-1');
    expect(points, hasLength(3));
    expect(points.last.seq, 2);
  });

  testWidgets('a MACHINE session never subscribes to positionStream at all', (tester) async {
    final since = DateTime.now().subtract(const Duration(minutes: 5));
    await pump(
      tester,
      session: WorkoutSession(
        clientId: 'bike-1',
        exercises: const [],
        sets: const [],
        startedAt: since,
        sessionKind: 'CARDIO',
        activityType: 'INDOOR_BIKE',
        movingSeconds: 0,
        movingSinceEpochMs: since.millisecondsSinceEpoch,
      ),
    );

    location.emitFix(_fixAt(0));
    await tester.pump();

    expect(await CardioTrackPointRepository(db).pointsForSession('bike-1'), isEmpty);
  });
}
