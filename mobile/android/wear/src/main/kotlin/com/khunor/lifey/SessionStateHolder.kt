package com.khunor.lifey

import android.os.SystemClock
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.update

/**
 * [ERROR] is `startExercise` having been rejected because another app
 * already owns the Health Services exercise session (docs/40-watch-app-plan.md
 * §12.1 B12) — shown as a dedicated screen with an OK button, the watch-side
 * counterpart of the phone's `startRejected` snackbar.
 */
enum class SessionPhase { IDLE, ACTIVE, ERROR }

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
)

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

    /** Back to idle — both once a real exercise's notification is fully torn
     * down, and as [ErrorScreen]'s OK-button dismissal for [onStartRejected]. */
    fun reset() {
        _phase.value = SessionPhase.IDLE
        _metadata.value = SessionMetadata()
        _liveMetrics.value = LiveMetrics()
    }
}
