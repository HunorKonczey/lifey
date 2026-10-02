package com.khunor.lifey

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.runtime.CompositionLocalProvider
import androidx.wear.ambient.AmbientLifecycleObserver
import java.util.Calendar
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.core.content.ContextCompat
import androidx.lifecycle.lifecycleScope
import com.khunor.lifey.ui.active.ActiveWorkoutScreen
import com.khunor.lifey.ui.ErrorScreen
import com.khunor.lifey.ui.IdleScreen
import com.khunor.lifey.ui.StandalonePickerScreen
import com.khunor.lifey.ui.SummaryScreen
import com.khunor.lifey.ui.theme.AmbientState
import com.khunor.lifey.ui.theme.LifeyTheme
import com.khunor.lifey.ui.theme.LocalAmbientState
import kotlinx.coroutines.launch

/**
 * Compose host, switching between [IdleScreen], [ActiveWorkoutScreen], and
 * [ErrorScreen] purely off [SessionStateHolder.phase] — all the actual state syncing
 * happens in [PhoneListenerService]/[ExerciseService], not here
 * (docs/40-watch-app-plan.md §5.1, F3).
 *
 * Also requests the sensor/notification runtime permissions on first launch
 * (docs/40-watch-app-plan.md §5.2: "A BODY_SENSORS-t a watch app első
 * indításkor... kéri el") — [ExerciseService] only *checks* them, it can't
 * request them itself since that needs an Activity context. If the exercise
 * is already running by the time the user grants it, HR simply isn't added
 * retroactively (docs/40-watch-app-plan.md §5.2's accepted degradation:
 * kcal-only for that session).
 */
class MainActivity : ComponentActivity() {
    private val permissionLauncher =
        registerForActivityResult(ActivityResultContracts.RequestMultiplePermissions()) { /* no-op — ExerciseService re-checks live before each start */ }

    /** Always-On state for the screens that have an ambient layout (frame 08, D-X0.15). */
    private val ambient = mutableStateOf(AmbientState())

    private fun minuteOfDay(): Int = Calendar.getInstance().let { it.get(Calendar.HOUR_OF_DAY) * 60 + it.get(Calendar.MINUTE) }

    private val ambientCallback = object : AmbientLifecycleObserver.AmbientLifecycleCallback {
        override fun onEnterAmbient(ambientDetails: AmbientLifecycleObserver.AmbientDetails) {
            ambient.value = AmbientState(isAmbient = true, minuteOfDay = minuteOfDay())
        }

        override fun onExitAmbient() {
            ambient.value = AmbientState(isAmbient = false, minuteOfDay = minuteOfDay())
        }

        // Once a minute while ambient: the screens recompute their minute-resolution values from this.
        override fun onUpdateAmbient() {
            ambient.value = AmbientState(isAmbient = true, minuteOfDay = minuteOfDay())
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Keeps the app visible (instead of the watch face) on wrist-down; only screens with an ambient layout
        // draw it, the others show their normal layout dimmed by the system.
        lifecycle.addObserver(AmbientLifecycleObserver(this, ambientCallback))
        requestSensorPermissionsIfNeeded()
        // App-start retry for any standalone session still queued from a
        // previous run (docs/watch/44-watch-f6-standalone-plan.md §4.1) —
        // `PhoneListenerService.onPeerConnected` covers the reconnect-while-
        // running case, this covers "the phone only reappeared after the
        // watch app was already closed and reopened".
        lifecycleScope.launch { SummarySender.flushPending(applicationContext) }
        // Same idea for live bridging: a still-running, not-yet-adopted
        // standalone session (ExerciseService survived as a foreground
        // service while just this Activity was closed/reopened) retries its
        // adoption snapshot here too.
        lifecycleScope.launch { SummarySender.sendAdoptionRequestIfNeeded(applicationContext) }
        // Reattaches to a still-running standalone exercise after a process
        // death/reboot (docs/watch/44-watch-f6-standalone-plan.md §3.2,
        // §11/6) — mirrors the two retries above, but for the *running*
        // session itself rather than a queued/pending one. A no-op in the
        // overwhelmingly common case (nothing to recover).
        lifecycleScope.launch { ExerciseService.recoverIfNeeded(applicationContext) }
        setContent {
          CompositionLocalProvider(LocalAmbientState provides ambient.value) {
            LifeyTheme {
                val phase by SessionStateHolder.phase.collectAsState()
                // Whether StandalonePickerScreen is showing instead of the
                // launcher, while phase == IDLE (docs/watch/
                // 44-watch-f6-standalone-plan.md §3.1) — pure UI navigation,
                // so it stays local here rather than on SessionStateHolder
                // (mirrors iOS's identical S10 call: `showEffortSelector`-
                // style manager state is for things the business logic
                // itself needs to read/drive, this isn't one of them).
                var showStandalonePicker by remember { mutableStateOf(false) }
                when (phase) {
                    SessionPhase.IDLE -> {
                        if (showStandalonePicker) {
                            StandalonePickerScreen(
                                onQuickStrengthTapped = {
                                    // Re-checks/re-prompts right before the
                                    // action that needs it, not just once at
                                    // cold start — catches a user who denied
                                    // on first launch and is only now trying
                                    // to actually start a workout.
                                    requestSensorPermissionsIfNeeded()
                                    ContextCompat.startForegroundService(
                                        this@MainActivity,
                                        ExerciseService.startStandaloneIntent(this@MainActivity),
                                    )
                                },
                                onTemplateTapped = { template ->
                                    // Same re-check-right-before-starting
                                    // reasoning as the quick-strength branch
                                    // above (docs/watch/
                                    // 49-watch-f6b-template-sync-plan.md T6).
                                    requestSensorPermissionsIfNeeded()
                                    ContextCompat.startForegroundService(
                                        this@MainActivity,
                                        ExerciseService.startStandaloneIntent(
                                            this@MainActivity,
                                            templateJson = template.toString(),
                                        ),
                                    )
                                },
                                onCardioTapped = { activityType, title ->
                                    // Same re-check-right-before-starting
                                    // reasoning as the two branches above
                                    // (docs/cardio/55-cardio-watch-plan.md
                                    // §5/§7 W-8, C5.7a). [title] is the row's
                                    // own pre-localized activity name, handed
                                    // straight through so the session's header
                                    // reads "Walking" rather than the generic
                                    // STRENGTH label.
                                    requestSensorPermissionsIfNeeded()
                                    ContextCompat.startForegroundService(
                                        this@MainActivity,
                                        ExerciseService.startStandaloneIntent(
                                            this@MainActivity,
                                            activityType = activityType,
                                            title = title,
                                        ),
                                    )
                                },
                                onBack = { showStandalonePicker = false },
                            )
                        } else {
                            IdleScreen(onStartTapped = { showStandalonePicker = true })
                        }
                    }
                    SessionPhase.ACTIVE -> ActiveWorkoutScreen()
                    SessionPhase.ERROR -> ErrorScreen()
                    SessionPhase.SUMMARY -> SummaryScreen()
                }
            }
          }
        }
    }

    private fun requestSensorPermissionsIfNeeded() {
        val missing = REQUIRED_PERMISSIONS.filter {
            ContextCompat.checkSelfPermission(this, it) != PackageManager.PERMISSION_GRANTED
        }
        if (missing.isNotEmpty()) {
            permissionLauncher.launch(missing.toTypedArray())
        }
    }

    companion object {
        private val REQUIRED_PERMISSIONS = buildList {
            add(Manifest.permission.BODY_SENSORS)
            // API 36+ Health Services rejects startExerciseAsync's heart-rate
            // data type without this, even with BODY_SENSORS granted
            // (confirmed via a real SecurityException on a 36 system image).
            add("android.permission.health.READ_HEART_RATE")
            // Required for ExerciseService to even start as a "health"-typed
            // foreground service on API 34+ (Android validates that at least
            // one of a specific permission set is actually granted, not just
            // declared — ACTIVITY_RECOGNITION is the one from that set this
            // app plausibly wants; BODY_SENSORS alone doesn't satisfy it).
            add(Manifest.permission.ACTIVITY_RECOGNITION)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                add(Manifest.permission.POST_NOTIFICATIONS)
            }
        }
    }
}
