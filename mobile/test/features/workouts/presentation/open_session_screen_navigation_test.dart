import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/sync/sync_status_provider.dart';
import 'package:lifey/features/settings/application/settings_controller.dart';
import 'package:lifey/features/settings/domain/user_settings.dart';
import 'package:lifey/features/workouts/application/exercise_controller.dart';
import 'package:lifey/features/workouts/application/workout_session_controller.dart';
import 'package:lifey/features/workouts/domain/exercise.dart';
import 'package:lifey/features/workouts/domain/workout_session.dart';
import 'package:lifey/features/workouts/presentation/cardio_session_screen.dart';
import 'package:lifey/features/workouts/presentation/cardio_summary_screen.dart';
import 'package:lifey/features/workouts/presentation/log_session_screen.dart';
import 'package:lifey/features/workouts/presentation/open_workout_screens.dart';
import 'package:lifey/l10n/app_localizations.dart';

/// C1.9: the single kind-branch point (`open_workout_screens.dart`) now
/// actually branches — the TODO left since C0.4 is resolved here. See
/// docs/cardio/59-cardio-implementation-plan.md C1.9 — kész-ha "a mentett
/// edzés megnyitható és olvasható".
///
/// C2.1 refines the CARDIO branch further: `inProgress` now also decides
/// between the live [CardioSessionScreen] and the read-only
/// [CardioSummaryScreen] (previously the only cardio destination, since no
/// cardio session could be in-progress yet).

class _FakeSessions extends WorkoutSessionController {
  @override
  Stream<List<WorkoutSession>> build() => Stream.value(const []);
}

class _FakeExercises extends ExerciseController {
  @override
  Stream<List<Exercise>> build() => Stream.value(const []);
}

class _FakeSettings extends SettingsController {
  @override
  Stream<UserSettings> build() => Stream.value(const UserSettings.defaults());
}

Future<void> _pumpAndOpen(WidgetTester tester, WorkoutSession session) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        workoutSessionControllerProvider.overrideWith(_FakeSessions.new),
        exerciseControllerProvider.overrideWith(_FakeExercises.new),
        settingsControllerProvider.overrideWith(_FakeSettings.new),
        syncStatusByClientIdProvider.overrideWithValue(const {}),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => openSessionScreen(Navigator.of(context), session),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(resetOpenWorkoutScreens);
  tearDown(resetOpenWorkoutScreens);

  testWidgets('a finished CARDIO session opens the read-only CardioSummaryScreen',
      (tester) async {
    final session = WorkoutSession(
      clientId: 'c1',
      exercises: const [],
      sets: const [],
      startedAt: DateTime.now(),
      finishedAt: DateTime.now().add(const Duration(minutes: 30)),
      sessionKind: 'CARDIO',
      activityType: 'RUNNING',
      movingSeconds: 1800,
    );

    await _pumpAndOpen(tester, session);

    expect(find.byType(CardioSummaryScreen), findsOneWidget);
    expect(find.byType(CardioSessionScreen), findsNothing);
    expect(find.byType(LogSessionScreen), findsNothing);
  });

  testWidgets('an in-progress CARDIO session opens the live CardioSessionScreen',
      (tester) async {
    final session = WorkoutSession(
      clientId: 'c3',
      exercises: const [],
      sets: const [],
      startedAt: DateTime.now().subtract(const Duration(minutes: 10)),
      sessionKind: 'CARDIO',
      activityType: 'RUNNING',
      movingSeconds: 0,
      movingSinceEpochMs: DateTime.now()
          .subtract(const Duration(minutes: 10))
          .millisecondsSinceEpoch,
    );

    await _pumpAndOpen(tester, session);

    expect(find.byType(CardioSessionScreen), findsOneWidget);
    expect(find.byType(CardioSummaryScreen), findsNothing);
    expect(find.byType(LogSessionScreen), findsNothing);
  });

  testWidgets('a STRENGTH session still opens LogSessionScreen, unchanged', (tester) async {
    final session = WorkoutSession(
      clientId: 'c2',
      exercises: const [],
      sets: const [],
      startedAt: DateTime.now(),
      finishedAt: DateTime.now().add(const Duration(minutes: 40)),
    );

    await _pumpAndOpen(tester, session);

    expect(find.byType(LogSessionScreen), findsOneWidget);
    expect(find.byType(CardioSummaryScreen), findsNothing);
  });
}
