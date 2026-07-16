package com.khunor.lifey.ui

import android.os.SystemClock
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.wear.compose.material.Button
import androidx.wear.compose.material.MaterialTheme
import androidx.wear.compose.material.Text
import com.khunor.lifey.R
import com.khunor.lifey.SessionStateHolder
import com.khunor.lifey.SummarySender
import kotlin.math.roundToInt
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/**
 * Live workout screen — elapsed time, heart rate, calories, current
 * exercise/set counter, rest-timer countdown (docs/40-watch-app-plan.md
 * §4.4/§5.1 "ActiveWorkoutView" equivalent; the haptic at rest-end is
 * scheduled independently in [com.khunor.lifey.ExerciseService], not here —
 * it needs to fire even while this screen isn't composed). The End button
 * only *asks* the phone to close the session (§8.2 decision (b)) — it never
 * touches [com.khunor.lifey.ExerciseService] directly.
 */
@Composable
fun ActiveWorkoutScreen() {
    val metadata by SessionStateHolder.metadata.collectAsState()
    val liveMetrics by SessionStateHolder.liveMetrics.collectAsState()
    val context = LocalContext.current
    val scope = rememberCoroutineScope()

    var elapsedMs by remember { mutableLongStateOf(0L) }
    LaunchedEffect(liveMetrics.startedAtElapsedRealtimeMs) {
        val startedAt = liveMetrics.startedAtElapsedRealtimeMs ?: return@LaunchedEffect
        while (true) {
            elapsedMs = SystemClock.elapsedRealtime() - startedAt
            delay(1000)
        }
    }

    var restRemainingMs by remember { mutableLongStateOf(0L) }
    LaunchedEffect(metadata.restEndsAtEpochMs) {
        val restEndsAtEpochMs = metadata.restEndsAtEpochMs
        if (restEndsAtEpochMs == null) {
            restRemainingMs = 0L
            return@LaunchedEffect
        }
        while (true) {
            val remaining = restEndsAtEpochMs - System.currentTimeMillis()
            restRemainingMs = remaining
            if (remaining <= 0) break
            delay(1000)
        }
    }

    Column(
        modifier = Modifier.fillMaxSize().padding(16.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Text(text = formatElapsed(elapsedMs), style = MaterialTheme.typography.display2)
        Text(
            text = metadata.exerciseName ?: stringResource(R.string.active_default_exercise),
            style = MaterialTheme.typography.body1,
        )
        val setsDone = metadata.setsDone
        val setsTotal = metadata.setsTotal
        if (setsDone != null && setsTotal != null) {
            Text(
                text = stringResource(R.string.active_sets_format, setsDone, setsTotal),
                style = MaterialTheme.typography.caption1,
            )
        }
        if (restRemainingMs > 0) {
            Text(
                text = stringResource(R.string.active_rest_format, formatElapsed(restRemainingMs)),
                style = MaterialTheme.typography.caption1,
            )
        }
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            liveMetrics.heartRateBpm?.let { bpm ->
                Text(
                    text = "${bpm.roundToInt()} ${stringResource(R.string.active_heart_rate_unit)}",
                    style = MaterialTheme.typography.caption1,
                )
            }
            liveMetrics.activeCalories?.let { kcal ->
                Text(
                    text = "${kcal.roundToInt()} ${stringResource(R.string.active_calories_unit)}",
                    style = MaterialTheme.typography.caption1,
                )
            }
        }
        Button(onClick = {
            val sessionClientId = metadata.sessionClientId ?: return@Button
            scope.launch { SummarySender.sendEndRequested(context, sessionClientId) }
        }) {
            Text(stringResource(R.string.active_end_button))
        }
    }
}

private fun formatElapsed(totalMs: Long): String {
    val totalSeconds = totalMs / 1000
    val minutes = totalSeconds / 60
    val seconds = totalSeconds % 60
    return "%02d:%02d".format(minutes, seconds)
}
