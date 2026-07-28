package com.khunor.lifey

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.os.IBinder
import android.os.SystemClock
import android.os.VibrationEffect
import android.os.Vibrator
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat
import androidx.core.content.ContextCompat
import androidx.health.services.client.ExerciseUpdateCallback
import androidx.health.services.client.HealthServices
import androidx.health.services.client.data.Availability
import androidx.health.services.client.data.DataType
import androidx.health.services.client.data.ExerciseConfig
import androidx.health.services.client.data.ExerciseLapSummary
import androidx.health.services.client.data.ExerciseType
import androidx.health.services.client.data.ExerciseUpdate
import java.util.UUID
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.guava.await
import kotlinx.coroutines.launch
import org.json.JSONArray
import org.json.JSONObject

/**
 * Foreground service owning the Health Services `ExerciseClient` for the
 * strength-training session (docs/40-watch-app-plan.md §5.3). Driven
 * entirely by [PhoneListenerService] — never started/stopped directly by the
 * Compose UI (the watch End button asks the phone to close the session
 * instead, see [SummarySender.sendEndRequested] and the doc's §8.2 decision).
 */
class ExerciseService : Service() {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)
    private val exerciseClient by lazy { HealthServices.getClient(this).exerciseClient }

    private var heartRateSum = 0.0
    private var heartRateSamples = 0
    // Running sum of DataType.CALORIES deltas (activity only, excludes BMR) —
    // not DataType.CALORIES_TOTAL, which is a Health Services *aggregate*
    // that keeps accruing basal/resting calories for the whole exercise
    // duration on top of the activity kcal, and read noticeably too high
    // (user report after a leg session). CALORIES is a delta type, so each
    // callback only carries the *new* interval(s) since the last one — this
    // has to be summed by hand, unlike CALORIES_TOTAL's precomputed running
    // total.
    // Null (not 0.0) until the first delta arrives, so a session that ends
    // before any CALORIES callback fires still reports "no data" rather than
    // a misleading zero (mirrors the old CALORIES_TOTAL field's nullability).
    private var activeCaloriesTotal: Double? = null
    private var currentSessionClientId: String? = null

    // Pihenő-visszaszámláló haptika (docs/40-watch-app-plan.md §5.4/F4):
    // scheduled independently of start/end commands, for the service's whole
    // lifetime, since restEndsAtEpochMs can change many times per session.
    private var restVibrationJob: Job? = null

    // "+1 set" tap-to-ack timeout/haptika (docs/watch/
    // 43-watch-f5-set-logging-plan.md §3.2): scheduled here rather than on
    // the Compose UI, mirroring [restVibrationJob] — dropping the log page
    // (or the whole UI) mid-tap must not cut off a pending ack's timeout or
    // a confirm/fail haptic + settle-back-to-Ready.
    private var logSetJob: Job? = null

    // The adjust stepper's idle-dismiss timer (docs/watch/
    // 48-watch-f5b-set-adjust-plan.md D-F5b.7) — same "lives on the service,
    // not the screen" treatment as the jobs above.
    private var logAdjustIdleJob: Job? = null

    // SUMMARY auto-dismiss for a standalone session (docs/watch/
    // 44-watch-f6-standalone-plan.md D-F6.7, mirrors iOS's
    // scheduleSummaryAutoDismiss) — scheduled here, not the Compose UI, so
    // it still fires even if MainActivity isn't the foreground component
    // right when the session ends.
    private var summaryDismissJob: Job? = null

    private val updateCallback = object : ExerciseUpdateCallback {
        override fun onExerciseUpdateReceived(update: ExerciseUpdate) {
            update.latestMetrics.getData(DataType.HEART_RATE_BPM).lastOrNull()?.value?.let { bpm ->
                SessionStateHolder.onHeartRate(bpm)
                heartRateSum += bpm
                heartRateSamples += 1
            }
            val newActiveCalories = update.latestMetrics.getData(DataType.CALORIES)
            if (newActiveCalories.isNotEmpty()) {
                activeCaloriesTotal = (activeCaloriesTotal ?: 0.0) + newActiveCalories.sumOf { it.value }
                SessionStateHolder.onCalories(activeCaloriesTotal!!)
            }
            SessionStateHolder.onPausedChanged(update.exerciseStateInfo.state.isPaused)
            sendLiveMetrics()
        }

        override fun onLapSummaryReceived(lapSummary: ExerciseLapSummary) {
            // No lap concept for a strength session (docs/40-watch-app-plan.md §5.3).
        }

        override fun onAvailabilityChanged(dataType: DataType<*, *>, availability: Availability) {
            // No UI treatment in V1 — a denied/unavailable sensor just means
            // that metric stays absent (docs/40-watch-app-plan.md §5.2).
        }

        override fun onRegistered() {}

        override fun onRegistrationFailed(throwable: Throwable) {
            Log.w(TAG, "ExerciseUpdateCallback registration failed", throwable)
        }
    }

    /** Relays [SessionStateHolder]'s just-updated live metrics to the phone
     * (docs/40-watch-app-plan.md — mirrors iOS's `WorkoutManager` forwarding
     * every `HKLiveWorkoutBuilderDelegate` tick). No-ops before
     * [startExercise] has recorded a [currentSessionClientId]. */
    private fun sendLiveMetrics() {
        val sessionClientId = currentSessionClientId ?: return
        val liveMetrics = SessionStateHolder.liveMetrics.value
        scope.launch {
            SummarySender.sendLiveMetrics(
                context = this@ExerciseService,
                sessionClientId = sessionClientId,
                heartRateBpm = liveMetrics.heartRateBpm,
                activeCalories = liveMetrics.activeCalories,
            )
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        // Runs for this service's whole lifetime, not just start/end — a
        // rest timer can start/end/restart many times within one exercise
        // (docs/40-watch-app-plan.md §5.4/F4).
        scope.launch {
            SessionStateHolder.metadata
                .map { it.restDeadlineElapsedRealtimeMs }
                .distinctUntilChanged()
                .collect { deadlineElapsedRealtimeMs -> scheduleRestVibration(deadlineElapsedRealtimeMs) }
        }
        // Same "for the service's whole lifetime" treatment as the rest
        // haptic above — see [logSetJob].
        scope.launch {
            SessionStateHolder.logSetState.collect { state -> scheduleLogSetTransition(state) }
        }
        // The adjust stepper's idle-dismiss timer and per-step haptic live
        // here rather than on the Compose screen for the same reason as the
        // rest/log-set jobs above (docs/watch/48-watch-f5b-set-adjust-plan.md
        // §6.2): dropping the UI mid-adjust must not strand the timer.
        scope.launch {
            var previousValues: Pair<Int, Double>? = null
            SessionStateHolder.logAdjustState.collect { state ->
                scheduleLogAdjustIdleDismiss(state)
                val values = state?.let { it.reps to it.weight }
                // Tick only on a real value change *within* an open stepper —
                // not when it opens (previous == null) or closes (values ==
                // null), and not on a bare field toggle.
                if (previousValues != null && values != null && values != previousValues) {
                    vibrateLogAdjustTick()
                }
                previousValues = values
            }
        }
        // Keeps the recovery snapshot current after every locally logged
        // standalone set (docs/watch/44-watch-f6-standalone-plan.md §3.2) —
        // observed here rather than called from the (not-yet-built, S17)
        // log-tap UI, so this service stays the single owner of
        // `StandaloneSessionStore` writes. Harmlessly no-ops via
        // [saveStandaloneActiveSnapshot]'s own guards outside standalone
        // mode, including the first (empty-list) emission every flow
        // collector gets on subscribe.
        scope.launch {
            SessionStateHolder.metadata
                .map { it.standaloneSets }
                .distinctUntilChanged()
                .collect { saveStandaloneActiveSnapshot() }
        }
    }

    /**
     * [deadlineElapsedRealtimeMs] is anchored to this device's own
     * `SystemClock.elapsedRealtime()` (docs/40-watch-app-plan.md §12.1
     * bugfix) — comparing it against `System.currentTimeMillis()` here would
     * reintroduce the exact cross-device wall-clock bug this field exists to
     * avoid (see `SessionStateHolder.SessionMetadata`'s doc comment): a
     * wall-clock target would previously schedule the haptic hours late (or
     * early) whenever the watch's and phone's clocks disagreed.
     */
    private fun scheduleRestVibration(deadlineElapsedRealtimeMs: Long?) {
        restVibrationJob?.cancel()
        if (deadlineElapsedRealtimeMs == null) return
        restVibrationJob = scope.launch {
            val delayMs = deadlineElapsedRealtimeMs - SystemClock.elapsedRealtime()
            if (delayMs > 0) delay(delayMs)
            vibrateRestEnd()
        }
    }

    private fun vibrateRestEnd() {
        val vibrator = getSystemService(Vibrator::class.java) ?: return
        vibrator.vibrate(VibrationEffect.createOneShot(400, VibrationEffect.DEFAULT_AMPLITUDE))
    }

    /**
     * Reacts to every [LogSetState] change (docs/watch/
     * 43-watch-f5-set-logging-plan.md §3.2) by (re)scheduling exactly one of:
     * the 5 s ack-timeout ([LogSetState.Pending]), or a confirm/fail haptic
     * followed by the 1.2 s/2.5 s settle-back-to-Ready
     * ([LogSetState.Confirmed]/[LogSetState.Failed]). [LogSetState.Ready]
     * itself needs nothing scheduled — cancelling the previous job is enough
     * (harmless even if that job already finished on its own, e.g. the
     * settle job that just called `onLogSetSettled()` and produced this very
     * `Ready` emission).
     */
    private fun scheduleLogSetTransition(state: LogSetState) {
        logSetJob?.cancel()
        logSetJob = when (state) {
            is LogSetState.Ready -> null
            is LogSetState.Pending -> scope.launch {
                delay(LOG_SET_ACK_TIMEOUT_MS)
                SessionStateHolder.onLogSetTimeout(state.eventId)
            }
            is LogSetState.Confirmed -> scope.launch {
                vibrateLogSetConfirmed()
                delay(LOG_SET_CONFIRMED_SETTLE_MS)
                SessionStateHolder.onLogSetSettled()
            }
            is LogSetState.Failed -> scope.launch {
                vibrateLogSetFailed()
                delay(LOG_SET_FAILED_SETTLE_MS)
                SessionStateHolder.onLogSetSettled()
            }
        }
    }

    private fun vibrateLogSetConfirmed() {
        val vibrator = getSystemService(Vibrator::class.java) ?: return
        // Short double pulse — success (docs/watch/43-watch-f5-set-logging-plan.md §3.2).
        vibrator.vibrate(VibrationEffect.createWaveform(longArrayOf(0, 60, 80, 60), -1))
    }

    /**
     * Restarted by every stepper interaction, so it measures *idle* time
     * rather than time-since-open (D-F5b.7). A null state means the stepper
     * closed — cancelling is then all there is to do.
     */
    private fun scheduleLogAdjustIdleDismiss(state: LogAdjustState?) {
        logAdjustIdleJob?.cancel()
        if (state == null) return
        logAdjustIdleJob = scope.launch {
            delay(LOG_ADJUST_IDLE_DISMISS_MS)
            SessionStateHolder.onLogAdjustCancelled()
        }
    }

    /**
     * One detent's worth of feedback while dialling a value (§11/5). Wear has
     * no built-in detent haptic for a *custom* value stepper — the automatic
     * one belongs to `rotaryScrollableBehavior`, which the adjust view
     * doesn't use — so unlike watchOS this has to be fired by hand. Kept
     * deliberately lighter than [vibrateLogSetConfirmed]/[vibrateLogSetFailed]:
     * the stepper "clicks", the log "confirms".
     */
    private fun vibrateLogAdjustTick() {
        val vibrator = getSystemService(Vibrator::class.java) ?: return
        vibrator.vibrate(VibrationEffect.createPredefined(VibrationEffect.EFFECT_TICK))
    }

    private fun vibrateLogSetFailed() {
        val vibrator = getSystemService(Vibrator::class.java) ?: return
        // One longer pulse — failure, same shape as vibrateRestEnd's.
        vibrator.vibrate(VibrationEffect.createOneShot(400, VibrationEffect.DEFAULT_AMPLITUDE))
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val sessionClientId = intent?.getStringExtra(EXTRA_SESSION_CLIENT_ID)
        when (intent?.action) {
            ACTION_START -> {
                if (sessionClientId == null) {
                    stopSelf()
                    return START_NOT_STICKY
                }
                promoteToForeground()
                scope.launch { startExercise(sessionClientId) }
            }
            ACTION_END -> {
                // Re-promoting is a safe no-op if already foreground, and
                // required if this service instance was recreated (e.g. the
                // process died) since Android 12+ blocks a plain background
                // startService in that case.
                promoteToForeground()
                scope.launch { endExercise() }
            }
            ACTION_START_STANDALONE -> {
                promoteToForeground()
                scope.launch { startStandaloneExercise() }
            }
            ACTION_END_STANDALONE -> {
                val rpe = if (intent.hasExtra(EXTRA_RPE)) intent.getIntExtra(EXTRA_RPE, 0) else null
                promoteToForeground()
                scope.launch { endStandaloneExercise(rpe) }
            }
            else -> stopSelf()
        }
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        scope.cancel()
        super.onDestroy()
    }

    private fun promoteToForeground() {
        val channel = NotificationChannel(
            CHANNEL_ID, getString(R.string.exercise_notification_channel), NotificationManager.IMPORTANCE_LOW,
        )
        getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
        val notification: Notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(getString(R.string.exercise_notification_title))
            .setSmallIcon(R.drawable.ic_stat_lifey)
            .setOngoing(true)
            .build()
        ServiceCompat.startForeground(
            this, NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_HEALTH,
        )
    }

    /**
     * Shared by [startExercise] and [startStandaloneExercise] — checks the
     * heart-rate permission, publishes it (§12.1 B13), and builds the
     * `ExerciseConfig` both start paths use identically.
     */
    private fun buildExerciseConfig(): ExerciseConfig {
        // Either satisfies it depending on OS version — BODY_SENSORS pre-36,
        // the granular health permission on 36+ (see MainActivity, which
        // requests both). Health Services itself enforces the latter with a
        // SecurityException regardless of BODY_SENSORS on a 36 system image.
        val hasHeartRatePermission =
            ContextCompat.checkSelfPermission(this, Manifest.permission.BODY_SENSORS) ==
                PackageManager.PERMISSION_GRANTED ||
                ContextCompat.checkSelfPermission(this, "android.permission.health.READ_HEART_RATE") ==
                    PackageManager.PERMISSION_GRANTED

        // §12.1 B13: the Compose UI needs this to tell "permission denied"
        // apart from "no HR sample has arrived yet" and show the degraded
        // state accordingly.
        SessionStateHolder.onHeartRatePermissionChecked(hasHeartRatePermission)

        // Always requestable — CALORIES (like CALORIES_TOTAL) doesn't need
        // BODY_SENSORS, it's derived from motion/user profile, not the heart
        // rate sensor.
        val dataTypes = buildSet {
            add(DataType.CALORIES)
            if (hasHeartRatePermission) add(DataType.HEART_RATE_BPM)
        }

        return ExerciseConfig(
            exerciseType = ExerciseType.STRENGTH_TRAINING,
            dataTypes = dataTypes,
            isAutoPauseAndResumeEnabled = false,
            isGpsEnabled = false,
        )
    }

    private suspend fun startExercise(sessionClientId: String) {
        currentSessionClientId = sessionClientId
        val config = buildExerciseConfig()
        try {
            exerciseClient.setUpdateCallback(updateCallback)
            exerciseClient.startExerciseAsync(config).await()
            SessionStateHolder.onExerciseActive(SystemClock.elapsedRealtime())
            SummarySender.sendStartedOnWatch(this, sessionClientId)
        } catch (e: Exception) {
            // Another app already owns an exercise, or the sensor/service is
            // unavailable — docs/40-watch-app-plan.md §5.3, §8.1. §12.1 B12:
            // surface it locally too, not just to the phone — the ongoing
            // notification promoteToForeground() already posted would
            // otherwise claim an exercise is running when it isn't.
            Log.w(TAG, "startExercise failed for $sessionClientId", e)
            SessionStateHolder.onStartRejected()
            SummarySender.sendStartRejected(this, sessionClientId)
            ServiceCompat.stopForeground(this, ServiceCompat.STOP_FOREGROUND_REMOVE)
            stopSelf()
        }
    }

    /**
     * Entry point for the launcher's "Start workout" / picker's "Quick
     * strength" tap (docs/watch/44-watch-f6-standalone-plan.md §3.1) — no
     * `sessionClientId` from the phone this time, since there's no
     * phone-mastered session to hang off: the watch generates its own.
     * Guarded on `SessionPhase.IDLE` (mirrors iOS's `guard phase == .idle`
     * in `startStandalone()`) so a double-tap on the picker's "Quick
     * strength" row — S16 doesn't debounce it, this is where that
     * protection actually has to live — can't launch two overlapping
     * exercises.
     */
    private suspend fun startStandaloneExercise() {
        if (SessionStateHolder.phase.value != SessionPhase.IDLE) return
        val sessionClientId = UUID.randomUUID().toString()
        currentSessionClientId = sessionClientId
        val config = buildExerciseConfig()
        try {
            exerciseClient.setUpdateCallback(updateCallback)
            exerciseClient.startExerciseAsync(config).await()
            SessionStateHolder.onStandaloneStarted(sessionClientId, SystemClock.elapsedRealtime())
            saveStandaloneActiveSnapshot()
        } catch (e: Exception) {
            // Another app owns the sensors — unlike startExercise, there's
            // no phone waiting on a sessionClientId to reject against here,
            // so just fail back to idle silently (a dedicated error state
            // is out of scope for F6a).
            Log.w(TAG, "startStandaloneExercise failed", e)
            currentSessionClientId = null
            ServiceCompat.stopForeground(this, ServiceCompat.STOP_FOREGROUND_REMOVE)
            stopSelf()
        }
    }

    private suspend fun endExercise() {
        val sessionClientId = SessionStateHolder.metadata.value.sessionClientId
        try {
            exerciseClient.endExerciseAsync().await()
        } catch (e: Exception) {
            Log.w(TAG, "endExercise failed", e)
        }
        if (sessionClientId != null) {
            val averageHeartRate = if (heartRateSamples > 0) heartRateSum / heartRateSamples else null
            SummarySender.sendSummary(
                context = this,
                sessionClientId = sessionClientId,
                activeCalories = activeCaloriesTotal,
                averageHeartRate = averageHeartRate,
            )
        }
        SessionStateHolder.reset()
        ServiceCompat.stopForeground(this, ServiceCompat.STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    /**
     * The standalone counterpart of [endExercise] (docs/watch/
     * 44-watch-f6-standalone-plan.md §3.1, §4.1) — closes the Health
     * Services exercise the same way, but queues the finished session for
     * delivery instead of sending a live `sendSummary`, and moves to
     * `SessionPhase.SUMMARY` (with a ~6 s auto-dismiss, D-F6.7) instead of
     * going straight back to idle. [rpe] is whatever the watch's own
     * effort-selector produced (null if skipped) — same source as
     * [SummarySender.sendEndRequested]'s [rpe] on the phone-mastered path.
     */
    private suspend fun endStandaloneExercise(rpe: Int?) {
        val metadata = SessionStateHolder.metadata.value
        val sessionClientId = metadata.sessionClientId
        val startedAtElapsedRealtimeMs = SessionStateHolder.liveMetrics.value.startedAtElapsedRealtimeMs
        val setsCount = metadata.standaloneSets.size

        try {
            exerciseClient.endExerciseAsync().await()
        } catch (e: Exception) {
            Log.w(TAG, "endStandaloneExercise failed", e)
        }

        if (sessionClientId != null) {
            val averageHeartRate = if (heartRateSamples > 0) heartRateSum / heartRateSamples else null
            val nowElapsedRealtimeMs = SystemClock.elapsedRealtime()
            val nowEpochMs = System.currentTimeMillis()
            // Converts this device's own monotonic start mark back to an
            // epoch instant for the wire payload (§4.1) — the reverse of
            // what SessionStateHolder.onStateSynced does for the phone's
            // rest deadline, same reasoning: only this device's own clock
            // readings are compared against each other here.
            val startedAtEpochMs = startedAtElapsedRealtimeMs?.let {
                nowEpochMs - (nowElapsedRealtimeMs - it)
            } ?: nowEpochMs
            val totalDurationSeconds = startedAtElapsedRealtimeMs?.let {
                ((nowElapsedRealtimeMs - it) / 1_000L).toInt()
            } ?: 0

            val payload = JSONObject().apply {
                put("standaloneSessionId", sessionClientId)
                put("startedAtEpochMs", startedAtEpochMs)
                put("endedAtEpochMs", nowEpochMs)
                putOpt("rpe", rpe)
                put(
                    "sets",
                    JSONArray().apply {
                        metadata.standaloneSets.forEach { set ->
                            put(
                                JSONObject().apply {
                                    put("loggedAtEpochMs", set.loggedAtEpochMs)
                                    put("reps", set.reps)
                                    putOpt("exerciseIndex", set.exerciseIndex)
                                },
                            )
                        }
                    },
                )
                putOpt("activeCalories", activeCaloriesTotal)
                putOpt("averageHeartRate", averageHeartRate)
                // Android never writes Health Connect from the watch — the
                // phone does (D-F6.5) — so healthWorkoutId is simply absent
                // rather than an explicit null (matches how the rest of
                // this payload omits absent optionals).
            }
            StandaloneSessionStore.add(this, payload.toString())
            StandaloneSessionStore.clearActive(this)
            SummarySender.flushPending(this)

            SessionStateHolder.onStandaloneEnded(
                StandaloneSummary(
                    standaloneSessionId = sessionClientId,
                    totalDurationSeconds = totalDurationSeconds,
                    setsCount = setsCount,
                    averageHeartRate = averageHeartRate,
                    activeCalories = activeCaloriesTotal,
                ),
            )
            // Notification comes down right away — the workout genuinely
            // ended — but the service (and this coroutine's scope) stays
            // alive a little longer for the delayed reset below.
            ServiceCompat.stopForeground(this, ServiceCompat.STOP_FOREGROUND_REMOVE)
            scheduleSummaryAutoDismiss()
        } else {
            SessionStateHolder.reset()
            ServiceCompat.stopForeground(this, ServiceCompat.STOP_FOREGROUND_REMOVE)
            stopSelf()
        }
    }

    /** Mirrors iOS's `scheduleSummaryAutoDismiss()` — falls
     * `SessionPhase.SUMMARY` back to idle on its own after
     * [SUMMARY_AUTO_DISMISS_MS] (docs/40-watch-app-plan.md §12.1 B9's ~6 s,
     * reused for D-F6.7's standalone summary). */
    private fun scheduleSummaryAutoDismiss() {
        summaryDismissJob?.cancel()
        summaryDismissJob = scope.launch {
            delay(SUMMARY_AUTO_DISMISS_MS)
            SessionStateHolder.reset()
            stopSelf()
        }
    }

    /** Overwrites the live standalone session's recovery snapshot — called
     * on start and after every locally logged set (docs/watch/
     * 44-watch-f6-standalone-plan.md §3.2). Recovery itself (reading this
     * back after a process death) isn't implemented yet — out of scope for
     * S15, flagged as an open gap (§10). */
    private fun saveStandaloneActiveSnapshot() {
        val metadata = SessionStateHolder.metadata.value
        val sessionClientId = metadata.sessionClientId ?: return
        val startedAtElapsedRealtimeMs = SessionStateHolder.liveMetrics.value.startedAtElapsedRealtimeMs ?: return
        val nowElapsedRealtimeMs = SystemClock.elapsedRealtime()
        val nowEpochMs = System.currentTimeMillis()
        val startedAtEpochMs = nowEpochMs - (nowElapsedRealtimeMs - startedAtElapsedRealtimeMs)

        val json = JSONObject().apply {
            put("standaloneSessionId", sessionClientId)
            put("startedAtEpochMs", startedAtEpochMs)
            put(
                "sets",
                JSONArray().apply {
                    metadata.standaloneSets.forEach { set ->
                        put(
                            JSONObject().apply {
                                put("loggedAtEpochMs", set.loggedAtEpochMs)
                                put("reps", set.reps)
                                putOpt("exerciseIndex", set.exerciseIndex)
                            },
                        )
                    }
                },
            )
        }
        StandaloneSessionStore.saveActive(this, json.toString())
    }

    companion object {
        private const val TAG = "LifeyExerciseService"
        private const val CHANNEL_ID = "lifey_exercise"
        private const val NOTIFICATION_ID = 1001

        // "+1 set" timing (docs/watch/43-watch-f5-set-logging-plan.md §3.2, §10/4).
        private const val LOG_SET_ACK_TIMEOUT_MS = 5_000L

        /** How long the adjust stepper stays up without any interaction —
         * **3 s, deliberately longer than the design's 2 s** (§11/3): on a
         * wrist a single glance away shouldn't cost the half-dialled value,
         * and the wait costs nothing since the view never logs on its own. */
        private const val LOG_ADJUST_IDLE_DISMISS_MS = 3_000L
        private const val LOG_SET_CONFIRMED_SETTLE_MS = 1_200L
        private const val LOG_SET_FAILED_SETTLE_MS = 2_500L

        // Standalone SUMMARY auto-dismiss (docs/watch/
        // 44-watch-f6-standalone-plan.md D-F6.7, mirrors iOS's ~6 s).
        private const val SUMMARY_AUTO_DISMISS_MS = 6_000L

        const val ACTION_START = "com.khunor.lifey.action.START_EXERCISE"
        const val ACTION_END = "com.khunor.lifey.action.END_EXERCISE"
        const val EXTRA_SESSION_CLIENT_ID = "sessionClientId"

        const val ACTION_START_STANDALONE = "com.khunor.lifey.action.START_STANDALONE_EXERCISE"
        const val ACTION_END_STANDALONE = "com.khunor.lifey.action.END_STANDALONE_EXERCISE"
        const val EXTRA_RPE = "rpe"

        fun startIntent(context: Context, sessionClientId: String) =
            Intent(context, ExerciseService::class.java).apply {
                action = ACTION_START
                putExtra(EXTRA_SESSION_CLIENT_ID, sessionClientId)
            }

        fun endIntent(context: Context) =
            Intent(context, ExerciseService::class.java).apply {
                action = ACTION_END
            }

        /** Entry point for the launcher/picker "Quick strength" tap (S16) —
         * no `sessionClientId` extra, `startStandaloneExercise` generates
         * its own (docs/watch/44-watch-f6-standalone-plan.md §3.1). */
        fun startStandaloneIntent(context: Context) =
            Intent(context, ExerciseService::class.java).apply {
                action = ACTION_START_STANDALONE
            }

        /** Entry point for the End button in standalone mode (S17). [rpe] is
         * whatever the watch's own effort-selector produced, omitted
         * entirely when null (mirrors [SummarySender.sendEndRequested]'s
         * `putOpt` treatment of the same field). */
        fun endStandaloneIntent(context: Context, rpe: Int?) =
            Intent(context, ExerciseService::class.java).apply {
                action = ACTION_END_STANDALONE
                rpe?.let { putExtra(EXTRA_RPE, it) }
            }

        /**
         * Pause/resume (docs/40-watch-app-plan.md §12.1 B3) go straight
         * through a fresh [androidx.health.services.client.ExerciseClient]
         * handle rather than through this service's Binder — the exercise
         * session lives in the system Health Services process, not in this
         * [ExerciseService] instance, so any client handle for this app can
         * command it. Unlike End (§8.2 decision (b)), this never involves the
         * phone: only the *sensor* session pauses, the phone-session's own
         * timing is untouched (§4.4/§5.3).
         */
        suspend fun pause(context: Context) {
            try {
                HealthServices.getClient(context).exerciseClient.pauseExerciseAsync().await()
            } catch (e: Exception) {
                Log.w(TAG, "pauseExercise failed", e)
            }
        }

        suspend fun resume(context: Context) {
            try {
                HealthServices.getClient(context).exerciseClient.resumeExerciseAsync().await()
            } catch (e: Exception) {
                Log.w(TAG, "resumeExercise failed", e)
            }
        }
    }
}
