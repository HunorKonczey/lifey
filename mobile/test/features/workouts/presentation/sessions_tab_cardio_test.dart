import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/entitlements/entitlement_providers.dart';
import 'package:lifey/core/sync/sync_status_provider.dart';
import 'package:lifey/features/settings/application/settings_controller.dart';
import 'package:lifey/features/settings/domain/user_settings.dart';
import 'package:lifey/features/workouts/application/exercise_controller.dart';
import 'package:lifey/features/workouts/application/workout_session_controller.dart';
import 'package:lifey/features/workouts/application/workout_template_controller.dart';
import 'package:lifey/features/workouts/domain/exercise.dart';
import 'package:lifey/features/workouts/domain/route_encoder.dart';
import 'package:lifey/features/workouts/domain/track_filter.dart';
import 'package:lifey/features/workouts/domain/workout_session.dart';
import 'package:lifey/features/workouts/domain/workout_template.dart';
import 'package:lifey/features/workouts/presentation/sessions_tab.dart';
import 'package:lifey/features/workouts/presentation/widgets/route_painter.dart';
import 'package:lifey/l10n/app_localizations.dart';
import 'package:lifey/shared/widgets/activity_chip.dart';

/// C1.6: `ActivityChip` on the session list card, with a family-dependent
/// primary metric for cardio sessions. See
/// docs/cardio/59-cardio-implementation-plan.md C1.6 — kész-ha: all seven
/// cardio types render, and the strength card stays visually unchanged.

class _FakeWorkoutSessionController extends WorkoutSessionController {
  _FakeWorkoutSessionController(this._sessions);
  final List<WorkoutSession> _sessions;
  @override
  Stream<List<WorkoutSession>> build() => Stream.value(_sessions);
}

class _FakeExerciseController extends ExerciseController {
  @override
  Stream<List<Exercise>> build() => Stream.value(const []);
}

class _FakeWorkoutTemplateController extends WorkoutTemplateController {
  @override
  Stream<List<WorkoutTemplate>> build() => Stream.value(const []);
}

class _FakeSettingsController extends SettingsController {
  @override
  Stream<UserSettings> build() => Stream.value(const UserSettings.defaults());
}

WorkoutSession _cardioSession({
  required String clientId,
  required String activityType,
  CardioMetrics? cardio,
  int? movingSeconds,
}) {
  final startedAt = DateTime.now();
  return WorkoutSession(
    clientId: clientId,
    exercises: const [],
    sets: const [],
    startedAt: startedAt,
    finishedAt: startedAt.add(const Duration(minutes: 30)),
    sessionKind: 'CARDIO',
    activityType: activityType,
    movingSeconds: movingSeconds,
    cardio: cardio,
  );
}

WorkoutSession _strengthSession(String clientId) {
  final startedAt = DateTime.now();
  return WorkoutSession(
    clientId: clientId,
    exercises: const [SessionExercise(exerciseClientId: 'ex-1', exerciseName: 'Squat')],
    sets: [
      ExerciseSet(
        exerciseClientId: 'ex-1',
        exerciseName: 'Squat',
        reps: 5,
        weight: 100,
        performedAt: startedAt,
      ),
    ],
    startedAt: startedAt,
    finishedAt: startedAt.add(const Duration(minutes: 40)),
  );
}

Future<void> _pumpSessionsTab(WidgetTester tester, List<WorkoutSession> sessions) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        workoutSessionControllerProvider.overrideWith(() => _FakeWorkoutSessionController(sessions)),
        exerciseControllerProvider.overrideWith(_FakeExerciseController.new),
        workoutTemplateControllerProvider.overrideWith(_FakeWorkoutTemplateController.new),
        settingsControllerProvider.overrideWith(_FakeSettingsController.new),
        syncStatusByClientIdProvider.overrideWithValue(const {}),
        // SessionsTab now reads the entitlement's history cutoff (`67` §3.2)
        // — unrelated to this file's cardio-rendering assertions, and
        // `null` (unlimited) keeps every session visible as before that
        // existed, without needing a real/fake database here.
        historyCutoffProvider.overrideWithValue(null),
      ],
      child: const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: SessionsTab()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  // One session per pump (matching the rest of this suite's convention)
  // rather than all seven in one list — a 7-card list overflows the default
  // test viewport, and off-screen ListView.builder items simply aren't in
  // the widget tree yet.
  final cardioTypes = <String, (String label, CardioMetrics? cardio, int? movingSeconds)>{
    'RUNNING': ('Running', const CardioMetrics(distanceMeters: 5000), null),
    'WALKING': ('Walking', const CardioMetrics(distanceMeters: 3000), null),
    'HIKING': ('Hiking', const CardioMetrics(distanceMeters: 14200, elevationGainMeters: 684), null),
    'INDOOR_BIKE': ('Indoor bike', null, 2400),
    'BASKETBALL': ('Basketball', null, 3120),
    'FOOTBALL': ('Football', null, 2880),
    'OTHER_CARDIO': ('Other', null, 1800),
  };

  for (final entry in cardioTypes.entries) {
    final (label, cardio, movingSeconds) = entry.value;
    testWidgets('$label (${entry.key}) renders with an ActivityChip and its type label as title',
        (tester) async {
      await _pumpSessionsTab(tester, [
        _cardioSession(
          clientId: entry.key,
          activityType: entry.key,
          cardio: cardio,
          movingSeconds: movingSeconds,
        ),
      ]);

      expect(tester.takeException(), isNull);
      expect(find.text(label), findsOneWidget);
      expect(find.byType(ActivityChip), findsOneWidget);
    });
  }

  testWidgets('the strength card keeps its existing badge and gets no ActivityChip',
      (tester) async {
    await _pumpSessionsTab(tester, [_strengthSession('s1')]);

    expect(tester.takeException(), isNull);
    expect(find.byType(ActivityChip), findsNothing);
    expect(find.byIcon(Icons.fitness_center), findsOneWidget);
    expect(find.text('1 sets'), findsOneWidget);
  });

  testWidgets('a DISTANCE session shows its distance as the primary metric', (tester) async {
    await _pumpSessionsTab(tester, [
      _cardioSession(
        clientId: 'run',
        activityType: 'RUNNING',
        cardio: const CardioMetrics(distanceMeters: 5000),
      ),
    ]);

    expect(find.text('5.00 km'), findsOneWidget);
  });

  testWidgets('a MACHINE session shows its moving duration, not a distance', (tester) async {
    await _pumpSessionsTab(tester, [
      _cardioSession(
        clientId: 'bike',
        activityType: 'INDOOR_BIKE',
        cardio: const CardioMetrics(distanceMeters: 18400),
        movingSeconds: 2538,
      ),
    ]);

    expect(find.text('42:18'), findsOneWidget);
    expect(find.text('18.40 km'), findsNothing);
  });

  group('route thumbnail (C4a.6)', () {
    String testPolyline() {
      final t0 = DateTime.utc(2026, 8, 10, 7);
      final trail = [
        for (var i = 0; i <= 20; i++)
          TrackFilterTrailPoint(
            latitude: 47.5 + i * 0.0001,
            longitude: 19.05 + i * 0.0001,
            recordedAt: t0.add(Duration(seconds: i)),
          ),
      ];
      return encodeRoute(trail).polyline;
    }

    testWidgets('a DISTANCE session with a recorded route shows the thumbnail', (tester) async {
      await _pumpSessionsTab(tester, [
        _cardioSession(
          clientId: 'run',
          activityType: 'RUNNING',
          cardio: CardioMetrics(distanceMeters: 5000, routePolyline: testPolyline()),
        ),
      ]);

      expect(tester.takeException(), isNull);
      expect(find.byType(RouteThumbnail), findsOneWidget);
    });

    testWidgets('a DISTANCE session without a route shows no thumbnail', (tester) async {
      await _pumpSessionsTab(tester, [
        _cardioSession(
          clientId: 'run',
          activityType: 'RUNNING',
          cardio: const CardioMetrics(distanceMeters: 5000),
        ),
      ]);

      expect(find.byType(RouteThumbnail), findsNothing);
    });

    testWidgets('a MACHINE session never shows a thumbnail, route data or not', (tester) async {
      await _pumpSessionsTab(tester, [
        _cardioSession(
          clientId: 'bike',
          activityType: 'INDOOR_BIKE',
          cardio: CardioMetrics(distanceMeters: 18400, routePolyline: testPolyline()),
          movingSeconds: 2400,
        ),
      ]);

      expect(find.byType(RouteThumbnail), findsNothing);
    });
  });

  testWidgets('a still-running cardio session shows the in-progress pill instead', (tester) async {
    final running = WorkoutSession(
      clientId: 'run-live',
      exercises: const [],
      sets: const [],
      startedAt: DateTime.now(),
      sessionKind: 'CARDIO',
      activityType: 'RUNNING',
    );

    await _pumpSessionsTab(tester, [running]);

    expect(tester.takeException(), isNull);
    expect(find.text('In progress'), findsOneWidget);
  });
}
