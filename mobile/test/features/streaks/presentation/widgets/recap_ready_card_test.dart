import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/features/nutrition/application/daily_macros_controller.dart';
import 'package:lifey/features/nutrition/domain/daily_macros.dart';
import 'package:lifey/features/settings/application/settings_controller.dart';
import 'package:lifey/features/settings/domain/user_settings.dart';
import 'package:lifey/features/steps/data/step_count_repository.dart';
import 'package:lifey/features/streaks/domain/weekly_recap.dart';
import 'package:lifey/features/streaks/presentation/widgets/recap_ready_card.dart';
import 'package:lifey/features/water/application/daily_water_totals_provider.dart';
import 'package:lifey/features/weight/application/weight_controller.dart';
import 'package:lifey/features/weight/domain/weight_entry.dart';
import 'package:lifey/features/workouts/application/workout_session_controller.dart';
import 'package:lifey/features/workouts/domain/workout_session.dart';
import 'package:lifey/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

// A fixed Tuesday, safely inside the Monday–Wednesday nudge window.
final _tuesday = DateTime(2026, 6, 2);
final _lastCompletedWeekStart = WeeklyRecap.lastCompletedWeekStart(_tuesday);

class _FakeSettingsController extends SettingsController {
  @override
  Stream<UserSettings> build() => Stream.value(const UserSettings.defaults());
}

class _FakeWorkoutSessionController extends WorkoutSessionController {
  _FakeWorkoutSessionController(this._sessions);
  final List<WorkoutSession> _sessions;

  @override
  Stream<List<WorkoutSession>> build() => Stream.value(_sessions);
}

class _FakeWeightController extends WeightController {
  @override
  Stream<List<WeightEntry>> build() => Stream.value(const []);
}

Future<void> _pumpCard(
  WidgetTester tester, {
  DateTime? now,
  List<DailyMacros> macros = const [],
  List<WorkoutSession> sessions = const [],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        settingsControllerProvider.overrideWith(() => _FakeSettingsController()),
        dailyMacrosProvider.overrideWith((ref) => Stream.value(macros)),
        workoutSessionControllerProvider.overrideWith(
          () => _FakeWorkoutSessionController(sessions),
        ),
        weightControllerProvider.overrideWith(() => _FakeWeightController()),
        dailyWaterTotalsProvider.overrideWith((ref) => const AsyncValue.data({})),
        allStepCountsProvider.overrideWith((ref) => Stream.value(const [])),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: RecapReadyCard(now: now ?? _tuesday)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('hidden when the last completed week has no data', (tester) async {
    await _pumpCard(tester);

    expect(find.text('Your weekly recap is ready'), findsNothing);
  });

  testWidgets('shown when the last completed week has data, within the Mon–Wed window', (
    tester,
  ) async {
    await _pumpCard(
      tester,
      sessions: [
        WorkoutSession(
          clientId: 's1',
          startedAt: _lastCompletedWeekStart,
          exercises: const [],
          sets: const [],
        ),
      ],
    );

    expect(find.text('Your weekly recap is ready'), findsOneWidget);
  });

  testWidgets('hidden outside the Monday–Wednesday window even with data', (tester) async {
    final saturday = DateTime(2026, 6, 6);
    await _pumpCard(
      tester,
      now: saturday,
      macros: [DailyMacros(day: saturday.subtract(const Duration(days: 7)), calories: 1800, protein: 0, carbs: 0, fat: 0)],
    );

    expect(find.text('Your weekly recap is ready'), findsNothing);
  });

  testWidgets('tapping dismiss hides the card and persists the dismissal', (tester) async {
    await _pumpCard(
      tester,
      sessions: [
        WorkoutSession(
          clientId: 's1',
          startedAt: _lastCompletedWeekStart,
          exercises: const [],
          sets: const [],
        ),
      ],
    );
    expect(find.text('Your weekly recap is ready'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(find.text('Your weekly recap is ready'), findsNothing);

    // Rebuilding the whole tree (simulating a fresh dashboard build after
    // dismissal was persisted) must stay hidden.
    await _pumpCard(
      tester,
      sessions: [
        WorkoutSession(
          clientId: 's1',
          startedAt: _lastCompletedWeekStart,
          exercises: const [],
          sets: const [],
        ),
      ],
    );
    expect(find.text('Your weekly recap is ready'), findsNothing);
  });
}
