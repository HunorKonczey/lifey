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
import 'package:lifey/features/workouts/presentation/sessions_tab.dart';
import 'package:lifey/l10n/app_localizations.dart';

/// C1.7: the sessions-tab kind/type filter (mind / erősítő / cardio +
/// másodlagos típus-szűrő). See docs/cardio/59-cardio-implementation-plan.md
/// C1.7 — kész-ha: filter state survives a tab switch, which
/// `_WorkoutsScreenState` guarantees structurally (same State object across
/// TabController changes), so this file covers the actual filtering logic
/// instead: `matchesSessionKindFilter` plus `SessionsTab` wired to it.

WorkoutSession _strengthSession(String clientId) {
  final startedAt = DateTime.now();
  return WorkoutSession(
    clientId: clientId,
    exercises: const [],
    sets: const [],
    startedAt: startedAt,
    finishedAt: startedAt.add(const Duration(minutes: 30)),
  );
}

WorkoutSession _cardioSession(String clientId, String activityType) {
  final startedAt = DateTime.now();
  return WorkoutSession(
    clientId: clientId,
    exercises: const [],
    sets: const [],
    startedAt: startedAt,
    finishedAt: startedAt.add(const Duration(minutes: 30)),
    sessionKind: 'CARDIO',
    activityType: activityType,
  );
}

void main() {
  group('matchesSessionKindFilter', () {
    test('null kindFilter matches everything', () {
      expect(
        matchesSessionKindFilter(_strengthSession('s'),
            kindFilter: null, activityTypeFilter: null),
        isTrue,
      );
      expect(
        matchesSessionKindFilter(_cardioSession('c', 'RUNNING'),
            kindFilter: null, activityTypeFilter: null),
        isTrue,
      );
    });

    test("'STRENGTH' matches only non-cardio sessions", () {
      expect(
        matchesSessionKindFilter(_strengthSession('s'),
            kindFilter: 'STRENGTH', activityTypeFilter: null),
        isTrue,
      );
      expect(
        matchesSessionKindFilter(_cardioSession('c', 'RUNNING'),
            kindFilter: 'STRENGTH', activityTypeFilter: null),
        isFalse,
      );
    });

    test("'CARDIO' with no activityTypeFilter matches any cardio type", () {
      expect(
        matchesSessionKindFilter(_cardioSession('c', 'RUNNING'),
            kindFilter: 'CARDIO', activityTypeFilter: null),
        isTrue,
      );
      expect(
        matchesSessionKindFilter(_cardioSession('c', 'BASKETBALL'),
            kindFilter: 'CARDIO', activityTypeFilter: null),
        isTrue,
      );
      expect(
        matchesSessionKindFilter(_strengthSession('s'),
            kindFilter: 'CARDIO', activityTypeFilter: null),
        isFalse,
      );
    });

    test("'CARDIO' + activityTypeFilter narrows to that one type", () {
      expect(
        matchesSessionKindFilter(_cardioSession('c', 'RUNNING'),
            kindFilter: 'CARDIO', activityTypeFilter: 'RUNNING'),
        isTrue,
      );
      expect(
        matchesSessionKindFilter(_cardioSession('c', 'WALKING'),
            kindFilter: 'CARDIO', activityTypeFilter: 'RUNNING'),
        isFalse,
      );
    });

    test('an activityTypeFilter is ignored under a STRENGTH or null kindFilter', () {
      // A stale secondary selection can never sneak in — only `_sessionKindFilter`
      // (workouts_screen.dart) actually produces this shape, but the predicate
      // itself should be defensive too.
      expect(
        matchesSessionKindFilter(_strengthSession('s'),
            kindFilter: null, activityTypeFilter: 'RUNNING'),
        isTrue,
      );
    });
  });

  group('SessionsTab wired to the kind filter', () {
    Future<void> pump(
      WidgetTester tester,
      List<WorkoutSession> sessions, {
      String? kindFilter,
      String? activityTypeFilter,
    }) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            workoutSessionControllerProvider.overrideWith(() => _FakeSessions(sessions)),
            exerciseControllerProvider.overrideWith(_FakeExercises.new),
            workoutTemplateControllerProvider.overrideWith(_FakeTemplates.new),
            settingsControllerProvider.overrideWith(_FakeSettings.new),
            syncStatusByClientIdProvider.overrideWithValue(const {}),
          ],
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SessionsTab(kindFilter: kindFilter, activityTypeFilter: activityTypeFilter),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('STRENGTH filter hides cardio sessions', (tester) async {
      await pump(
        tester,
        [_strengthSession('s1'), _cardioSession('c1', 'RUNNING')],
        kindFilter: 'STRENGTH',
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Running'), findsNothing);
    });

    testWidgets('CARDIO + RUNNING filter shows only that one type', (tester) async {
      await pump(
        tester,
        [_cardioSession('run', 'RUNNING'), _cardioSession('walk', 'WALKING')],
        kindFilter: 'CARDIO',
        activityTypeFilter: 'RUNNING',
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Running'), findsOneWidget);
      expect(find.text('Walking'), findsNothing);
    });

    testWidgets('no filter shows everything', (tester) async {
      await pump(
        tester,
        [_strengthSession('s1'), _cardioSession('c1', 'RUNNING')],
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Running'), findsOneWidget);
      expect(find.text('0 sets'), findsOneWidget);
    });
  });
}

class _FakeSessions extends WorkoutSessionController {
  _FakeSessions(this._sessions);
  final List<WorkoutSession> _sessions;
  @override
  Stream<List<WorkoutSession>> build() => Stream.value(_sessions);
}

class _FakeExercises extends ExerciseController {
  @override
  Stream<List<Exercise>> build() => Stream.value(const []);
}

class _FakeTemplates extends WorkoutTemplateController {
  @override
  Stream<List<WorkoutTemplate>> build() => Stream.value(const []);
}

class _FakeSettings extends SettingsController {
  @override
  Stream<UserSettings> build() => Stream.value(const UserSettings.defaults());
}
