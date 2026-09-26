import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:lifey/core/theme/app_theme.dart';
import 'package:lifey/features/nutrition/application/daily_macros_controller.dart';
import 'package:lifey/features/nutrition/domain/daily_macros.dart';
import 'package:lifey/features/settings/application/settings_controller.dart';
import 'package:lifey/features/settings/domain/user_settings.dart';
import 'package:lifey/features/steps/data/step_count_repository.dart';
import 'package:lifey/features/streaks/domain/weekly_recap.dart';
import 'package:lifey/features/streaks/presentation/weekly_recap_screen.dart';
import 'package:lifey/features/water/application/daily_water_totals_provider.dart';
import 'package:lifey/features/weight/application/weight_controller.dart';
import 'package:lifey/features/weight/domain/weight_entry.dart';
import 'package:lifey/features/workouts/application/workout_session_controller.dart';
import 'package:lifey/features/workouts/domain/workout_session.dart';
import 'package:lifey/l10n/app_localizations.dart';

final _lastWeek = WeeklyRecap.lastCompletedWeekStart();
DateTime _lastWeekDay(int offset) => _lastWeek.add(Duration(days: offset));

DailyMacros _macros(DateTime day, double calories) =>
    DailyMacros(day: day, calories: calories, protein: 0, carbs: 0, fat: 0);

class _FakeSettingsController extends SettingsController {
  _FakeSettingsController(this._settings);
  final UserSettings _settings;

  @override
  Stream<UserSettings> build() => Stream.value(_settings);
}

class _FakeWorkoutSessionController extends WorkoutSessionController {
  _FakeWorkoutSessionController(this._sessions);
  final List<WorkoutSession> _sessions;

  @override
  Stream<List<WorkoutSession>> build() => Stream.value(_sessions);
}

class _FakeWeightController extends WeightController {
  _FakeWeightController(this._entries);
  final List<WeightEntry> _entries;

  @override
  Stream<List<WeightEntry>> build() => Stream.value(_entries);
}

Future<void> _pumpScreen(
  WidgetTester tester, {
  UserSettings settings = const UserSettings.defaults(),
  List<DailyMacros> macros = const [],
  List<WorkoutSession> sessions = const [],
  List<WeightEntry> weights = const [],
  Map<DateTime, double> water = const {},
  Locale locale = const Locale('en'),
  double textScale = 1,
  ThemeData? theme,
}) async {
  tester.view.physicalSize = const Size(360 * 2.625, 923 * 2.625);
  tester.view.devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        settingsControllerProvider.overrideWith(() => _FakeSettingsController(settings)),
        dailyMacrosProvider.overrideWith((ref) => Stream.value(macros)),
        workoutSessionControllerProvider.overrideWith(
          () => _FakeWorkoutSessionController(sessions),
        ),
        weightControllerProvider.overrideWith(() => _FakeWeightController(weights)),
        dailyWaterTotalsProvider.overrideWith((ref) => AsyncValue.data(water)),
        allStepCountsProvider.overrideWith((ref) => Stream.value(const [])),
      ],
      child: MaterialApp(
        theme: theme ?? AppTheme.dark,
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const WeeklyRecapScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  final fmt = DateFormat('MMM d');

  testWidgets('defaults to the last completed week and shows its date range', (tester) async {
    await _pumpScreen(tester);

    final weekEnd = _lastWeek.add(const Duration(days: 6));
    expect(find.text('${fmt.format(_lastWeek)} – ${fmt.format(weekEnd)}'), findsOneWidget);
  });

  testWidgets('an entirely empty week shows empty hints, no weight/goals sections', (
    tester,
  ) async {
    await _pumpScreen(tester);

    expect(find.text('No workouts logged this week.'), findsOneWidget);
    expect(find.text('No meals logged this week.'), findsOneWidget);
    expect(find.text('Weight'), findsNothing);
    expect(find.text('Goals & Streaks'), findsNothing);
  });

  testWidgets('shows workout count, minutes and nutrition average when data exists', (
    tester,
  ) async {
    await _pumpScreen(
      tester,
      sessions: [
        WorkoutSession(
          clientId: 's1',
          startedAt: _lastWeekDay(0),
          finishedAt: _lastWeekDay(0).add(const Duration(minutes: 40)),
          exercises: const [],
          sets: const [],
        ),
      ],
      macros: [_macros(_lastWeekDay(0), 1800), _macros(_lastWeekDay(1), 2200)],
    );

    expect(find.text('1 workout'), findsOneWidget);
    expect(find.text('40 min total'), findsOneWidget);
    expect(find.textContaining('2,000', findRichText: true), findsOneWidget); // avg of 1800/2200
    expect(find.text('avg of 2 logged days'), findsOneWidget);
  });

  testWidgets('weight section shows start, end and a delta badge', (tester) async {
    await _pumpScreen(
      tester,
      weights: [
        WeightEntry(
          clientId: 'w0',
          date: _lastWeek.subtract(const Duration(days: 2)),
          weight: 82.0,
          recordedAt: _lastWeek.subtract(const Duration(days: 2)),
        ),
        WeightEntry(
          clientId: 'w1',
          date: _lastWeekDay(4),
          weight: 80.5,
          recordedAt: _lastWeekDay(4),
        ),
      ],
    );

    expect(find.text('WEIGHT'), findsOneWidget); // SectionLabel uppercases its title
    expect(find.text('82.0 kg'), findsOneWidget);
    expect(find.textContaining('80.5', findRichText: true), findsOneWidget);
    expect(find.textContaining('1.5 kg', findRichText: true), findsOneWidget); // delta magnitude
    expect(find.byIcon(Icons.south_rounded), findsOneWidget); // lost weight
  });

  testWidgets('goals section shows a row per set goal with days-met text', (tester) async {
    await _pumpScreen(
      tester,
      settings: const UserSettings.defaults().copyWith(
        dailyCalorieGoal: 2000,
        dailyStepGoal: 8000,
      ),
      macros: [
        _macros(_lastWeekDay(0), 1800), // met
        _macros(_lastWeekDay(1), 2500), // over
      ],
    );

    expect(find.text('GOALS & STREAKS'), findsOneWidget); // SectionLabel uppercases its title
    // "1/7 days within goal" appears twice: once in the nutrition section's
    // caption, once in the goals section's calorie row — both legitimately.
    expect(find.text('1/7 days within goal'), findsNWidgets(2));
    expect(find.text('0/7 days met'), findsOneWidget); // steps, no data
  });

  testWidgets('the next-week chevron is disabled on the default (latest) week', (tester) async {
    await _pumpScreen(tester);

    final nextButton = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.chevron_right_rounded),
    );
    expect(nextButton.onPressed, isNull);
  });

  testWidgets('tapping previous then next returns to the original week range', (tester) async {
    await _pumpScreen(tester);

    final weekEnd = _lastWeek.add(const Duration(days: 6));
    final originalLabel = '${fmt.format(_lastWeek)} – ${fmt.format(weekEnd)}';

    await tester.tap(find.byIcon(Icons.chevron_left_rounded));
    await tester.pumpAndSettle();
    expect(find.text(originalLabel), findsNothing);

    await tester.tap(find.byIcon(Icons.chevron_right_rounded));
    await tester.pumpAndSettle();
    expect(find.text(originalLabel), findsOneWidget);

    final nextButton = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.chevron_right_rounded),
    );
    expect(nextButton.onPressed, isNull);
  });

  group('Hungarian', () {
    final full = [
      WorkoutSession(
        clientId: 's1',
        startedAt: _lastWeekDay(0),
        finishedAt: _lastWeekDay(0).add(const Duration(minutes: 40)),
        exercises: const [],
        sets: const [],
      ),
    ];

    testWidgets('the week range and weekday letters are Hungarian', (tester) async {
      await _pumpScreen(tester, locale: const Locale('hu'), sessions: full, macros: [_macros(_lastWeekDay(0), 1800)]);
      final weekEnd = _lastWeek.add(const Duration(days: 6));
      final hu = DateFormat('MMM d.', 'hu');
      expect(find.text('${hu.format(_lastWeek)} – ${hu.format(weekEnd)}'), findsOneWidget);
      expect(find.text('Heti összefoglaló'), findsOneWidget);
      // Monday-first letters, no repeated "Sz".
      expect(find.text('Szo'), findsWidgets);
      expect(find.text('Sze'), findsWidgets);
    });

    for (final scale in [1.0, 1.3]) {
      for (final theme in {'dark': AppTheme.dark, 'light': AppTheme.light}.entries) {
        testWidgets('a full week fits at 360 dp — ${theme.key}, ×$scale', (tester) async {
          await _pumpScreen(
            tester,
            locale: const Locale('hu'),
            textScale: scale,
            theme: theme.value,
            settings: const UserSettings.defaults().copyWith(dailyCalorieGoal: 2000, dailyStepGoal: 8000, dailyWaterGoalLiters: 2.5),
            sessions: full,
            macros: [_macros(_lastWeekDay(0), 1800), _macros(_lastWeekDay(2), 2200)],
            weights: [
              WeightEntry(clientId: 'a', date: _lastWeek.subtract(const Duration(days: 2)), weight: 82, recordedAt: _lastWeek),
              WeightEntry(clientId: 'b', date: _lastWeekDay(4), weight: 80.5, recordedAt: _lastWeek),
            ],
          );
          await tester.drag(find.byType(Scrollable).first, const Offset(0, -800));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.textContaining('80,5', findRichText: true), findsOneWidget);
        });
      }
    }
  });
}
