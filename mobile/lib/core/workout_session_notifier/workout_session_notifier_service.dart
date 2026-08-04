import 'dart:io' show Platform;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../notifications/notification_service.dart';

/// Mutable per-update state for the running workout session. Feeds both
/// platform mechanisms: the iOS Live Activity content state (mirrors the
/// Swift `WorkoutActivityAttributes.ContentState`,
/// docs/24-ios-widget-live-activity-plan.md) and the Android ongoing
/// notification's body/anchor (docs/25-android-widget-ongoing-notification-plan.md).
class WorkoutSessionState {
  const WorkoutSessionState({
    required this.exerciseName,
    required this.setsDone,
    this.setsTotal,
    required this.totalSetsDone,
    this.lastSetAtEpochMs,
    this.restEndsAtEpochMs,
    this.restTotalSeconds,
    this.restRemainingSeconds,
    this.nextSetWeight,
    this.nextSetReps,
    this.setsDoneExerciseIndex,
    this.setsDonePerExercise,
  });

  /// Current (last touched) exercise name; pass a pre-localized fallback
  /// (e.g. "Gyakorlat") for the empty-block case rather than an empty string.
  final String exerciseName;
  final int setsDone;
  final int? setsTotal;
  final int totalSetsDone;
  final int? lastSetAtEpochMs;

  /// The rest timer's target end time, epoch ms — null when the rest timer
  /// is disabled, skipped, or already expired (docs/39-rest-timer-plan.md
  /// §Prompt 5). When present, both native surfaces render a countdown to it
  /// instead of the plain count-up from [lastSetAtEpochMs].
  final int? restEndsAtEpochMs;

  /// The rest timer's full configured duration in seconds (including any
  /// manual +15s adjustments already applied when the timer started) — null
  /// exactly when [restEndsAtEpochMs] is null. Watch UIs use this alongside
  /// [restEndsAtEpochMs] to render a drain-down progress ring (the "of 1:30"
  /// target in docs/40-watch-app-plan.md §12.1 B1), not just the bare
  /// countdown text.
  final int? restTotalSeconds;

  /// Seconds remaining *as of this device's own clock, right now* — null
  /// exactly when [restEndsAtEpochMs] is null. This is what the watch bridge
  /// uses for its countdown instead of [restEndsAtEpochMs]: turning an
  /// absolute epoch target into a countdown requires comparing it against
  /// the *receiving* device's wall clock, which can be meaningfully
  /// unsynced from the phone's on a paired watch (docs/40-watch-app-plan.md
  /// §12.1 bugfix). A relative "seconds left" value sidesteps that entirely
  /// — the watch anchors it to its own monotonic clock on receipt.
  final int? restRemainingSeconds;

  /// What a watch "+1 set" tap would prefill its adjust stepper with — the
  /// weight/reps of the row the phone would actually log into
  /// (docs/watch/48-watch-f5b-set-adjust-plan.md D-F5b.2, §4.2). Null when
  /// there's nothing to go on (no planned values, no previous performance,
  /// no earlier done set); the watch then starts from its own default and
  /// presents it as new data rather than as an adjustment.
  ///
  /// Only the watch reads these — the Live Activity / ongoing notification
  /// ignore them. They are always in **kg**, matching the phone's own
  /// workout UI, which doesn't convert for `UnitSystem` either (D-F5b.4).
  final double? nextSetWeight;
  final int? nextSetReps;

  /// Which exercise [setsDone]/[setsTotal] describe, as the **watch's** own
  /// index into its cached template (see
  /// [WatchStandaloneAdoption.currentExerciseIndex]) — non-null only for a
  /// watch-mastered session whose current exercise the watch itself named.
  ///
  /// A watch-started session logs its sets locally and knows nothing about the
  /// ones logged on the phone's mirror screen, so its own counter under-counts
  /// them. The phone's row holds both halves, so it can report the real number
  /// — but only usefully if the watch can tell *which* exercise the number is
  /// about: the two sides pick "current exercise" by different rules and can
  /// legitimately disagree for a moment. The watch takes the count only when
  /// this index matches the exercise it is about to log into, and ignores it
  /// otherwise rather than showing a confidently wrong number.
  ///
  /// Ignored by the Live Activity / ongoing notification, like the prefill
  /// fields above.
  final int? setsDoneExerciseIndex;

  /// How many sets are logged for **every** exercise of the watch's plan, in
  /// its own index order — the phone's row is the only place the two devices'
  /// sets meet, so this is the only complete answer that exists.
  ///
  /// [setsDoneExerciseIndex] above covers the exercise the watch is on right
  /// now, which is enough to render "2/3" — but not enough to decide when to
  /// move on. The watch picks its next exercise by scanning its plan for the
  /// first one that isn't finished yet, and judged from its own set list every
  /// exercise the user completed *on the phone* still looks unfinished. It
  /// would jump back to one, be told it was complete after all, jump to the
  /// next, and so on — visibly hopping between already-finished exercises.
  ///
  /// Null outside a watch-mastered session, and whenever the plan's exercise
  /// order isn't known here; the watch then falls back to counting its own
  /// sets, exactly as it did before.
  final List<int>? setsDonePerExercise;

  Map<String, dynamic> toJson() => {
        'exerciseName': exerciseName,
        'setsDone': setsDone,
        'setsTotal': setsTotal,
        'totalSetsDone': totalSetsDone,
        'lastSetAtEpochMs': lastSetAtEpochMs,
        'restEndsAtEpochMs': restEndsAtEpochMs,
        'restTotalSeconds': restTotalSeconds,
        'restRemainingSeconds': restRemainingSeconds,
        'nextSetWeight': nextSetWeight,
        'nextSetReps': nextSetReps,
        'setsDoneExerciseIndex': setsDoneExerciseIndex,
        'setsDonePerExercise': setsDonePerExercise,
      };
}

/// Why [WorkoutSessionNotifierService.start] didn't produce an indicator, when
/// it didn't — the difference between "ask again later" and "don't bother".
enum WorkoutSessionNotifierStatus {
  /// The Live Activity / ongoing notification is up.
  started,

  /// A transient refusal: retry at the next opportunity. The one that
  /// actually happens is iOS refusing to *start* a Live Activity while the
  /// app is in the background (`ActivityAuthorizationError.visibility`) —
  /// which is precisely the situation a workout driven from the watch
  /// creates, since the phone can be persisting sets with its screen off.
  retryable,

  /// A refusal that won't change while this workout runs: Live Activities
  /// switched off in Settings, Android's notification permission denied,
  /// or a platform/OS version without either mechanism. Retrying would just
  /// be asking the same question repeatedly.
  unavailable,
}

/// [WorkoutSessionNotifierService.start]'s outcome. Callers need more than
/// the iOS activity id it used to return: on Android there is no id at all,
/// so "did it actually start?" was unanswerable there — and a caller that
/// assumes it did will never retry, leaving the workout with no indicator
/// for its whole duration.
class WorkoutSessionNotifierStart {
  const WorkoutSessionNotifierStart(this.status, {this.activityId});

  final WorkoutSessionNotifierStatus status;

  /// The native Live Activity id on iOS; always null on Android (no such
  /// concept) and on any non-[WorkoutSessionNotifierStatus.started] result.
  final String? activityId;

  bool get started => status == WorkoutSessionNotifierStatus.started;
  bool get shouldRetry => status == WorkoutSessionNotifierStatus.retryable;
}

/// Platform-neutral facade over both "ongoing workout indicator" mechanisms:
///
/// - **iOS**: hand-rolled `lifey/live_activity` MethodChannel → ActivityKit
///   (docs/24-ios-widget-live-activity-plan.md, "Hand-rolled MethodChannel").
/// - **Android**: [NotificationService]'s silent ongoing notification on the
///   `workout_session` channel — Android's stand-in for a Live Activity,
///   since content only changes while the app is foregrounded and the
///   ticking timer is rendered natively via `usesChronometer`
///   (docs/25-android-widget-ongoing-notification-plan.md, decision #2/#3).
/// - Other platforms: no-op.
///
/// Same call sites regardless of platform — [LogSessionScreen],
/// `WorkoutResumePrompt`, `SessionsTab` — this service picks the native
/// mechanism.
class WorkoutSessionNotifierService {
  WorkoutSessionNotifierService({
    MethodChannel? channel,
    bool? isAvailable,
    bool? useAndroidBranch,
    Future<bool> Function()? requestAndroidPermission,
    Future<void> Function({
      required String title,
      required String body,
      required String subText,
      required int whenEpochMs,
      bool chronometerCountDown,
    })? showAndroidNotification,
    Future<void> Function()? cancelAndroidNotification,
  })  : _channel = channel ?? const MethodChannel('lifey/live_activity'),
        isAvailable = isAvailable ?? (Platform.isIOS || Platform.isAndroid),
        _useAndroid = useAndroidBranch ?? Platform.isAndroid,
        _requestAndroidPermission =
            requestAndroidPermission ?? NotificationService.requestWorkoutSessionPermission,
        _showAndroidNotificationCall =
            showAndroidNotification ?? NotificationService.showWorkoutSession,
        _cancelAndroidNotification =
            cancelAndroidNotification ?? NotificationService.cancelWorkoutSession;

  final MethodChannel _channel;

  /// Defaults to [Platform.isIOS] || [Platform.isAndroid]; overridable in
  /// the constructor so tests can exercise calls on other test hosts.
  final bool isAvailable;

  /// Defaults to [Platform.isAndroid]; overridable in the constructor so
  /// tests (which run on a non-Android host) can exercise the Android
  /// branch against the injected callables below.
  final bool _useAndroid;

  // Android-only calls, injectable so tests can assert on them without
  // touching the real flutter_local_notifications platform channel — same
  // pattern as WidgetSnapshotWriter.
  final Future<bool> Function() _requestAndroidPermission;
  final Future<void> Function({
    required String title,
    required String body,
    required String subText,
    required int whenEpochMs,
    bool chronometerCountDown,
  }) _showAndroidNotificationCall;
  final Future<void> Function() _cancelAndroidNotification;

  // Android only: the iOS channel re-sends title/startedAt on every call,
  // but the Android notification only receives them at start() — cached
  // here so update() can rebuild the "when" anchor and subText.
  String? _androidTitle;
  DateTime? _androidStartedAt;

  /// Starts tracking [sessionClientId] — see [WorkoutSessionNotifierStart]
  /// for what the result means and why a bare activity id wasn't enough.
  /// Never throws: a platform refusal is reported, not raised, since the
  /// workout itself is unaffected by there being no indicator.
  Future<WorkoutSessionNotifierStart> start({
    required String sessionClientId,
    required String title,
    required DateTime startedAt,
    required String startedLabel,
    required WorkoutSessionState state,
  }) async {
    if (!isAvailable) {
      return const WorkoutSessionNotifierStart(WorkoutSessionNotifierStatus.unavailable);
    }

    if (_useAndroid) {
      _androidTitle = title;
      _androidStartedAt = startedAt;
      final granted = await _requestAndroidPermission();
      // Denied → the service silently no-ops; the workout itself is
      // unaffected (docs/25-android-widget-ongoing-notification-plan.md).
      // Not retryable: the permission dialog is a one-shot, and re-asking on
      // every resume would be nagging rather than recovery.
      if (!granted) {
        return const WorkoutSessionNotifierStart(WorkoutSessionNotifierStatus.unavailable);
      }
      await _renderAndroidNotification(state, startedLabel);
      return const WorkoutSessionNotifierStart(WorkoutSessionNotifierStatus.started);
    }

    try {
      final activityId = await _channel.invokeMethod<String>('start', {
        'sessionClientId': sessionClientId,
        'title': title,
        'startedAtEpochMs': startedAt.millisecondsSinceEpoch,
        'state': state.toJson(),
      });
      // A null id without an error is the iOS < 16.2 branch (no ActivityKit
      // `ActivityContent`) — nothing to retry into.
      if (activityId == null) {
        return const WorkoutSessionNotifierStart(WorkoutSessionNotifierStatus.unavailable);
      }
      return WorkoutSessionNotifierStart(
        WorkoutSessionNotifierStatus.started,
        activityId: activityId,
      );
    } on PlatformException catch (e) {
      // LiveActivityChannel.swift's error codes: only `start_failed` (the
      // ActivityKit request itself was refused — backgrounded app, budget)
      // can succeed on a later attempt.
      return WorkoutSessionNotifierStart(e.code == 'start_failed'
          ? WorkoutSessionNotifierStatus.retryable
          : WorkoutSessionNotifierStatus.unavailable);
    } on MissingPluginException {
      return const WorkoutSessionNotifierStart(WorkoutSessionNotifierStatus.unavailable);
    }
  }

  /// Updates the running session's content state. No-ops (native side) if
  /// none is found (iOS) or if [start] was never called / was denied
  /// (Android).
  Future<void> update({
    required String sessionClientId,
    required String startedLabel,
    required WorkoutSessionState state,
  }) async {
    if (!isAvailable) return;

    if (_useAndroid) {
      await _renderAndroidNotification(state, startedLabel);
      return;
    }

    await _channel.invokeMethod('update', {
      'sessionClientId': sessionClientId,
      'state': state.toJson(),
    });
  }

  /// Ends the current workout's indicator immediately.
  Future<void> end() async {
    if (!isAvailable) return;
    if (_useAndroid) {
      _androidTitle = null;
      _androidStartedAt = null;
      await _cancelAndroidNotification();
      return;
    }
    await _channel.invokeMethod('end');
  }

  /// Safety sweep: ends every orphaned indicator. Called once on app start
  /// when no in-progress session was found (see `WorkoutResumePrompt`).
  Future<void> endAll() async {
    if (!isAvailable) return;
    if (_useAndroid) {
      await _cancelAndroidNotification();
      return;
    }
    await _channel.invokeMethod('endAll');
  }

  Future<void> _renderAndroidNotification(WorkoutSessionState state, String startedLabel) async {
    final title = _androidTitle;
    final startedAt = _androidStartedAt;
    if (title == null || startedAt == null) return;

    // A known, still-future rest-timer target renders as a countdown
    // (docs/39-rest-timer-plan.md, Prompt 5); otherwise decision #3
    // (docs/25-android-widget-ongoing-notification-plan.md) applies: before
    // the first logged set the chronometer shows elapsed time from
    // startedAt, after each set a rest count-up from the last set.
    final restEndsAt = state.restEndsAtEpochMs;
    final useRestCountdown =
        restEndsAt != null && restEndsAt > DateTime.now().millisecondsSinceEpoch;
    final whenEpochMs = useRestCountdown
        ? restEndsAt
        : (state.lastSetAtEpochMs ?? startedAt.millisecondsSinceEpoch);
    final body = state.setsTotal != null
        ? '${state.exerciseName} · ${state.setsDone}/${state.setsTotal}'
        : state.exerciseName;
    final subText = '$startedLabel ${DateFormat('HH:mm').format(startedAt.toLocal())}';

    await _showAndroidNotificationCall(
      title: title,
      body: body,
      subText: subText,
      whenEpochMs: whenEpochMs,
      chronometerCountDown: useRestCountdown,
    );
  }
}

final workoutSessionNotifierServiceProvider = Provider<WorkoutSessionNotifierService>((ref) {
  return WorkoutSessionNotifierService();
});
