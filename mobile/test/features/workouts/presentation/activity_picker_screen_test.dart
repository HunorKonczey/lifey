import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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
import 'package:lifey/l10n/app_localizations.dart';

/// C2.7 (M03): the full activity/template picker reached from the
/// quick-start sheet's "All workout types" row.
/// docs/cardio/59-cardio-implementation-plan.md C2.7.

class _RecordingSessionController extends WorkoutSessionController {
  final startCardioCalls = <String>[];

  @override
  Stream<List<WorkoutSession>> build() => Stream.value(const []);

  @override
  Future<String> startCardioSession({required DateTime startedAt, required String activityType}) async {
    startCardioCalls.add(activityType);
    return 'new-session';
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

Future<_RecordingSessionController> _pump(WidgetTester tester, {List<WorkoutTemplate> templates = const []}) async {
  final controller = _RecordingSessionController();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        workoutSessionControllerProvider.overrideWith(() => controller),
        workoutTemplateControllerProvider.overrideWith(() => _FakeTemplates()..templates = templates),
        exerciseControllerProvider.overrideWith(_FakeExercises.new),
        settingsControllerProvider.overrideWith(_FakeSettings.new),
        syncStatusByClientIdProvider.overrideWithValue(const {}),
      ],
      child: const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ActivityPickerScreen(),
      ),
    ),
  );
  await tester.pump();
  return controller;
}

void main() {
  setUp(resetOpenWorkoutScreens);
  tearDown(resetOpenWorkoutScreens);

  testWidgets('lists all seven cardio types with their modality subtitle', (tester) async {
    await _pump(tester);

    expect(find.text('Running'), findsOneWidget);
    expect(find.text('Walking'), findsOneWidget);
    expect(find.text('Hiking'), findsOneWidget);
    expect(find.text('Indoor bike'), findsOneWidget);
    expect(find.text('Basketball'), findsOneWidget);
    expect(find.text('Football'), findsOneWidget);
    expect(find.text('Other'), findsOneWidget);
    // DISTANCE family (running/walking/hiking) shares one subtitle.
    expect(find.text('Distance · pace · GPS'), findsNWidgets(3));
    expect(find.text('Cadence · power'), findsOneWidget); // MACHINE
    expect(find.text('Playing time · heart-rate zones'), findsNWidgets(3)); // GAME ×3
  });

  testWidgets('the strength-templates section is hidden when there are no templates',
      (tester) async {
    await _pump(tester);

    expect(find.text('STRENGTH TEMPLATES'), findsNothing);
  });

  testWidgets('lists every saved template with its exercise count, no freeform row',
      (tester) async {
    await _pump(tester, templates: [
      const WorkoutTemplate(
        clientId: 't1',
        name: 'Push day',
        exercises: [TemplateExercise(exerciseClientId: 'e1'), TemplateExercise(exerciseClientId: 'e2')],
      ),
      const WorkoutTemplate(clientId: 't2', name: 'Pull day', exercises: []),
    ]);

    expect(find.text('STRENGTH TEMPLATES'), findsOneWidget);
    expect(find.text('Push day'), findsOneWidget);
    expect(find.text('2 exercises'), findsOneWidget);
    expect(find.text('Pull day'), findsOneWidget);
    expect(find.text('0 exercises'), findsOneWidget);
    // M03 deliberately omits an "Empty workout" row — see the class doc.
    expect(find.text('Empty workout'), findsNothing);
  });

  testWidgets('tapping a cardio row starts that activity immediately', (tester) async {
    final controller = await _pump(tester);

    await tester.tap(find.text('Basketball'));
    await tester.pumpAndSettle();

    expect(controller.startCardioCalls, ['BASKETBALL']);
    expect(find.byType(CardioSessionScreen), findsOneWidget);
    expect(find.byType(ActivityPickerScreen), findsNothing);
  });

  testWidgets('the close button pops the screen', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          workoutSessionControllerProvider.overrideWith(_RecordingSessionController.new),
          workoutTemplateControllerProvider.overrideWith(() => _FakeTemplates()),
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
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ActivityPickerScreen()),
                  ),
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
    expect(find.byType(ActivityPickerScreen), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(find.byType(ActivityPickerScreen), findsNothing);
  });
}
