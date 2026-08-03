import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/features/settings/application/settings_controller.dart';
import 'package:lifey/features/settings/domain/user_settings.dart';
import 'package:lifey/features/workouts/application/exercise_controller.dart';
import 'package:lifey/features/workouts/application/watch_template_sync.dart';
import 'package:lifey/features/workouts/application/workout_session_controller.dart';
import 'package:lifey/features/workouts/application/workout_template_controller.dart';
import 'package:lifey/features/workouts/domain/exercise.dart';
import 'package:lifey/features/workouts/domain/workout_session.dart';
import 'package:lifey/features/workouts/domain/workout_template.dart';

/// Each fake replaces one of the four sources
/// [watchTemplateSyncPayloadProvider] reads. A `null` list stands for "still
/// loading" — the stream simply never emits, leaving the provider on
/// `AsyncValue.loading`.
class _FakeSettingsController extends SettingsController {
  _FakeSettingsController(this._settings);
  final UserSettings _settings;

  @override
  Stream<UserSettings> build() => Stream.value(_settings);
}

class _FakeSessionController extends WorkoutSessionController {
  _FakeSessionController(this._sessions);
  final List<WorkoutSession>? _sessions;

  @override
  Stream<List<WorkoutSession>> build() =>
      _sessions == null ? const Stream.empty() : Stream.value(_sessions);
}

class _FakeTemplateController extends WorkoutTemplateController {
  _FakeTemplateController(this._templates);
  final List<WorkoutTemplate>? _templates;

  @override
  Stream<List<WorkoutTemplate>> build() =>
      _templates == null ? const Stream.empty() : Stream.value(_templates);
}

class _FakeExerciseController extends ExerciseController {
  _FakeExerciseController(this._exercises);
  final List<Exercise>? _exercises;

  @override
  Stream<List<Exercise>> build() =>
      _exercises == null ? const Stream.empty() : Stream.value(_exercises);
}

/// The phone side of F6b's template sync (docs/watch/
/// 49-watch-f6b-template-sync-plan.md T1.1, T1.2): which templates the watch
/// picker offers, and the payload they turn into.
void main() {
  /// [inProgress] leaves `finishedAt` null; otherwise the session counts as
  /// finished.
  WorkoutSession session(
    String? templateClientId, {
    bool inProgress = false,
  }) {
    return WorkoutSession(
      clientId: 'session-${templateClientId ?? 'none'}-${inProgress ? 'live' : 'done'}',
      exercises: const [],
      sets: const [],
      startedAt: DateTime.utc(2026, 7, 28, 9),
      finishedAt: inProgress ? null : DateTime.utc(2026, 7, 28, 10),
      templateClientId: templateClientId,
    );
  }

  Exercise exercise(String clientId, {String? name, int? defaultRestSeconds}) {
    return Exercise(
      clientId: clientId,
      name: name ?? clientId,
      defaultRestSeconds: defaultRestSeconds,
    );
  }

  WorkoutTemplate template(
    String clientId, {
    String? name,
    required List<TemplateExercise> exercises,
  }) {
    return WorkoutTemplate(
      clientId: clientId,
      name: name ?? clientId,
      exercises: exercises,
    );
  }

  const settings = UserSettings.defaults();

  group('recentlyUsedTemplateClientIds', () {
    test('returns nothing when there is no session history at all', () {
      expect(recentlyUsedTemplateClientIds(const []), isEmpty);
    });

    test('keeps the newest-first order it was given', () {
      final result = recentlyUsedTemplateClientIds([
        session('push'),
        session('pull'),
        session('legs'),
      ]);

      expect(result, ['push', 'pull', 'legs']);
    });

    test('collapses a repeated template to its most recent use', () {
      // push is used twice: it must keep the position of the *newer* session,
      // not slide down to where the older one sits.
      final result = recentlyUsedTemplateClientIds([
        session('push'),
        session('pull'),
        session('push'),
        session('legs'),
      ]);

      expect(result, ['push', 'pull', 'legs']);
    });

    test('skips sessions started as an empty workout (no template)', () {
      final result = recentlyUsedTemplateClientIds([
        session(null),
        session('push'),
        session(null),
        session('pull'),
      ]);

      expect(result, ['push', 'pull']);
    });

    test('skips a workout that is still running', () {
      // A session in progress shouldn't reorder the picker mid-workout —
      // matches predictNextTemplateClientId's own filter.
      final result = recentlyUsedTemplateClientIds([
        session('legs', inProgress: true),
        session('push'),
        session('pull'),
      ]);

      expect(result, ['push', 'pull']);
    });

    test('stops at max, dropping older templates', () {
      final result = recentlyUsedTemplateClientIds([
        session('a'),
        session('b'),
        session('c'),
        session('d'),
        session('e'),
        session('f'),
      ]);

      expect(result, ['a', 'b', 'c', 'd', 'e']);
    });

    test('counts distinct templates towards max, not sessions', () {
      // Six sessions but only three distinct templates — all three fit under
      // the cap of 5, so nothing may be dropped.
      final result = recentlyUsedTemplateClientIds([
        session('a'),
        session('a'),
        session('b'),
        session('b'),
        session('c'),
        session('c'),
      ]);

      expect(result, ['a', 'b', 'c']);
    });

    test('honours a custom max', () {
      final result = recentlyUsedTemplateClientIds(
        [session('a'), session('b'), session('c')],
        max: 2,
      );

      expect(result, ['a', 'b']);
    });
  });

  group('buildWatchTemplateSync', () {
    test('follows the id order given, not the templates list order', () {
      // `templates` arrives alphabetically (WorkoutTemplateRepository.watchAll
      // orders by name); the recency order must win.
      final result = buildWatchTemplateSync(
        templateClientIds: ['legs', 'push'],
        templates: [
          template('legs', exercises: [const TemplateExercise(exerciseClientId: 'squat')]),
          template('push', exercises: [const TemplateExercise(exerciseClientId: 'bench')]),
        ],
        exercises: [exercise('squat'), exercise('bench')],
        settings: settings,
      );

      expect(result.map((t) => t.templateId), ['legs', 'push']);
    });

    test('resolves rest from the exercise override when it has one', () {
      final result = buildWatchTemplateSync(
        templateClientIds: ['push'],
        templates: [
          template('push', exercises: [const TemplateExercise(exerciseClientId: 'bench')]),
        ],
        exercises: [exercise('bench', defaultRestSeconds: 150)],
        settings: settings,
      );

      expect(result.single.exercises.single.restSeconds, 150);
    });

    test('falls back to the account-wide rest default', () {
      final result = buildWatchTemplateSync(
        templateClientIds: ['push'],
        templates: [
          template('push', exercises: [const TemplateExercise(exerciseClientId: 'bench')]),
        ],
        // No per-exercise override.
        exercises: [exercise('bench')],
        settings: const UserSettings.defaults().copyWith(defaultRestSeconds: 120),
      );

      // Never null on the wire: the watch can't resolve a fallback itself.
      expect(result.single.exercises.single.restSeconds, 120);
    });

    test('carries name and targetSets through, omitting a null targetSets', () {
      final result = buildWatchTemplateSync(
        templateClientIds: ['push'],
        templates: [
          template('push', name: 'Push day', exercises: const [
            TemplateExercise(exerciseClientId: 'bench', targetSets: 4),
            TemplateExercise(exerciseClientId: 'fly'),
          ]),
        ],
        exercises: [exercise('bench', name: 'Bench Press'), exercise('fly', name: 'Cable Fly')],
        settings: settings,
      );

      expect(result.single.title, 'Push day');
      expect(result.single.toJson(), {
        'templateId': 'push',
        'title': 'Push day',
        'exercises': [
          {'exerciseId': 'bench', 'name': 'Bench Press', 'restSeconds': 90, 'targetSets': 4},
          {'exerciseId': 'fly', 'name': 'Cable Fly', 'restSeconds': 90},
        ],
      });
    });

    test('skips an id whose template no longer exists', () {
      // Deleted since it was last used — its sessions still reference it, so
      // recentlyUsedTemplateClientIds keeps handing it over.
      final result = buildWatchTemplateSync(
        templateClientIds: ['deleted', 'push'],
        templates: [
          template('push', exercises: [const TemplateExercise(exerciseClientId: 'bench')]),
        ],
        exercises: [exercise('bench')],
        settings: settings,
      );

      expect(result.map((t) => t.templateId), ['push']);
    });

    test('skips an exercise missing from the exercise list', () {
      // Most likely a delete in flight: ExerciseRepository.watchAll filters
      // those out, so the template link outlives the exercise briefly.
      final result = buildWatchTemplateSync(
        templateClientIds: ['push'],
        templates: [
          template('push', exercises: const [
            TemplateExercise(exerciseClientId: 'bench'),
            TemplateExercise(exerciseClientId: 'ghost'),
            TemplateExercise(exerciseClientId: 'fly'),
          ]),
        ],
        exercises: [exercise('bench'), exercise('fly')],
        settings: settings,
      );

      expect(result.single.exercises.map((e) => e.exerciseId), ['bench', 'fly']);
    });

    test('drops a template left with no resolvable exercises', () {
      // Starting a plan with nothing in it is a dead end on the watch; the
      // "Quick strength" card covers that case better.
      final result = buildWatchTemplateSync(
        templateClientIds: ['empty', 'push'],
        templates: [
          template('empty', exercises: const []),
          template('push', exercises: [const TemplateExercise(exerciseClientId: 'bench')]),
        ],
        exercises: [exercise('bench')],
        settings: settings,
      );

      expect(result.map((t) => t.templateId), ['push']);
    });

    test('truncates a long template instead of dropping it', () {
      final result = buildWatchTemplateSync(
        templateClientIds: ['marathon'],
        templates: [
          template('marathon', exercises: [
            for (var i = 0; i < 20; i++) TemplateExercise(exerciseClientId: 'e$i'),
          ]),
        ],
        exercises: [for (var i = 0; i < 20; i++) exercise('e$i')],
        settings: settings,
      );

      expect(result.single.exercises, hasLength(watchTemplateSyncMaxExercisesPerTemplate));
      expect(result.single.exercises.first.exerciseId, 'e0');
      expect(result.single.exercises.last.exerciseId, 'e11');
    });

    test('caps the template count even if handed more than the limit', () {
      // The selector normally caps at 5 already; this is the wire-payload
      // guard for any other caller.
      final ids = [for (var i = 0; i < 8; i++) 't$i'];
      final result = buildWatchTemplateSync(
        templateClientIds: ids,
        templates: [
          for (final id in ids)
            template(id, exercises: [const TemplateExercise(exerciseClientId: 'bench')]),
        ],
        exercises: [exercise('bench')],
        settings: settings,
      );

      expect(result, hasLength(watchTemplateSyncMaxTemplates));
      expect(result.map((t) => t.templateId), ['t0', 't1', 't2', 't3', 't4']);
    });

    test('dropped templates do not consume the cap', () {
      // Two dead ids up front must not cost two of the five slots.
      final ids = ['deleted-a', 'deleted-b', for (var i = 0; i < 6; i++) 't$i'];
      final result = buildWatchTemplateSync(
        templateClientIds: ids,
        templates: [
          for (var i = 0; i < 6; i++)
            template('t$i', exercises: [const TemplateExercise(exerciseClientId: 'bench')]),
        ],
        exercises: [exercise('bench')],
        settings: settings,
      );

      expect(result.map((t) => t.templateId), ['t0', 't1', 't2', 't3', 't4']);
    });

    test('returns nothing when there are no templates to send', () {
      final result = buildWatchTemplateSync(
        templateClientIds: const [],
        templates: const [],
        exercises: const [],
        settings: settings,
      );

      expect(result, isEmpty);
    });
  });

  group('previousSets (the watch\'s own "+1"/stepper prefill)', () {
    /// A finished session that actually logged something, unlike the shared
    /// [session] helper above (which only ever needs a templateClientId).
    WorkoutSession sessionWithSets(
      String clientId, {
      String? templateClientId,
      required DateTime startedAt,
      bool inProgress = false,
      required List<({String exerciseClientId, double weight, int reps})> sets,
    }) {
      return WorkoutSession(
        clientId: clientId,
        templateClientId: templateClientId,
        startedAt: startedAt,
        finishedAt: inProgress ? null : startedAt.add(const Duration(hours: 1)),
        exercises: const [],
        sets: [
          for (final set in sets)
            ExerciseSet(
              exerciseClientId: set.exerciseClientId,
              exerciseName: set.exerciseClientId,
              reps: set.reps,
              weight: set.weight,
              performedAt: startedAt,
            ),
        ],
      );
    }

    List<Map<String, Object?>> exercisePayloads(List<WorkoutSession> sessionsDesc) {
      final result = buildWatchTemplateSync(
        templateClientIds: ['push'],
        templates: [
          template('push', name: 'Push day', exercises: const [
            TemplateExercise(exerciseClientId: 'bench', targetSets: 3),
          ]),
        ],
        exercises: [exercise('bench', name: 'Bench Press')],
        settings: settings,
        sessionsDesc: sessionsDesc,
      );
      return [
        for (final payload in result.single.toJson()['exercises']! as List)
          payload as Map<String, Object?>,
      ];
    }

    test('sends the last session\'s sets for the exercise, heaviest first', () {
      final payloads = exercisePayloads([
        sessionWithSets(
          'newest',
          templateClientId: 'push',
          startedAt: DateTime.utc(2026, 7, 28, 9),
          sets: const [
            (exerciseClientId: 'bench', weight: 60, reps: 10),
            (exerciseClientId: 'bench', weight: 80, reps: 6),
            // A different exercise in the same session is not this
            // exercise's history.
            (exerciseClientId: 'squat', weight: 100, reps: 5),
          ],
        ),
      ]);

      expect(payloads.single['previousSets'], [
        {'weight': 80.0, 'reps': 6},
        {'weight': 60.0, 'reps': 10},
      ]);
    });

    test('prefers the last session started from the same template', () {
      final payloads = exercisePayloads([
        sessionWithSets(
          'newest-other-template',
          templateClientId: 'full-body',
          startedAt: DateTime.utc(2026, 7, 28, 9),
          sets: const [(exerciseClientId: 'bench', weight: 50, reps: 12)],
        ),
        sessionWithSets(
          'older-same-template',
          templateClientId: 'push',
          startedAt: DateTime.utc(2026, 7, 21, 9),
          sets: const [(exerciseClientId: 'bench', weight: 80, reps: 6)],
        ),
      ]);

      expect(payloads.single['previousSets'], [
        {'weight': 80.0, 'reps': 6},
      ]);
    });

    test('falls back to any template when this one has no history yet', () {
      final payloads = exercisePayloads([
        sessionWithSets(
          'other-template',
          templateClientId: 'full-body',
          startedAt: DateTime.utc(2026, 7, 28, 9),
          sets: const [(exerciseClientId: 'bench', weight: 50, reps: 12)],
        ),
      ]);

      expect(payloads.single['previousSets'], [
        {'weight': 50.0, 'reps': 12},
      ]);
    });

    test('skips a session that is still running', () {
      // Quite possibly the standalone session asking for this prefill — a
      // workout is not its own history.
      final payloads = exercisePayloads([
        sessionWithSets(
          'running-now',
          templateClientId: 'push',
          startedAt: DateTime.utc(2026, 7, 28, 9),
          inProgress: true,
          sets: const [(exerciseClientId: 'bench', weight: 20, reps: 20)],
        ),
        sessionWithSets(
          'last-finished',
          templateClientId: 'push',
          startedAt: DateTime.utc(2026, 7, 21, 9),
          sets: const [(exerciseClientId: 'bench', weight: 80, reps: 6)],
        ),
      ]);

      expect(payloads.single['previousSets'], [
        {'weight': 80.0, 'reps': 6},
      ]);
    });

    test('caps the list, keeping the heaviest sets', () {
      final payloads = buildWatchTemplateSync(
        templateClientIds: ['push'],
        templates: [
          template('push', exercises: const [TemplateExercise(exerciseClientId: 'bench')]),
        ],
        exercises: [exercise('bench')],
        settings: settings,
        maxPreviousSets: 2,
        sessionsDesc: [
          sessionWithSets(
            'newest',
            templateClientId: 'push',
            startedAt: DateTime.utc(2026, 7, 28, 9),
            sets: const [
              (exerciseClientId: 'bench', weight: 60, reps: 10),
              (exerciseClientId: 'bench', weight: 80, reps: 6),
              (exerciseClientId: 'bench', weight: 70, reps: 8),
            ],
          ),
        ],
      ).single.exercises;

      expect(
        [for (final set in payloads.single.previousSets) (set.weight, set.reps)],
        [(80.0, 6), (70.0, 8)],
      );
    });

    test('omits the key entirely when the exercise has no history', () {
      expect(exercisePayloads(const []).single.containsKey('previousSets'), isFalse);
    });
  });

  group('watchTemplateSyncPayloadProvider', () {
    /// Passing null for any of the three lists leaves that source loading —
    /// its stream never emits. [settle] awaits exactly the sources that *do*
    /// emit, so a loading case is asserted with the others genuinely
    /// resolved, rather than passing trivially because nothing had arrived
    /// yet.
    ({ProviderContainer container, Future<void> Function() settle}) buildContainer({
      UserSettings userSettings = const UserSettings.defaults(),
      List<WorkoutSession>? sessions = const [],
      List<WorkoutTemplate>? templates = const [],
      List<Exercise>? exercises = const [],
    }) {
      final container = ProviderContainer(
        overrides: [
          settingsControllerProvider.overrideWith(() => _FakeSettingsController(userSettings)),
          workoutSessionControllerProvider.overrideWith(() => _FakeSessionController(sessions)),
          workoutTemplateControllerProvider.overrideWith(() => _FakeTemplateController(templates)),
          exerciseControllerProvider.overrideWith(() => _FakeExerciseController(exercises)),
        ],
      );
      addTearDown(container.dispose);

      Future<void> settle() async {
        await container.listen(settingsControllerProvider.future, (_, __) {}).read();
        if (sessions != null) {
          await container.listen(workoutSessionControllerProvider.future, (_, __) {}).read();
        }
        if (templates != null) {
          await container.listen(workoutTemplateControllerProvider.future, (_, __) {}).read();
        }
        if (exercises != null) {
          await container.listen(exerciseControllerProvider.future, (_, __) {}).read();
        }
      }

      return (container: container, settle: settle);
    }

    test('builds the payload from all four sources', () async {
      final harness = buildContainer(
        sessions: [session('push'), session('legs')],
        templates: [
          template('push', name: 'Push day', exercises: const [
            TemplateExercise(exerciseClientId: 'bench', targetSets: 4),
          ]),
          template('legs', name: 'Leg day', exercises: const [
            TemplateExercise(exerciseClientId: 'squat'),
          ]),
        ],
        exercises: [
          exercise('bench', name: 'Bench Press', defaultRestSeconds: 150),
          exercise('squat', name: 'Back Squat'),
        ],
      );
      await harness.settle();

      final result = harness.container.read(watchTemplateSyncPayloadProvider)!;

      // Recency order from the sessions, names/rest from the exercises.
      expect(result.map((t) => t.templateId), ['push', 'legs']);
      expect(result.first.exercises.single.name, 'Bench Press');
      expect(result.first.exercises.single.restSeconds, 150);
      expect(result.last.exercises.single.restSeconds, 90);
    });

    test('sends nothing while watchWorkoutEnabled is off', () async {
      // The single gate for all watch traffic — an empty payload also tells
      // the watch to clear whatever it still holds.
      final harness = buildContainer(
        userSettings: const UserSettings.defaults().copyWith(watchWorkoutEnabled: false),
        sessions: [session('push')],
        templates: [
          template('push', exercises: [const TemplateExercise(exerciseClientId: 'bench')]),
        ],
        exercises: [exercise('bench')],
      );
      await harness.settle();

      expect(harness.container.read(watchTemplateSyncPayloadProvider), isEmpty);
    });

    test('is null — not empty — while any source is still loading', () async {
      // Null keeps the watch's existing cache; an empty list would order it
      // wiped, which at cold start would throw away a good cache.
      for (final harness in [
        buildContainer(sessions: null),
        buildContainer(templates: null),
        buildContainer(exercises: null),
      ]) {
        await harness.settle();
        expect(harness.container.read(watchTemplateSyncPayloadProvider), isNull);
      }
    });

    test('is empty — not null — when the user has no templates at all', () async {
      // A real answer: there is nothing to offer, so the watch should hold
      // nothing either.
      final harness = buildContainer();
      await harness.settle();

      expect(harness.container.read(watchTemplateSyncPayloadProvider), isEmpty);
    });

    test('drops a template that was deleted but is still in session history', () async {
      final harness = buildContainer(
        sessions: [session('deleted'), session('push')],
        templates: [
          template('push', exercises: [const TemplateExercise(exerciseClientId: 'bench')]),
        ],
        exercises: [exercise('bench')],
      );
      await harness.settle();

      expect(
        harness.container.read(watchTemplateSyncPayloadProvider)!.map((t) => t.templateId),
        ['push'],
      );
    });
  });
}
