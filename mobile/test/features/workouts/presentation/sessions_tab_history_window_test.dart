import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lifey/core/entitlements/entitlement_providers.dart';
import 'package:lifey/core/sync/sync_status_provider.dart';
import 'package:lifey/features/settings/application/settings_controller.dart';
import 'package:lifey/features/settings/domain/user_settings.dart';
import 'package:lifey/features/workouts/application/exercise_controller.dart';
import 'package:lifey/features/workouts/application/workout_session_controller.dart';
import 'package:lifey/features/workouts/application/workout_template_controller.dart';
import 'package:lifey/features/workouts/domain/exercise.dart';
import 'package:lifey/features/workouts/domain/workout_session.dart';
import 'package:lifey/features/workouts/domain/workout_template.dart';
import 'package:lifey/features/workouts/presentation/sessions_tab.dart';
import 'package:lifey/l10n/app_localizations.dart';
import 'package:lifey/shared/widgets/date_range_filter_bar.dart';
import 'package:lifey/shared/widgets/history_boundary_row.dart';

/// Covers the history boundary row in a workout list (frame P12, `69` §4.2)
/// at both `historyDays: 30` and `historyDays: null`, and D-P6's explicit
/// requirement: [workoutSessionControllerProvider]'s own query — how many
/// sessions the fake controller ever hands back — is identical between the
/// two; only what [SessionsTab] chooses to *render* differs.

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

WorkoutSession _session({required String clientId, required DateTime startedAt}) {
  return WorkoutSession(
    clientId: clientId,
    exercises: const [],
    sets: const [],
    startedAt: startedAt,
    finishedAt: startedAt.add(const Duration(minutes: 30)),
    templateName: 'Session $clientId',
  );
}

/// Ten sessions, one every 10 days back from today (0, 10, 20, ..., 90) —
/// newest-first, matching `WorkoutSessionRepository.watchAll`'s real order.
List<WorkoutSession> _tenSessionsSpanningNinetyDays() {
  final now = DateTime.now();
  return [
    for (var i = 0; i < 10; i++)
      _session(clientId: 's$i', startedAt: now.subtract(Duration(days: i * 10))),
  ];
}

Future<ProviderContainer> _pumpSessionsTab(
  WidgetTester tester, {
  required List<WorkoutSession> sessions,
  required DateTime? historyCutoff,
}) async {
  // Tall enough that every one of the ten test sessions renders without
  // scrolling — ListView.builder only builds what's on screen, and the
  // default test viewport is too short for all ten cards at once.
  tester.view.physicalSize = const Size(800, 4000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  late ProviderContainer container;
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) {
          container = ProviderScope.containerOf(context);
          return const Scaffold(
            body: SessionsTab(filter: DateRangeFilter.all),
          );
        },
      ),
      GoRoute(
        path: '/paywall',
        builder: (context, state) => const Scaffold(body: Text('paywall')),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        workoutSessionControllerProvider.overrideWith(() => _FakeWorkoutSessionController(sessions)),
        exerciseControllerProvider.overrideWith(_FakeExerciseController.new),
        workoutTemplateControllerProvider.overrideWith(_FakeWorkoutTemplateController.new),
        settingsControllerProvider.overrideWith(_FakeSettingsController.new),
        syncStatusByClientIdProvider.overrideWithValue(const {}),
        historyCutoffProvider.overrideWithValue(historyCutoff),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

DateTime _thirtyDaysAgo() {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  return today.subtract(const Duration(days: 30));
}

void main() {
  testWidgets('historyDays: 30 shows only the sessions within the window, plus the boundary row',
      (tester) async {
    final sessions = _tenSessionsSpanningNinetyDays();
    await _pumpSessionsTab(tester, sessions: sessions, historyCutoff: _thirtyDaysAgo());

    // Days 0, 10, 20, 30 back are within a 30-day window — 4 sessions.
    expect(find.byType(Dismissible), findsNWidgets(4));
    expect(find.byType(HistoryBoundaryRow), findsOneWidget);
  });

  testWidgets('historyDays: null shows every session, no boundary row', (tester) async {
    final sessions = _tenSessionsSpanningNinetyDays();
    await _pumpSessionsTab(tester, sessions: sessions, historyCutoff: null);

    expect(find.byType(Dismissible), findsNWidgets(10));
    expect(find.byType(HistoryBoundaryRow), findsNothing);
  });

  testWidgets('tapping the boundary row opens the paywall', (tester) async {
    final sessions = _tenSessionsSpanningNinetyDays();
    await _pumpSessionsTab(tester, sessions: sessions, historyCutoff: _thirtyDaysAgo());

    await tester.tap(find.byType(HistoryBoundaryRow));
    await tester.pumpAndSettle();

    expect(find.text('paywall'), findsOneWidget);
  });

  testWidgets(
      "D-P6: workoutSessionControllerProvider's own data is identical whether "
      'historyDays is 30 or null — only what SessionsTab renders differs',
      (tester) async {
    final sessions = _tenSessionsSpanningNinetyDays();

    final freeContainer =
        await _pumpSessionsTab(tester, sessions: sessions, historyCutoff: _thirtyDaysAgo());
    final freeQueryResult = freeContainer.read(workoutSessionControllerProvider).value;

    final proContainer = await _pumpSessionsTab(tester, sessions: sessions, historyCutoff: null);
    final proQueryResult = proContainer.read(workoutSessionControllerProvider).value;

    // The underlying query result is the same ten sessions either way — the
    // history window is a rendering choice in SessionsTab, never a change to
    // what workoutSessionControllerProvider itself fetches (D-P6).
    expect(freeQueryResult, hasLength(10));
    expect(proQueryResult, hasLength(10));
    expect(freeQueryResult, equals(proQueryResult));
  });
}
