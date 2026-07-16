package com.khunor.lifey

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.core.content.ContextCompat
import com.khunor.lifey.ui.ActiveWorkoutScreen
import com.khunor.lifey.ui.IdleScreen

/**
 * Compose host, switching between [IdleScreen] and [ActiveWorkoutScreen]
 * purely off [SessionStateHolder.phase] — all the actual state syncing
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

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        requestSensorPermissionsIfNeeded()
        setContent {
            val phase by SessionStateHolder.phase.collectAsState()
            when (phase) {
                SessionPhase.IDLE -> IdleScreen()
                SessionPhase.ACTIVE -> ActiveWorkoutScreen()
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
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                add(Manifest.permission.POST_NOTIFICATIONS)
            }
        }
    }
}
