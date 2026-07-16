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
    private var lastActiveCalories: Double? = null

    // Pihenő-visszaszámláló haptika (docs/40-watch-app-plan.md §5.4/F4):
    // scheduled independently of start/end commands, for the service's whole
    // lifetime, since restEndsAtEpochMs can change many times per session.
    private var restVibrationJob: Job? = null

    private val updateCallback = object : ExerciseUpdateCallback {
        override fun onExerciseUpdateReceived(update: ExerciseUpdate) {
            update.latestMetrics.getData(DataType.HEART_RATE_BPM).lastOrNull()?.value?.let { bpm ->
                SessionStateHolder.onHeartRate(bpm)
                heartRateSum += bpm
                heartRateSamples += 1
            }
            update.latestMetrics.getData(DataType.CALORIES_TOTAL)?.total?.let { kcal ->
                SessionStateHolder.onCalories(kcal)
                lastActiveCalories = kcal
            }
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

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        // Runs for this service's whole lifetime, not just start/end — a
        // rest timer can start/end/restart many times within one exercise
        // (docs/40-watch-app-plan.md §5.4/F4).
        scope.launch {
            SessionStateHolder.metadata
                .map { it.restEndsAtEpochMs }
                .distinctUntilChanged()
                .collect { restEndsAtEpochMs -> scheduleRestVibration(restEndsAtEpochMs) }
        }
    }

    private fun scheduleRestVibration(restEndsAtEpochMs: Long?) {
        restVibrationJob?.cancel()
        if (restEndsAtEpochMs == null) return
        restVibrationJob = scope.launch {
            val delayMs = restEndsAtEpochMs - System.currentTimeMillis()
            if (delayMs > 0) delay(delayMs)
            vibrateRestEnd()
        }
    }

    private fun vibrateRestEnd() {
        val vibrator = getSystemService(Vibrator::class.java) ?: return
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

    private suspend fun startExercise(sessionClientId: String) {
        // Either satisfies it depending on OS version — BODY_SENSORS pre-36,
        // the granular health permission on 36+ (see MainActivity, which
        // requests both). Health Services itself enforces the latter with a
        // SecurityException regardless of BODY_SENSORS on a 36 system image.
        val hasHeartRatePermission =
            ContextCompat.checkSelfPermission(this, Manifest.permission.BODY_SENSORS) ==
                PackageManager.PERMISSION_GRANTED ||
                ContextCompat.checkSelfPermission(this, "android.permission.health.READ_HEART_RATE") ==
                    PackageManager.PERMISSION_GRANTED

        // Always requestable — CALORIES_TOTAL doesn't need BODY_SENSORS.
        val dataTypes = buildSet {
            add(DataType.CALORIES_TOTAL)
            if (hasHeartRatePermission) add(DataType.HEART_RATE_BPM)
        }

        val config = ExerciseConfig(
            exerciseType = ExerciseType.STRENGTH_TRAINING,
            dataTypes = dataTypes,
            isAutoPauseAndResumeEnabled = false,
            isGpsEnabled = false,
        )

        try {
            exerciseClient.setUpdateCallback(updateCallback)
            exerciseClient.startExerciseAsync(config).await()
            SessionStateHolder.onExerciseActive(SystemClock.elapsedRealtime())
        } catch (e: Exception) {
            // Another app already owns an exercise, or the sensor/service is
            // unavailable — docs/40-watch-app-plan.md §5.3, §8.1.
            Log.w(TAG, "startExercise failed for $sessionClientId", e)
            SummarySender.sendStartRejected(this, sessionClientId)
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
                activeCalories = lastActiveCalories,
                averageHeartRate = averageHeartRate,
            )
        }
        SessionStateHolder.reset()
        ServiceCompat.stopForeground(this, ServiceCompat.STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    companion object {
        private const val TAG = "LifeyExerciseService"
        private const val CHANNEL_ID = "lifey_exercise"
        private const val NOTIFICATION_ID = 1001
        const val ACTION_START = "com.khunor.lifey.action.START_EXERCISE"
        const val ACTION_END = "com.khunor.lifey.action.END_EXERCISE"
        const val EXTRA_SESSION_CLIENT_ID = "sessionClientId"

        fun startIntent(context: Context, sessionClientId: String) =
            Intent(context, ExerciseService::class.java).apply {
                action = ACTION_START
                putExtra(EXTRA_SESSION_CLIENT_ID, sessionClientId)
            }

        fun endIntent(context: Context) =
            Intent(context, ExerciseService::class.java).apply {
                action = ACTION_END
            }
    }
}
