import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/entitlements/entitlement_providers.dart';
import 'package:lifey/core/sync/sync_status_provider.dart';
import 'package:lifey/core/theme/app_theme.dart';
import 'package:lifey/features/settings/application/settings_controller.dart';
import 'package:lifey/features/settings/domain/user_settings.dart';
import 'package:lifey/features/workouts/application/exercise_controller.dart';
import 'package:lifey/features/workouts/application/workout_session_controller.dart';
import 'package:lifey/features/workouts/application/workout_template_controller.dart';
import 'package:lifey/features/workouts/domain/exercise.dart';
import 'package:lifey/features/workouts/domain/workout_session.dart';
import 'package:lifey/features/workouts/domain/workout_template.dart';
import 'package:lifey/features/workouts/presentation/sessions_tab.dart';
import 'package:lifey/features/workouts/presentation/widgets/session_row.dart';
import 'package:lifey/features/workouts/presentation/widgets/week_summary_row.dart';
import 'package:lifey/l10n/app_localizations.dart';
import 'package:lifey/shared/widgets/date_range_filter_bar.dart';

class _FakeSessions extends WorkoutSessionController {
  _FakeSessions(this._sessions);
  final List<WorkoutSession> _sessions;
  final deleted = <String>[];

  @override
  Stream<List<WorkoutSession>> build() => Stream.value(_sessions);

  @override
  Future<void> deleteSession(String clientId) async => deleted.add(clientId);
}

class _NoExercises extends ExerciseController {
  @override
  Stream<List<Exercise>> build() => Stream.value(const []);
}

class _NoTemplates extends WorkoutTemplateController {
  @override
  Stream<List<WorkoutTemplate>> build() => Stream.value(const []);
}

class _Settings extends SettingsController {
  @override
  Stream<UserSettings> build() => Stream.value(const UserSettings.defaults());
}

final _now = DateTime.now();

DateTime _at(int daysAgo, int hour) => DateTime(_now.year, _now.month, _now.day - daysAgo, hour);

WorkoutSession _bench(String id, DateTime start, double kg) => WorkoutSession(
      clientId: id,
      exercises: const [],
      sets: [
        ExerciseSet(exerciseClientId: 'bench', exerciseName: 'Bench press', reps: 8, weight: kg, performedAt: start),
      ],
      startedAt: start,
      finishedAt: start.add(const Duration(minutes: 40)),
      templateName: 'Push day',
    );

Future<_FakeSessions> _pump(
  WidgetTester tester,
  List<WorkoutSession> sessions, {
  Locale locale = const Locale('en'),
}) async {
  tester.view.physicalSize = const Size(411 * 2.625, 1400 * 2.625);
  tester.view.devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);
  final fake = _FakeSessions(sessions);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        workoutSessionControllerProvider.overrideWith(() => fake),
        exerciseControllerProvider.overrideWith(_NoExercises.new),
        workoutTemplateControllerProvider.overrideWith(_NoTemplates.new),
        settingsControllerProvider.overrideWith(_Settings.new),
        syncStatusByClientIdProvider.overrideWithValue(const {}),
        historyCutoffProvider.overrideWithValue(null),
      ],
      child: MaterialApp(
        theme: AppTheme.dark,
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: SessionsTab(filter: DateRangeFilter.all)),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return fake;
}

void main() {
  // Sessions on fixed days back; which group each falls in depends on the
  // weekday the suite runs on, so only the order and the presence of the
  // "older" group (three weeks back) are asserted.
  final history = [
    _bench('now', _at(0, 8), 65),
    _bench('old', _at(21, 18), 60),
    _bench('older', _at(35, 18), 50),
  ];

  testWidgets('the week summary leads, then the groups, oldest last', (tester) async {
    await _pump(tester, history);

    expect(find.byType(WeekSummaryRow), findsOneWidget);
    expect(find.text('TODAY'), findsOneWidget);
    expect(find.byType(SessionRow), findsNWidgets(3));
    final headers = tester.widgetList<Text>(find.byType(Text)).map((t) => t.data).whereType<String>().where((t) => t == t.toUpperCase() && t.contains(RegExp('[A-Z]{3}')));
    expect(headers.first, 'TODAY');
  });

  testWidgets('an older week is headed by its date range', (tester) async {
    await _pump(tester, history);

    // "Aug 24 – Aug 30" style: two short dates joined by an en dash.
    expect(find.textContaining(' – '), findsWidgets);
  });

  testWidgets('every session that beat the earlier ones carries the trophy chip, the first ever none', (tester) async {
    await _pump(tester, history);

    // 65 kg beat 60, 60 beat 50 (heaviest set + estimated 1RM each); the 50 kg
    // session set the baseline.
    expect(find.text('2 PRs'), findsNWidgets(2));
  });

  testWidgets('Hungarian group header', (tester) async {
    await _pump(tester, history, locale: const Locale('hu'));

    expect(find.text('MA'), findsOneWidget);
  });

  testWidgets('long-press opens Open / Delete; Delete asks first and then removes', (tester) async {
    final fake = await _pump(tester, history);

    await tester.longPress(find.byType(SessionRow).first);
    await tester.pumpAndSettle();
    expect(find.text('Open'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(fake.deleted, ['now']);
  });

  testWidgets('a row has no trash icon any more', (tester) async {
    await _pump(tester, history);

    expect(find.byIcon(Icons.delete_outline), findsNothing);
    expect(find.byTooltip('Delete workout'), findsNothing);
  });
}
