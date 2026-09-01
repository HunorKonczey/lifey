import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/ads/interstitial_manager.dart';
import '../../../core/health/health_controller.dart';
import '../../../core/health/health_service.dart';
import '../../../core/music/music_controller.dart';
import '../../../core/notifications/notification_service.dart';
import '../../../core/watch/watch_workout_service.dart';
import '../../../core/workout_session_notifier/workout_session_notifier_service.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/confirm_delete_dialog.dart';
import '../../settings/application/settings_controller.dart';
import '../../settings/domain/user_settings.dart';
import '../application/exercise_controller.dart';
import '../application/workout_session_controller.dart';
import '../data/workout_session_repository.dart';
import '../data/workout_template_repository.dart';
import '../domain/exercise.dart';
import '../domain/personal_record.dart';
import '../domain/workout_session.dart';
import '../domain/workout_template.dart';
import 'open_workout_screens.dart';
import 'session_row_plan.dart';
import 'watch_mirror_signature.dart';
import 'watch_session_plan.dart';
import 'watch_set_log_decision.dart';
import 'widgets/add_exercise_to_session_sheet.dart';
import 'widgets/exercise_session_card.dart';
import 'widgets/music_sticky_button.dart';
import 'widgets/post_workout_feedback_sheet.dart';
import 'widgets/workout_success_dialog.dart';

/// Full-screen form for logging a session, or editing one when [session] is given.
///
/// Exercises are represented as [ExerciseBlock]s — one card per exercise —
/// each carrying a list of [SetRow]s. Only rows with [SetRow.doneAt] set are
/// persisted as [ExerciseSetInput]s; their values (weight/reps) don't survive
/// a session close. The *count* of rows (done + blank) is persisted as each
/// exercise's targetSets (see [_buildPlanned]), so a blank row added ad-hoc
/// still regenerates the next time the session is opened.
///
/// While it shows a running session it registers itself in
/// [openWorkoutScreens] — that's how `workout_resume_prompt.dart` knows not
/// to push a *second* screen for the same session (see
/// [isWorkoutScreenOpenFor]).
class LogSessionScreen extends ConsumerStatefulWidget {
  const LogSessionScreen({
    super.key,
    this.session,
    this.template,
    this.watchMastered = false,
    this.watchCurrentExerciseIndex,
  });

  final WorkoutSession? session;
  final WorkoutTemplate? template;

  /// True when [session] is the phone's live mirror of a workout running on
  /// the watch (docs/watch/44-watch-f6-standalone-plan.md, live bridging) —
  /// passed by `workout_resume_prompt.dart` when it opens a session it just
  /// adopted. See [_LogSessionScreenState._watchMastered] for what changes;
  /// leaving it false is never wrong for long, since the watch's next
  /// adoption snapshot flips it on anyway.
  final bool watchMastered;

  /// The exercise the watch says it is logging into, from the very adoption
  /// snapshot that caused this screen to be opened
  /// ([WatchStandaloneAdoption.currentExerciseIndex]).
  ///
  /// The screen only starts listening for watch events once it is mounted, so
  /// without this hand-off it would know nothing about the watch's position
  /// until the *next* snapshot — i.e. until the watch logged another set. A
  /// set logged here on the phone before that point could not be reported
  /// back to the watch at all, because the counts are only usable with the
  /// exercise they belong to (see
  /// [WorkoutSessionState.setsDoneExerciseIndex]).
  final int? watchCurrentExerciseIndex;

  @override
  ConsumerState<LogSessionScreen> createState() => _LogSessionScreenState();
}

class _LogSessionScreenState extends ConsumerState<LogSessionScreen>
    with WidgetsBindingObserver {
  // Used for formatting the trainer comment timestamp.
  static final _label = DateFormat('EEE, MMM d · HH:mm');

  DateTime? _startedAt;
  DateTime? _finishedAt;

  /// Difficulty rating (1-10) + optional note, captured after finishing.
  /// See [_maybeCollectFeedback] and the inline section built by
  /// [_buildFeedbackSection].
  int? _rpe;
  String? _feedbackNote;

  /// The persisted session's clientId. Set when editing an existing session,
  /// or once a brand-new session has been created via the first [_persist].
  String? _sessionClientId;

  /// This screen's entry in [openWorkoutScreens] while it shows a running
  /// session; null for a finished one. Its `sessionClientId` is kept in step
  /// with [_sessionClientId] — including the moment a template-started
  /// workout first gets one, in [_persist].
  OpenWorkoutScreen? _openScreen;

  /// Whether the session notifier (Live Activity on iOS, ongoing notification
  /// on Android) is actually up for this session — see [_persist] and the
  /// "Session notifier" section below. Distinct from [_sessionClientId] being
  /// set: a session can exist in the DB (e.g. a resumed in-progress session)
  /// before this screen has (re-)started its notifier.
  ///
  /// Set from the platform's *answer* ([WorkoutSessionNotifierStart]), not
  /// optimistically before the call: a refused start (iOS won't create a Live
  /// Activity while the app is backgrounded — the normal case when a set
  /// logged on the watch is what created the session) used to flip this
  /// anyway, after which every later call took the `update` branch against an
  /// activity that never existed, and the workout ran to the end with no
  /// indicator at all.
  bool _sessionNotifierStarted = false;

  /// A start attempt is in flight — keeps a retry ([didChangeAppLifecycleState])
  /// and a concurrent [_persist] from firing two.
  bool _startingSessionNotifier = false;

  /// The platform refused for a reason that won't change while this workout
  /// runs (Live Activities switched off, notification permission denied, an
  /// OS without either) — stop retrying rather than asking on every resume.
  bool _sessionNotifierUnavailable = false;

  /// Whether the watch has been asked to start its own session. Tracked
  /// separately from [_sessionNotifierStarted] because the two are
  /// independent best-effort pushes that now succeed and fail on their own:
  /// a Live Activity retry must not re-send `startWorkout` (the watch rejects
  /// a second start and the phone would show a spurious "the watch didn't
  /// mirror this" message), and a *failed* Live Activity must not stop
  /// [_persistFinished] from telling the watch to close its session.
  bool _watchStartPushed = false;

  /// Whether this screen instance has (re-)activated the music controller
  /// (docs/music/46-workout-music-controls-plan.md §3.3) — same shape as
  /// [_sessionNotifierStarted], but tied to "showing a running session" (see
  /// `initState`) rather than to the first successful persist, since a
  /// music-app choice made before the first set is logged should still work.
  /// [_musicController] is cached at activation time so [dispose] can call
  /// it directly without touching `ref` (which isn't safe to read there).
  bool _musicActivated = false;
  MusicController? _musicController;

  /// One block per planned exercise. Each block's rows are either done
  /// (doneAt set → will be persisted) or plan (doneAt null → UI only).
  final List<ExerciseBlock> _blocks = [];

  /// exerciseClientId → the set count the session's originating template
  /// plans for, used only where the session's own stored count is missing —
  /// see [_loadTemplatePlan] / [_rebuildBlocks]. Empty until that load
  /// resolves (and for a session with no template at all).
  Map<String, int> _templateTargetSets = const {};

  /// The template's exercises in plan order — the index space the watch's
  /// [WatchStandaloneAdoption.currentExerciseIndex] refers to. Loaded
  /// alongside [_templateTargetSets]; empty until then.
  List<String> _templateExerciseIds = const [];

  /// The last exercise index the watch reported for a watch-mastered session
  /// (see [WatchStandaloneAdoption.currentExerciseIndex]). Resolved lazily in
  /// [_watchCurrentBlock] rather than stored as a clientId, so an adoption
  /// that arrives before [_loadTemplatePlan] finishes isn't simply dropped.
  int? _watchCurrentExerciseIndex;

  /// The same answer by clientId, when the watch is new enough to send one
  /// (F6c — [WatchStandaloneAdoption.currentExerciseId]). Preferred over the
  /// index: it needs no template to resolve, and it's the only form that can
  /// name an exercise *added to the session on the phone*, which has no
  /// position in the plan the index space is built from.
  String? _watchCurrentExerciseClientId;

  bool _saving = false;
  // Set when an edit arrives while a save is already in flight, so that
  // edit isn't silently dropped — _autoSave replays once the current save
  // finishes instead of losing it (see _autoSave).
  bool _dirty = false;
  Timer? _ticker;
  DateTime _now = DateTime.now();

  // ── Rest timer (docs/39-rest-timer-plan.md §2.1) ──
  // Fully derived from the last-done set's `doneAt` + the effective rest
  // duration; these three fields are the only ephemeral pieces, all keyed to
  // the `doneAt` they apply to and reset whenever a newer set is logged (see
  // the sync in build() below).
  Duration _restAdjustment = Duration.zero;
  DateTime? _restSkippedAt;
  DateTime? _restTrackedDoneAt;
  bool _restOvertimeHapticFired = false;

  // ── Near-live heart rate (Health store, running sessions only) ──
  // Neither HealthKit nor Health Connect streams live samples to a
  // third-party app: a paired watch syncs heart-rate samples into the store
  // in batches with a short delay, so
  // we poll the latest one. We reveal the readout as soon as a *fresh* sample
  // shows up — a sample landing this recently is itself proof the watch is
  // actively feeding live data (a workout), which is a faster and more reliable
  // signal than waiting for the value to move a few times (it never would while
  // the heart rate is steady). If the data dries up the latest sample ages past
  // the fresh window, the query returns nothing, and we hide the readout rather
  // than leaving a frozen number on screen.
  static const _kHrPollInterval = Duration(seconds: 5);
  static const _kHrFreshWindow = Duration(minutes: 2);

  Timer? _hrTicker;
  int? _currentHeartRate; // latest bpm; only shown while [_showHeartRate]
  DateTime? _lastHrSampleAt; // timestamp of the sample currently shown
  bool _showHeartRate = false;

  // Live calories burned, pushed straight from the watch's own session
  // (WatchLiveMetrics) — unlike heart rate there's no Health-store polling
  // fallback for this on the phone, so it's only ever shown while a
  // connected watch is actively measuring and feeding it.
  double? _watchActiveCalories;

  // "Measuring" ⌚-pill (docs/40-watch-app-plan.md §12.4 B14) — true once the
  // watch confirms its own session actually started, cleared on reachability
  // loss; also implicitly hidden once [_finishedAt] is set (see build()).
  bool _measuringOnWatch = false;

  // Lets the watch's own End button drive the same finish flow as the
  // in-app one (docs/40-watch-app-plan.md §8.2 decision (b)) — only while
  // this screen instance for the matching session is mounted; see
  // [_onWatchEvent].
  StreamSubscription<Object>? _watchEventsSubscription;

  /// Last 8 `WatchSetLogged.eventId`s already handled — retried deliveries of
  /// the same tap (transport retry, not a second real tap) ack `true` again
  /// without logging twice (docs/watch/43-watch-f5-set-logging-plan.md §4.2).
  final List<String> _recentWatchSetEventIds = [];

  /// Whether this screen is showing a **watch-mastered** session — one the
  /// user started on the watch and the phone only adopted a live mirror of
  /// (docs/watch/44-watch-f6-standalone-plan.md, live bridging). Those work
  /// the opposite way round from a phone-started session: the watch logs
  /// every set locally and resends its whole set list, which
  /// [StandaloneSessionProcessor] writes into this session's row — so this
  /// screen has to *re-read* that row instead of trusting the [_blocks] it
  /// built once in [initState]. Without it the phone sat frozen on however
  /// the session looked when it was adopted, and stayed open on a workout the
  /// watch had already finished. Set by [_startWatchMirror], only ever from a
  /// watch event naming this screen's own session.
  bool _watchMastered = false;
  ProviderSubscription? _watchMirrorSubscription;

  /// [watchMirrorSignature] of the row [_applyWatchMirror] last rebuilt from,
  /// so an emission that doesn't actually change this session is skipped.
  /// Null until the first one is applied — the mirror always runs once.
  String? _mirroredSignature;

  /// Guards [_closeFromWatchMirror] against re-entry — the mirror keeps
  /// emitting after the finishing write lands.
  bool _closingFromWatchMirror = false;

  bool get _isEditing => widget.session != null;

  /// "Edzés indítása az órán" Settings kapcsoló (docs/40-watch-app-plan.md
  /// §6.4) — a [WatchWorkoutService] hívásait itt, a call site-oknál
  /// kapuzzuk, nem magában a service-ben, hogy az settings-független,
  /// egyszerűen tesztelhető maradjon.
  bool get _watchEnabled =>
      ref.read(settingsControllerProvider).value?.watchWorkoutEnabled ?? true;

  // ---------------------------------------------------------------------------
  // Init / dispose
  // ---------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _watchEventsSubscription =
        ref.read(watchWorkoutServiceProvider).events.listen(_onWatchEvent);
    final session = widget.session;
    // For existing sessions, start time is known. For new sessions _startedAt
    // stays null until the first set is persisted — the timer only starts then.
    _startedAt = session?.startedAt;
    _finishedAt = session?.finishedAt;
    _rpe = session?.rpe;
    _feedbackNote = session?.feedbackNote;
    // Set here, not in the deferred [_startWatchMirror] below: the session
    // notifier is started from this same initState (a frame earlier than the
    // mirror attaches), and it reads this to decide whether to push a
    // `startWorkout` at the watch.
    _watchMastered = widget.watchMastered;
    _watchCurrentExerciseIndex = widget.watchCurrentExerciseIndex;

    if (_finishedAt == null) _openScreen = openWorkoutScreen(session?.clientId);
    if (_finishedAt == null) _activateMusic();

    if (session != null) {
      _sessionClientId = session.clientId;
      _rebuildBlocks(session);
    } else if (widget.template != null) {
      for (final te in widget.template!.exercises) {
        // Name resolved at render time from the catalog (TemplateExercise has no name).
        _blocks.add(ExerciseBlock(
          exerciseClientId: te.exerciseClientId,
          exerciseName: '',
          targetSets: te.targetSets,
          rows: _generateRows(te.targetSets),
        ));
      }
    }

    // Only start the ticker immediately when editing an existing session
    // that's already started. For a brand-new session the ticker starts
    // lazily in _persist() once the first set is saved; for a trainer-
    // scheduled session being started now, _startScheduledSession below
    // starts it once the stamp lands.
    if (_isEditing && _finishedAt == null && _startedAt != null) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _now = DateTime.now());
      });
      _hrTicker = Timer.periodic(_kHrPollInterval, (_) => _pollHeartRate());
      _pollHeartRate(); // don't wait a full interval for the first read

      // Re-attach to (or start, if the OS killed the app mid-workout and no
      // indicator survived) the session notifier for this in-progress
      // session. Deferred a frame, same as WorkoutResumePrompt, since this
      // can run during initState before ancestor InheritedWidgets are
      // guaranteed ready for AppLocalizations.of(context).
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_startSessionNotifier());
      });
    }

    // Attaching the mirror is deferred a frame rather than done inline: its
    // immediate first read calls setState, which isn't allowed while
    // initState is still running.
    if (_watchMastered) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _startWatchMirror();
      });
    }

    // Only for an existing session: a brand-new one built from
    // widget.template already carries the template's counts on its blocks.
    if (session != null) unawaited(_loadTemplatePlan());

    if (session != null && session.isUpcoming) {
      unawaited(_startScheduledSession(session));
    } else {
      unawaited(_loadPreviousPerformance(_blocks));
      unawaited(_loadPrBaselines(_blocks));
    }
  }

  /// (Re)builds [_blocks] from a persisted session — one block per
  /// [SessionExercise] in plan order, its done rows first (in `performedAt`
  /// order) followed by however many blank rows the plan still has left.
  /// Factored out of [initState] so the watch mirror ([_applyWatchMirror])
  /// can rerun it against a refreshed row; replaces whatever was there, so
  /// callers wrap it in `setState` when the screen is already built.
  void _rebuildBlocks(WorkoutSession session) {
    final setsByEx = <String, List<ExerciseSet>>{};
    for (final s in session.sets) {
      setsByEx.putIfAbsent(s.exerciseClientId, () => []).add(s);
    }
    for (final sets in setsByEx.values) {
      sets.sort((a, b) => a.performedAt.compareTo(b.performedAt));
    }
    _blocks.clear();
    for (final se in session.exercises) {
      final doneSets = setsByEx[se.exerciseClientId] ?? [];
      final rows = <SetRow>[
        for (final s in doneSets)
          SetRow(weight: s.weight, reps: s.reps, doneAt: s.performedAt),
      ];
      // The plan size and the blank rows that follow the logged ones — see
      // [planSessionRows] for why a null `targetSets` can't be taken at face
      // value, and why a running session always keeps one row open. Any blank
      // row it opens here is written back as this exercise's targetSets by
      // the next persist ([_buildPlanned]), so the gap closes itself rather
      // than reappearing on the next rebuild.
      final plan = planSessionRows(
        storedTargetSets: se.targetSets,
        templateTargetSets: _templateTargetSets[se.exerciseClientId],
        doneSets: doneSets.length,
        sessionFinished: _finishedAt != null,
      );
      rows.addAll(List.generate(plan.blankRows, (_) => SetRow()));
      _blocks.add(ExerciseBlock(
        exerciseClientId: se.exerciseClientId,
        exerciseName: se.exerciseName,
        targetSets: plan.targetSets,
        rows: rows,
      ));
    }
  }

  /// Loads what this screen needs from the session's originating template:
  /// the exercise order (which the watch's `currentExerciseIndex` indexes
  /// into — see [_watchCurrentBlock]) and each exercise's set count.
  ///
  /// The counts are a fallback for [_rebuildBlocks]'s `targetSets` — the
  /// recovery half of the same client-only-state problem described there, for
  /// sessions whose stored count was already lost before this build (a `null`
  /// that's now sitting in the local DB can't be un-lost by fixing the write
  /// path alone).
  ///
  /// Fire-and-forget from [initState], like [_loadPreviousPerformance]: the
  /// blocks are already built by the time it resolves, so it tops them up in
  /// place instead of calling [_rebuildBlocks] again — a rebuild would drop
  /// whatever the user has done in the meantime. Any *later* rebuild (the
  /// watch mirror's) then picks the map up directly.
  ///
  /// Deliberately doesn't persist the topped-up rows: a watch-mastered
  /// session must not be written from this screen (see [_applyWatchMirror]),
  /// and for every other session the next real edit persists the corrected
  /// count anyway.
  Future<void> _loadTemplatePlan() async {
    final templateClientId = _templateClientId;
    if (templateClientId == null) return;
    final template = await ref
        .read(workoutTemplateRepositoryProvider)
        .findByClientId(templateClientId);
    if (template == null || !mounted) return;
    // Set before the early return below: the watch's `currentExerciseIndex`
    // is resolved against this list, and a template whose exercises carry no
    // targetSets at all is still perfectly indexable.
    _templateExerciseIds = [
      for (final te in template.exercises) te.exerciseClientId,
    ];
    final targetSetsByExercise = {
      for (final te in template.exercises)
        if (te.targetSets != null) te.exerciseClientId: te.targetSets!,
    };
    if (targetSetsByExercise.isEmpty) return;
    _templateTargetSets = targetSetsByExercise;
    setState(() {
      for (final block in _blocks) {
        if (block.targetSets != null) continue;
        final target = targetSetsByExercise[block.exerciseClientId];
        if (target == null) continue;
        block.targetSets = target;
        // Tops up to `target` *rows* (not target-minus-done): the block may
        // already carry the single blank row [_rebuildBlocks] opens when it
        // knows no plan at all.
        final missing = target - block.rows.length;
        if (missing > 0) {
          block.rows.addAll(List.generate(missing, (_) => SetRow()));
        }
      }
    });
  }

  /// "Kezdés" on an upcoming (trainer-scheduled) session: loads its planned
  /// exercises from the linked template — never materialized on the server
  /// until start, see docs/personal_trainer/09-utemezett-edzesek-domain-backend.md
  /// — then stamps startedAt and persists immediately, so the row leaves the
  /// "Közelgő" section right away even if the trainer never logs a set.
  Future<void> _startScheduledSession(WorkoutSession session) async {
    final templateClientId = session.templateClientId;
    if (templateClientId != null) {
      final template = await ref
          .read(workoutTemplateRepositoryProvider)
          .findByClientId(templateClientId);
      // The client may have deleted their copy since the trainer scheduled
      // this — start as an empty session rather than failing (matches the
      // backend's same fallback for this case).
      if (template != null && mounted) {
        setState(() {
          for (final te in template.exercises) {
            _blocks.add(ExerciseBlock(
              exerciseClientId: te.exerciseClientId,
              exerciseName: '',
              targetSets: te.targetSets,
              rows: _generateRows(te.targetSets),
            ));
          }
        });
      }
    }
    if (!mounted) return;
    setState(() {
      _startedAt = DateTime.now();
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _now = DateTime.now());
      });
      _hrTicker = Timer.periodic(_kHrPollInterval, (_) => _pollHeartRate());
    });
    _pollHeartRate();
    unawaited(_loadPreviousPerformance(_blocks));
    unawaited(_loadPrBaselines(_blocks));
    await _persist();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final openScreen = _openScreen;
    if (openScreen != null) closeWorkoutScreen(openScreen);
    _ticker?.cancel();
    _hrTicker?.cancel();
    unawaited(_watchEventsSubscription?.cancel());
    _watchMirrorSubscription?.close();
    _deactivateMusic();
    super.dispose();
  }

  /// M5 polish (docs/music/46-workout-music-controls-plan.md §3.3/§4): the
  /// only platform bridge that can silently miss a change while backgrounded
  /// is iOS Spotify's App Remote connection (not yet wired — M4) — Android's
  /// MediaSessionManager callbacks and iOS Apple Music's
  /// MPMusicPlayerController notifications both keep firing/get re-checked
  /// on their own (§9/§10). Still cheap and correct to resync unconditionally
  /// on every resume rather than special-case by platform: catches a
  /// mid-background permission revocation too (Settings → notification
  /// access / Media Library), which otherwise would only surface the next
  /// time a transport button is tapped.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    if (_musicActivated) unawaited(_musicController?.refresh());
    // The retry point for a refused Live Activity: iOS only lets an app
    // *start* one while it's in the foreground, and the start attempt can
    // easily have happened in the background — a set logged on the watch
    // persists (and thus creates the session) with the phone's screen off.
    // Coming back to the foreground is exactly when that can succeed, and
    // without this the workout kept running with no indicator until the app
    // was restarted. No-ops once started, once refused permanently, or
    // before there's a session to attach to (see [_startSessionNotifier]).
    if (_finishedAt == null && _sessionClientId != null) {
      unawaited(_startSessionNotifier());
    }
  }

  /// Starts the music controller listening to the platform bridge
  /// (docs/music/46-workout-music-controls-plan.md §3.3). Cheap and
  /// idempotent — guarded by [_musicActivated] — and safe to call even
  /// before a provider is chosen; the controller/service simply reports
  /// `notConfigured` until [MusicController.selectProvider] is called from
  /// the picker sheet.
  void _activateMusic() {
    if (_musicActivated) return;
    _musicActivated = true;
    _musicController = ref.read(musicControllerProvider.notifier);
    unawaited(_musicController!.activate());
  }

  /// Stops listening — called both from [_persistFinished] (so a session
  /// that finishes without the screen unmounting yet, e.g. while the
  /// feedback sheet/success dialog is still showing, stops right away
  /// rather than waiting for [dispose]) and from [dispose] itself as a
  /// safety net for a session abandoned mid-workout. Never touches actual
  /// playback — whatever's playing keeps playing.
  void _deactivateMusic() {
    if (!_musicActivated) return;
    _musicActivated = false;
    unawaited(_musicController?.deactivate());
  }

  /// The watch's End button asks the phone to close the session rather than
  /// ending its own sensor session unilaterally (docs/40-watch-app-plan.md
  /// §8.2 decision (b)) — but unlike the in-app Finish button, the watch
  /// already collected (or skipped) the effort rating itself before sending
  /// this, so [_finishWorkoutFromWatch] persists it directly instead of
  /// showing the phone's own feedback sheet. No-ops if this screen isn't
  /// showing the matching session, or it's already finished/finishing.
  void _onWatchEvent(Object event) {
    switch (event) {
      case WatchEndRequested():
        if (event.sessionClientId != _sessionClientId) return;
        if (_finishedAt != null || _saving) return;
        unawaited(_finishWorkoutFromWatch(event.rpe));
      case WatchStartRejected():
        // Another app already owns an exercise on the watch
        // (docs/40-watch-app-plan.md §5.3/§8.1) — the phone-side workout
        // itself is unaffected, just let the user know the watch didn't
        // mirror it.
        if (event.sessionClientId != _sessionClientId || !mounted) return;
        AppSnackbar.showInfo(
          context,
          title: AppLocalizations.of(context)!.watchStartRejectedMessage,
        );
      case WatchStartedOnWatch():
        if (event.sessionClientId != _sessionClientId || !mounted) return;
        setState(() => _measuringOnWatch = true);
      case WatchReachabilityChanged():
        if (event.reachable || !mounted) return;
        setState(() {
          _measuringOnWatch = false;
          _watchActiveCalories = null;
        });
      case WatchLiveMetrics():
        // The watch is the more real-time source while it's actively
        // measuring: its readings arrive far more often than the Health
        // store's batched samples _pollHeartRate polls for, so a live push
        // simply supersedes whatever _pollHeartRate last saw.
        if (event.sessionClientId != _sessionClientId || !mounted) return;
        setState(() {
          if (event.heartRateBpm != null) {
            _currentHeartRate = event.heartRateBpm!.round();
            _showHeartRate = true;
            _lastHrSampleAt = DateTime.now();
          }
          if (event.activeCalories != null) {
            _watchActiveCalories = event.activeCalories;
          }
        });
      case WatchSetLogged():
        _handleWatchSetLogged(event);
      // Both halves of the watch-mastered (standalone) flow: the running
      // snapshot the watch resends after every set it logs, and the final
      // payload it sends when the user ends the workout on the wrist. Either
      // one naming this session means the watch — not this screen — is the
      // source of truth for it, so switch to mirroring the DB row the
      // processor writes. Neither is handled inline here: the write happens
      // asynchronously in WorkoutResumePrompt's own listener on this same
      // broadcast stream, so reacting to the event itself would race it.
      case WatchStandaloneAdoption():
        if (event.standaloneSessionId != _sessionClientId) return;
        final index = event.currentExerciseIndex;
        final exerciseClientId = event.currentExerciseId;
        final movedOn = (index != null && index != _watchCurrentExerciseIndex) ||
            (exerciseClientId != null && exerciseClientId != _watchCurrentExerciseClientId);
        if (index != null) _watchCurrentExerciseIndex = index;
        if (exerciseClientId != null) _watchCurrentExerciseClientId = exerciseClientId;
        _startWatchMirror();
        // A snapshot can report a new current exercise without carrying a new
        // set — the watch sends one the moment the user picks an exercise from
        // the gyakorlat-lista, and re-sends on reconnect — and the mirror
        // deliberately skips those. The prefill this pushes back is
        // per-exercise, though, so without this it would stay pointed at the
        // previous exercise until the next set landed, and the wrist would
        // open its stepper on that one's numbers.
        //
        // Deliberately **not** gated on `_sessionNotifierStarted`: this push
        // is the watch's, and a Live Activity that was refused or switched off
        // must not take it down with it (see [_updateSessionNotifier]).
        if (movedOn && _finishedAt == null) {
          unawaited(_updateSessionNotifier());
        }
      case WatchStandaloneSession():
        if (event.standaloneSessionId != _sessionClientId) return;
        _startWatchMirror();
      // The wrist's exercise picker, in a session this phone owns (docs/watch/
      // 50-watch-f6c-session-plan-sync-plan.md §7). Nothing is logged here —
      // it only moves "which exercise is current", so the very next state push
      // (name, counts, stepper prefill) describes what the user just picked.
      case WatchExerciseSelected():
        if (event.sessionClientId != _sessionClientId || _finishedAt != null) return;
        if (event.exerciseId == _watchCurrentExerciseClientId) return;
        if (!_blocks.any((b) => b.exerciseClientId == event.exerciseId)) return;
        setState(() => _watchCurrentExerciseClientId = event.exerciseId);
        unawaited(_updateSessionNotifier());
    }
  }

  /// Switches this screen into mirror mode for a watch-mastered session (see
  /// [_watchMastered]) and attaches the listener that keeps it in sync —
  /// idempotent, so the adoption snapshot arriving after every logged set
  /// only ever attaches one.
  void _startWatchMirror() {
    _watchMastered = true;
    if (_watchMirrorSubscription != null) return;
    _watchMirrorSubscription = ref.listenManual(
      workoutSessionControllerProvider,
      (_, next) => _applyWatchMirror(next.value),
      // The write that prompted this may already have landed — don't wait for
      // the *next* set to catch up with the one that just arrived.
      fireImmediately: true,
    );
  }

  /// Re-reads this session's row and rebuilds the screen from it. Deliberately
  /// a full replace rather than a merge: on a watch-mastered session the
  /// watch's set list is authoritative (it resends all of it, every time), so
  /// there is nothing on this side worth preserving against it.
  ///
  /// Which is also why it must only run when the row's *content* actually
  /// changed — see [watchMirrorSignature]: the stream behind it re-emits on
  /// unrelated database traffic too, and rebuilding then threw away the
  /// screen's state (and re-pushed it to the watch) for nothing.
  void _applyWatchMirror(List<WorkoutSession>? sessions) {
    if (!mounted || sessions == null) return;
    final clientId = _sessionClientId;
    if (clientId == null) return;
    WorkoutSession? mirrored;
    for (final candidate in sessions) {
      if (candidate.clientId == clientId) {
        mirrored = candidate;
        break;
      }
    }
    if (mirrored == null) return;
    final session = mirrored;
    final signature = watchMirrorSignature(session);
    if (signature == _mirroredSignature) return;
    _mirroredSignature = signature;
    setState(() {
      _startedAt = session.startedAt ?? _startedAt;
      _rpe = session.rpe ?? _rpe;
      _rebuildBlocks(session);
    });
    // The set that just landed is the newest one, so the rest timer restarts
    // against it exactly as it would for a set logged on this screen.
    _syncRestEphemeralState();
    unawaited(_rescheduleRestNotification());
    // Chained, not fired in parallel: the state push below carries
    // `watchSetPrefill(_blocks, …)`, which reads `ExerciseBlock.previousSets`
    // — pushing before this future completes would send a prefill computed
    // against a block whose history hasn't loaded yet.
    unawaited(_loadPreviousPerformance(_blocks).then((_) {
      if (mounted && session.finishedAt == null) unawaited(_updateSessionNotifier());
    }));
    unawaited(_loadPrBaselines(_blocks));
    if (session.finishedAt != null) unawaited(_closeFromWatchMirror(session));
  }

  /// The watch ended a watch-mastered session. Its final
  /// [WatchStandaloneSession] already wrote `finishedAt` (with the rpe and
  /// health-workout id) into the row this screen mirrors, so — unlike
  /// [_finishWorkoutFromWatch] — there is nothing left to persist here, and
  /// writing anyway would push this screen's copy back over the processor's
  /// authoritative one. This only tears down the running-session machinery
  /// and leaves, the way the Finish button does. It also never calls
  /// `endWorkout` on the watch: the watch closed its own session before
  /// sending this.
  Future<void> _closeFromWatchMirror(WorkoutSession session) async {
    if (_closingFromWatchMirror) return;
    _closingFromWatchMirror = true;
    _finishedAt = session.finishedAt;
    _ticker?.cancel();
    _ticker = null;
    _hrTicker?.cancel();
    _hrTicker = null;
    _deactivateMusic();
    // Sees _finishedAt set and cancels, same as _persistFinished's call.
    unawaited(_rescheduleRestNotification());
    if (_sessionNotifierStarted) {
      _sessionNotifierStarted = false;
      unawaited(ref.read(workoutSessionNotifierServiceProvider).end());
    }
    if (!mounted) return;
    await _maybeShowWorkoutSuccess();
    if (!mounted) return;
    await _maybeShowInterstitial();
    if (!mounted) return;
    _navigateToDashboard();
  }

  /// The watch is a dumb trigger — it doesn't choose which exercise/set gets
  /// logged, only that "the next one" should be (docs/watch/
  /// 43-watch-f5-set-logging-plan.md §2, §5.2/3–4). The actual guard/dedup/
  /// row-selection decision lives in [decideWatchSetLog], a pure function,
  /// so it stays unit-testable without mounting this screen; logging itself
  /// goes through the exact same [_handleRowMarkDone]/[_handleAddSet] paths
  /// the phone's own "+" button uses, so rest-start/state-sync/autosave all
  /// fire the same way.
  void _handleWatchSetLogged(WatchSetLogged event) {
    // Resolved once and reused below: the row this tap lands in and the values
    // it should carry have to be worked out against the *same* current block,
    // and both before anything is mutated.
    final currentBlock = _currentExerciseBlock();
    // The wrist's exercise picker naming this tap's exercise (F6c §7). Its row
    // wins over the phone's own choice — and unlike that choice it stays put
    // even when the exercise is already complete, since pointing at a finished
    // exercise is how you add one more set to it from the watch.
    final chosenBlock = _blockForExerciseId(event.exerciseId);
    final decision = decideWatchSetLog(
      eventSessionClientId: event.sessionClientId,
      currentSessionClientId: _sessionClientId,
      sessionFinished: _finishedAt != null,
      saving: _saving,
      eventId: event.eventId,
      recentEventIds: _recentWatchSetEventIds,
      blocks: _blocks,
      currentBlock: currentBlock,
      chosenBlock: chosenBlock,
    );

    switch (decision.action) {
      case WatchSetLogAction.reject:
        unawaited(ref.read(watchWorkoutServiceProvider).ackSetLogged(
              sessionClientId: event.sessionClientId,
              eventId: event.eventId,
              accepted: false,
            ));
      case WatchSetLogAction.dedupe:
        unawaited(ref.read(watchWorkoutServiceProvider).ackSetLogged(
              sessionClientId: event.sessionClientId,
              eventId: event.eventId,
              accepted: true,
            ));
      case WatchSetLogAction.log:
        // A tap that named its exercise also *is* a selection: everything the
        // phone publishes from here on (name, counts, stepper prefill) should
        // describe it, exactly as an explicit pick would have.
        if (chosenBlock != null) {
          _watchCurrentExerciseClientId = chosenBlock.exerciseClientId;
        }
        final target = decision.target!;
        final blockIndex = target.blockIndex;
        // Resolved *before* anything is mutated: it answers "what should the
        // row this tap lands in hold", and appending a row would move that
        // position. Same function — and therefore the same answer — as the
        // prefill this screen publishes to the watch's adjust stepper
        // (docs/watch/48-watch-f5b-set-adjust-plan.md D-F5b.2): the row's own
        // planned values, else what this exercise did at that position in the
        // last workout, else the last set already logged for it here.
        final prefill = chosenBlock != null
            ? watchSetPrefillForBlock(chosenBlock)
            : watchSetPrefill(_blocks, currentBlock);
        final int rowIndex;
        if (target.needsNewRow) {
          _handleAddSet(blockIndex, prefillFromPrevious: true);
          rowIndex = _blocks[blockIndex].rows.length - 1;
        } else {
          rowIndex = target.rowIndex!;
        }
        // F5b (docs/watch/48-watch-f5b-set-adjust-plan.md D-F5b.3): a tap that
        // came through the watch's adjust stepper carries reps+weight, and
        // goes through _handleRowEdit — which writes the values *and* stamps
        // doneAt, so rest/PR/autosave all fire exactly as they do for the
        // phone's own compact editor.
        //
        // A plain one-tap log carries no values, and used to only stamp
        // `doneAt` on the row. Planned rows are created blank, so that logged
        // a *done but empty* set — one that `_buildSets` then drops entirely
        // for having no reps/weight, i.e. the tap left nothing behind but an
        // empty row. It now writes the same prefill the watch would have
        // opened its stepper on, so a one-tap log records what the user is
        // actually lifting. With nothing at all to go on it still falls back
        // to the bare mark-done (the watch offers the stepper instead in that
        // case — see `LogPage.handleTap`).
        final values = event.loggedValues ??
            (prefill == null ? null : (weight: prefill.weight, reps: prefill.reps));
        if (values != null) {
          _handleRowEdit(blockIndex, rowIndex, values.weight, values.reps);
        } else {
          _handleRowMarkDone(blockIndex, rowIndex);
        }
        _recentWatchSetEventIds.add(event.eventId);
        if (_recentWatchSetEventIds.length > 8) {
          _recentWatchSetEventIds.removeAt(0);
        }
        unawaited(ref.read(watchWorkoutServiceProvider).ackSetLogged(
              sessionClientId: event.sessionClientId,
              eventId: event.eventId,
              accepted: true,
            ));
    }
  }

  // ---------------------------------------------------------------------------
  // Near-live heart rate
  // ---------------------------------------------------------------------------

  /// Polls the platform health store for the latest heart-rate sample. A
  /// sample that landed within [_kHrFreshWindow] counts as live and is shown
  /// immediately; once the freshest sample ages past that window the watch
  /// has stopped feeding us data, so we hide the readout instead of leaving a
  /// stale value on screen. No-ops when the session is finished, or when the
  /// user hasn't enabled the health connection.
  Future<void> _pollHeartRate() async {
    if (!mounted || _finishedAt != null) return;
    final enabled = ref.read(healthControllerProvider).value ?? false;
    if (!enabled) return;

    final sample = await ref
        .read(healthServiceProvider)
        .latestHeartRate(within: _kHrFreshWindow);
    if (!mounted) return;

    // No fresh Health-store sample → normally the watch has stopped syncing,
    // so hide a stale readout. But while the watch is actively measuring, it
    // already pushes HR far more often than the Health store's batched sync
    // can keep up with (see [WatchLiveMetrics]'s handler) — a poll finding
    // nothing here just means the store hasn't caught up yet, not that the
    // watch stopped; a real disconnect clears [_showHeartRate] via
    // [WatchReachabilityChanged] instead. Don't let a stale poll tick clobber
    // an up-to-date live-pushed value in that case.
    if (sample == null) {
      if (_showHeartRate && !_measuringOnWatch) setState(() => _showHeartRate = false);
      return;
    }

    // Skip if HealthKit handed us the same sample again (no new data synced).
    if (_lastHrSampleAt != null &&
        !sample.timestamp.isAfter(_lastHrSampleAt!)) {
      return;
    }
    _lastHrSampleAt = sample.timestamp;

    setState(() {
      _currentHeartRate = sample.bpm.round();
      _showHeartRate = true;
    });
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  List<SetRow> _generateRows(int? targetSets) {
    final count = (targetSets != null && targetSets > 0) ? targetSets : 1;
    return List.generate(count, (_) => SetRow());
  }

  /// clientId of the template this session was (or is being) started from,
  /// whether it's a brand-new session or one already being edited.
  String? get _templateClientId =>
      widget.template?.clientId ?? widget.session?.templateClientId;

  /// Fetches and fills in [ExerciseBlock.previousSets] for each of [blocks],
  /// so the exercise cards can show what was done last time. Fire-and-forget
  /// from initState / after adding an exercise — not awaited by callers.
  Future<void> _loadPreviousPerformance(List<ExerciseBlock> blocks) async {
    final repo = ref.read(workoutSessionRepositoryProvider);
    final templateClientId = _templateClientId;
    for (final block in blocks) {
      final previous = await repo.getPreviousPerformance(
        exerciseClientId: block.exerciseClientId,
        templateClientId: templateClientId,
        excludeSessionClientId: _sessionClientId,
      );
      if (!mounted) return;
      setState(() => block.previousSets = previous);
    }
  }

  /// Fetches and fills in [ExerciseBlock.prBaseline] for each of [blocks] —
  /// every set ever logged for that exercise, excluding this session, so
  /// live PR detection has something to compare against (see
  /// [_recomputePrFlags]). Fire-and-forget, same pattern as
  /// [_loadPreviousPerformance]. Template-agnostic on purpose — a record is
  /// a record regardless of which template it was logged under.
  Future<void> _loadPrBaselines(List<ExerciseBlock> blocks) async {
    final repo = ref.read(workoutSessionRepositoryProvider);
    for (final block in blocks) {
      final baseline = await repo.getPrBaseline(
        exerciseClientId: block.exerciseClientId,
        excludeSessionClientId: _sessionClientId,
      );
      if (!mounted) return;
      setState(() {
        block.prBaseline = baseline;
        _recomputePrFlagsForBlock(block);
      });
    }
  }

  /// Recomputes PR flags for every done row in [block] from scratch: the
  /// block's baseline (once loaded) extended forward through its currently
  /// done rows in [SetRow.doneAt] order. Flags are fully derived state, so
  /// they can never go stale or double-count across edits — see
  /// docs/38-personal-records-plan.md, M3. No-ops (clearing every row's
  /// flags) while the baseline hasn't loaded yet, rather than celebrating
  /// against a half-loaded history.
  void _recomputePrFlagsForBlock(ExerciseBlock block) {
    for (final row in block.rows) {
      row.prTypes = const {};
    }
    final baseline = block.prBaseline;
    if (baseline == null) return;

    final doneRows = [
      for (final row in block.rows)
        if (row.isDone && row.weight != null && row.reps != null) row,
    ]..sort((a, b) => a.doneAt!.compareTo(b.doneAt!));
    final sets = [
      for (final row in doneRows)
        (weight: row.weight!, reps: row.reps!, performedAt: row.doneAt!),
    ];
    final perRow = detectPrsInOrder(baseline, sets);
    for (var i = 0; i < doneRows.length; i++) {
      doneRows[i].prTypes = perRow[i].toSet();
    }
  }

  /// [_recomputePrFlagsForBlock] for block index [bi], plus haptic feedback
  /// when the row just interacted with ([ri]) ends up earning a record —
  /// instant physical feedback without interrupting the logging flow (the
  /// full celebration is reserved for the finish-workout success dialog).
  void _recomputePrFlags(int bi, {int? justEditedRow}) {
    _recomputePrFlagsForBlock(_blocks[bi]);
    if (justEditedRow != null &&
        _blocks[bi].rows[justEditedRow].prTypes.isNotEmpty) {
      unawaited(HapticFeedback.mediumImpact());
    }
  }

  DateTime? _lastDoneAt() => _lastDoneEntry()?.doneAt;

  /// The block + timestamp of the most recently logged set, or null if none
  /// is done yet. Used both for the elapsed-since-last-set display and to
  /// resolve which exercise's rest-timer duration applies (docs/39-rest-timer-plan.md §2.4).
  ({ExerciseBlock block, DateTime doneAt})? _lastDoneEntry() {
    ExerciseBlock? bestBlock;
    DateTime? bestAt;
    for (final block in _blocks) {
      for (final row in block.rows) {
        final doneAt = row.doneAt;
        if (doneAt != null && (bestAt == null || doneAt.isAfter(bestAt))) {
          bestAt = doneAt;
          bestBlock = block;
        }
      }
    }
    if (bestBlock == null || bestAt == null) return null;
    return (block: bestBlock, doneAt: bestAt);
  }

  /// Effective rest duration for [block]: its own override if set, otherwise
  /// the account-wide default (docs/39-rest-timer-plan.md §2.2).
  int _effectiveRestSeconds(ExerciseBlock block,
      Map<String, Exercise> exercisesById, UserSettings settings) {
    return exercisesById[block.exerciseClientId]?.defaultRestSeconds ??
        settings.defaultRestSeconds;
  }

  // ---------------------------------------------------------------------------
  // Rest timer notification scheduling (docs/39-rest-timer-plan.md §2.3)
  // ---------------------------------------------------------------------------

  /// Resets the ephemeral +15s/skip/haptic state whenever a newer set has
  /// become "last" — they're keyed to the `doneAt` they applied to, never
  /// carried forward to the next rest. Idempotent; called both from build()
  /// (for the banner) and from every handler that can change `_lastDoneAt()`
  /// before it (re)schedules the notification, since setState's callback runs
  /// synchronously but the next build() doesn't.
  void _syncRestEphemeralState() {
    final lastDoneAt = _lastDoneAt();
    if (lastDoneAt != _restTrackedDoneAt) {
      _restTrackedDoneAt = lastDoneAt;
      _restAdjustment = Duration.zero;
      _restSkippedAt = null;
      _restOvertimeHapticFired = false;
    }
  }

  UserSettings _currentRestSettings() =>
      ref.read(settingsControllerProvider).value ??
      const UserSettings.defaults();

  int _currentEffectiveRestSeconds(ExerciseBlock block, UserSettings settings) {
    final exercises =
        ref.read(exerciseControllerProvider).value ?? const <Exercise>[];
    final exercisesById = {for (final e in exercises) e.clientId: e};
    return _effectiveRestSeconds(block, exercisesById, settings);
  }

  /// Re-derives the rest-end target from the current [_lastDoneEntry] (+
  /// [_restAdjustment]) and (re)schedules the local notification for it, or
  /// cancels it if there's nothing to notify about. The single call site
  /// every mutation that can change "the current rest" goes through — a
  /// newer set logged replaces the schedule (same fixed notification id), an
  /// exhausted or skipped rest cancels it.
  Future<void> _rescheduleRestNotification() async {
    final settings = _currentRestSettings();
    final entry = _lastDoneEntry();
    final skipped = _restSkippedAt != null && _restSkippedAt == entry?.doneAt;
    if (!settings.restTimerEnabled ||
        entry == null ||
        skipped ||
        _finishedAt != null) {
      await NotificationService.cancelRestEnd();
      return;
    }
    final seconds = _currentEffectiveRestSeconds(entry.block, settings);
    final endsAt =
        entry.doneAt.add(Duration(seconds: seconds) + _restAdjustment);
    if (!endsAt.isAfter(DateTime.now())) {
      await NotificationService.cancelRestEnd();
      return;
    }
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    await NotificationService.scheduleRestEnd(
      endsAt: endsAt,
      title: l10n.restTimerNotificationTitle,
      body: l10n.restTimerNotificationBody,
    );
  }

  /// Shared derivation behind [_currentRestEndsAtEpochMs],
  /// [_currentRestTotalSeconds], and [_currentRestRemainingSeconds] — null
  /// under the same conditions for all three (timer disabled, no last set,
  /// skipped, or already expired). Same derivation as
  /// [_rescheduleRestNotification]'s target.
  ({DateTime endsAt, int totalSeconds})? _currentRestTarget() {
    final settings = _currentRestSettings();
    if (!settings.restTimerEnabled) return null;
    final entry = _lastDoneEntry();
    if (entry == null) return null;
    final skipped = _restSkippedAt != null && _restSkippedAt == entry.doneAt;
    if (skipped) return null;
    final seconds = _currentEffectiveRestSeconds(entry.block, settings);
    final totalSeconds = seconds + _restAdjustment.inSeconds;
    final endsAt = entry.doneAt.add(Duration(seconds: totalSeconds));
    if (!endsAt.isAfter(DateTime.now())) return null;
    return (endsAt: endsAt, totalSeconds: totalSeconds);
  }

  /// The rest timer's current target end time, epoch ms — feeds the phone's
  /// own native countdown on both platforms via
  /// [WorkoutSessionState.restEndsAtEpochMs] (docs/39-rest-timer-plan.md,
  /// Prompt 5). Same-device only (Live Activity / Android notification) —
  /// safe to compare against this device's own wall clock. The watch bridge
  /// uses [_currentRestRemainingSeconds] instead, precisely to avoid that
  /// same comparison across two devices' potentially-unsynced wall clocks.
  int? _currentRestEndsAtEpochMs() => _currentRestTarget()?.endsAt.millisecondsSinceEpoch;

  /// The rest timer's full configured duration in seconds — feeds
  /// [WorkoutSessionState.restTotalSeconds] (docs/40-watch-app-plan.md §12.1
  /// B1) so the watch can render "0:47 of 1:30" instead of just "0:47".
  int? _currentRestTotalSeconds() => _currentRestTarget()?.totalSeconds;

  /// Seconds remaining *right now*, computed entirely against this device's
  /// own clock — feeds [WorkoutSessionState.restRemainingSeconds], which the
  /// watch bridge turns into a local deadline anchored to its own monotonic
  /// clock (`SystemClock.elapsedRealtime()`) instead of comparing timestamps
  /// across two devices' wall clocks. [_currentRestEndsAtEpochMs] doesn't
  /// work for this: a watch whose wall clock has drifted from the phone's
  /// (seen in practice on paired emulators, hours apart) would render a
  /// wildly wrong countdown from an absolute epoch target.
  int? _currentRestRemainingSeconds() {
    final target = _currentRestTarget();
    if (target == null) return null;
    return target.endsAt.difference(DateTime.now()).inSeconds;
  }

  String _formatElapsed() {
    if (_startedAt == null) return '0:00';
    final duration = (_finishedAt ?? _now).difference(_startedAt!);
    final h = duration.inHours;
    final m = duration.inMinutes % 60;
    final s = duration.inSeconds % 60;
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  /// targetSets here means "how many rows (done + blank) this exercise has
  /// right now", not the original template goal — so a blank row added via
  /// "+ add set" or removed via the delete icon regenerates correctly next
  /// time the session reopens, instead of always reverting to the template's
  /// original set count.
  List<PlannedExerciseInput> _buildPlanned() => _blocks
      .map((b) => PlannedExerciseInput(
            exerciseClientId: b.exerciseClientId,
            targetSets: b.rows.length,
          ))
      .toList();

  // Only rows with both reps and weight filled in count as a real set — a
  // row can be `isDone` (doneAt set) while still missing one of these, e.g.
  // if a stale autosave fires between marking a row done and the editor
  // sheet returning a value. Such rows are dropped here rather than sent
  // with a coalesced 0, which the backend would otherwise have to reject or
  // silently discard itself.
  List<ExerciseSetInput> _buildSets() => [
        for (final block in _blocks)
          for (final row in block.rows)
            if (row.isDone &&
                row.reps != null &&
                row.reps! > 0 &&
                row.weight != null)
              ExerciseSetInput(
                exerciseClientId: block.exerciseClientId,
                reps: row.reps!,
                weight: row.weight!,
                performedAt: row.doneAt!,
              ),
      ];

  void _navigateToDashboard() {
    context.go('/dashboard');
    Navigator.of(context).pop();
  }

  // ---------------------------------------------------------------------------
  // Block / row mutations
  // ---------------------------------------------------------------------------

  void _handleRowMarkDone(int bi, int ri) {
    setState(() {
      _blocks[bi].rows[ri].doneAt = DateTime.now();
      _recomputePrFlags(bi, justEditedRow: ri);
    });
    _syncRestEphemeralState();
    unawaited(_rescheduleRestNotification());
    _autoSave();
  }

  void _handleRowReopen(int bi, int ri) {
    setState(() {
      _blocks[bi].rows[ri].doneAt = null;
      _recomputePrFlags(bi);
    });
    // The reopened row may have been the latest done set — recompute and
    // reschedule against whichever set is now last, or cancel if none is
    // (docs/39-rest-timer-plan.md §2.3).
    _syncRestEphemeralState();
    unawaited(_rescheduleRestNotification());
    _autoSave();
  }

  void _handleRowEdit(int bi, int ri, double? weight, int? reps) {
    final wasDone = _blocks[bi].rows[ri].isDone;
    setState(() {
      _blocks[bi].rows[ri].weight = weight;
      _blocks[bi].rows[ri].reps = reps;
      _blocks[bi].rows[ri].doneAt ??= DateTime.now();
      _recomputePrFlags(bi, justEditedRow: ri);
    });
    // Only a freshly-stamped doneAt (row wasn't already done) starts a new
    // rest — editing the weight/reps of an already-done row doesn't move it.
    if (!wasDone) {
      _syncRestEphemeralState();
      unawaited(_rescheduleRestNotification());
    }
    _autoSave();
  }

  void _handleRowDelete(int bi, int ri) {
    setState(() {
      _blocks[bi].rows.removeAt(ri);
      _recomputePrFlagsForBlock(_blocks[bi]);
    });
    _syncRestEphemeralState();
    unawaited(_rescheduleRestNotification());
    _autoSave();
  }

  void _handleRowDuplicate(int bi, int ri) {
    final row = _blocks[bi].rows[ri];
    final nextIdx = ri + 1;
    setState(() {
      if (nextIdx < _blocks[bi].rows.length &&
          _blocks[bi].rows[nextIdx].weight == null &&
          _blocks[bi].rows[nextIdx].reps == null) {
        _blocks[bi].rows[nextIdx].weight = row.weight;
        _blocks[bi].rows[nextIdx].reps = row.reps;
      } else {
        _blocks[bi]
            .rows
            .insert(nextIdx, SetRow(weight: row.weight, reps: row.reps));
      }
    });
    _autoSave();
  }

  void _handleAddSet(int bi, {bool prefillFromPrevious = false}) {
    setState(() {
      final block = _blocks[bi];
      PreviousSetHint? hint;
      if (prefillFromPrevious &&
          block.rows.length < block.previousSets.length) {
        hint = block.previousSets[block.rows.length];
      }
      var weight = hint?.weight;
      var reps = hint?.reps;
      // No plan for this position and no prior-session hint either — this is
      // the watch "+1" tap's empty-row report: with nothing to go on, the
      // row used to stay genuinely blank (null weight, null reps) once
      // marked done. Instead, carry the weight forward from the last set
      // already logged for this exercise *this session* (so a run of
      // watch taps stays at the same working weight rather than reading as
      // 0), and default reps to 1 rather than leaving it null — a visible
      // placeholder the user can correct, never nothing at all.
      if (prefillFromPrevious && hint == null) {
        for (var i = block.rows.length - 1; i >= 0; i--) {
          final row = block.rows[i];
          if (row.isDone && row.weight != null) {
            weight = row.weight;
            break;
          }
        }
        reps = 1;
      }
      block.rows.add(SetRow(weight: weight, reps: reps));
    });
    _autoSave();
  }

  Future<void> _handleRemoveExercise(int bi) async {
    final hasDone = _blocks[bi].rows.any((r) => r.isDone);
    if (hasDone) {
      final l10n = AppLocalizations.of(context)!;
      final confirmed = await showAppConfirmDialog(
        context,
        title: l10n.removeExerciseTitle,
        message: l10n.removeExerciseConfirmMessage,
        confirmLabel: l10n.removeButton,
        cancelLabel: l10n.cancelButton,
        icon: Icons.remove_circle_rounded,
        accentColor: const Color(0xFFD66B5A),
      );
      if (confirmed != true || !mounted) return;
    }
    setState(() => _blocks.removeAt(bi));
    _syncRestEphemeralState();
    unawaited(_rescheduleRestNotification());
    await _autoSave();
  }

  Future<void> _handleAddExercise() async {
    final excluded = {for (final b in _blocks) b.exerciseClientId};
    final draft = await showModalBottomSheet<PlannedExerciseDraft>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => AddExerciseToSessionSheet(excludeIds: excluded),
    );
    if (draft == null || !mounted) return;
    final block = ExerciseBlock(
      exerciseClientId: draft.exercise.clientId,
      exerciseName: draft.exercise.name,
      targetSets: draft.targetSets,
      rows: _generateRows(draft.targetSets),
    );
    setState(() => _blocks.add(block));
    unawaited(_loadPreviousPerformance([block]));
    unawaited(_loadPrBaselines([block]));
    await _autoSave();
  }

  // ---------------------------------------------------------------------------
  // Persistence
  // ---------------------------------------------------------------------------

  Future<void> _autoSave() async {
    if (_saving) {
      // A save is already writing an older snapshot — remember that a newer
      // one is waiting so it gets persisted once that save completes,
      // instead of being silently dropped.
      _dirty = true;
      return;
    }
    setState(() => _saving = true);
    final l10n = AppLocalizations.of(context)!;
    try {
      await _persist();
    } catch (_) {
      if (mounted) {
        AppSnackbar.showError(context, title: l10n.couldNotSaveSessionMessage);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
      final needsReplay = _dirty;
      _dirty = false;
      if (needsReplay) unawaited(_autoSave());
    }
  }

  Future<void> _persist() async {
    final notifier = ref.read(workoutSessionControllerProvider.notifier);
    final existingId = _sessionClientId;
    if (existingId == null) {
      // First real save: stamp the start time now and kick off the ticker.
      // Any call reaching here already followed a real user action (a set
      // logged, a row/exercise added or removed, etc — see the call sites of
      // _autoSave) rather than just mounting the screen, so it's safe to
      // create the session immediately instead of waiting specifically for
      // the first done set: otherwise plan-only edits (e.g. a blank row
      // added via "+ Add set" before any set is marked done) live only in
      // memory and are silently dropped if the screen is torn down and
      // rebuilt from the last persisted DB state (e.g. resuming via the Live
      // Activity/notification tap — see [isWorkoutScreenOpenFor]).
      if (_startedAt == null) {
        _startedAt = DateTime.now();
        if (_finishedAt == null) {
          setState(() {});
          _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
            if (mounted) setState(() => _now = DateTime.now());
          });
          _hrTicker = Timer.periodic(_kHrPollInterval, (_) => _pollHeartRate());
          _pollHeartRate();
        }
      }

      _sessionClientId = await notifier.logSession(
        startedAt: _startedAt!,
        finishedAt: _finishedAt,
        exercises: _buildPlanned(),
        sets: _buildSets(),
        templateClientId: widget.template?.clientId,
        templateName: widget.template?.name,
        rpe: _rpe,
        feedbackNote: _feedbackNote,
      );
      // This screen now owns a real session: claim it in the registry so a
      // Live Activity/notification tap reopens *this* screen instead of
      // rebuilding a second one from the row just written.
      _openScreen?.sessionClientId = _sessionClientId;
    } else {
      await notifier.updateSession(
        existingId,
        startedAt: _startedAt!,
        finishedAt: _finishedAt,
        exercises: _buildPlanned(),
        sets: _buildSets(),
        rpe: _rpe,
        feedbackNote: _feedbackNote,
      );
    }

    // Session notifier (Live Activity / ongoing notification): the first
    // successful persist of a running session starts it, every one after
    // that updates it. Never touches a finished session — _persistFinished
    // ends it explicitly instead. A persist whose start was refused stays on
    // this branch, so every later set is another retry (alongside the
    // foreground one in [didChangeAppLifecycleState]).
    if (_finishedAt == null && mounted) {
      // Always push the state — the watch half of it must reach the wrist on
      // every logged set even when the indicator itself never came up (see
      // [_updateSessionNotifier]). Kicking off a start attempt as well is
      // what makes every persist a retry point for a refused Live Activity.
      if (!_sessionNotifierStarted) unawaited(_startSessionNotifier());
      unawaited(_updateSessionNotifier());
    }
  }

  // ---------------------------------------------------------------------------
  // Session notifier (Live Activity on iOS, ongoing notification on Android)
  // ---------------------------------------------------------------------------

  /// The block whose set was most recently marked done, falling back to the
  /// first block with remaining (not-yet-done) sets — the plan's "current
  /// exercise" rule for the session notifier. Null only when there are no
  /// blocks at all.
  ///
  /// On a watch-mastered session the watch's own answer wins over that rule —
  /// see [_watchCurrentBlock].
  ExerciseBlock? _currentExerciseBlock() {
    if (_blocks.isEmpty) return null;
    final watchCurrent = _watchCurrentBlock();
    if (watchCurrent != null) return watchCurrent;
    ExerciseBlock? mostRecent;
    DateTime? mostRecentAt;
    for (final block in _blocks) {
      for (final row in block.rows) {
        final doneAt = row.doneAt;
        if (doneAt != null &&
            (mostRecentAt == null || doneAt.isAfter(mostRecentAt))) {
          mostRecentAt = doneAt;
          mostRecent = block;
        }
      }
    }
    if (mostRecent != null) return mostRecent;
    return _blocks.firstWhere(
      (b) => b.rows.any((r) => !r.isDone),
      orElse: () => _blocks.first,
    );
  }

  /// The block the *watch* says its next set will count against, on a
  /// watch-mastered session (see
  /// [WatchStandaloneAdoption.currentExerciseIndex]). Null for every
  /// phone-mastered session, for a Quick strength one (no plan), and
  /// whenever the reported index can't be resolved — a template that hasn't
  /// loaded yet, or one that shrank since the watch cached it. Every one of
  /// those falls back to [_currentExerciseBlock]'s own rule rather than
  /// guessing.
  ///
  /// This matters because "current exercise" drives what the phone publishes
  /// back: the `nextSetWeight`/`nextSetReps` prefill the watch's stepper
  /// opens on, and the exercise name/counts on the Live Activity. The phone's
  /// own rule is "the exercise of the most recently logged set", which lags a
  /// full exercise behind on the watch's flow — the watch moves on as soon as
  /// an exercise has all its planned sets, so at that moment the phone was
  /// still describing the finished one.
  /// The session's block for [exerciseClientId], or null when this session
  /// doesn't (or no longer) contains it — the watch naming an exercise that
  /// was removed on the phone between the tap and its delivery.
  ExerciseBlock? _blockForExerciseId(String? exerciseClientId) {
    if (exerciseClientId == null) return null;
    for (final block in _blocks) {
      if (block.exerciseClientId == exerciseClientId) return block;
    }
    return null;
  }

  ExerciseBlock? _watchCurrentBlock() =>
      watchCurrentBlock(
        _blocks,
        _templateExerciseIds,
        _watchCurrentExerciseIndex,
        currentExerciseClientId: _watchCurrentExerciseClientId,
      );

  WorkoutSessionState _sessionState(AppLocalizations l10n) {
    // Everything published here — the exercise name, its set counts and the
    // adjust stepper's prefill — describes **one** exercise: the one the next
    // set will count against. Which device gets to answer that differs:
    //
    // - watch-mastered: the watch does, and its answer is final (`watchCurrent`
    //   is exactly what it reported). Its pick holds even when that exercise
    //   already has all its planned sets — the user selected it from the wrist
    //   to add one more, so the prefill is pinned to that block rather than run
    //   through [selectWatchSetLogTarget], whose rule (b) would leave it for
    //   the first exercise with a row still open ("the adjust stepper shows the
    //   *next* exercise's values" report);
    // - phone-mastered: the phone's own row-selection rule does, and that is
    //   [selectWatchSetLogTarget]'s target — not [_currentExerciseBlock], which
    //   answers "the exercise of the most recently logged set" and therefore
    //   stays on an exercise whose sets are all done. The watch would then show
    //   "Bench · 3/3 sets" (and the Live Activity the same) while its next tap
    //   already logged into the next exercise, with that exercise's prefill.
    final watchCurrent = _watchCurrentBlock();
    final ExerciseBlock? current;
    final WatchSetPrefill? prefill;
    if (watchCurrent != null) {
      current = watchCurrent;
      prefill = watchSetPrefillForBlock(watchCurrent);
    } else {
      final phoneCurrent = _currentExerciseBlock();
      final target = selectWatchSetLogTarget(_blocks, phoneCurrent);
      current = target == null ? phoneCurrent : _blocks[target.blockIndex];
      prefill = watchSetPrefill(_blocks, phoneCurrent);
    }
    final totalSetsDone = _blocks.fold<int>(
        0, (sum, b) => sum + b.rows.where((r) => r.isDone).length);
    return WorkoutSessionState(
      exerciseName: (current != null && current.exerciseName.isNotEmpty)
          ? current.exerciseName
          : l10n.liveActivityDefaultExerciseName,
      setsDone: current?.rows.where((r) => r.isDone).length ?? 0,
      // current.targetSets is the frozen original plan count — a row added
      // ad-hoc via "+ Add set" (or removed) doesn't update it. rows.length
      // is the live count, matching setsDone's own semantics above; using
      // targetSets here made the watch/Live-Activity "N of total" freeze at
      // the session's starting value forever (docs/40-watch-app-plan.md
      // §12.1 B-fixes).
      setsTotal: current?.rows.length,
      totalSetsDone: totalSetsDone,
      lastSetAtEpochMs: _lastDoneAt()?.millisecondsSinceEpoch,
      restEndsAtEpochMs: _currentRestEndsAtEpochMs(),
      restTotalSeconds: _currentRestTotalSeconds(),
      restRemainingSeconds: _currentRestRemainingSeconds(),
      nextSetWeight: prefill?.weight,
      nextSetReps: prefill?.reps,
      // Tagged with the watch's own exercise index only when the counts above
      // describe the exercise *it* named — never when they describe the phone's
      // own choice of current exercise (see
      // [WorkoutSessionState.setsDoneExerciseIndex]).
      setsDoneExerciseIndex: watchCurrent != null ? _watchCurrentExerciseIndex : null,
      setsDoneExerciseId: watchCurrent?.exerciseClientId,
      setsDonePerExercise: _watchSetsDonePerExercise(),
      removedExerciseIndexes: _watchRemovedExerciseIndexes(),
      sessionPlan: _watchSessionPlan(),
      kind: 'STRENGTH',
    );
  }

  /// Done-set counts for the whole plan, in the watch's index order — see
  /// [WorkoutSessionState.setsDonePerExercise] for why the current exercise's
  /// count alone wasn't enough.
  ///
  /// Null unless this is a watch-mastered session whose template order is
  /// known: that order *is* the watch's index space (both sides read the same
  /// synced template), and it's the only thing that makes the positions mean
  /// the same on both devices. An exercise the plan has but this session has
  /// no block for counts as 0 rather than being skipped, so the positions
  /// stay aligned.
  List<int>? _watchSetsDonePerExercise() {
    if (!_watchMastered || _templateExerciseIds.isEmpty) return null;
    final doneByExercise = <String, int>{};
    for (final block in _blocks) {
      doneByExercise[block.exerciseClientId] =
          block.rows.where((r) => r.isDone).length;
    }
    return [
      for (final exerciseClientId in _templateExerciseIds)
        doneByExercise[exerciseClientId] ?? 0,
    ];
  }

  /// The plan positions this session no longer contains, for the watch's
  /// exercise list — see [WorkoutSessionState.removedExerciseIndexes].
  ///
  /// Same gate and same index space as [_watchSetsDonePerExercise]: an
  /// exercise the plan lists but this session has no block for was removed on
  /// this screen (the mirror's blocks are rebuilt from the session row, which
  /// the removal already rewrote). Null rather than an empty list in the
  /// ordinary "nothing removed" case, so the key doesn't travel at all.
  List<int>? _watchRemovedExerciseIndexes() {
    if (!_watchMastered || _templateExerciseIds.isEmpty) return null;
    final present = {for (final block in _blocks) block.exerciseClientId};
    final removed = [
      for (var i = 0; i < _templateExerciseIds.length; i++)
        if (!present.contains(_templateExerciseIds[i])) i,
    ];
    return removed.isEmpty ? null : removed;
  }

  /// The session's own exercise list for the watch (F6c) — see
  /// [WorkoutSessionState.sessionPlan].
  ///
  /// Sent for **every** session, not just watch-mastered ones: the wrist's
  /// exercise picker works in a phone-started workout too now, and this list
  /// is what it shows (docs/watch/50-watch-f6c-session-plan-sync-plan.md §7).
  /// Unlike [_watchSetsDonePerExercise] it needs no template — it *is* the
  /// answer the template can't give, and it stays correct for a Quick strength
  /// session that has since gained exercises on the phone.
  String? _watchSessionPlan() {
    final settings = _currentRestSettings();
    return buildWatchSessionPlanJson(
      blocks: _blocks,
      restSecondsFor: (block) => _currentEffectiveRestSeconds(block, settings),
    );
  }

  String _sessionTitle(AppLocalizations l10n) =>
      widget.session?.templateName ??
      widget.template?.name ??
      l10n.liveActivityDefaultTitle;

  /// Brings up the Live Activity / ongoing notification, and (once) tells the
  /// watch to start its own session. Safe to call repeatedly — it's the retry
  /// entry point as well as the first attempt: no-ops while one is in flight,
  /// once the indicator is up, once the platform has refused for good, and
  /// before there's a session/start time to describe.
  Future<void> _startSessionNotifier() async {
    if (!mounted) return;
    final sessionClientId = _sessionClientId;
    final startedAt = _startedAt;
    if (sessionClientId == null || startedAt == null || _finishedAt != null) return;

    final l10n = AppLocalizations.of(context)!;
    final state = _sessionState(l10n);

    // Best-effort, alongside (not instead of) the Live Activity/ongoing
    // notification below — see docs/40-watch-app-plan.md §6.2 — and gated
    // only on its own latch: whether the phone's indicator started, was
    // refused, or is switched off entirely says nothing about whether the
    // watch should mirror this workout. Sent once per screen, so a retry of
    // the indicator doesn't ask the watch to start a second session. Skipped
    // for a watch-mastered session: the watch is already running this exact
    // workout, so asking it to start one would at best be ignored (both
    // platforms reject a phone start during standalone) and at worst read as
    // a conflict.
    if (_watchEnabled && !_watchMastered && !_watchStartPushed) {
      _watchStartPushed = true;
      unawaited(ref.read(watchWorkoutServiceProvider).startWorkout(
            sessionClientId: sessionClientId,
            title: _sessionTitle(l10n),
            startedAt: startedAt,
            state: state,
          ));
    }

    if (_startingSessionNotifier ||
        _sessionNotifierStarted ||
        _sessionNotifierUnavailable) {
      return;
    }
    _startingSessionNotifier = true;
    try {
      final result = await ref.read(workoutSessionNotifierServiceProvider).start(
            sessionClientId: sessionClientId,
            title: _sessionTitle(l10n),
            startedAt: startedAt,
            startedLabel: l10n.startedLabel,
            state: state,
          );
      _sessionNotifierStarted = result.started;
      // A retryable refusal leaves both flags false: the next persisted set
      // and the next foreground both try again.
      _sessionNotifierUnavailable =
          result.status == WorkoutSessionNotifierStatus.unavailable;
    } finally {
      _startingSessionNotifier = false;
    }
  }

  /// Pushes the current state to both surfaces. The indicator update no-ops
  /// natively when there's nothing showing (iOS finds no activity, Android has
  /// no notification to re-render), so this is safe to call whether or not
  /// [_startSessionNotifier] ever succeeded — and it has to be, because the
  /// watch push below must not be collateral damage of a Live Activity that
  /// was refused or switched off.
  Future<void> _updateSessionNotifier() async {
    if (!mounted) return;
    final sessionClientId = _sessionClientId;
    if (sessionClientId == null) return;
    final l10n = AppLocalizations.of(context)!;
    final state = _sessionState(l10n);
    await ref.read(workoutSessionNotifierServiceProvider).update(
          sessionClientId: sessionClientId,
          startedLabel: l10n.startedLabel,
          state: state,
        );
    // Pushed for a watch-mastered session too — unlike `startWorkout`, which
    // would ask the watch to start a session it is already running. This is
    // how the watch-started path gets the `nextSetWeight`/`nextSetReps`
    // prefill and (for the exercise it named) the real set counts, which
    // include the sets logged here on the phone — its own list has no idea
    // about those. See `WorkoutSessionState.setsDoneExerciseIndex`.
    if (_watchEnabled) {
      unawaited(ref.read(watchWorkoutServiceProvider).updateState(
            sessionClientId: sessionClientId,
            state: state,
          ));
    }
  }

  /// Shows the post-workout feedback sheet (skippable) and stores the result
  /// in state so the next [_persist] call carries it. Called right after a
  /// session finishes, before any health-workout pairing dialogs — the rating
  /// doesn't depend on that flow.
  Future<void> _maybeCollectFeedback() async {
    final result = await showPostWorkoutFeedbackSheet(
      context,
      initialRpe: _rpe,
      initialNote: _feedbackNote,
    );
    if (result == null || !mounted) return;
    setState(() {
      _rpe = result.rpe;
      _feedbackNote = result.feedbackNote;
    });
  }

  /// Reopens the feedback sheet to edit an already-saved rating (from the
  /// inline section on a finished session) and autosaves the change like any
  /// other field edit on this screen.
  Future<void> _editFeedback() async {
    final result = await showPostWorkoutFeedbackSheet(
      context,
      initialRpe: _rpe,
      initialNote: _feedbackNote,
    );
    if (result == null || !mounted) return;
    setState(() {
      _rpe = result.rpe;
      _feedbackNote = result.feedbackNote;
    });
    unawaited(_autoSave());
  }

  /// Shows the celebration dialog if the just-finished session improved on
  /// at least 2 metrics net vs. the previous one for each exercise. No-op
  /// (and returns immediately) otherwise. Awaited so callers navigate away
  /// only after the user dismisses it.
  Future<void> _maybeShowWorkoutSuccess() async {
    final l10n = AppLocalizations.of(context)!;
    final progress = computeWorkoutProgress(_blocks, l10n);
    if (!progress.isSuccess) return;
    await showWorkoutSuccessDialog(context, progress);
  }

  /// Stamps finishedAt = now, stops the ticker, and persists.
  /// Does NOT navigate — the caller decides where to go.
  Future<void> _persistFinished() async {
    _finishedAt = DateTime.now();
    // If no set was ever logged, start = finish (session was created via Finish).
    _startedAt ??= _finishedAt;
    _ticker?.cancel();
    _ticker = null;
    _hrTicker?.cancel();
    _hrTicker = null;
    _deactivateMusic();
    // _rescheduleRestNotification() sees _finishedAt set and cancels.
    unawaited(_rescheduleRestNotification());
    await _persist();
    if (_sessionNotifierStarted) {
      _sessionNotifierStarted = false;
      unawaited(ref.read(workoutSessionNotifierServiceProvider).end());
    }
    // Keyed on the watch having a session for this id, not on the indicator:
    // the two are independent (see [_watchStartPushed]), and a Live Activity
    // that never came up must not leave the watch's own session running
    // forever. `_watchMastered` counts too — the phone never sent that one a
    // `startWorkout` (the watch started it), but ending the workout here still
    // has to close it on the wrist, which is exactly what the watch's
    // adopted-standalone `end` handler does. The watch answers asynchronously
    // with a summary on WatchWorkoutService.events, handled by
    // WorkoutResumePrompt — not here (docs/40-watch-app-plan.md §3 "Lezárás").
    if (_watchStartPushed || _watchMastered) {
      unawaited(ref.read(watchWorkoutServiceProvider).endWorkout(_sessionClientId!));
    }
  }

  /// Finish button handler. No more health-workout pairing (removed —
  /// `activeCalories`/`averageHeartRate`/`healthWorkoutId` now come from the
  /// watch summary instead, see docs/40-watch-app-plan.md and
  /// [workoutResumePromptProvider]'s `_onWatchEvent`): RPE feedback, then
  /// straight to persisted + dashboard.
  Future<void> _finishWorkout() async {
    if (_saving) return;
    setState(() => _saving = true);
    final l10n = AppLocalizations.of(context)!;

    try {
      await _maybeCollectFeedback();
      if (!mounted) return;

      await _persistFinished();
      if (!mounted) return;
      await _maybeShowWorkoutSuccess();
      if (!mounted) return;
      await _maybeShowInterstitial();
      if (!mounted) return;
      _navigateToDashboard();
    } catch (_) {
      if (mounted) {
        AppSnackbar.showError(context, title: l10n.couldNotSaveSessionMessage);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// The watch's End button handler. [rpe] is whatever the watch's own
  /// effort stepper produced (null if the user skipped it) — unlike
  /// [_finishWorkout], this never shows [PostWorkoutFeedbackSheet]: the
  /// rating was already collected (or deliberately skipped) on the watch, so
  /// [_feedbackNote] is left untouched and stays empty.
  Future<void> _finishWorkoutFromWatch(int? rpe) async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _rpe = rpe;
    });
    final l10n = AppLocalizations.of(context)!;

    try {
      await _persistFinished();
      if (!mounted) return;
      await _maybeShowWorkoutSuccess();
      if (!mounted) return;
      await _maybeShowInterstitial();
      if (!mounted) return;
      _navigateToDashboard();
    } catch (_) {
      if (mounted) {
        AppSnackbar.showError(context, title: l10n.couldNotSaveSessionMessage);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// `67` §5.3: fired after a workout session is successfully saved,
  /// regardless of how the Finish action was reached.
  Future<void> _maybeShowInterstitial() {
    return ref
        .read(interstitialManagerProvider)
        .maybeShow(context, InterstitialReason.workoutSaved);
  }

  // ---------------------------------------------------------------------------
  // Top bar
  // ---------------------------------------------------------------------------

  /// Tappable "how hard was it?" card for a finished session — shows the
  /// saved rating/note, or an empty-state prompt when unrated. Tapping
  /// either state reopens [PostWorkoutFeedbackSheet] via [_editFeedback].
  Widget _buildFeedbackSection(BuildContext context, AppLocalizations l10n) {
    final scheme = Theme.of(context).colorScheme;
    final rpe = _rpe;
    final note = _feedbackNote;
    return InkWell(
      onTap: _editFeedback,
      borderRadius: BorderRadius.circular(AppRadius.input),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppRadius.input),
        ),
        child: Row(
          children: [
            if (rpe != null)
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$rpe',
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
              )
            else
              Icon(Icons.mood_rounded,
                  size: 21, color: scheme.onSurfaceVariant),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    rpe != null
                        ? l10n.postWorkoutFeedbackSectionTitle
                        : l10n.postWorkoutFeedbackEmptyState,
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                    ),
                  ),
                  if (note != null && note.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        note,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 11.5,
                          color: scheme.onSurfaceVariant.withValues(alpha: 0.8),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Icon(Icons.chevron_right,
                size: 20,
                color: scheme.onSurfaceVariant.withValues(alpha: 0.6)),
          ],
        ),
      ),
    );
  }

  /// Non-tappable "Trainer comment" block — shown only when present, no
  /// reply affordance (the push notification is the only attention
  /// mechanism; this block is just the persistent record). See
  /// docs/31-session-feedback-loop-plan.md, M2.
  Widget _buildTrainerCommentSection(
      BuildContext context, AppLocalizations l10n) {
    final scheme = Theme.of(context).colorScheme;
    final comment = widget.session!.trainerComment!;
    final commentAt = widget.session!.trainerCommentAt;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.input),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.chat_bubble_outline_rounded,
              size: 21, color: scheme.onSurfaceVariant),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.trainerCommentLabel,
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    comment,
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 11.5,
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.8),
                    ),
                  ),
                ),
                if (commentAt != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      _label.format(commentAt),
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 10.5,
                        color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, ColorScheme scheme,
      AppLocalizations l10n, String title) {
    return Container(
      height: 58,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.30),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            color: scheme.surfaceContainer.withValues(alpha: 0.92),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Center(
                      child: Icon(Icons.arrow_back,
                          size: 22, color: scheme.onSurfaceVariant),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: scheme.onSurface,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
                if (_startedAt != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.timer, size: 18, color: scheme.primary),
                        const SizedBox(width: 6),
                        Text(
                          _formatElapsed(),
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: scheme.onSurface,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                // "Measuring" pill (docs/40-watch-app-plan.md §12.4 B14):
                // the watch confirmed its own session started, until it ends
                // or reachability is lost. Icon-only — the label is still
                // exposed via the tooltip/semantics for accessibility.
                if (_measuringOnWatch && _finishedAt == null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Tooltip(
                      message: l10n.watchMeasuringPillLabel,
                      child: Icon(
                        Icons.watch,
                        size: 18,
                        color: scheme.primary,
                        semanticLabel: l10n.watchMeasuringPillLabel,
                      ),
                    ),
                  ),
                ],
                // Near-live heart rate, shown while a fresh sample is arriving.
                if (_showHeartRate && _currentHeartRate != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.favorite,
                            size: 18, color: context.metricColors.heart),
                        const SizedBox(width: 6),
                        Text(
                          '$_currentHeartRate',
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: scheme.onSurface,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                // Live calories burned, pushed from the watch's own session
                // — only ever available while a connected watch is actively
                // measuring (see [WatchLiveMetrics]).
                if (_watchActiveCalories != null && _finishedAt == null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.local_fire_department,
                            size: 18, color: context.metricColors.calories),
                        const SizedBox(width: 6),
                        Text(
                          '${_watchActiveCalories!.round()}',
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: scheme.onSurface,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final template = widget.template;
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;

    // Resolve exercise names for template-seeded blocks (TemplateExercise has no name).
    final Map<String, Exercise> exercisesById =
        ref.watch(exerciseControllerProvider).maybeWhen(
              data: (list) => {for (final e in list) e.clientId: e},
              orElse: () => const {},
            );
    for (final block in _blocks) {
      if (block.exerciseName.isEmpty) {
        block.exerciseName = exercisesById[block.exerciseClientId]?.name ?? '';
      }
      block.exerciseCategory = exercisesById[block.exerciseClientId]?.category;
    }

    // ── Rest timer (docs/39-rest-timer-plan.md §2.1/§2.4) ──
    final restSettings = ref.watch(settingsControllerProvider).value ??
        const UserSettings.defaults();
    final lastDoneEntry = _lastDoneEntry();
    final lastDoneAt = lastDoneEntry?.doneAt;
    _syncRestEphemeralState();

    final restIsSkipped =
        _restSkippedAt != null && _restSkippedAt == lastDoneAt;
    final restTimerActive = restSettings.restTimerEnabled &&
        _finishedAt == null &&
        lastDoneEntry != null &&
        !restIsSkipped;
    int? restTargetSeconds;
    bool restIsOvertime = false;
    if (restTimerActive) {
      restTargetSeconds = _effectiveRestSeconds(
          lastDoneEntry.block, exercisesById, restSettings);
      final target = Duration(seconds: restTargetSeconds) + _restAdjustment;
      final elapsed = _now.difference(lastDoneEntry.doneAt);
      restIsOvertime = elapsed >= target;
      if (restIsOvertime && !_restOvertimeHapticFired) {
        _restOvertimeHapticFired = true;
        WidgetsBinding.instance.addPostFrameCallback(
            (_) => unawaited(HapticFeedback.mediumImpact()));
      }
    }

    final safeBottom = MediaQuery.paddingOf(context).bottom;
    final statusTop = MediaQuery.paddingOf(context).top;
    final barTop = statusTop + 8.0;
    final restBannerVisible =
        _finishedAt == null && lastDoneAt != null && !restIsSkipped;
    final restBannerHeight =
        (restBannerVisible && restSettings.restTimerEnabled) ? 74.0 : 50.0;
    final restBannerTop = barTop + 58.0 + 8.0;
    final contentTop = restBannerVisible
        ? restBannerTop + restBannerHeight + 8.0
        : barTop + 58.0 + 8.0;

    // Finish button is only shown for running (not-yet-finished) sessions.
    final showFinishButton = _finishedAt == null;
    // ListView needs extra bottom room so content isn't hidden behind the sticky button.
    final listBottomPad =
        showFinishButton ? (safeBottom + 24 + 54 + 16) : (safeBottom + 16);

    final title = _isEditing
        ? (widget.session!.templateName ?? l10n.editWorkoutTitle)
        : (template != null ? template.name : l10n.logWorkoutTitle);

    return Scaffold(
      body: Stack(
        children: [
          // ── Scrollable content ──
          ListView(
            padding: EdgeInsets.fromLTRB(16, contentTop, 16, listBottomPad),
            children: [
              // Health stat cards (watch-enriched finished sessions only).
              if (widget.session?.finishedAt != null &&
                  widget.session!.enrichedFromWatch) ...[
                Row(
                  children: [
                    Expanded(
                      child: _HealthStatCard(
                        icon: Icons.local_fire_department,
                        iconColor: context.metricColors.calories,
                        value: widget.session!.activeCalories
                                ?.round()
                                .toString() ??
                            '–',
                        label: l10n.activeKcalLabel,
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: _HealthStatCard(
                        icon: Icons.favorite,
                        iconColor: context.metricColors.heart,
                        value: widget.session!.averageHeartRate
                                ?.round()
                                .toString() ??
                            '–',
                        label: l10n.avgBpmLabel,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 13),
              ],

              // Post-workout difficulty rating + note — editable any time
              // after the session is finished, autosaves via _editFeedback.
              if (_finishedAt != null) ...[
                _buildFeedbackSection(context, l10n),
                const SizedBox(height: 13),
              ],

              // Trainer's comment on this session, if any — persistent
              // record only, no reply affordance (docs/31-session-feedback-loop-plan.md, M2).
              if (widget.session?.trainerComment != null) ...[
                _buildTrainerCommentSection(context, l10n),
                const SizedBox(height: 13),
              ],

              // Exercise cards.
              for (int bi = 0; bi < _blocks.length; bi++) ...[
                ExerciseSessionCard(
                  key: ValueKey(_blocks[bi].exerciseClientId),
                  block: _blocks[bi],
                  onRowMarkDone: (ri) => _handleRowMarkDone(bi, ri),
                  onRowReopen: (ri) => _handleRowReopen(bi, ri),
                  onRowEdit: (ri, w, r) => _handleRowEdit(bi, ri, w, r),
                  onRowDelete: (ri) => _handleRowDelete(bi, ri),
                  onRowDuplicate: (ri) => _handleRowDuplicate(bi, ri),
                  onAddSet: (prefill) =>
                      _handleAddSet(bi, prefillFromPrevious: prefill),
                  onRemoveExercise: () => _handleRemoveExercise(bi),
                ),
                const SizedBox(height: 13),
              ],

              // Dashed "Add exercise" button.
              _AddExerciseButton(onTap: _handleAddExercise, scheme: scheme),
            ],
          ),

          // ── Floating top bar ──
          Positioned(
            top: barTop,
            left: 12,
            right: 12,
            child: _buildTopBar(context, scheme, l10n, title),
          ),

          // ── Pinned rest banner ──
          if (restBannerVisible)
            Positioned(
              top: restBannerTop,
              left: 16,
              right: 16,
              child: _RestBanner(
                lastSetAt: lastDoneAt,
                now: _now,
                enabled: restSettings.restTimerEnabled,
                targetSeconds: restTargetSeconds,
                adjustment: _restAdjustment,
                isOvertime: restIsOvertime,
                onAddFifteen: () {
                  setState(
                      () => _restAdjustment += const Duration(seconds: 15));
                  unawaited(_rescheduleRestNotification());
                  // Keep the native Live Activity / Android chronometer
                  // countdown in sync (docs/39-rest-timer-plan.md, Prompt 5)
                  // — otherwise it'd only pick up the new target on the next
                  // autosave.
                  if (_sessionNotifierStarted) {
                    unawaited(_updateSessionNotifier());
                  }
                },
                onSkip: () {
                  setState(() => _restSkippedAt = lastDoneAt);
                  unawaited(NotificationService.cancelRestEnd());
                  if (_sessionNotifierStarted) {
                    unawaited(_updateSessionNotifier());
                  }
                },
              ),
            ),

          // ── Sticky music button + "Finish workout" button ──
          // The music button only shows alongside Finish — both gated on
          // "running session" (docs/music/46-workout-music-controls-plan.md
          // §3.4); it never grows the sticky zone's height (listBottomPad
          // above stays keyed to the Finish button's own 54px alone).
          if (showFinishButton)
            Positioned(
              bottom: safeBottom + 24,
              left: 16,
              right: 16,
              child: Row(
                children: [
                  const MusicStickyButton(),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SizedBox(
                      height: 54,
                      child: FilledButton.icon(
                        onPressed: _saving ? null : _finishWorkout,
                        style: FilledButton.styleFrom(
                          backgroundColor: scheme.primary,
                          foregroundColor: scheme.onPrimary,
                          disabledBackgroundColor:
                              scheme.primary.withValues(alpha: 0.6),
                          disabledForegroundColor:
                              scheme.onPrimary.withValues(alpha: 0.7),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          textStyle: const TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        icon: _saving
                            ? SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: scheme.onPrimary.withValues(alpha: 0.7),
                                ),
                              )
                            : const Icon(Icons.check, size: 20),
                        label: Text(l10n.finishWorkoutButton),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Dashed "Add exercise" button
// ---------------------------------------------------------------------------

class _AddExerciseButton extends StatelessWidget {
  const _AddExerciseButton({required this.onTap, required this.scheme});

  final VoidCallback onTap;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: CustomPaint(
        painter: _DashedBorderPainter(
          color: scheme.outline,
          radius: AppRadius.input,
          strokeWidth: 1.5,
        ),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.input),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add, size: 21, color: scheme.onSurfaceVariant),
              const SizedBox(width: 7),
              Text(
                AppLocalizations.of(context)!.addExerciseTitle,
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({
    required this.color,
    required this.radius,
    required this.strokeWidth,
  });

  final Color color;
  final double radius;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final inset = strokeWidth / 2;
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
          inset, inset, size.width - strokeWidth, size.height - strokeWidth),
      Radius.circular(radius),
    );
    const dashLen = 7.0;
    const gapLen = 5.0;

    for (final metric in (Path()..addRRect(rrect)).computeMetrics()) {
      var distance = 0.0;
      var drawing = true;
      while (distance < metric.length) {
        final next =
            (distance + (drawing ? dashLen : gapLen)).clamp(0.0, metric.length);
        if (drawing) canvas.drawPath(metric.extractPath(distance, next), paint);
        distance = next;
        drawing = !drawing;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) =>
      old.color != color ||
      old.strokeWidth != strokeWidth ||
      old.radius != radius;
}

// ---------------------------------------------------------------------------
// Rest banner
// ---------------------------------------------------------------------------

class _RestBanner extends StatelessWidget {
  const _RestBanner({
    required this.lastSetAt,
    required this.now,
    required this.enabled,
    required this.targetSeconds,
    required this.adjustment,
    required this.isOvertime,
    required this.onAddFifteen,
    required this.onSkip,
  });

  final DateTime lastSetAt;
  final DateTime now;

  /// Whether the rest-timer feature is on (`UserSettings.restTimerEnabled`).
  /// When false, this renders today's plain elapsed-since-last-set count-up
  /// with no buttons — the feature degrades, it never disappears.
  final bool enabled;

  /// The effective rest duration for the last-done set's exercise, seconds.
  /// Null when [enabled] is false (unused in that branch).
  final int? targetSeconds;

  /// Accumulated +15s taps for the current rest.
  final Duration adjustment;
  final bool isOvertime;
  final VoidCallback onAddFifteen;
  final VoidCallback onSkip;

  static const _warnColor = Color(0xFFD66B5A);

  String _mmss(Duration d) {
    final m = d.inMinutes;
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final elapsed = now.difference(lastSetAt);

    if (!enabled) {
      return _container(
        scheme: scheme,
        child: _headerRow(
          context: context,
          icon: Icons.hourglass_top,
          iconColor: scheme.primary,
          timeText: _mmss(elapsed),
          timeColor: scheme.primary,
          l10n: l10n,
        ),
      );
    }

    final target = Duration(seconds: targetSeconds!) + adjustment;

    if (isOvertime) {
      final overage = elapsed - target;
      return _container(
        scheme: scheme,
        accentColor: _warnColor,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _headerRow(
              context: context,
              icon: Icons.hourglass_bottom,
              iconColor: _warnColor,
              timeText: '+${_mmss(overage)}',
              timeColor: _warnColor,
              l10n: l10n,
              trailing: _RestIconButton(
                icon: Icons.close,
                color: _warnColor,
                tooltip: l10n.restTimerSkipButton,
                onTap: onSkip,
              ),
            ),
            const SizedBox(height: 8),
            _progressBar(color: _warnColor, value: 1),
          ],
        ),
      );
    }

    final remaining = target - elapsed;
    final progress = target.inMilliseconds == 0
        ? 1.0
        : (elapsed.inMilliseconds / target.inMilliseconds).clamp(0.0, 1.0);

    return _container(
      scheme: scheme,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _headerRow(
            context: context,
            icon: Icons.hourglass_top,
            iconColor: scheme.primary,
            timeText: _mmss(remaining),
            timeColor: scheme.primary,
            l10n: l10n,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _RestActionChip(
                  label: l10n.restTimerAddSecondsButton,
                  color: scheme.primary,
                  onTap: onAddFifteen,
                ),
                const SizedBox(width: 6),
                _RestIconButton(
                  icon: Icons.close,
                  color: scheme.onSurfaceVariant,
                  tooltip: l10n.restTimerSkipButton,
                  onTap: onSkip,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _progressBar(color: scheme.primary, value: progress),
        ],
      ),
    );
  }

  Widget _container({
    required ColorScheme scheme,
    required Widget child,
    Color? accentColor,
  }) {
    final accent = accentColor ?? scheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.input),
        border: Border.all(color: accent.withValues(alpha: 0.40)),
      ),
      child: child,
    );
  }

  Widget _headerRow({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String timeText,
    required Color timeColor,
    required AppLocalizations l10n,
    Widget? trailing,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 22, color: iconColor),
        const SizedBox(width: 10),
        Text(
          l10n.restLabel,
          style: TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: scheme.onSurface,
          ),
        ),
        const Spacer(),
        Text(
          timeText,
          style: TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: timeColor,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 8),
          trailing,
        ],
      ],
    );
  }

  Widget _progressBar({required Color color, required double value}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(
        value: value,
        minHeight: 4,
        backgroundColor: color.withValues(alpha: 0.2),
        valueColor: AlwaysStoppedAnimation(color),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Rest banner action buttons
// ---------------------------------------------------------------------------

class _RestActionChip extends StatelessWidget {
  const _RestActionChip(
      {required this.label, required this.color, required this.onTap});

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ),
    );
  }
}

class _RestIconButton extends StatelessWidget {
  const _RestIconButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 14, color: color),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Health stat card (active kcal / avg bpm)
// ---------------------------------------------------------------------------

class _HealthStatCard extends StatelessWidget {
  const _HealthStatCard({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.input),
      ),
      child: Row(
        children: [
          Icon(icon, size: 21, color: iconColor),
          const SizedBox(width: 9),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: scheme.onSurface,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
