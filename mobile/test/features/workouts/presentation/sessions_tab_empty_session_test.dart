import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/features/settings/application/settings_controller.dart';
import 'package:lifey/features/settings/domain/user_settings.dart';
import 'package:lifey/features/workouts/application/exercise_controller.dart';
import 'package:lifey/features/workouts/application/workout_session_controller.dart';
import 'package:lifey/features/workouts/application/workout_template_controller.dart';
import 'package:lifey/features/workouts/domain/exercise.dart';
import 'package:lifey/features/workouts/domain/workout_session.dart';
import 'package:lifey/features/workouts/domain/workout_template.dart';
import 'package:lifey/features/workouts/presentation/sessions_tab.dart';
import 'package:lifey/core/sync/sync_status_provider.dart';
import 'package:lifey/l10n/app_localizations.dart';

/// C0.3 regression: a hand-inserted session with no exercises and no sets —
/// today possible for a plain STRENGTH session started and never filled in,
/// and the exact shape a future CARDIO session (docs/cardio/52) will also
/// have — must render on every screen without throwing or showing a broken
/// ("NaN" / literally empty) patch. See docs/cardio/53-cardio-mobile-plan.md
/// §0 and docs/cardio/59-cardio-implementation-plan.md C0.3.

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

WorkoutSession _emptySession({required String clientId, String? templateName}) {
  final now = DateTime.now();
  return WorkoutSession(
    clientId: clientId,
    exercises: const [],
    sets: const [],
    startedAt: now,
    finishedAt: now.add(const Duration(minutes: 20)),
    templateName: templateName,
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
  testWidgets('a freeform empty session (no template) renders without throwing', (tester) async {
    await _pumpSessionsTab(tester, [_emptySession(clientId: 'c1')]);

    expect(tester.takeException(), isNull);
    // "0 sets" (l10n.setsCountLabel(0)) shows instead of a blank/NaN patch.
    expect(find.textContaining('0'), findsWidgets);
  });

  testWidgets('an empty session started from a template renders without throwing', (tester) async {
    await _pumpSessionsTab(
      tester,
      [_emptySession(clientId: 'c2', templateName: 'Push day')],
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Push day'), findsOneWidget);
  });

  testWidgets('a still-running empty session renders without throwing', (tester) async {
    final now = DateTime.now();
    final running = WorkoutSession(
      clientId: 'c3',
      exercises: const [],
      sets: const [],
      startedAt: now,
    );

    await _pumpSessionsTab(tester, [running]);

    expect(tester.takeException(), isNull);
  });

  testWidgets('a mixed list of empty and normal sessions renders without throwing', (tester) async {
    final now = DateTime.now();
    final normal = WorkoutSession(
      clientId: 'c4',
      exercises: const [SessionExercise(exerciseClientId: 'ex-1', exerciseName: 'Squat')],
      sets: [
        ExerciseSet(
          exerciseClientId: 'ex-1',
          exerciseName: 'Squat',
          reps: 5,
          weight: 100,
          performedAt: now,
        ),
      ],
      startedAt: now,
      finishedAt: now.add(const Duration(minutes: 30)),
    );

    await _pumpSessionsTab(tester, [_emptySession(clientId: 'c1'), normal]);

    expect(tester.takeException(), isNull);
  });
}
