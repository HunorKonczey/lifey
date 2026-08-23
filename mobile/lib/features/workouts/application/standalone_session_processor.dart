import 'package:drift/drift.dart' show Value;
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/health/health_service.dart';
import '../../../core/watch/watch_workout_service.dart';
import '../../settings/domain/user_settings.dart';
import '../../../l10n/app_localizations.dart';
import '../data/exercise_repository.dart';
import '../data/workout_session_repository.dart';
import '../data/workout_template_repository.dart';
import '../domain/workout_template.dart';
import 'watch_session_merge.dart';

/// Matches [HealthService.writeStrengthWorkoutAndGetId]'s signature, narrowed
/// to just that one method — like [WidgetSnapshotWriter]'s save/update-widget
/// callbacks — so a test can inject a fixed result instead of fighting
/// `HealthService`'s internal `Platform.isAndroid` gate, which always
/// no-ops on a non-Android test host regardless of what's faked underneath.
typedef WriteHealthWorkout = Future<String?> Function({
  required DateTime start,
  required DateTime end,
  double? activeCalories,
  String? title,
});

/// Turns a finished standalone (phone-less) watch session into a normal,
/// already-*closed* [WorkoutSession] — the counterpart of
/// [WorkoutResumePrompt]'s [WatchWorkoutSummary] handling, for the F6
/// standalone flow (docs/watch/44-watch-f6-standalone-plan.md §1, §6/3).
///
/// Deliberately plain-constructor-injected (no [Ref], no `BuildContext`),
/// unlike [WorkoutResumePrompt] itself — so it's directly unit-testable with
/// fakes, the way [WidgetSnapshotWriter] is.
class StandaloneSessionProcessor {
  StandaloneSessionProcessor({
    required WorkoutSessionRepository sessionRepository,
    required ExerciseRepository exerciseRepository,
    required WorkoutTemplateRepository templateRepository,
    required WatchWorkoutService watchService,
    required WriteHealthWorkout writeHealthWorkout,
  })  : _sessionRepository = sessionRepository,
        _exerciseRepository = exerciseRepository,
        _templateRepository = templateRepository,
        _watchService = watchService,
        _writeHealthWorkout = writeHealthWorkout;

  final WorkoutSessionRepository _sessionRepository;
  final ExerciseRepository _exerciseRepository;
  final WorkoutTemplateRepository _templateRepository;
  final WatchWorkoutService _watchService;
  final WriteHealthWorkout _writeHealthWorkout;

  /// [language] resolves the session's generic exercise/title text
  /// (docs/watch/44-watch-f6-standalone-plan.md D-F6.3) — passed in rather
  /// than read internally so this stays a plain class (mirrors
  /// [WidgetSnapshotWriter.write]'s `settings` parameter).
  ///
  /// Three-way idempotent branch on [WorkoutSessionRepository
  /// .isFinishedByClientId], now that a session can arrive here having
  /// already been adopted mid-workout (live bridging — see
  /// [processAdoption]):
  /// - doesn't exist yet → [_createSession] (the original F6a/F6b path,
  ///   unchanged: creates an already-*closed* session).
  /// - exists but not finished (was adopted, this is it finishing) →
  ///   [_finishAdoptedSession] updates the existing row instead of creating
  ///   a duplicate.
  /// - exists and already finished → [_enrichFinishedSession]. Usually a
  ///   retried, already-processed delivery (the watch's own
  ///   retry-until-acked, docs/watch/44-watch-f6-standalone-plan.md §4.2,
  ///   D-F6.2) that changes nothing — but *not always*, which is why this
  ///   branch can't simply ack and walk away any more; see that method.
  Future<void> process(WatchStandaloneSession event, {required LanguagePreference language}) {
    return _serialized(() async {
      if (event.kind == 'CARDIO') {
        // No exercises/sets to resolve, adopt or merge for this branch
        // (docs/cardio/55-cardio-watch-plan.md §5/2-3) — see [_processCardio].
        await _processCardio(event);
      } else {
        final alreadyFinished =
            await _sessionRepository.isFinishedByClientId(event.standaloneSessionId);
        if (alreadyFinished == null) {
          // A create that loses to a row appearing underneath it finishes that
          // row instead — see [_createOrElse].
          await _createOrElse(
            () => _createSession(event, language: language),
            () => _finishAdoptedSession(event, language: language),
          );
        } else if (alreadyFinished == false) {
          await _finishAdoptedSession(event, language: language);
        } else {
          await _enrichFinishedSession(event, language: language);
        }
      }
      await _watchService.ackStandaloneSession(event.standaloneSessionId);
    });
  }

  /// The CARDIO counterpart of the three-way STRENGTH branch above
  /// (docs/cardio/55-cardio-watch-plan.md §5, W-1; D-C5.4 — this branch
  /// exists before any native watch build can send a CARDIO payload). There
  /// is no create-vs-finish-vs-enrich distinction to make here: a cardio
  /// session has no set list to adopt mid-workout or merge with phone-side
  /// edits ([watch_session_merge.dart] never runs for it), so every
  /// delivery — including a retried one, D-F6.2 — carries the session's
  /// complete, final state. Writing it is always a plain, idempotent full
  /// replace; an already-finished row means this exact delivery was already
  /// applied, so there's nothing left to write.
  Future<void> _processCardio(WatchStandaloneSession event) async {
    final alreadyFinished =
        await _sessionRepository.isFinishedByClientId(event.standaloneSessionId);
    if (alreadyFinished == true) {
      await _enrichFinishedCardioSession(event);
      return;
    }
    await _createOrElse(
      () => _createCardioSession(event),
      () => _updateCardioSession(event),
    );
  }

  /// The phone finished this session itself before the watch's payload
  /// arrived — which is now the *normal* ending for a watch-started cardio
  /// session the phone joined ([_adoptCardio]): the watch's End button asks
  /// the phone to close its own session first, so by the time the closing
  /// payload lands the row is already finished, with the phone's own GPS
  /// route, distance and moving time on it.
  ///
  /// Those stay untouched — a phone-measured value always wins
  /// (docs/cardio/51-cardio-overview-plan.md R8) — but everything the phone
  /// has *no* answer for is worth taking: the watch's wrist heart rate and
  /// active calories, which no cardio screen writes at finish, plus any
  /// cardio field the row is missing ([CardioMetrics.mergedWithWatchMeasurement],
  /// the same merge the phone-mastered `WatchWorkoutSummary` path already
  /// uses). The STRENGTH counterpart of this is [_enrichFinishedSession].
  Future<void> _enrichFinishedCardioSession(WatchStandaloneSession event) async {
    final stored = await _sessionRepository.findByClientId(event.standaloneSessionId);
    if (stored == null || stored.startedAt == null) return;

    final activeCalories = stored.activeCalories ?? event.activeCalories;
    final averageHeartRate = stored.averageHeartRate ?? event.averageHeartRate;
    final healthWorkoutId = stored.healthWorkoutId ?? event.healthWorkoutId;
    final rpe = stored.rpe ?? event.rpe;
    final watchCardio = event.cardio;
    final cardio = watchCardio == null
        ? stored.cardio
        : (stored.cardio?.mergedWithWatchMeasurement(watchCardio) ?? watchCardio);

    // Same "write nothing when it would change nothing" rule
    // [_enrichFinishedSession] follows, so the watch's retry-until-acked
    // deliveries stay no-ops. `CardioMetrics` has no value equality, so the
    // merge is judged field by field — over exactly the fields the watch's
    // closing block can carry (`WorkoutManager.cardioSummaryPayload()` /
    // `ExerciseService.cardioSummaryJson()`), not the whole class.
    final gainsCardio = watchCardio != null &&
        (stored.cardio == null ||
            _fills(stored.cardio!.distanceMeters, watchCardio.distanceMeters) ||
            _fills(stored.cardio!.elevationGainMeters, watchCardio.elevationGainMeters) ||
            _fills(stored.cardio!.elevationLossMeters, watchCardio.elevationLossMeters) ||
            _fills(stored.cardio!.avgCadence, watchCardio.avgCadence) ||
            _fills(stored.cardio!.maxCadence, watchCardio.maxCadence));
    final unchanged = !gainsCardio &&
        activeCalories == stored.activeCalories &&
        averageHeartRate == stored.averageHeartRate &&
        healthWorkoutId == stored.healthWorkoutId &&
        rpe == stored.rpe;
    if (unchanged) return;

    await _sessionRepository.update(
      event.standaloneSessionId,
      startedAt: stored.startedAt!,
      finishedAt: stored.finishedAt,
      exercises: const [],
      sets: const [],
      activeCalories: Value(activeCalories),
      averageHeartRate: Value(averageHeartRate),
      healthWorkoutId: Value(healthWorkoutId),
      rpe: Value(rpe),
      cardio: cardio == null ? const Value.absent() : Value(cardio),
    );
  }

  /// Whether [theirs] would fill a blank [mine] — the one direction a merge
  /// is allowed to move a value (R8).
  static bool _fills(double? mine, double? theirs) => mine == null && theirs != null;

  Future<void> _createCardioSession(WatchStandaloneSession event) {
    final startedAt = DateTime.fromMillisecondsSinceEpoch(event.startedAtEpochMs, isUtc: true);
    final endedAt = DateTime.fromMillisecondsSinceEpoch(event.endedAtEpochMs, isUtc: true);
    return _sessionRepository.create(
      clientId: event.standaloneSessionId,
      startedAt: startedAt,
      finishedAt: endedAt,
      // No template for a cardio session (docs/cardio/
      // 51-cardio-overview-plan.md §5) — templateClientId/templateName stay
      // null, same as [_resolveExercisesAndSets]'s template-less path.
      exercises: const [],
      sets: const [],
      activeCalories: event.activeCalories,
      averageHeartRate: event.averageHeartRate,
      // Unlike the STRENGTH branch, this never falls back to
      // [_writeHealthWorkout] — that callback is typed for
      // [HealthService.writeStrengthWorkoutAndGetId] specifically, and there
      // is no cardio equivalent yet. Writing a "traditional strength
      // training" record for a run would be a wrong, silent mislabel, so
      // this only ever carries through what the event already has (watchOS's
      // real HKWorkout uuid, D-F6.5) and otherwise leaves it null.
      healthWorkoutId: event.healthWorkoutId,
      rpe: event.rpe,
      sessionKind: 'CARDIO',
      activityType: event.activityType,
      movingSeconds: event.movingSeconds ?? endedAt.difference(startedAt).inSeconds,
      cardio: event.cardio,
    );
  }

  /// The row exists but isn't finished — either an adoption created it
  /// ([_adoptCardio]) and the phone never closed it itself, or a pre-cardio
  /// build's strength mirror row is being converted in place.
  ///
  /// [existing] is read for one reason: its `cardio` may already hold what
  /// the *phone* measured live while the session ran (`CardioSessionScreen`
  /// persists metrics during the workout), and the watch's block must fill
  /// that in rather than replace it — R8 again, same rule
  /// [_enrichFinishedCardioSession] follows. The scalar columns are the
  /// watch's: it is the device that actually closed this session, so its
  /// end time (and the duration derived from it) is the true one.
  Future<void> _updateCardioSession(WatchStandaloneSession event) async {
    final startedAt = DateTime.fromMillisecondsSinceEpoch(event.startedAtEpochMs, isUtc: true);
    final endedAt = DateTime.fromMillisecondsSinceEpoch(event.endedAtEpochMs, isUtc: true);
    final existing = await _sessionRepository.findByClientId(event.standaloneSessionId);
    final watchCardio = event.cardio;
    final mergedCardio = watchCardio == null
        ? existing?.cardio
        : (existing?.cardio?.mergedWithWatchMeasurement(watchCardio) ?? watchCardio);
    await _sessionRepository.update(
      event.standaloneSessionId,
      startedAt: startedAt,
      finishedAt: endedAt,
      exercises: const [],
      sets: const [],
      activeCalories: Value(event.activeCalories),
      averageHeartRate: Value(event.averageHeartRate),
      healthWorkoutId: Value(event.healthWorkoutId),
      rpe: Value(event.rpe),
      sessionKind: const Value('CARDIO'),
      activityType: Value(event.activityType),
      movingSeconds: Value(event.movingSeconds ?? endedAt.difference(startedAt).inSeconds),
      cardio: Value(mergedCardio),
    );
  }

  /// The live-bridging counterpart of [process]: a watch-started session
  /// that is still *running*, sent as soon as the phone is (or becomes)
  /// reachable so the phone can mirror it live instead of only importing it
  /// once it ends. Idempotent the same way [process] is — an already-adopted
  /// (or already-finished, if this raced behind the final event) session is
  /// left alone, only re-acked — an already-finished session's set list is
  /// authoritative and must not be reopened by a stale resend.
  ///
  /// The watch resends this snapshot after every set it logs, not just at
  /// the initial handshake (`WorkoutManager.sendAdoptionRequestIfNeeded`) —
  /// so a session that's already adopted and still running gets its set
  /// list *refreshed* here too, which is what keeps the phone's mirror in
  /// sync live instead of only catching up once the workout ends.
  Future<void> processAdoption(
    WatchStandaloneAdoption event, {
    required LanguagePreference language,
  }) {
    return _serialized(() async {
      // A **cardio** session is adopted through a completely different door
      // ([_adoptCardio]): everything below is strength-shaped — resolve the
      // template's exercises, mirror a set list — and running a walk through
      // it is exactly what produced a template-less *strength* session on
      // the phone ("Quick strength") for a workout started as Walking.
      if (event.isCardio) {
        await _adoptCardio(event);
        await _watchService.ackAdoption(event.standaloneSessionId);
        return;
      }
      final alreadyFinished =
          await _sessionRepository.isFinishedByClientId(event.standaloneSessionId);
      if (alreadyFinished == null) {
        await _createOrElse(
          () => _createRunningSession(event, language: language),
          () => _refreshRunningSession(event, language: language),
        );
      } else if (alreadyFinished == false) {
        await _refreshRunningSession(event, language: language);
      }
      await _watchService.ackAdoption(event.standaloneSessionId);
    });
  }

  /// Gives a watch-started **cardio** session its live row on the phone, so
  /// the workout runs on both devices instead of only surfacing when it ends
  /// (docs/cardio/55-cardio-watch-plan.md §5). The row is shaped exactly like
  /// one `createCardioSession` (the phone's own quick-start) would make —
  /// same kind/activityType, `movingSeconds: 0` and a `movingSinceEpochMs`
  /// checkpoint at the watch's start time — because that is precisely what
  /// makes `CardioSessionScreen` open on it and keep going from there, rather
  /// than needing a second, watch-specific screen mode.
  ///
  /// From that point the phone is the one measuring GPS, and its numbers win
  /// at the end (R8) — see [_enrichFinishedCardioSession].
  ///
  /// **Create-only.** The watch resends this snapshot on every reconnect, and
  /// a resend has nothing to add: a cardio session carries no set list to
  /// refresh (that's the whole reason [_refreshRunningSession] exists for
  /// strength), and rewriting `startedAt`/`movingSinceEpochMs` under a
  /// running screen would jerk its clock. An already-finished row is left
  /// alone too — a snapshot that lost a race with the session's own ending
  /// must not reopen it.
  Future<void> _adoptCardio(WatchStandaloneAdoption event) async {
    final alreadyFinished =
        await _sessionRepository.isFinishedByClientId(event.standaloneSessionId);
    if (alreadyFinished != null) return;
    await _createOrElse(() => _createAdoptedCardioSession(event), () async {});
  }

  Future<void> _createAdoptedCardioSession(WatchStandaloneAdoption event) {
    final startedAt = DateTime.fromMillisecondsSinceEpoch(event.startedAtEpochMs, isUtc: true);
    return _sessionRepository.create(
      clientId: event.standaloneSessionId,
      startedAt: startedAt,
      // No template, no exercises, no sets — a cardio session has none
      // (docs/cardio/51-cardio-overview-plan.md §5), which is also why this
      // needs no `_resolveExercisesAndSets` pass at all.
      exercises: const [],
      sets: const [],
      // Whatever the watch has measured so far; the phone's own screen takes
      // over from here and the closing payload reconciles the rest.
      activeCalories: event.activeCalories,
      averageHeartRate: event.averageHeartRate,
      sessionKind: 'CARDIO',
      activityType: event.activityType,
      movingSeconds: 0,
      movingSinceEpochMs: startedAt.millisecondsSinceEpoch,
    );
  }

  /// Tail of the queue every [process]/[processAdoption] call runs on.
  Future<void> _queue = Future<void>.value();

  /// Runs [create], falling back to [update] if the row turned out to exist
  /// after all — the session's clientId is its primary key, so that surfaces
  /// as a failed insert rather than as a "no rows affected".
  ///
  /// Belt to [_serialized]'s braces. That queue is what actually prevents two
  /// deliveries from racing, but the fallback is what keeps a lost race from
  /// costing the *whole* delivery: without it the create throws, the ack never
  /// runs, and a finished workout stays on the phone as a running one until
  /// the watch happens to retry. A create is never the only correct answer for
  /// an event whose row already exists — updating it is.
  Future<void> _createOrElse(
    Future<void> Function() create,
    Future<void> Function() update,
  ) async {
    try {
      await create();
    } catch (_) {
      await update();
    }
  }

  /// Runs [action] after every call already queued here has finished.
  ///
  /// Both entry points are "look at the row, then write it" — safe one at a
  /// time, but not concurrently, and concurrently is exactly how they arrive.
  /// The watch's deliveries are *queued* transports: while the phone app isn't
  /// running they pile up (`WatchEventBuffer` on iOS), and the moment Dart
  /// starts listening the whole backlog is emitted in one go. `Stream.listen`
  /// doesn't await an async handler, so a session's adoption and its
  /// completion would then run at the same time — both seeing "this session
  /// doesn't exist yet", both taking the create branch, and the second one
  /// dying on the primary-key conflict *before* it could ack. The visible
  /// result was a workout that had already ended on the watch sitting on the
  /// phone as still running, until some later retry happened to arrive alone.
  ///
  /// Serializing also fixes the ordering: the completion now always sees the
  /// row the adoption created, so it finishes it instead of trying to create
  /// it again.
  Future<void> _serialized(Future<void> Function() action) {
    final queued = _queue.then((_) => action());
    // Keep the chain alive after a failure — a single bad payload must not
    // wedge every later delivery behind a rejected future.
    _queue = queued.catchError((_) {});
    return queued;
  }

  Future<void> _createSession(
    WatchStandaloneSession event, {
    required LanguagePreference language,
  }) async {
    final resolved = await _resolveExercisesAndSets(
      sessionClientId: event.standaloneSessionId,
      templateId: event.templateId,
      sets: event.sets,
      language: language,
    );
    final startedAt = DateTime.fromMillisecondsSinceEpoch(event.startedAtEpochMs, isUtc: true);
    final endedAt = DateTime.fromMillisecondsSinceEpoch(event.endedAtEpochMs, isUtc: true);

    // Android fills this in from the just-written Health Connect record;
    // iOS already sends a real HKWorkout uuid on the wire (D-F6.5).
    final healthWorkoutId = event.healthWorkoutId ??
        await _writeHealthWorkout(
          start: startedAt,
          end: endedAt,
          activeCalories: event.activeCalories,
          title: resolved.title,
        );

    await _sessionRepository.create(
      clientId: event.standaloneSessionId,
      startedAt: startedAt,
      finishedAt: endedAt,
      exercises: resolved.exercises,
      sets: resolved.sets,
      activeCalories: event.activeCalories,
      averageHeartRate: event.averageHeartRate,
      healthWorkoutId: healthWorkoutId,
      templateClientId: resolved.template?.clientId,
      templateName: resolved.title,
      rpe: event.rpe,
    );
  }

  /// Creates the **running** mirror row for a just-adopted watch session —
  /// same exercise/set resolution as [_createSession], but `finishedAt` is
  /// left null and there's no `rpe`/`healthWorkoutId` yet (the workout isn't
  /// over; those only exist once the final [WatchStandaloneSession] lands
  /// and [_finishAdoptedSession] runs).
  Future<void> _createRunningSession(
    WatchStandaloneAdoption event, {
    required LanguagePreference language,
  }) async {
    final resolved = await _resolveExercisesAndSets(
      sessionClientId: event.standaloneSessionId,
      templateId: event.templateId,
      sets: event.sets,
      language: language,
    );
    final startedAt = DateTime.fromMillisecondsSinceEpoch(event.startedAtEpochMs, isUtc: true);

    await _sessionRepository.create(
      clientId: event.standaloneSessionId,
      startedAt: startedAt,
      finishedAt: null,
      exercises: resolved.exercises,
      sets: resolved.sets,
      activeCalories: event.activeCalories,
      averageHeartRate: event.averageHeartRate,
      templateClientId: resolved.template?.clientId,
      templateName: resolved.title,
    );
  }

  /// Refreshes an already-adopted running mirror row's set list — called
  /// every time the watch resends its adoption snapshot after logging a new
  /// set (see [processAdoption]'s doc comment), so the phone's copy doesn't
  /// go stale until the workout ends. Still a running session (`finishedAt`
  /// stays null); `rpe`/`healthWorkoutId` are left untouched (`Value.absent`)
  /// since [WatchStandaloneAdoption] doesn't carry them — only the final
  /// [WatchStandaloneSession] does, via [_finishAdoptedSession].
  Future<void> _refreshRunningSession(
    WatchStandaloneAdoption event, {
    required LanguagePreference language,
  }) async {
    final resolved = await _resolveExercisesAndSets(
      sessionClientId: event.standaloneSessionId,
      templateId: event.templateId,
      sets: event.sets,
      language: language,
    );
    final startedAt = DateTime.fromMillisecondsSinceEpoch(event.startedAtEpochMs, isUtc: true);
    final merged = await _mergeWithStoredContent(event.standaloneSessionId, resolved);

    await _sessionRepository.update(
      event.standaloneSessionId,
      startedAt: startedAt,
      finishedAt: null,
      exercises: merged.exercises,
      sets: merged.sets,
      activeCalories: Value(event.activeCalories),
      averageHeartRate: Value(event.averageHeartRate),
    );
  }

  /// Folds whatever is already on the session's row into the watch's version of
  /// it — see [mergeWatchSessionContent] for the rules and for why a straight
  /// replace was wrong. A row that has vanished (deleted between the event
  /// arriving and this write) leaves the watch's version untouched.
  Future<MergedWatchSessionContent> _mergeWithStoredContent(
    String sessionClientId,
    ({
      WorkoutTemplate? template,
      List<PlannedExerciseInput> exercises,
      List<ExerciseSetInput> sets,
      String title,
    }) resolved,
  ) async {
    final stored = await _sessionRepository.findByClientId(sessionClientId);
    if (stored == null) {
      return MergedWatchSessionContent(exercises: resolved.exercises, sets: resolved.sets);
    }
    return mergeWatchSessionContent(
      existingExercises: stored.exercises,
      existingSets: stored.sets,
      watchExercises: resolved.exercises,
      watchSets: resolved.sets,
    );
  }

  /// Turns an already-adopted running mirror row into a closed session — the
  /// [WorkoutSessionRepository.update] counterpart of [_createSession]'s
  /// `.create`, called once the final [WatchStandaloneSession] arrives for a
  /// [standaloneSessionId] that [_createRunningSession] already wrote. Reuses
  /// the exact same exercise/set resolution and re-writes the *complete*
  /// exercises/sets list (matching [update]'s own full-replace contract) —
  /// the running mirror's own resolution could differ slightly if, say, a
  /// template changed mid-workout, so this doesn't try to diff/append.
  Future<void> _finishAdoptedSession(
    WatchStandaloneSession event, {
    required LanguagePreference language,
  }) async {
    final resolved = await _resolveExercisesAndSets(
      sessionClientId: event.standaloneSessionId,
      templateId: event.templateId,
      sets: event.sets,
      language: language,
    );
    final startedAt = DateTime.fromMillisecondsSinceEpoch(event.startedAtEpochMs, isUtc: true);
    final endedAt = DateTime.fromMillisecondsSinceEpoch(event.endedAtEpochMs, isUtc: true);
    // Merged for the same reason the running refresh is: this is the last
    // write the session gets, so a phone-logged set that isn't kept here is
    // gone for good — including one logged after the watch's final tap, which
    // no earlier refresh ever saw.
    final merged = await _mergeWithStoredContent(event.standaloneSessionId, resolved);

    final healthWorkoutId = event.healthWorkoutId ??
        await _writeHealthWorkout(
          start: startedAt,
          end: endedAt,
          activeCalories: event.activeCalories,
          title: resolved.title,
        );

    await _sessionRepository.update(
      event.standaloneSessionId,
      startedAt: startedAt,
      finishedAt: endedAt,
      exercises: merged.exercises,
      sets: merged.sets,
      activeCalories: Value(event.activeCalories),
      averageHeartRate: Value(event.averageHeartRate),
      healthWorkoutId: Value(healthWorkoutId),
      rpe: Value(event.rpe),
    );
  }

  /// Applies what the watch's final payload carries to a session that is
  /// **already closed** — without reopening it or moving the times the phone
  /// wrote.
  ///
  /// This branch used to ack and write nothing, on the assumption that an
  /// already-finished row means "I've seen this delivery before". That holds
  /// for the watch's own retries, but not for the case that closes the session
  /// from the *other* side: ending a watch-started workout on the **phone**
  /// stamps `finishedAt` immediately, and the watch's final payload — the only
  /// thing that ever carries `activeCalories`, `averageHeartRate` and the
  /// HealthKit workout id — then arrived to a finished row and was dropped on
  /// the floor. The session ended up with no health metrics at all and no ⌚
  /// badge anywhere (that badge is exactly `healthWorkoutId != null`, see
  /// [WorkoutSession.enrichedFromWatch]), which is what the user sees as "the
  /// data never came back from the watch".
  ///
  /// What the phone already has wins, field by field: it closed the session,
  /// so its `finishedAt`, its rating and any health workout it was already
  /// paired with are the deliberate values (the same rule
  /// `WorkoutResumePrompt` applies to a `WatchWorkoutSummary`). The payload
  /// only fills in blanks — and its sets are merged in, so a set the watch
  /// logged but never managed to deliver before the phone ended the workout
  /// still lands.
  ///
  /// Writes nothing when it would change nothing, so the watch's
  /// retry-until-acked deliveries stay the no-ops they were.
  Future<void> _enrichFinishedSession(
    WatchStandaloneSession event, {
    required LanguagePreference language,
  }) async {
    final stored = await _sessionRepository.findByClientId(event.standaloneSessionId);
    if (stored == null || stored.startedAt == null) return;

    final resolved = await _resolveExercisesAndSets(
      sessionClientId: event.standaloneSessionId,
      templateId: event.templateId,
      sets: event.sets,
      language: language,
    );
    final merged = mergeWatchSessionContent(
      existingExercises: stored.exercises,
      existingSets: stored.sets,
      watchExercises: resolved.exercises,
      watchSets: resolved.sets,
    );

    final activeCalories = stored.activeCalories ?? event.activeCalories;
    final averageHeartRate = stored.averageHeartRate ?? event.averageHeartRate;
    final rpe = stored.rpe ?? event.rpe;
    // Android's watch never writes to Health Connect — the phone does, once it
    // has the metrics (D-F6.5). Only worth doing if this session isn't paired
    // with a health workout yet.
    final healthWorkoutId = stored.healthWorkoutId ??
        event.healthWorkoutId ??
        await _writeHealthWorkout(
          start: stored.startedAt!,
          end: stored.finishedAt ?? DateTime.now(),
          activeCalories: activeCalories,
          title: stored.templateName ?? resolved.title,
        );

    final unchanged = merged.sets.length == stored.sets.length &&
        merged.exercises.length == stored.exercises.length &&
        activeCalories == stored.activeCalories &&
        averageHeartRate == stored.averageHeartRate &&
        rpe == stored.rpe &&
        healthWorkoutId == stored.healthWorkoutId;
    if (unchanged) return;

    await _sessionRepository.update(
      event.standaloneSessionId,
      startedAt: stored.startedAt!,
      finishedAt: stored.finishedAt,
      exercises: merged.exercises,
      sets: merged.sets,
      activeCalories: Value(activeCalories),
      averageHeartRate: Value(averageHeartRate),
      healthWorkoutId: Value(healthWorkoutId),
      rpe: Value(rpe),
    );
  }

  /// The exercise/set resolution shared by [_createSession],
  /// [_createRunningSession] and [_finishAdoptedSession] — [templateId]/
  /// [sets] are the fields common to both [WatchStandaloneSession] and
  /// [WatchStandaloneAdoption] (there's no shared base class, so this takes
  /// the fields directly rather than the whole event).
  Future<
      ({
        WorkoutTemplate? template,
        List<PlannedExerciseInput> exercises,
        List<ExerciseSetInput> sets,
        String title,
      })> _resolveExercisesAndSets({
    required String sessionClientId,
    required String? templateId,
    required List<WatchStandaloneSet> sets,
    required LanguagePreference language,
  }) async {
    final genericTitle = lookupAppLocalizations(_localeFor(language)).standaloneSessionTitle;

    // Resolves to the real, synced template (docs/watch/
    // 49-watch-f6b-template-sync-plan.md D-F6b.5, T5) whenever the watch
    // sent one — F6a's `templateId == null` path (and this session's own
    // fallback below) are unaffected, this is purely additive. `null` here
    // covers every unresolvable case identically: no `templateId` at all, a
    // template deleted since the watch cached it, or (via
    // [_resolvesWithinTemplate] below) an out-of-range `exerciseIndex` — all
    // of these fall all the way back to the F6a generic-exercise behavior,
    // never partially.
    final template = templateId == null ? null : await _templateRepository.findByClientId(templateId);

    // F6c: the watch now names the exercise by **clientId** where it can
    // (docs/watch/50-watch-f6c-session-plan-sync-plan.md) — the id wins over
    // the position, because the exercise list it logged against is the live
    // session's and may have gained or lost entries since. Checked against
    // this device's own rows first: the id came from here, but the exercise
    // can have been deleted since, and a dangling reference has to fall back
    // like any other unresolvable set rather than write an invisible one.
    final knownExerciseIds = await _exerciseRepository.existingClientIds({
      for (final set in sets)
        if (set.exerciseId != null) set.exerciseId!,
    });
    String? resolvedExerciseId(WatchStandaloneSet set) {
      final exerciseId = set.exerciseId;
      if (exerciseId != null && knownExerciseIds.contains(exerciseId)) return exerciseId;
      if (_resolvesWithinTemplate(set.exerciseIndex, template)) {
        return template!.exercises[set.exerciseIndex!].exerciseClientId;
      }
      return null;
    }

    // Distinct, in the order the sets first mention them — the fallback
    // exercise list for a session with no template (below).
    final resolvedIds = <String>[];
    for (final set in sets) {
      final exerciseId = resolvedExerciseId(set);
      if (exerciseId != null && !resolvedIds.contains(exerciseId)) resolvedIds.add(exerciseId);
    }

    // Computed once, before any exercise is created — a session can be a
    // *mix* of resolved and unresolved sets (e.g. the plan shrank after the
    // watch cached it), so the generic exercise is only fetched/created when
    // at least one set actually needs it, not unconditionally the way F6a's
    // single-exercise path always did. A template-less session needs it too
    // when nothing resolved at all: that's F6a's original Quick strength case,
    // which has no other exercise to point at.
    final needsGenericExercise = sets.any((set) => resolvedExerciseId(set) == null) ||
        (template == null && resolvedIds.isEmpty);
    final genericExerciseClientId =
        needsGenericExercise ? await _exerciseRepository.getOrCreateByName(genericTitle) : null;

    final title = template?.name ?? genericTitle;

    // Which exercise each set counts against, resolved once up front: both
    // the `sets` list below and [_resolveWeights]'s per-exercise fallback
    // need it, and it must be the same answer for both.
    final setExerciseIds = [
      for (final set in sets) resolvedExerciseId(set) ?? genericExerciseClientId!,
    ];
    final weights = await _resolveWeights(
      sessionClientId: sessionClientId,
      templateClientId: template?.clientId,
      sets: sets,
      setExerciseIds: setExerciseIds,
    );

    return (
      template: template,
      // The template's *full* exercise list, not just the ones a set was
      // actually logged against — so the session looks the same on the
      // phone as the plan it was started from (§5/T5). `WorkoutSessionRepository
      // .create`/`templateClientId`/`templateName` already existed before F6b
      // (the normal in-app "start from a template" flow); F6a simply never
      // populated them.
      exercises: template != null
          ? [
              for (final exercise in template.exercises)
                PlannedExerciseInput(
                  exerciseClientId: exercise.exerciseClientId,
                  targetSets: exercise.targetSets,
                ),
            ]
          // No template: whatever the sets themselves resolved to (F6c — a
          // Quick strength session the phone has since added exercises to
          // logs into real ones by id), and the generic placeholder when
          // there's genuinely nothing else, which is F6a's original shape.
          : resolvedIds.isEmpty
              ? [PlannedExerciseInput(exerciseClientId: genericExerciseClientId!)]
              : [
                  for (final exerciseClientId in resolvedIds)
                    PlannedExerciseInput(exerciseClientId: exerciseClientId),
                ],
      sets: [
        for (var i = 0; i < sets.length; i++)
          ExerciseSetInput(
            exerciseClientId: setExerciseIds[i],
            reps: sets[i].reps,
            weight: weights[i],
            performedAt: DateTime.fromMillisecondsSinceEpoch(sets[i].loggedAtEpochMs, isUtc: true),
          ),
      ],
      title: title,
    );
  }

  /// The weight to persist for each of [sets], positionally.
  ///
  /// A plain watch "+1" tap carries **no** weight — only the adjust stepper
  /// sends one (docs/watch/48-watch-f5b-set-adjust-plan.md §4.1) — and
  /// `exercise_sets.weight` is NOT NULL, so those sets used to land as a
  /// literal 0 kg even when the exercise obviously has a working weight.
  /// This mirrors what the phone already does for the same tap on a
  /// phone-mastered session (`LogSessionScreen._handleAddSet`'s
  /// `prefillFromPrevious`), in the same priority order:
  ///
  /// 1. the positional hint from the last session that trained this exercise;
  /// 2. otherwise the working weight carried forward from an earlier set of
  ///    the same exercise in *this* session;
  /// 3. otherwise 0 — genuinely nothing to go on (bodyweight).
  ///
  /// A set that *does* carry a weight is never second-guessed, including an
  /// explicit 0 the user dialled in on the stepper.
  Future<List<double>> _resolveWeights({
    required String sessionClientId,
    required String? templateClientId,
    required List<WatchStandaloneSet> sets,
    required List<String> setExerciseIds,
  }) async {
    final needsFallback = <String>{
      for (var i = 0; i < sets.length; i++)
        if (sets[i].weight == null) setExerciseIds[i],
    };
    final hints = <String, List<PreviousSetHint>>{};
    for (final exerciseClientId in needsFallback) {
      hints[exerciseClientId] = await _sessionRepository.getPreviousPerformance(
        exerciseClientId: exerciseClientId,
        templateClientId: templateClientId,
        // The row this batch is (re)writing must not seed itself: an
        // adoption resend mid-workout would otherwise read back the weights
        // an earlier resend had already inferred, and treat its own guess as
        // history.
        excludeSessionClientId: sessionClientId,
      );
    }

    final positionByExercise = <String, int>{};
    final carriedWeight = <String, double>{};
    final weights = <double>[];
    for (var i = 0; i < sets.length; i++) {
      final exerciseClientId = setExerciseIds[i];
      // `update` returns the new value, so the first set of an exercise gets
      // position 0 — the index its hint sits at in that exercise's previous
      // performance.
      final position =
          positionByExercise.update(exerciseClientId, (value) => value + 1, ifAbsent: () => 0);
      var weight = sets[i].weight;
      if (weight == null) {
        final exerciseHints = hints[exerciseClientId] ?? const <PreviousSetHint>[];
        weight = position < exerciseHints.length
            ? exerciseHints[position].weight
            : carriedWeight[exerciseClientId];
      }
      weight ??= 0;
      carriedWeight[exerciseClientId] = weight;
      weights.add(weight);
    }
    return weights;
  }

  /// Whether [exerciseIndex] points at a real entry in [template]'s exercise
  /// list — false for a null template, a null index, or an index the plan
  /// no longer has (shrunk since the watch cached it). Every false case
  /// falls back to the generic exercise identically; this helper is what
  /// keeps that fallback condition in exactly one place instead of
  /// duplicated across the `exercises`/`sets` construction above.
  bool _resolvesWithinTemplate(int? exerciseIndex, WorkoutTemplate? template) {
    if (template == null || exerciseIndex == null) return false;
    return exerciseIndex >= 0 && exerciseIndex < template.exercises.length;
  }

  // Matches the fallback in step_goal_notifier.dart / widget_snapshot_writer.dart:
  // hungarian -> hu, everything else (including "system") -> en. We don't
  // read the OS locale here, only the in-app LanguagePreference.
  Locale _localeFor(LanguagePreference preference) =>
      preference == LanguagePreference.hungarian ? const Locale('hu') : const Locale('en');
}

final standaloneSessionProcessorProvider = Provider<StandaloneSessionProcessor>((ref) {
  return StandaloneSessionProcessor(
    sessionRepository: ref.watch(workoutSessionRepositoryProvider),
    exerciseRepository: ref.watch(exerciseRepositoryProvider),
    templateRepository: ref.watch(workoutTemplateRepositoryProvider),
    watchService: ref.watch(watchWorkoutServiceProvider),
    writeHealthWorkout: ref.watch(healthServiceProvider).writeStrengthWorkoutAndGetId,
  );
});
