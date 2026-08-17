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
import androidx.health.services.client.data.ExerciseTrackedStatus
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

    /**
     * The activity type this exercise was started with (docs/cardio/
     * 55-cardio-watch-plan.md §2, C5.6/C5.7a) — `null` for STRENGTH (every
     * pre-cardio session). Drives both [buildExerciseConfig]'s
     * `dataTypes`/`ExerciseType` choice at start and, at end, whether
     * [endExercise]/[endStandaloneExercise] have any distance/elevation to
     * report back at all.
     */
    private var currentActivityType: String? = null

    // Latest cumulative reading per aggregate data type (docs/cardio/
    // 55-cardio-watch-plan.md §4.3, C5.7a) — unlike [activeCaloriesTotal]'s
    // hand-summed delta, these are already running totals Health Services
    // computes itself, so the *last* value read is the final one; no summing
    // needed. Only ever non-null when [buildExerciseConfig] actually
    // requested (and the device's capabilities actually granted) the
    // matching data type — see [cardioSummaryJson].
    private var lastDistanceMeters: Double? = null
    private var lastElevationGainMeters: Double? = null
    private var lastElevationLossMeters: Double? = null

    // Running cadence (docs/cardio/60-cardio-sport-specifics-plan.md C6.5).
    // STEPS_PER_MINUTE_STATS is a *statistical* aggregate, so Health Services
    // hands over the average and the max already computed — no summing by
    // hand, unlike [activeCaloriesTotal]. Only ever non-null for a RUNNING
    // session whose device actually backs the data type: walking and hiking
    // never request it (see [buildExerciseConfig]), so their summary carries
    // no cadence at all rather than a number nobody asked for.
    private var lastAvgCadence: Double? = null
    private var lastMaxCadence: Double? = null

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
            // Cumulative aggregates — the latest reading already *is* the
            // running total, unlike CALORIES above (see [lastDistanceMeters]'s
            // own doc). A no-op when the data type wasn't requested at all
            // (`getData` simply returns null then).
            update.latestMetrics.getData(DataType.DISTANCE_TOTAL)?.total?.let { lastDistanceMeters = it }
            update.latestMetrics.getData(DataType.ELEVATION_GAIN_TOTAL)?.total?.let { lastElevationGainMeters = it }
            update.latestMetrics.getData(DataType.ELEVATION_LOSS_TOTAL)?.total?.let { lastElevationLossMeters = it }
            update.latestMetrics.getData(DataType.STEPS_PER_MINUTE_STATS)?.let { stats ->
                lastAvgCadence = stats.average.toDouble()
                lastMaxCadence = stats.max.toDouble()
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
        // collector gets on subscribe. Also re-sends the live-bridging
        // adoption snapshot on the same trigger — a real set-count change,
        // not the initial empty-list emission every collector gets on
        // subscribe (that one's already covered by the explicit call right
        // after `SessionStateHolder.onStandaloneStarted` in
        // [startStandaloneExercise]) — so an already-adopted phone mirror
        // stays in sync with every set as it lands, not just at start/end.
        scope.launch {
            SessionStateHolder.metadata
                // The current exercise counts as a change too, not just the set
                // list: [SessionStateHolder.onStateSynced] can move it on its
                // own when a set logged on the phone completes the exercise, and
                // that new position has to be persisted for recovery and told to
                // the phone just like a locally logged set's would be.
                .map { it.standaloneSets to it.standaloneExerciseIndex }
                .distinctUntilChanged()
                .collect {
                    saveStandaloneActiveSnapshot()
                    SummarySender.sendAdoptionRequestIfNeeded(this@ExerciseService)
                }
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
                val activityType = intent.getStringExtra(EXTRA_ACTIVITY_TYPE)
                scope.launch { startExercise(sessionClientId, activityType) }
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
                val templateJson = intent.getStringExtra(EXTRA_TEMPLATE_JSON)
                val activityType = intent.getStringExtra(EXTRA_ACTIVITY_TYPE)
                promoteToForeground()
                scope.launch { startStandaloneExercise(templateJson, activityType) }
            }
            ACTION_END_STANDALONE -> {
                val rpe = if (intent.hasExtra(EXTRA_RPE)) intent.getIntExtra(EXTRA_RPE, 0) else null
                promoteToForeground()
                scope.launch { endStandaloneExercise(rpe) }
            }
            ACTION_RECOVER_STANDALONE -> {
                promoteToForeground()
                scope.launch { recoverStandaloneExercise() }
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
     * `ExerciseConfig` both start paths use, keyed off [activityType]
     * (docs/cardio/55-cardio-watch-plan.md §2, C5.6). `null` — every
     * pre-cardio (STRENGTH) call site — reproduces the original hardcoded
     * `STRENGTH_TRAINING`/no-extra-`dataTypes` config exactly. `venue` (the
     * other C5.2 field the phone sends) has nothing to bind to here: it
     * drives `HKWorkoutSessionLocationType` on iOS, and `ExerciseConfig` —
     * confirmed via the health-services-client 1.0.0 API surface — has no
     * indoor/outdoor field at all, only `isGpsEnabled` (unconditionally
     * `false` below, unchanged: watch-GPS is future "W4" work,
     * docs/cardio/55-cardio-watch-plan.md §6, out of C5.6's scope same as
     * it was out of iOS's C5.4/C5.5).
     *
     * `suspend`, unlike before C5.6: cardio's extra `dataTypes`
     * (`DISTANCE_TOTAL`/`PACE`/`ELEVATION_GAIN_TOTAL`) aren't safe to request
     * unconditionally — D-C5.2 ([55 §2](docs/cardio/55-cardio-watch-plan.md))
     * is explicit that requesting one the device's sensor set can't back
     * throws `ExerciseCapabilities` — so this queries
     * [androidx.health.services.client.ExerciseClient.getCapabilitiesAsync]
     * for the chosen [ExerciseType] first and intersects the desired set
     * against what it actually reports supported, rather than requesting the
     * D-C5.2 table blindly. STRENGTH_TRAINING's own two data types
     * (CALORIES/HEART_RATE_BPM) skip this check, unchanged from before this
     * step — they were never observed to be a problem, and this is a
     * cardio-specific caution, not a blanket new requirement.
     */
    private suspend fun buildExerciseConfig(activityType: String?): ExerciseConfig {
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

        val exerciseType = cardioExerciseType(activityType)

        // Always requestable — CALORIES (like CALORIES_TOTAL) doesn't need
        // BODY_SENSORS, it's derived from motion/user profile, not the heart
        // rate sensor.
        val desiredDataTypes = buildSet {
            add(DataType.CALORIES)
            if (hasHeartRatePermission) add(DataType.HEART_RATE_BPM)
            if (activityType != null) {
                val family = cardioActivityFamily(activityType)
                if (family == CardioActivityFamily.DISTANCE || family == CardioActivityFamily.MACHINE) {
                    add(DataType.DISTANCE_TOTAL)
                }
                if (family == CardioActivityFamily.DISTANCE) {
                    add(DataType.PACE)
                    add(DataType.ELEVATION_GAIN_TOTAL)
                }
                // Cadence is running's metric, not the whole DISTANCE
                // family's (C6.5): a walker's or hiker's steps-per-minute is
                // a number nobody trains on, and the summary deliberately
                // has no place to show it. Requesting it anyway would put it
                // on the wire for the phone to then ignore.
                if (activityType == "RUNNING") {
                    add(DataType.STEPS_PER_MINUTE_STATS)
                }
            }
        }
        // D-C5.2's own warning: "nem kérünk olyan adattípust, amit a
        // szenzorkészlet nem tud" — only the cardio-only additions above need
        // this (CALORIES/HEART_RATE_BPM are the pre-cardio baseline, never
        // gated). A capabilities lookup failure (an old watch, or the OS
        // genuinely has nothing to say) falls back to the ungated set rather
        // than blocking the start on it — same "degrade, don't fail" spirit
        // as every other capability check in this codebase.
        val dataTypes = if (activityType == null) {
            desiredDataTypes
        } else {
            try {
                val supported = exerciseClient.getCapabilitiesAsync().await()
                    .getExerciseTypeCapabilities(exerciseType)?.supportedDataTypes
                supported?.let { desiredDataTypes.intersect(it) } ?: desiredDataTypes
            } catch (e: Exception) {
                Log.w(TAG, "getCapabilitiesAsync failed, requesting the ungated data type set", e)
                desiredDataTypes
            }
        }

        return ExerciseConfig(
            exerciseType = exerciseType,
            dataTypes = dataTypes,
            isAutoPauseAndResumeEnabled = false,
            isGpsEnabled = false,
        )
    }

    /**
     * ExerciseType per `ActivityType` (docs/cardio/55-cardio-watch-plan.md
     * §2's table) — `null` (every pre-cardio call) keeps the original
     * `STRENGTH_TRAINING`. `SOCCER`, not the table's literal
     * "FOOTBALL_SOCCER" — the real `androidx.health.services.client.data
     * .ExerciseType` enum (health-services-client 1.0.0) has no constant by
     * that exact name; `SOCCER` is what actually exists and is football's
     * closest match. An unrecognized code (a future activity type this build
     * predates) falls back to `WORKOUT`, the same generic type `OTHER_CARDIO`
     * itself uses.
     */
    private fun cardioExerciseType(activityType: String?): ExerciseType = when (activityType) {
        null -> ExerciseType.STRENGTH_TRAINING
        "RUNNING" -> ExerciseType.RUNNING
        "WALKING" -> ExerciseType.WALKING
        "HIKING" -> ExerciseType.HIKING
        "INDOOR_BIKE" -> ExerciseType.BIKING_STATIONARY
        "BASKETBALL" -> ExerciseType.BASKETBALL
        "FOOTBALL" -> ExerciseType.SOCCER
        else -> ExerciseType.WORKOUT // OTHER_CARDIO, and any future/unknown code
    }

    private suspend fun startExercise(sessionClientId: String, activityType: String? = null) {
        currentSessionClientId = sessionClientId
        currentActivityType = activityType
        lastDistanceMeters = null
        lastElevationGainMeters = null
        lastElevationLossMeters = null
        lastAvgCadence = null
        lastMaxCadence = null
        val config = buildExerciseConfig(activityType)
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
     * strength" **and** synced-template rows (docs/watch/
     * 44-watch-f6-standalone-plan.md §3.1; docs/watch/
     * 49-watch-f6b-template-sync-plan.md §3.3, T6) — no `sessionClientId`
     * from the phone this time, since there's no phone-mastered session to
     * hang off: the watch generates its own. Guarded on `SessionPhase.IDLE`
     * (mirrors iOS's `guard phase == .idle` in `startStandalone()`) so a
     * double-tap on the picker — S16 doesn't debounce it, this is where that
     * protection actually has to live — can't launch two overlapping
     * exercises.
     *
     * [templateJson] is the exact JSON `StandaloneSessionStore.entries()`
     * returned for the tapped row (`MainActivity`'s `onTemplateTapped`), or
     * `null` for Quick strength — decoded exactly once, here, into the typed
     * [StandaloneTemplate] the session state holds from then on. [activityType]
     * (docs/cardio/55-cardio-watch-plan.md §5, §7 W-8, C5.7a) is the *other*
     * kind of standalone start — a `CARDIO` row from the same picker, no
     * template, mutually exclusive with [templateJson] (`MainActivity` never
     * passes both).
     */
    private suspend fun startStandaloneExercise(templateJson: String?, activityType: String? = null) {
        if (SessionStateHolder.phase.value != SessionPhase.IDLE) return
        val sessionClientId = UUID.randomUUID().toString()
        currentSessionClientId = sessionClientId
        currentActivityType = activityType
        lastDistanceMeters = null
        lastElevationGainMeters = null
        lastElevationLossMeters = null
        lastAvgCadence = null
        lastMaxCadence = null
        val template = templateJson?.let { parseStandaloneTemplate(it) }
        val config = buildExerciseConfig(activityType)
        try {
            exerciseClient.setUpdateCallback(updateCallback)
            exerciseClient.startExerciseAsync(config).await()
            SessionStateHolder.onStandaloneStarted(
                sessionClientId, SystemClock.elapsedRealtime(), template, activityType,
            )
            saveStandaloneActiveSnapshot()
            // Live bridging: if a phone is already connected at the exact
            // moment the session starts, ask it to join in right away. If
            // not, PhoneListenerService.onPeerConnected retries this the
            // moment the phone reconnects, so a workout started out of
            // range still gets adopted as soon as the phone comes back.
            SummarySender.sendAdoptionRequestIfNeeded(this)
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
                cardio = cardioSummaryJson(),
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
                putOpt("templateId", metadata.standaloneTemplate?.templateId)
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
                                    putOpt("weight", set.weight)
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
                // docs/cardio/55-cardio-watch-plan.md §5/§7 W-8, C5.7a — a
                // standalone CARDIO session, mutually exclusive with the
                // `sets`/`templateId` above (always empty/absent for one).
                // `movingSeconds` is deliberately omitted: standalone has no
                // pause-aware moving-time tracking of its own (the GAME
                // pályán/padon distinction is C5.7's phone-mastered-only
                // territory so far), so the phone's own
                // `_createCardioSession` fallback — the full wall-clock
                // duration — is exactly right here, not something this
                // needs to compute and possibly get wrong.
                currentActivityType?.let { activityType ->
                    put("kind", "CARDIO")
                    put("activityType", activityType)
                    cardioSummaryJson()?.let { put("cardio", it) }
                }
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

    /**
     * The distance/elevation half of a cardio closing summary (docs/cardio/
     * 55-cardio-watch-plan.md §4.3, C5.7a) — `null` whenever this wasn't a
     * cardio session ([currentActivityType] null), or Health Services never
     * actually reported any of these (an indoor/no-GPS device, or
     * [buildExerciseConfig]'s capability check dropped the data type — a
     * MACHINE/GAME session, which never requests them at all). Matches
     * `CardioMetrics.fromJson`'s key names (`mobile/lib/features/workouts/
     * domain/workout_session.dart`) so the phone decodes this exactly like
     * every other cardio JSON block already does.
     *
     * `distanceSource: "DEVICE"` is sent whenever this watch measured a
     * distance, unconditionally — the phone side
     * (`CardioMetrics.mergedWithWatchMeasurement`) is what actually decides
     * whether that tag sticks (only when the phone's own distance was null),
     * so there's nothing to gate here.
     */
    private fun cardioSummaryJson(): JSONObject? {
        if (currentActivityType == null) return null
        if (lastDistanceMeters == null && lastElevationGainMeters == null &&
            lastElevationLossMeters == null && lastAvgCadence == null
        ) {
            return null
        }
        return JSONObject().apply {
            putOpt("distanceMeters", lastDistanceMeters)
            if (lastDistanceMeters != null) put("distanceSource", "DEVICE")
            putOpt("elevationGainMeters", lastElevationGainMeters)
            putOpt("elevationLossMeters", lastElevationLossMeters)
            // Absent unless the sensor genuinely reported it (C6.5's kész-ha)
            // — putOpt drops a null key entirely, so the phone sees "no
            // cadence", not "cadence: 0".
            putOpt("avgCadence", lastAvgCadence)
            putOpt("maxCadence", lastMaxCadence)
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
     * 44-watch-f6-standalone-plan.md §3.2). Read back by
     * [recoverStandaloneExercise] after a process death/reboot (§11/6). */
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
            put("exerciseIndex", metadata.standaloneExerciseIndex)
            // docs/cardio/55-cardio-watch-plan.md §5/§7 W-8, C5.7a — restores
            // the right active screen (`ActiveWorkoutScreen`'s
            // `metadata.isCardio` dispatch) after a process death mid-standalone-
            // cardio-session, same as every other recovered field here.
            if (metadata.isCardio) {
                put("kind", metadata.kind)
                metadata.cardioActivityType?.let { put("activityType", it) }
            }
            metadata.standaloneTemplate?.let { put("template", it.toJson()) }
            // The phone's live plan as it stood at this save (F6c) — restored
            // with the session so `exerciseIndex` still means a position in
            // the *same* list after a process death. Without it a recovered
            // session would read a plan position as a template position and
            // land on whatever exercise happened to sit there.
            metadata.sessionPlanExercises?.let {
                put("sessionPlan", StandalonePlanJson.exercisesToJson(it))
            }
            put(
                "sets",
                JSONArray().apply {
                    metadata.standaloneSets.forEach { set ->
                        put(
                            JSONObject().apply {
                                put("loggedAtEpochMs", set.loggedAtEpochMs)
                                put("reps", set.reps)
                                putOpt("weight", set.weight)
                                putOpt("exerciseIndex", set.exerciseIndex)
                                putOpt("exerciseId", set.exerciseId)
                            },
                        )
                    }
                },
            )
        }
        StandaloneSessionStore.saveActive(this, json.toString())
    }

    /**
     * Reattaches to a still-running standalone exercise after a process
     * death/reboot (docs/watch/44-watch-f6-standalone-plan.md §3.2, §11/6 —
     * mirrors iOS's `WorkoutManager.recoverStandaloneSessionIfNeeded()`).
     * Triggered by [recoverIfNeeded] via a fresh [ACTION_RECOVER_STANDALONE]
     * intent, once that companion check has already confirmed (via Health
     * Services' `getCurrentExerciseInfoAsync`) that *this app's own*
     * exercise is still tracked in progress — this method itself trusts
     * that and just re-attaches + restores state, it doesn't re-check.
     *
     * Deliberately does **not** call `startExerciseAsync` — the exercise is
     * already running at the Health Services level; only this (fresh)
     * process's callback registration and in-memory/`SessionStateHolder`
     * view of it were lost. `heartRateSum`/`heartRateSamples`/
     * `activeCaloriesTotal` start over at zero here, same as any fresh
     * instance — the eventual summary's average HR/calories cover the
     * post-recovery portion of the workout only, an accepted gap (there's
     * no API to recover Health Services' own running totals).
     */
    private suspend fun recoverStandaloneExercise() {
        val snapshot = StandaloneSessionStore.loadActive(this)
        if (snapshot == null || SessionStateHolder.phase.value != SessionPhase.IDLE) {
            ServiceCompat.stopForeground(this, ServiceCompat.STOP_FOREGROUND_REMOVE)
            stopSelf()
            return
        }
        val sessionClientId = snapshot.optString("standaloneSessionId").ifEmpty { null }
        val startedAtEpochMs = if (snapshot.has("startedAtEpochMs")) {
            snapshot.optLong("startedAtEpochMs")
        } else {
            null
        }
        if (sessionClientId == null || startedAtEpochMs == null) {
            // A corrupt/partial snapshot — nothing sane to recover into.
            StandaloneSessionStore.clearActive(this)
            ServiceCompat.stopForeground(this, ServiceCompat.STOP_FOREGROUND_REMOVE)
            stopSelf()
            return
        }
        currentSessionClientId = sessionClientId
        val activityType = snapshot.optString("activityType").ifEmpty { null }
        currentActivityType = activityType
        exerciseClient.setUpdateCallback(updateCallback)

        val nowElapsedRealtimeMs = SystemClock.elapsedRealtime()
        val nowEpochMs = System.currentTimeMillis()
        val startedAtElapsedRealtimeMs = nowElapsedRealtimeMs - (nowEpochMs - startedAtEpochMs)
        val template = snapshot.optJSONObject("template")?.let { parseStandaloneTemplate(it.toString()) }
        val exerciseIndex = snapshot.optInt("exerciseIndex", 0)
        val sets = parseStandaloneSets(snapshot.optJSONArray("sets") ?: JSONArray())
        val sessionPlan = snapshot.optJSONArray("sessionPlan")
            ?.let { StandalonePlanJson.parseExercises(it) }
            ?.ifEmpty { null }

        SessionStateHolder.onStandaloneRecovered(
            sessionClientId = sessionClientId,
            startedAtElapsedRealtimeMs = startedAtElapsedRealtimeMs,
            activityType = activityType,
            template = template,
            exerciseIndex = exerciseIndex,
            sets = sets,
            sessionPlan = sessionPlan,
        )
        // Live bridging picks back up from here too, same as a fresh start —
        // a phone that reconnects after this recovery still adopts the
        // session live rather than only seeing it once it ends.
        SummarySender.sendAdoptionRequestIfNeeded(this)
    }

    /** The recovery-snapshot counterpart of [saveStandaloneActiveSnapshot]'s
     * `sets` array — decodes it back into typed [StandaloneSet]s. Malformed
     * entries are skipped individually rather than failing the whole list,
     * since a partially-recovered set history is far better than none. */
    private fun parseStandaloneSets(array: JSONArray): List<StandaloneSet> =
        (0 until array.length()).mapNotNull { i ->
            try {
                val obj = array.getJSONObject(i)
                StandaloneSet(
                    loggedAtEpochMs = obj.getLong("loggedAtEpochMs"),
                    reps = obj.getInt("reps"),
                    exerciseId = if (obj.has("exerciseId")) obj.getString("exerciseId") else null,
                    weight = if (obj.has("weight")) obj.getDouble("weight") else null,
                    exerciseIndex = if (obj.has("exerciseIndex")) obj.getInt("exerciseIndex") else null,
                )
            } catch (e: Exception) {
                Log.w(TAG, "parseStandaloneSets skipped a malformed entry", e)
                null
            }
        }

    /**
     * Decodes the picker row's tapped JSON (docs/watch/
     * 49-watch-f6b-template-sync-plan.md §4.1, T6) — exactly the shape a
     * `"TEMPLATE"` row from `StandaloneSessionStore.entries()` hands back
     * (this app's convention of keeping the store itself untyped) — into the
     * typed
     * [StandaloneTemplate] the session state holds from start to end.
     * Malformed JSON falls back to `null` — a Quick-strength-equivalent
     * session, not a crash.
     */
    private fun parseStandaloneTemplate(json: String): StandaloneTemplate? =
        StandalonePlanJson.parseTemplate(json)

    /** The recovery-snapshot counterpart of [parseStandaloneTemplate]. */
    private fun StandaloneTemplate.toJson(): JSONObject = StandalonePlanJson.templateToJson(this)

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
        /** `WatchBridge.kt`'s (phone-side) C5.2/C5.6 activity-type field, read
         * from the `/start` message by [PhoneListenerService] and carried
         * here as an ordinary intent extra — see [buildExerciseConfig]'s doc
         * comment for why `venue`, the message's other C5.2 field, has no
         * equivalent extra. */
        const val EXTRA_ACTIVITY_TYPE = "activityType"

        const val ACTION_START_STANDALONE = "com.khunor.lifey.action.START_STANDALONE_EXERCISE"
        const val ACTION_END_STANDALONE = "com.khunor.lifey.action.END_STANDALONE_EXERCISE"
        const val ACTION_RECOVER_STANDALONE = "com.khunor.lifey.action.RECOVER_STANDALONE_EXERCISE"
        const val EXTRA_RPE = "rpe"
        const val EXTRA_TEMPLATE_JSON = "templateJson"

        fun startIntent(context: Context, sessionClientId: String, activityType: String? = null) =
            Intent(context, ExerciseService::class.java).apply {
                action = ACTION_START
                putExtra(EXTRA_SESSION_CLIENT_ID, sessionClientId)
                activityType?.let { putExtra(EXTRA_ACTIVITY_TYPE, it) }
            }

        fun endIntent(context: Context) =
            Intent(context, ExerciseService::class.java).apply {
                action = ACTION_END
            }

        /** Entry point for the launcher/picker "Quick strength" tap (S16),
         * a synced-template row (T6), **and** a `CARDIO` row (docs/cardio/
         * 55-cardio-watch-plan.md §5/§7 W-8, C5.7a) — no `sessionClientId`
         * extra, `startStandaloneExercise` generates its own (docs/watch/
         * 44-watch-f6-standalone-plan.md §3.1). [templateJson] is the exact
         * `StandaloneSessionStore.entries()` JSON for the tapped row, omitted
         * entirely for Quick strength (docs/watch/
         * 49-watch-f6b-template-sync-plan.md §3.3, T6). [activityType] is the
         * cardio counterpart — `MainActivity`'s `CardioRow` tap passes this
         * instead of [templateJson], never both. */
        fun startStandaloneIntent(context: Context, templateJson: String? = null, activityType: String? = null) =
            Intent(context, ExerciseService::class.java).apply {
                action = ACTION_START_STANDALONE
                templateJson?.let { putExtra(EXTRA_TEMPLATE_JSON, it) }
                activityType?.let { putExtra(EXTRA_ACTIVITY_TYPE, it) }
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

        private fun recoverStandaloneIntent(context: Context) =
            Intent(context, ExerciseService::class.java).apply { action = ACTION_RECOVER_STANDALONE }

        /**
         * Checked once from `MainActivity.onCreate()` (docs/watch/
         * 44-watch-f6-standalone-plan.md §3.2, §11/6) — mirrors iOS's
         * `LifeyWatchApp` calling `recoverStandaloneSessionIfNeeded()` at
         * launch. A no-op unless **all** of: this process's own
         * [SessionStateHolder] still thinks nothing is running (a fresh
         * process after death/reboot, not just a re-opened Activity while
         * [ExerciseService] is alive and already reflects the real state);
         * Health Services confirms *this app's own* exercise — not another
         * app's, not none — is still tracked in progress
         * (`getCurrentExerciseInfoAsync`, the standard Health Services
         * pattern for exactly this "app process died mid-exercise" case);
         * and a recovery snapshot actually exists to recover *into*. Starting
         * [ExerciseService] with [ACTION_RECOVER_STANDALONE] does the actual
         * re-attach + state restore ([recoverStandaloneExercise]) — kept
         * there rather than here so the Health Services client handle used
         * to re-register the update callback is the same long-lived one the
         * rest of the session's lifecycle already uses.
         */
        suspend fun recoverIfNeeded(context: Context) {
            if (SessionStateHolder.phase.value != SessionPhase.IDLE) return
            if (StandaloneSessionStore.loadActive(context) == null) return
            val info = try {
                HealthServices.getClient(context).exerciseClient.getCurrentExerciseInfoAsync().await()
            } catch (e: Exception) {
                Log.w(TAG, "getCurrentExerciseInfoAsync failed", e)
                return
            }
            if (info.exerciseTrackedStatus != ExerciseTrackedStatus.OWNED_EXERCISE_IN_PROGRESS) return
            ContextCompat.startForegroundService(context, recoverStandaloneIntent(context))
        }
    }
}
