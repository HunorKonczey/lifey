import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/local_db/app_database.dart';
import 'package:lifey/core/local_db/database_provider.dart';
import 'package:lifey/core/location/location_service.dart';
import 'package:lifey/features/settings/application/settings_controller.dart';
import 'package:lifey/features/settings/domain/user_settings.dart';
import 'package:lifey/features/workouts/application/workout_session_controller.dart';
import 'package:lifey/features/workouts/data/cardio_track_point_repository.dart';
import 'package:lifey/features/workouts/domain/route_encoder.dart';
import 'package:lifey/features/workouts/domain/track_filter.dart';
import 'package:lifey/features/workouts/domain/workout_session.dart';
import 'package:lifey/features/workouts/presentation/cardio_summary_screen.dart';
import 'package:lifey/features/workouts/presentation/widgets/elevation_profile_chart.dart';
import 'package:lifey/l10n/app_localizations.dart';

/// docs/cardio/60 C8.3 — the real elevation profile, built from this
/// device's local track points, versus the old polyline-based approximation
/// it falls back to when there's nothing local left to build one from
/// (docs/cardio/60 C8.3's kész-ha: "a nyers pontok törlése után
/// 'EGYSZERŰSÍTETT' profil marad, nem üres hely").

class _MetricSettings extends SettingsController {
  @override
  Stream<UserSettings> build() => Stream.value(const UserSettings.defaults());
}

class _StubSessionController extends WorkoutSessionController {
  @override
  Stream<List<WorkoutSession>> build() => Stream.value(const []);

  @override
  Future<void> updateLiveCardioMetrics(String clientId,
      {required DateTime startedAt, required CardioMetrics cardio}) async {}

  @override
  Future<void> rateSession(String clientId, {required int rpe, String? feedbackNote}) async {}
}

/// A short encoded polyline — the fallback path needs *some* stored route,
/// even though these tests care about the local track, not this string.
String _stubPolyline() {
  final trail = [
    for (var i = 0; i <= 5; i++)
      TrackFilterTrailPoint(
        latitude: 47.5 + i * 5 / 111320.0,
        longitude: 19.05,
        altitude: 100.0 + i,
        recordedAt: DateTime.utc(2026, 8, 19, 7, 0, i),
      ),
  ];
  return encodeRoute(trail).polyline;
}

WorkoutSession _hikeSession() {
  return WorkoutSession(
    clientId: 'hike-1',
    exercises: const [],
    sets: const [],
    startedAt: DateTime.utc(2026, 8, 19, 7, 0, 0),
    finishedAt: DateTime.utc(2026, 8, 19, 7, 20, 0),
    sessionKind: 'CARDIO',
    activityType: 'HIKING',
    movingSeconds: 1200,
    cardio: CardioMetrics(
      distanceMeters: 1000,
      elevationGainMeters: 20,
      routePolyline: _stubPolyline(),
      routePointCount: 6,
    ),
  );
}

/// Straight-line-north local track points, climbing steadily, seeded
/// directly into an in-memory `AppDatabase` — the same shape
/// `cardio_track_point_repository_test.dart` uses.
Future<AppDatabase> _databaseWithTrack(String sessionClientId, {bool withAltitude = true}) async {
  final db = AppDatabase(NativeDatabase.memory());
  final repo = CardioTrackPointRepository(db);
  final t0 = DateTime.utc(2026, 8, 19, 7, 0, 0);
  for (var i = 0; i <= 200; i++) {
    await repo.addPoint(
      sessionClientId,
      i,
      LocationFix(
        latitude: 47.5 + i * 5 / 111320.0,
        longitude: 19.05,
        recordedAt: t0.add(Duration(seconds: i)),
        altitude: withAltitude ? i * 0.25 : null,
        accuracy: 5,
      ),
    );
  }
  return db;
}

Future<AppDatabase> _emptyDatabase() async => AppDatabase(NativeDatabase.memory());

Future<void> _pump(WidgetTester tester, WorkoutSession session, AppDatabase db) async {
  // Same reasoning as cardio_summary_screen_test.dart's route/elevation
  // tests: the screen's body scrolls, and the default 800x600 test surface
  // leaves the elevation card's Elements unbuilt (virtualized away) without
  // a taller surface to lay it all out on.
  await tester.binding.setSurfaceSize(const Size(400, 1600));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        settingsControllerProvider.overrideWith(_MetricSettings.new),
        workoutSessionControllerProvider.overrideWith(_StubSessionController.new),
        appDatabaseProvider.overrideWithValue(db),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: CardioSummaryScreen(session: session),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('with local track points available', () {
    testWidgets('renders the real chart, not the old approximation', (tester) async {
      final session = _hikeSession();
      final db = await _databaseWithTrack(session.clientId);
      addTearDown(db.close);

      await _pump(tester, session, db);

      expect(tester.takeException(), isNull);
      expect(find.byType(ElevationProfileChart), findsOneWidget);
      expect(find.text('SIMPLIFIED'), findsNothing);
    });

    testWidgets('shows the peak caption below the chart', (tester) async {
      final session = _hikeSession();
      final db = await _databaseWithTrack(session.clientId);
      addTearDown(db.close);

      await _pump(tester, session, db);

      // 200 steps * 5 m * 0.05 m/m = 50 m climb, reached at the very last point.
      expect(find.textContaining('peak'), findsOneWidget);
      expect(find.textContaining('50 m'), findsWidgets);
    });

    testWidgets('tapping the chart selects a point and shows the three-number readout',
        (tester) async {
      final session = _hikeSession();
      final db = await _databaseWithTrack(session.clientId);
      addTearDown(db.close);

      await _pump(tester, session, db);

      expect(find.text('altitude'), findsNothing);
      expect(find.text('so far'), findsNothing);
      expect(find.text('elapsed'), findsNothing);

      await tester.tapAt(tester.getCenter(find.byType(ElevationProfileChart)));
      await tester.pumpAndSettle();

      expect(find.text('altitude'), findsOneWidget);
      expect(find.text('so far'), findsOneWidget);
      expect(find.text('elapsed'), findsOneWidget);
      expect(find.textContaining('selected point'), findsOneWidget);
    });

    testWidgets('tapping the same point again deselects it', (tester) async {
      final session = _hikeSession();
      final db = await _databaseWithTrack(session.clientId);
      addTearDown(db.close);

      await _pump(tester, session, db);

      // Re-located after each tap, not cached: selecting a point swaps the
      // card's header from a plain label to the taller `_SelectedPointChip`
      // pill, which nudges the chart down a few pixels — a stale coordinate
      // would miss the chart's `GestureDetector` on the second tap.
      await tester.tapAt(tester.getCenter(find.byType(ElevationProfileChart)));
      await tester.pumpAndSettle();
      expect(find.text('altitude'), findsOneWidget);

      await tester.tapAt(tester.getCenter(find.byType(ElevationProfileChart)));
      await tester.pumpAndSettle();
      expect(find.text('altitude'), findsNothing);
    });

    testWidgets('a track with no altitude anywhere falls back to the simplified view',
        (tester) async {
      final session = _hikeSession();
      final db = await _databaseWithTrack(session.clientId, withAltitude: false);
      addTearDown(db.close);

      await _pump(tester, session, db);

      expect(find.byType(ElevationProfileChart), findsNothing);
      expect(find.text('SIMPLIFIED'), findsOneWidget);
    });
  });

  group('without local track points', () {
    testWidgets('falls back to the old polyline chart, flagged SIMPLIFIED', (tester) async {
      final session = _hikeSession();
      final db = await _emptyDatabase();
      addTearDown(db.close);

      await _pump(tester, session, db);

      expect(tester.takeException(), isNull);
      expect(find.byType(ElevationProfileChart), findsNothing);
      expect(find.text('ELEVATION PROFILE'), findsOneWidget);
      expect(find.text('SIMPLIFIED'), findsOneWidget);
      // The old view still shows the gain summary next to the badge.
      expect(find.textContaining('+20'), findsOneWidget);
    });

    testWidgets('a non-DISTANCE session never touches the track-point database at all',
        (tester) async {
      // MACHINE/GAME never track location — this must not even attempt the
      // load, let alone show a SIMPLIFIED badge for a family that never had
      // a route to begin with.
      final session = WorkoutSession(
        clientId: 'ride-1',
        exercises: const [],
        sets: const [],
        startedAt: DateTime.utc(2026, 8, 19, 7),
        finishedAt: DateTime.utc(2026, 8, 19, 7, 30),
        sessionKind: 'CARDIO',
        activityType: 'INDOOR_BIKE',
        movingSeconds: 1800,
        cardio: const CardioMetrics(avgWatts: 150),
      );
      final db = await _emptyDatabase();
      addTearDown(db.close);

      await _pump(tester, session, db);

      expect(tester.takeException(), isNull);
      expect(find.text('SIMPLIFIED'), findsNothing);
      expect(find.byType(ElevationProfileChart), findsNothing);
    });
  });
}
