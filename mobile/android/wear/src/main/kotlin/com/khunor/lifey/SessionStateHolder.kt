package com.khunor.lifey

import android.os.SystemClock
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.update

/**
 * [ERROR] is `startExercise` having been rejected because another app
 * already owns the Health Services exercise session (docs/40-watch-app-plan.md
 * §12.1 B12) — shown as a dedicated screen with an OK button, the watch-side
 * counterpart of the phone's `startRejected` snackbar. [SUMMARY] only exists
 * for a standalone session (docs/watch/44-watch-f6-standalone-plan.md
 * D-F6.7) — a phone-mastered session never enters it (no summary screen ever
 * existed on Wear before F6, see [StandaloneSummary]'s doc comment for how
 * its data is carried, since a Kotlin `enum` can't attach an associated
 * value the way iOS's `WorkoutPhase.summary(WorkoutSummaryData)` does).
 */
enum class SessionPhase { IDLE, ACTIVE, SUMMARY, ERROR }

/** D-F6.8 — no reps input on the watch yet in F6a; every locally logged
 * standalone set uses this fixed value, the user corrects it on the phone
 * later. Carried per-set on the wire already so a future watch-side stepper
 * (F5b/F6b) won't need a protocol change. */
private const val STANDALONE_DEFAULT_REPS = 10
/** §3.5 — standalone has no phone-driven rest timer, so the watch starts
 * its own fixed-length one on every logged set. */
private const val STANDALONE_REST_SECONDS = 90

/** One set logged during a standalone session (docs/watch/
 * 44-watch-f6-standalone-plan.md §4.1) — [exerciseIndex] is null in F6a (no
 * plan); F6b resolves it against the synced template's exercise list. */
data class StandaloneSet(
    val loggedAtEpochMs: Long,
    val reps: Int,
    val exerciseIndex: Int? = null,
)

/**
 * The closed-out standalone session's stats (docs/watch/
 * 44-watch-f6-standalone-plan.md D-F6.7, canvas AW 15/W 14) — carried
 * separately from [SessionPhase.SUMMARY] rather than as an associated
 * value (Kotlin `enum class` can't hold one the way iOS's
 * `WorkoutPhase.summary(WorkoutSummaryData)` does), so [SessionStateHolder
 * .onStandaloneEnded] sets both together. [standaloneSessionId] is what a
 * summary screen (S17) checks [StandaloneSessionStore]/
 * [SessionStateHolder.standaloneSessionAcked] against to render its own
 * `sync_pending`/`sync_done` chip.
 */
data class StandaloneSummary(
    val standaloneSessionId: String,
    val totalDurationSeconds: Int,
    val setsCount: Int,
    val averageHeartRate: Double?,
    val activeCalories: Double?,
)

/**
 * The tap-to-ack lifecycle of the watch's "+1 set" control (docs/watch/
 * 43-watch-f5-set-logging-plan.md §3.2). [Pending]'s [Pending.eventId] is
 * the tap's id — [SessionStateHolder.onLogSetAck]/[SessionStateHolder
 * .onLogSetTimeout] only act on a match against this exact id, so a stale
 * ack/timeout for an already-settled/superseded tap is a no-op.
 */
sealed interface LogSetState {
    data object Ready : LogSetState
    data class Pending(val eventId: String) : LogSetState
    data object Confirmed : LogSetState
    data object Failed : LogSetState
}

data class SessionMetadata(
    val sessionClientId: String? = null,
    val title: String? = null,
    val exerciseName: String? = null,
    val setsDone: Int? = null,
    val setsTotal: Int? = null,
    /**
     * The rest timer's target end time, anchored to *this device's own*
     * `SystemClock.elapsedRealtime()` — null when no rest is active
     * (docs/39-rest-timer-plan.md). Deliberately not an absolute epoch
     * timestamp: [onStateSynced] converts the phone's relative
     * "seconds remaining" into this local monotonic deadline the instant a
     * sync arrives, so the countdown never depends on the watch's wall
     * clock agreeing with the phone's — two paired devices' wall clocks can
     * be meaningfully unsynced (seen in practice on paired emulators, hours
     * apart), which used to make this countdown wildly wrong
     * (docs/40-watch-app-plan.md §12.1 bugfix). Unlike the fields above,
     * [onStateSynced] always overwrites this one rather than preserving the
     * old value when absent — see its doc comment for why. */
    val restDeadlineElapsedRealtimeMs: Long? = null,
    /** The rest timer's full configured duration in seconds — null exactly
     * when [restDeadlineElapsedRealtimeMs] is null (docs/40-watch-app-plan.md
     * §12.1 B1). Same always-overwritten treatment. */
    val restTotalSeconds: Int? = null,
    /** Whether the running session is watch-only (docs/watch/
     * 44-watch-f6-standalone-plan.md §1) rather than phone-mastered —
     * `false` for every pre-F6 flow. Gates [SessionStateHolder.onStateSynced]'s
     * phone-state rejection (D-F6.2) and which end path applies. */
    val isStandalone: Boolean = false,
    /** The standalone session's own set log — the only record of it until
     * `ExerciseService.endStandaloneExercise` queues it (docs/watch/
     * 44-watch-f6-standalone-plan.md §3.1). Empty outside standalone mode;
     * phone-mastered sessions track their set count via [setsDone]/
     * [setsTotal] instead, which the phone itself owns. */
    val standaloneSets: List<StandaloneSet> = emptyList(),
) {
    /** [sessionClientId] doubles as the standalone session's own id during
     * standalone mode — reused rather than a separate `standaloneSessionId`
     * field (mirrors iOS's `WorkoutManager.sessionClientId`), so every
     * existing call site reading this field already picks it up. */
    val standaloneSessionId: String? get() = if (isStandalone) sessionClientId else null
}

data class LiveMetrics(
    val heartRateBpm: Double? = null,
    val activeCalories: Double? = null,
    val startedAtElapsedRealtimeMs: Long? = null,
    /** Mirrors `ExerciseUpdate.exerciseStateInfo.state.isPaused` — true for
     * both `USER_PAUSED` and `AUTO_PAUSED` (docs/40-watch-app-plan.md §12.1
     * B3). Only the *sensor* session is paused; the elapsed-time display
     * keeps ticking, matching the phone-session's timing (§4.4/§5.3: "csak a
     * szenzor-sessiont pauzálja, a telefon-session időzítését nem"). */
    val isPaused: Boolean = false,
    /** Whether `startExercise` was able to request `HEART_RATE_BPM` — false
     * means the sensor permission was denied, not just "no sample yet"
     * (docs/40-watch-app-plan.md §12.1 B13). Defaults to true (optimistic)
     * so the metrics page doesn't flash a denial before the first exercise
     * start has even run. */
    val hasHeartRatePermission: Boolean = true,
)

/**
 * Process-wide state shared between [PhoneListenerService] (the phone's
 * "last known state" DataItem sync, docs/40-watch-app-plan.md §D2),
 * [ExerciseService] (live Health Services metrics, §5.3), and the Compose UI
 * (§5.1) — this is the single in-process source of truth all three read from
 * or write into.
 */
object SessionStateHolder {
    private val _phase = MutableStateFlow(SessionPhase.IDLE)
    val phase: StateFlow<SessionPhase> = _phase

    private val _metadata = MutableStateFlow(SessionMetadata())
    val metadata: StateFlow<SessionMetadata> = _metadata

    private val _liveMetrics = MutableStateFlow(LiveMetrics())
    val liveMetrics: StateFlow<LiveMetrics> = _liveMetrics

    /** Set once [onStandaloneEnded] moves [phase] to [SessionPhase.SUMMARY]
     * — see [StandaloneSummary]'s doc comment for why this can't just be an
     * associated value on [phase] itself. Null outside that phase. */
    private val _standaloneSummary = MutableStateFlow<StandaloneSummary?>(null)
    val standaloneSummary: StateFlow<StandaloneSummary?> = _standaloneSummary

    private val _logSetState = MutableStateFlow<LogSetState>(LogSetState.Ready)
    val logSetState: StateFlow<LogSetState> = _logSetState

    /**
     * Emits a `standaloneSessionId` the instant its `standaloneSessionAck`
     * arrives (docs/watch/44-watch-f6-standalone-plan.md §4.2) — lets a
     * summary screen (S17) flip its own `sync_pending`/`sync_done` chip
     * without polling [StandaloneSessionStore]. A `SharedFlow`, not a
     * `StateFlow`: this is a one-shot event per ack, not a state that a late
     * collector should replay (mirrors iOS's `.standaloneSessionAcked`
     * `NotificationCenter` post, S8).
     */
    private val _standaloneSessionAcked = MutableSharedFlow<String>(extraBufferCapacity = 4)
    val standaloneSessionAcked: SharedFlow<String> = _standaloneSessionAcked

    /**
     * Applied from the phone's synced state message/DataItem — never clears
     * [SessionMetadata.title]/[SessionMetadata.exerciseName]/
     * [SessionMetadata.setsDone]/[SessionMetadata.setsTotal] if the new
     * payload didn't include them.
     *
     * [restRemainingSeconds] is the phone's own "seconds left" at the moment
     * it built the payload — converted here, on receipt, into
     * [SessionMetadata.restDeadlineElapsedRealtimeMs] by adding it to this
     * device's *own* `elapsedRealtime()`. That's the fix for the countdown
     * being wildly wrong: the old code stored the phone's absolute epoch
     * target and compared it against `System.currentTimeMillis()` on every
     * tick, which is only correct if the two devices' wall clocks agree.
     *
     * [restDeadlineElapsedRealtimeMs]/[SessionMetadata.restTotalSeconds] are
     * the exception to the "preserve if absent" rule above: they toggle
     * between a value and null constantly within a single session (rest
     * starts/ends), and null is indistinguishable on the wire from "key
     * absent" (`WatchBridge.kt`'s `toDataMap()` skips null values entirely)
     * — so unlike the other fields, these are always overwritten with the
     * new value, never preserved from the previous state.
     */
    fun onStateSynced(
        sessionClientId: String,
        title: String?,
        exerciseName: String?,
        setsDone: Int?,
        setsTotal: Int?,
        restRemainingSeconds: Int?,
        restTotalSeconds: Int?,
    ) {
        if (_metadata.value.isStandalone) {
            // A phone-mastered session's state can't touch the watch's own
            // standalone session (docs/watch/44-watch-f6-standalone-plan.md
            // D-F6.2). During standalone, `sessionClientId` here always
            // holds the watch's own locally generated id, so any state
            // arriving from the phone necessarily belongs to a *different*
            // session — [PhoneListenerService]'s `/start` handling is what
            // turns this into an explicit `sendStartRejected` (it has
            // access to `SummarySender`, this object doesn't).
            return
        }
        val restDeadlineElapsedRealtimeMs = restRemainingSeconds?.let {
            SystemClock.elapsedRealtime() + it * 1_000L
        }
        _metadata.update { current ->
            current.copy(
                sessionClientId = sessionClientId,
                title = title ?: current.title,
                exerciseName = exerciseName ?: current.exerciseName,
                setsDone = setsDone ?: current.setsDone,
                setsTotal = setsTotal ?: current.setsTotal,
                restDeadlineElapsedRealtimeMs = restDeadlineElapsedRealtimeMs,
                restTotalSeconds = restTotalSeconds,
            )
        }
    }

    /**
     * The exercise session actually started measuring, standalone
     * (docs/watch/44-watch-f6-standalone-plan.md §3.1) — the entry point for
     * the launcher's "Start workout" / picker's "Quick strength" tap, called
     * by `ExerciseService.startStandaloneExercise` once `startExerciseAsync`
     * succeeds. [sessionClientId] is the watch's own locally generated id;
     * no `sendStartedOnWatch` here — there's no phone-mastered session
     * waiting on that signal.
     */
    fun onStandaloneStarted(sessionClientId: String, startedAtElapsedRealtimeMs: Long) {
        _phase.value = SessionPhase.ACTIVE
        _metadata.update {
            SessionMetadata(sessionClientId = sessionClientId, isStandalone = true)
        }
        _liveMetrics.update { it.copy(startedAtElapsedRealtimeMs = startedAtElapsedRealtimeMs) }
    }

    /**
     * The standalone local-mode branch of the "+1 set" tap (docs/watch/
     * 44-watch-f6-standalone-plan.md §2.1, §3.2) — no PENDING/ack
     * round-trip: this tap's set *is* the record (there's no phone to
     * confirm against), appended immediately, and a fixed-length local rest
     * starts right away in the same field the phone-synced rest already
     * uses (`restDeadlineElapsedRealtimeMs`/`restTotalSeconds`), so
     * `ExerciseService`'s existing `scheduleRestVibration` collector works
     * unchanged.
     */
    fun onStandaloneSetLogged() {
        val nowElapsedRealtimeMs = SystemClock.elapsedRealtime()
        _metadata.update { current ->
            current.copy(
                standaloneSets = current.standaloneSets +
                    StandaloneSet(loggedAtEpochMs = System.currentTimeMillis(), reps = STANDALONE_DEFAULT_REPS),
                restDeadlineElapsedRealtimeMs = nowElapsedRealtimeMs + STANDALONE_REST_SECONDS * 1_000L,
                restTotalSeconds = STANDALONE_REST_SECONDS,
            )
        }
    }

    /**
     * The standalone counterpart of ending a session — called by
     * `ExerciseService.endStandaloneExercise` once the `HKWorkoutSession`-
     * equivalent Health Services exercise has closed and the finished
     * session is already queued in `StandaloneSessionStore`. Moves to
     * [SessionPhase.SUMMARY] with [summary] attached (see its doc comment)
     * and clears the running-session fields, same as [reset] otherwise
     * would for the phone-mastered path.
     */
    fun onStandaloneEnded(summary: StandaloneSummary) {
        _phase.value = SessionPhase.SUMMARY
        _standaloneSummary.value = summary
        _metadata.value = SessionMetadata()
        _liveMetrics.value = LiveMetrics()
    }

    fun onExerciseActive(startedAtElapsedRealtimeMs: Long) {
        _phase.value = SessionPhase.ACTIVE
        _liveMetrics.update { it.copy(startedAtElapsedRealtimeMs = startedAtElapsedRealtimeMs) }
    }

    fun onHeartRate(bpm: Double) {
        _liveMetrics.update { it.copy(heartRateBpm = bpm) }
    }

    fun onCalories(kcal: Double) {
        _liveMetrics.update { it.copy(activeCalories = kcal) }
    }

    fun onPausedChanged(isPaused: Boolean) {
        _liveMetrics.update { it.copy(isPaused = isPaused) }
    }

    fun onHeartRatePermissionChecked(hasPermission: Boolean) {
        _liveMetrics.update { it.copy(hasHeartRatePermission = hasPermission) }
    }

    /**
     * `startExercise` was rejected — another app already owns the exercise
     * session (docs/40-watch-app-plan.md §12.1 B12). Drives `MainActivity`
     * to `ErrorScreen`; [reset] (its OK button) is what clears it.
     */
    fun onStartRejected() {
        _phase.value = SessionPhase.ERROR
    }

    /**
     * The log-lap UI (S13) calls this the instant it fires
     * `SummarySender.sendLogSet` — moves to [LogSetState.Pending] so
     * [ExerciseService] can schedule the ack timeout (docs/watch/
     * 43-watch-f5-set-logging-plan.md §3.2).
     */
    fun onLogSetRequested(eventId: String) {
        _logSetState.value = LogSetState.Pending(eventId)
    }

    /**
     * Called by [PhoneListenerService] on a `logSetAck` reply
     * (docs/watch/43-watch-f5-set-logging-plan.md §4.3). Only acts when
     * [eventId] matches the currently-pending tap — a late ack for a tap
     * that already timed out (and thus already settled back to
     * [LogSetState.Ready]) is a no-op, not a resurrection of stale state.
     */
    fun onLogSetAck(eventId: String, accepted: Boolean) {
        val pending = _logSetState.value as? LogSetState.Pending ?: return
        if (pending.eventId != eventId) return
        _logSetState.value = if (accepted) LogSetState.Confirmed else LogSetState.Failed
    }

    /**
     * Called by [ExerciseService]'s ack-timeout job (docs/watch/
     * 43-watch-f5-set-logging-plan.md §3.2, §7.1) once 5 s pass with no
     * [onLogSetAck] for [eventId]. Same match-or-no-op guard as
     * [onLogSetAck] — an ack that arrives in the same instant the timeout
     * fires simply wins the race, whichever call lands first.
     */
    fun onLogSetTimeout(eventId: String) {
        val pending = _logSetState.value as? LogSetState.Pending ?: return
        if (pending.eventId != eventId) return
        _logSetState.value = LogSetState.Failed
    }

    /** [ExerciseService] calls this once its confirm/fail settle delay
     * (1.2 s / 2.5 s) elapses — falls [LogSetState.Confirmed]/
     * [LogSetState.Failed] back to [LogSetState.Ready] on its own. */
    fun onLogSetSettled() {
        _logSetState.value = LogSetState.Ready
    }

    /**
     * Called by [PhoneListenerService] on a `standaloneSessionAck`
     * (docs/watch/44-watch-f6-standalone-plan.md §4.2) — after
     * [StandaloneSessionStore.remove] already dropped the payload, this just
     * broadcasts the id for whichever summary screen is currently showing
     * it.
     */
    fun onStandaloneSessionAcked(standaloneSessionId: String) {
        _standaloneSessionAcked.tryEmit(standaloneSessionId)
    }

    /** Back to idle — both once a real exercise's notification is fully torn
     * down, and as [ErrorScreen]'s OK-button dismissal for [onStartRejected]. */
    fun reset() {
        _phase.value = SessionPhase.IDLE
        _metadata.value = SessionMetadata()
        _liveMetrics.value = LiveMetrics()
        _logSetState.value = LogSetState.Ready
        _standaloneSummary.value = null
    }
}
