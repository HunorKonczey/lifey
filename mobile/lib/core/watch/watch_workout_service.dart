import 'dart:io' show Platform;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/workouts/application/watch_template_sync.dart' show WatchTemplatePayload;
import '../workout_session_notifier/workout_session_notifier_service.dart' show WorkoutSessionState;

/// Enrichment payload a watch app sends back once its side of a workout ends
/// (docs/40-watch-app-plan.md §6.3). [sessionClientId] ties it back to the
/// Drift-cached session the phone already owns; the fields line up 1:1 with
/// [WorkoutSession]'s health-enrichment columns.
class WatchWorkoutSummary {
  const WatchWorkoutSummary({
    required this.sessionClientId,
    this.activeCalories,
    this.averageHeartRate,
    this.healthWorkoutId,
  });

  final String sessionClientId;
  final double? activeCalories;
  final double? averageHeartRate;
  final String? healthWorkoutId;

  factory WatchWorkoutSummary.fromJson(Map<Object?, Object?> json) => WatchWorkoutSummary(
        sessionClientId: json['sessionClientId'] as String,
        activeCalories: (json['activeCalories'] as num?)?.toDouble(),
        averageHeartRate: (json['averageHeartRate'] as num?)?.toDouble(),
        healthWorkoutId: json['healthWorkoutId'] as String?,
      );
}

/// The watch declined to start its own session — e.g. another app's exercise
/// is already running on Wear OS (docs/40-watch-app-plan.md §5.3, §8.1).
class WatchStartRejected {
  const WatchStartRejected(this.sessionClientId);
  final String sessionClientId;
}

/// The user ended the workout on the watch — the watch never closes its own
/// session unilaterally, it asks the phone to (docs/40-watch-app-plan.md
/// §8.2 decision (b)). The watch collects the effort rating itself before
/// sending this (an on-watch stepper, skippable), so [rpe] is already final:
/// the phone no longer shows its own feedback sheet for this path, it just
/// persists [rpe] as-is (null if skipped) with an empty note. Handled by
/// [LogSessionScreen] while its instance for this [sessionClientId] is
/// mounted; a no-op otherwise.
class WatchEndRequested {
  const WatchEndRequested(this.sessionClientId, this.rpe);
  final String sessionClientId;
  final int? rpe;
}

/// The watch's own session actually started measuring (its HealthKit/Health
/// Services session is running) — docs/watch/40-watch-app-plan.md §12.4 B14.
/// Drives the "Measuring" ⌚-pill in [LogSessionScreen]'s header; fired once
/// per watch session, not on every state sync.
class WatchStartedOnWatch {
  const WatchStartedOnWatch(this.sessionClientId);
  final String sessionClientId;
}

/// `WCSession.isReachable`'s change events, relayed 1:1 from iOS (Android has
/// no equivalent push and never emits this — see [WatchWorkoutService.events]'s
/// class doc). Used to hide the "Measuring" pill when the watch drops out of
/// range (docs/watch/42-watch-design-implementation-plan.md D1.4 P1).
class WatchReachabilityChanged {
  const WatchReachabilityChanged(this.reachable);
  final bool reachable;
}

/// Live heart-rate/calorie readings pushed from the watch's own session
/// while it's actively measuring — far more frequent than the one-shot
/// [WatchWorkoutSummary] sent when the workout ends. Best-effort and lossy:
/// sent as a plain message, not a guaranteed delivery, so a dropped reading
/// simply means the next one (moments later) supersedes it.
class WatchLiveMetrics {
  const WatchLiveMetrics({
    required this.sessionClientId,
    this.heartRateBpm,
    this.activeCalories,
  });

  final String sessionClientId;
  final double? heartRateBpm;
  final double? activeCalories;

  factory WatchLiveMetrics.fromJson(Map<Object?, Object?> json) => WatchLiveMetrics(
        sessionClientId: json['sessionClientId'] as String,
        heartRateBpm: (json['heartRateBpm'] as num?)?.toDouble(),
        activeCalories: (json['activeCalories'] as num?)?.toDouble(),
      );
}

/// The user tapped the "+1 set" control on the watch — the watch is a dumb
/// trigger, it doesn't log anything itself; [LogSessionScreen] logs the next
/// row from its own current position and acks back (docs/watch/
/// 43-watch-f5-set-logging-plan.md §2, §4.1). [eventId] is a watch-generated
/// UUID used for dedup (§4.2) and to correlate the eventual `ackSetLogged`
/// call.
class WatchSetLogged {
  const WatchSetLogged({
    required this.sessionClientId,
    required this.eventId,
    required this.loggedAtEpochMs,
    this.reps,
    this.weight,
    this.exerciseId,
  });

  final String sessionClientId;
  final String eventId;
  final int loggedAtEpochMs;

  /// Which exercise the watch chose to log this set into, by clientId
  /// (docs/watch/50-watch-f6c-session-plan-sync-plan.md §7) — the wrist's
  /// exercise picker now works in a phone-mastered session too, and this is
  /// how its choice reaches the row selection. Null for the plain "+1 set"
  /// flow, which leaves the choice entirely to the phone exactly as before.
  final String? exerciseId;

  /// What the watch's adjust stepper produced, when the user went through it
  /// (docs/watch/48-watch-f5b-set-adjust-plan.md §4.1). **Optional and
  /// backwards-compatible**: F5a's plain one-tap flow sends neither, and the
  /// phone then logs exactly as it does today (D-F5b.6). [weight] is in kg,
  /// matching the phone's own workout UI (D-F5b.4).
  final int? reps;
  final double? weight;

  /// The pair to log with, or null when the watch didn't send a usable one.
  /// §4.1 requires reps and weight to travel **together**, so a half-filled
  /// payload counts as "no values" rather than writing a null over a row's
  /// planned value — the caller falls back to the plain mark-done path.
  ({double weight, int reps})? get loggedValues {
    final r = reps;
    final w = weight;
    return (r != null && w != null) ? (weight: w, reps: r) : null;
  }

  factory WatchSetLogged.fromJson(Map<Object?, Object?> json) => WatchSetLogged(
        sessionClientId: json['sessionClientId'] as String,
        eventId: json['eventId'] as String,
        loggedAtEpochMs: json['loggedAtEpochMs'] as int,
        reps: json['reps'] as int?,
        // `as num?`, not `as double?`: a whole-number weight (60) arrives as
        // an int over the platform channel and would otherwise throw — the
        // same reason WatchLiveMetrics/WatchWorkoutSummary decode this way.
        weight: (json['weight'] as num?)?.toDouble(),
        exerciseId: json['exerciseId'] as String?,
      );
}

/// The watch picked a different exercise from its list during a
/// **phone-mastered** session (docs/watch/50-watch-f6c-session-plan-sync-plan.md
/// §7) — the counterpart of [WatchStandaloneAdoption.currentExerciseId] for a
/// session the phone owns, where there is no adoption snapshot to carry it.
///
/// Carries no set: it only moves "which exercise is current", so the phone's
/// next state push — the exercise name, its counts and the adjust stepper's
/// prefill — describes the exercise the user just picked on the wrist. The set
/// itself, when it comes, names the exercise again on its own
/// ([WatchSetLogged.exerciseId]), so a lost message can't misfile it.
class WatchExerciseSelected {
  const WatchExerciseSelected({required this.sessionClientId, required this.exerciseId});

  final String sessionClientId;
  final String exerciseId;

  factory WatchExerciseSelected.fromJson(Map<Object?, Object?> json) => WatchExerciseSelected(
        sessionClientId: json['sessionClientId'] as String,
        exerciseId: json['exerciseId'] as String,
      );
}

/// One set logged during a standalone (phone-less) session (docs/watch/
/// 44-watch-f6-standalone-plan.md §4.1) — part of the batch a
/// [WatchStandaloneSession] carries, unlike [WatchSetLogged]'s one-tap-at-a-time
/// live event. [reps]/[weight] default to `standaloneDefaultReps`/`null`
/// unless the watch-side F5b adjust stepper was used (now wired up for
/// standalone too). [exerciseIndex] is null outside a template session; F6b
/// resolves it against the synced template's exercise list.
class WatchStandaloneSet {
  const WatchStandaloneSet({
    required this.loggedAtEpochMs,
    required this.reps,
    this.weight,
    this.exerciseIndex,
    this.exerciseId,
  });

  final int loggedAtEpochMs;
  final int reps;
  final double? weight;
  final int? exerciseIndex;

  /// The exercise's **clientId**, as the watch received it in the session plan
  /// or the synced template (docs/watch/50-watch-f6c-session-plan-sync-plan.md)
  /// — the identity a set is attributed by from F6c on, and the reason the
  /// exercise list may change mid-session at all: a position means whatever
  /// the current list says, an id means the same exercise forever.
  ///
  /// Null for a set logged by a watch build that predates F6c, and for one
  /// logged outside any plan; [exerciseIndex] is still carried alongside it
  /// for exactly those cases, and stays the fallback.
  final String? exerciseId;

  factory WatchStandaloneSet.fromJson(Map<Object?, Object?> json) => WatchStandaloneSet(
        loggedAtEpochMs: json['loggedAtEpochMs'] as int,
        reps: json['reps'] as int,
        // `as num?`, not `as double?`: a whole-number weight (60) arrives as
        // an int on the Android side of the bridge.
        weight: (json['weight'] as num?)?.toDouble(),
        exerciseIndex: json['exerciseIndex'] as int?,
        exerciseId: json['exerciseId'] as String?,
      );
}

/// A workout the watch ran entirely on its own, phone-less, from start to
/// finish (docs/watch/44-watch-f6-standalone-plan.md §1, §4.1) — collected
/// locally on the watch, queued, and delivered once the phone reconnects,
/// possibly long after it ended. Unlike every other watch event, this one
/// already describes a *finished* workout — [LogSessionScreen] never has a
/// live instance for it; the resume-prompt sweep (docs/watch/
/// 44-watch-f6-standalone-plan.md §2 D-F6.2) creates the session directly.
///
/// [standaloneSessionId] becomes the resulting session's `clientId` — the
/// idempotency key: the watch retries delivery until acked (§4.2), so the
/// same id can arrive more than once and must be a no-op the second time.
/// [templateId] is null in F6a (no plan); F6b carries the synced template's
/// id. [rpe] is whatever the watch's own effort-selector produced (nil if
/// skipped). [healthWorkoutId] is always null on Android — the watch never
/// touches Health Connect there, the phone does (D-F6.5).
class WatchStandaloneSession {
  const WatchStandaloneSession({
    required this.standaloneSessionId,
    this.templateId,
    required this.startedAtEpochMs,
    required this.endedAtEpochMs,
    this.rpe,
    required this.sets,
    this.activeCalories,
    this.averageHeartRate,
    this.healthWorkoutId,
  });

  final String standaloneSessionId;
  final String? templateId;
  final int startedAtEpochMs;
  final int endedAtEpochMs;
  final int? rpe;
  final List<WatchStandaloneSet> sets;
  final double? activeCalories;
  final double? averageHeartRate;
  final String? healthWorkoutId;

  factory WatchStandaloneSession.fromJson(Map<Object?, Object?> json) => WatchStandaloneSession(
        standaloneSessionId: json['standaloneSessionId'] as String,
        templateId: json['templateId'] as String?,
        startedAtEpochMs: json['startedAtEpochMs'] as int,
        endedAtEpochMs: json['endedAtEpochMs'] as int,
        rpe: json['rpe'] as int?,
        sets: ((json['sets'] as List?) ?? const [])
            .map((raw) => WatchStandaloneSet.fromJson(Map<Object?, Object?>.from(raw as Map)))
            .toList(),
        activeCalories: (json['activeCalories'] as num?)?.toDouble(),
        averageHeartRate: (json['averageHeartRate'] as num?)?.toDouble(),
        healthWorkoutId: json['healthWorkoutId'] as String?,
      );
}

/// A watch-started (standalone) session that is still **running**, sent as
/// soon as the phone is (or becomes) reachable — the watch→phone half of
/// "starting on the watch should make the phone join in too", not just
/// import the workout after the fact. Same idea as [WatchStandaloneSession]
/// but a snapshot mid-flight: no `endedAtEpochMs`, [sets] is whatever has
/// been logged *so far* and may be resent with more sets as the workout
/// continues. [standaloneSessionId] is the same id the eventual
/// [WatchStandaloneSession] will carry when the workout finishes — that's
/// what lets [StandaloneSessionProcessor] recognize "this session already
/// has a running row, finish it" instead of creating a duplicate.
///
/// The watch still logs every set locally/instantly regardless of whether
/// adoption succeeded (docs/watch/44-watch-f6-standalone-plan.md's
/// reliability guarantee is unchanged) — adoption only gives the phone a
/// live, visible mirror of the session and the ability to end it too.
class WatchStandaloneAdoption {
  const WatchStandaloneAdoption({
    required this.standaloneSessionId,
    this.templateId,
    required this.startedAtEpochMs,
    required this.sets,
    this.activeCalories,
    this.averageHeartRate,
    this.currentExerciseIndex,
    this.currentExerciseId,
  });

  final String standaloneSessionId;
  final String? templateId;
  final int startedAtEpochMs;
  final List<WatchStandaloneSet> sets;
  final double? activeCalories;
  final double? averageHeartRate;

  /// Which of [templateId]'s exercises the watch will log its *next* set
  /// against — same index space as [WatchStandaloneSet.exerciseIndex], but
  /// about the future rather than a set already logged. Only the watch knows
  /// it: it moves on by itself once an exercise has all its planned sets,
  /// whereas the phone's own "current exercise" rule ([LogSessionScreen
  /// ._currentExerciseBlock]) still names the exercise of the last logged
  /// set. The phone needs it because the prefill it pushes back
  /// (`nextSetReps`/`nextSetWeight`) is what the watch's stepper opens on.
  ///
  /// Null for a Quick strength session (no plan to index into), and also
  /// absent from a watch build that predates this field — treated the same,
  /// falling back to the phone's own rule.
  final int? currentExerciseIndex;

  /// The same answer as [currentExerciseIndex], by **clientId** instead of
  /// position (F6c) — preferred wherever both are present, since the exercise
  /// list can change mid-session and a position can't survive that. Null on a
  /// watch build that predates F6c and outside any plan.
  final String? currentExerciseId;

  factory WatchStandaloneAdoption.fromJson(Map<Object?, Object?> json) => WatchStandaloneAdoption(
        standaloneSessionId: json['standaloneSessionId'] as String,
        templateId: json['templateId'] as String?,
        startedAtEpochMs: json['startedAtEpochMs'] as int,
        sets: ((json['sets'] as List?) ?? const [])
            .map((raw) => WatchStandaloneSet.fromJson(Map<Object?, Object?>.from(raw as Map)))
            .toList(),
        activeCalories: (json['activeCalories'] as num?)?.toDouble(),
        averageHeartRate: (json['averageHeartRate'] as num?)?.toDouble(),
        currentExerciseIndex: (json['currentExerciseIndex'] as num?)?.toInt(),
        currentExerciseId: json['currentExerciseId'] as String?,
      );
}

/// Platform-neutral facade over the phone↔watch workout bridge
/// (docs/40-watch-app-plan.md §6.1). Mirrors [WorkoutSessionNotifierService]'s
/// shape and constructor-injection pattern so it can be called side by side
/// from the same screens without a shared coordination layer — start/update/
/// end here drive the *watch's own* strength-workout session, independently
/// of the Live Activity / ongoing-notification indicator.
///
/// Every native call is best-effort and never throws: until the native watch
/// targets exist (docs/40-watch-app-plan.md phases F2/F3), the underlying
/// `MethodChannel` has no handler and calling it throws
/// `MissingPluginException` — caught and swallowed here exactly like a
/// missing/unpaired watch, so the phone-side workout is never affected by the
/// watch bridge being absent or not yet implemented natively.
class WatchWorkoutService {
  WatchWorkoutService({
    MethodChannel? channel,
    EventChannel? eventChannel,
    bool? isAvailable,
  })  : _channel = channel ?? const MethodChannel('lifey/watch'),
        _eventChannel = eventChannel ?? const EventChannel('lifey/watch/events'),
        isAvailable = isAvailable ?? (Platform.isIOS || Platform.isAndroid);

  final MethodChannel _channel;
  final EventChannel _eventChannel;

  /// Defaults to [Platform.isIOS] || [Platform.isAndroid]; overridable in the
  /// constructor so tests can exercise calls on a non-mobile test host.
  final bool isAvailable;

  Stream<Object>? _events;

  /// Emits [WatchWorkoutSummary], [WatchStartRejected], [WatchEndRequested],
  /// [WatchStartedOnWatch], [WatchReachabilityChanged], [WatchLiveMetrics],
  /// [WatchSetLogged], [WatchStandaloneSession], [WatchStandaloneAdoption],
  /// or a raw event-name `String` for anything not yet decoded — see
  /// docs/40-watch-app-plan.md §3. A no-op stream (never emits) when
  /// [isAvailable] is false.
  Stream<Object> get events {
    if (!isAvailable) return const Stream.empty();
    return _events ??= _eventChannel.receiveBroadcastStream().map(_decodeEvent);
  }

  Object _decodeEvent(dynamic raw) {
    final map = Map<Object?, Object?>.from(raw as Map);
    switch (map['type']) {
      case 'summary':
        return WatchWorkoutSummary.fromJson(Map<Object?, Object?>.from(map['payload'] as Map));
      case 'startRejected':
        return WatchStartRejected(map['sessionClientId'] as String);
      case 'endRequested':
        return WatchEndRequested(map['sessionClientId'] as String, map['rpe'] as int?);
      case 'startedOnWatch':
        return WatchStartedOnWatch(map['sessionClientId'] as String);
      case 'reachabilityChanged':
        return WatchReachabilityChanged(map['reachable'] as bool);
      case 'liveMetrics':
        return WatchLiveMetrics.fromJson(Map<Object?, Object?>.from(map['payload'] as Map));
      case 'setLogged':
        return WatchSetLogged.fromJson(map);
      case 'standaloneSession':
        return WatchStandaloneSession.fromJson(Map<Object?, Object?>.from(map['payload'] as Map));
      case 'standaloneSessionAdopted':
        return WatchStandaloneAdoption.fromJson(Map<Object?, Object?>.from(map['payload'] as Map));
      case 'exerciseSelected':
        return WatchExerciseSelected.fromJson(map);
      default:
        return (map['type'] as String?) ?? 'unknown';
    }
  }

  /// Whether a paired + installed watch app can currently receive a
  /// start/update/end. Best-effort: resolves to false (not an error) if the
  /// channel has no native handler yet.
  Future<bool> isWatchAppAvailable() async {
    if (!isAvailable) return false;
    try {
      return await _channel.invokeMethod<bool>('isWatchAppAvailable') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Starts (or re-syncs) the watch's own strength-workout session — see
  /// docs/40-watch-app-plan.md §3 "Indítás". Call alongside, not instead of,
  /// [WorkoutSessionNotifierService.start].
  Future<void> startWorkout({
    required String sessionClientId,
    required String title,
    required DateTime startedAt,
    required WorkoutSessionState state,
  }) async {
    if (!isAvailable) return;
    try {
      await _channel.invokeMethod('startWorkout', {
        'sessionClientId': sessionClientId,
        'title': title,
        'startedAtEpochMs': startedAt.millisecondsSinceEpoch,
        'state': state.toJson(),
      });
    } catch (_) {
      // Best-effort: no paired/installed watch, or the native bridge doesn't
      // exist yet — the phone-side workout is unaffected.
    }
  }

  /// Pushes the latest [state] to the watch's display — call alongside
  /// [WorkoutSessionNotifierService.update] after each set/rest change.
  Future<void> updateState({
    required String sessionClientId,
    required WorkoutSessionState state,
  }) async {
    if (!isAvailable) return;
    try {
      await _channel.invokeMethod('updateState', {
        'sessionClientId': sessionClientId,
        'state': state.toJson(),
      });
    } catch (_) {
      // Best-effort, see class doc.
    }
  }

  /// Tells the watch to close its session — call alongside
  /// [WorkoutSessionNotifierService.end]. The watch answers asynchronously
  /// with a [WatchWorkoutSummary] on [events], not as this call's return
  /// value: docs/40-watch-app-plan.md §3 "Lezárás" — the watch may be
  /// unreachable right now and only answer once it reconnects.
  Future<void> endWorkout(String sessionClientId) async {
    if (!isAvailable) return;
    try {
      await _channel.invokeMethod('endWorkout', {'sessionClientId': sessionClientId});
    } catch (_) {
      // Best-effort, see class doc.
    }
  }

  /// Answers a [WatchSetLogged] event — call exactly once per received
  /// [eventId], even on a dedup no-op (docs/watch/
  /// 43-watch-f5-set-logging-plan.md §4.2, §4.3). [accepted] is false when
  /// there's no matching active session or the phone couldn't log (e.g. the
  /// session is closing); the watch shows its failed state either way.
  /// [sessionClientId] is the one the watch tagged the original event with
  /// (i.e. [WatchSetLogged.sessionClientId], not necessarily this screen's
  /// current session) — passed through so the native bridge stays stateless
  /// rather than having to remember the last session it saw (§5.1/S5).
  Future<void> ackSetLogged({
    required String sessionClientId,
    required String eventId,
    required bool accepted,
  }) async {
    if (!isAvailable) return;
    try {
      await _channel.invokeMethod('ackSetLogged', {
        'sessionClientId': sessionClientId,
        'eventId': eventId,
        'accepted': accepted,
      });
    } catch (_) {
      // Best-effort, see class doc.
    }
  }

  /// Answers a [WatchStandaloneSession] event — call exactly once per
  /// successfully processed [standaloneSessionId], including on a dedup
  /// no-op (an already-created session just gets acked again, docs/watch/
  /// 44-watch-f6-standalone-plan.md §4.2). Unlike [ackSetLogged] there's no
  /// `accepted: false` — the watch retries an un-acked delivery from its
  /// pending-session store regardless of why it wasn't acked, so a
  /// processing failure here should simply not call this at all rather than
  /// ack a rejection.
  Future<void> ackStandaloneSession(String standaloneSessionId) async {
    if (!isAvailable) return;
    try {
      await _channel.invokeMethod('ackStandaloneSession', {
        'standaloneSessionId': standaloneSessionId,
      });
    } catch (_) {
      // Best-effort, see class doc.
    }
  }

  /// Answers a [WatchStandaloneAdoption] event — same "always ack, even on a
  /// dedup no-op" contract as [ackStandaloneSession], for the same reason:
  /// the watch retries an un-acked adoption snapshot (on reconnect/cold
  /// start) regardless of why it wasn't acked, so a processing failure here
  /// should simply not call this rather than ack a rejection.
  Future<void> ackAdoption(String standaloneSessionId) async {
    if (!isAvailable) return;
    try {
      await _channel.invokeMethod('ackAdoption', {
        'standaloneSessionId': standaloneSessionId,
      });
    } catch (_) {
      // Best-effort, see class doc.
    }
  }

  /// Pushes the user's most recent templates to the watch's standalone picker
  /// (docs/watch/49-watch-f6b-template-sync-plan.md §4.1, T1.3). Build
  /// [templates] with `buildWatchTemplateSync` — it owns the truncation and
  /// rest-resolution rules (D-F6b.4, D-F6b.6) this method deliberately knows
  /// nothing about.
  ///
  /// Fire-and-forget, like every other call here: there's no ack, and a
  /// missed push simply leaves the watch on its previous cache until the next
  /// push point (§4.3). An **empty** [templates] list is still sent rather
  /// than skipped — that's how a watch whose last template was just deleted
  /// gets told to clear its cache.
  ///
  /// [syncedAtEpochMs] is stamped from the *phone's* clock, the same choice
  /// D-F6.6 made for session times: the two devices' wall clocks can differ,
  /// and the phone is the authority on when it published this list.
  Future<void> syncTemplates(List<WatchTemplatePayload> templates) async {
    if (!isAvailable) return;
    try {
      await _channel.invokeMethod('syncTemplates', {
        'syncedAtEpochMs': DateTime.now().millisecondsSinceEpoch,
        'templates': [for (final template in templates) template.toJson()],
      });
    } catch (_) {
      // Best-effort, see class doc — on iOS/Android alike the native handler
      // only lands in T3, so until then this swallows a MissingPluginException
      // exactly the way every other method here did when it was introduced.
    }
  }
}

final watchWorkoutServiceProvider = Provider<WatchWorkoutService>((ref) {
  return WatchWorkoutService();
});
