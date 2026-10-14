import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/entitlements/entitlement_providers.dart';
import 'package:lifey/core/sync/sync_status_provider.dart';
import 'package:lifey/features/settings/application/settings_controller.dart';
import 'package:lifey/features/settings/domain/user_settings.dart';
import 'package:lifey/features/workouts/application/exercise_controller.dart';
import 'package:lifey/features/workouts/application/exercise_paged_controller.dart';
import 'package:lifey/features/workouts/application/workout_session_controller.dart';
import 'package:lifey/features/workouts/application/workout_sessions_paged_controller.dart';
import 'package:lifey/features/workouts/application/workout_template_controller.dart';
import 'package:lifey/features/workouts/domain/exercise.dart';
import 'package:lifey/features/workouts/domain/workout_session.dart';
import 'package:lifey/features/workouts/domain/workout_template.dart';
import 'package:lifey/features/workouts/presentation/exercises_tab.dart';
import 'package:lifey/features/workouts/presentation/sessions_tab.dart';
import 'package:lifey/l10n/app_localizations.dart';
import 'package:lifey/shared/widgets/date_range_filter_bar.dart';

import 'fake_paged_sessions.dart';
import '../../../helpers/summaries_bridge.dart';

/// What the Exercises and Sessions tabs do with their windows (docs/14-pagination-plan.md Phase 1.3, LIF-113): a footer while
/// older rows exist, a request for the next page when the viewport nears the bottom, and - for sessions - loading on its own
/// when a filter or the week summary leaves the window too short to be right.
void main() {
  group('SessionsTab', () {
    late FakePagedSessions fake;

    WorkoutSession session(String id, DateTime startedAt) => WorkoutSession(
          clientId: id,
          exercises: const [],
          sets: const [],
          startedAt: startedAt,
          finishedAt: startedAt.add(const Duration(minutes: 30)),
        );

    /// [count] sessions, one a day, starting [firstDaysAgo] days back.
    List<WorkoutSession> daily(int count, {int firstDaysAgo = 0}) {
      final now = DateTime.now();
      return [for (var i = 0; i < count; i++) session('s$i', now.subtract(Duration(days: firstDaysAgo + i)))];
    }

    Future<void> pump(WidgetTester tester, List<WorkoutSession> sessions,
        {bool more = false, DateTime? cutoff, DateRangeFilter filter = DateRangeFilter.all}) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      fake = FakePagedSessions(sessions, more: more);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            summariesFollowController,
            sessionsWithSetsFollowController,
            workoutSessionControllerProvider.overrideWith(() => _Sessions(sessions)),
            workoutSessionsPagedProvider.overrideWith(() => fake),
            exerciseControllerProvider.overrideWith(_Exercises.new),
            workoutTemplateControllerProvider.overrideWith(_Templates.new),
            settingsControllerProvider.overrideWith(_Settings.new),
            syncStatusByClientIdProvider.overrideWithValue(const {}),
            historyCutoffProvider.overrideWithValue(cutoff),
          ],
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: SessionsTab(filter: filter)),
          ),
        ),
      );
      await _settle(tester);
    }

    testWidgets('no footer and no request when there is nothing older', (tester) async {
      await pump(tester, daily(5));

      expect(find.byKey(const Key('sessions-loading-more')), findsNothing);
      expect(fake.loadMoreCalls, 0);
    });

    testWidgets('a footer shows while older sessions exist, and a window that is long enough asks for nothing yet', (tester) async {
      await pump(tester, daily(30, firstDaysAgo: 1), more: true);

      expect(fake.loadMoreCalls, 0);
      await tester.dragUntilVisible(find.byKey(const Key('sessions-loading-more')), find.byType(CustomScrollView), const Offset(0, -400));
      expect(find.byKey(const Key('sessions-loading-more')), findsOneWidget);
    });

    testWidgets('scrolling to the bottom asks for the next page', (tester) async {
      await pump(tester, daily(30, firstDaysAgo: 1), more: true);
      expect(fake.loadMoreCalls, 0);

      await _scrollToEnd(tester);

      expect(fake.loadMoreCalls, greaterThan(0));
    });

    testWidgets('a window that has not reached back past the start of the week loads more by itself', (tester) async {
      // Only today's workout is in the window, yet older ones exist - the week summary and the list would both be incomplete.
      await pump(tester, daily(1), more: true, filter: DateRangeFilter.today);

      expect(fake.loadMoreCalls, greaterThan(0));
    });

    testWidgets('under the Today filter a window that reaches back past the start of the week asks for nothing', (tester) async {
      await pump(
        tester,
        [...daily(1), session('old', DateTime.now().subtract(const Duration(days: 8)))],
        more: true,
        filter: DateRangeFilter.today,
      );

      expect(fake.loadMoreCalls, 0);
    });

    testWidgets('a window that is too short to fill the list loads more by itself', (tester) async {
      // Reaches back a month, but a kind filter or a sparse history leaves only 3 rows.
      await pump(tester, [...daily(1), session('old-1', DateTime.now().subtract(const Duration(days: 20))), session('old-2', DateTime.now().subtract(const Duration(days: 30)))], more: true);

      expect(fake.loadMoreCalls, greaterThan(0));
    });

    testWidgets('nothing older than the free history window is ever requested', (tester) async {
      final now = DateTime.now();
      final cutoff = now.subtract(const Duration(days: 30));
      await pump(
        tester,
        [session('today', now), session('beyond', now.subtract(const Duration(days: 45)))],
        more: true,
        cutoff: cutoff,
      );

      expect(fake.loadMoreCalls, 0);
    });
  });

  group('ExercisesTab', () {
    late _PagedExercises fake;

    Exercise exercise(int i) => Exercise(clientId: 'e$i', name: 'Exercise ${i.toString().padLeft(3, '0')}', category: 'CHEST');

    Future<void> pump(WidgetTester tester, int count, {bool more = false}) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      fake = _PagedExercises([for (var i = 0; i < count; i++) exercise(i)], more: more);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            exerciseControllerProvider.overrideWith(_Exercises.new),
            exercisePagedControllerProvider.overrideWith2((arg) => fake),
            syncStatusByClientIdProvider.overrideWithValue(const {}),
          ],
          child: const MaterialApp(
            locale: Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: ExercisesTab()),
          ),
        ),
      );
      await _settle(tester);
    }

    testWidgets('no footer and no request when the whole list fits the window', (tester) async {
      await pump(tester, 10);

      expect(find.byKey(const Key('exercises-loading-more')), findsNothing);
      expect(fake.loadMoreCalls, 0);
    });

    testWidgets('scrolling to the bottom of a window with more behind it asks for the next page and shows the footer', (tester) async {
      await pump(tester, 60, more: true);
      expect(fake.loadMoreCalls, 0);

      await _scrollToEnd(tester);

      expect(fake.loadMoreCalls, greaterThan(0));
      expect(find.byKey(const Key('exercises-loading-more')), findsOneWidget);
    });

    testWidgets('the request is edge-triggered: lingering at the bottom asks once', (tester) async {
      await pump(tester, 60, more: true);

      await _scrollToEnd(tester);
      final afterFirst = fake.loadMoreCalls;
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -50));
      await _settle(tester);

      expect(afterFirst, 1);
      expect(fake.loadMoreCalls, 1);
    });
  });
}

class _PagedExercises extends ExercisePagedController {
  _PagedExercises(this.exercises, {required this.more}) : super(null);

  final List<Exercise> exercises;
  final bool more;
  int loadMoreCalls = 0;

  @override
  Stream<List<Exercise>> build() {
    hasMore = more;
    return Stream.value(exercises);
  }

  @override
  void loadMore() => loadMoreCalls++;
}

class _Sessions extends WorkoutSessionController {
  _Sessions(this._sessions);
  final List<WorkoutSession> _sessions;

  @override
  Stream<List<WorkoutSession>> build() => Stream.value(_sessions);
}

class _Exercises extends ExerciseController {
  @override
  Stream<List<Exercise>> build() => Stream.value(const []);
}

class _Templates extends WorkoutTemplateController {
  @override
  Stream<List<WorkoutTemplate>> build() => Stream.value(const []);
}

class _Settings extends SettingsController {
  @override
  Stream<UserSettings> build() => Stream.value(const UserSettings.defaults());
}

/// The footer's spinner never stops animating, so `pumpAndSettle` would time out whenever a window has more behind it.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Drags to the end of the list; the extent of a lazily built list grows as it scrolls, so one drag can stop short.
Future<void> _scrollToEnd(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -20000));
    await _settle(tester);
  }
}
