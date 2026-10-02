package com.khunor.lifey.debug

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.wear.compose.material3.TimeText
import com.khunor.lifey.LogAdjustField
import com.khunor.lifey.LogAdjustState
import com.khunor.lifey.LogSetState
import com.khunor.lifey.ui.active.AdjustContent
import com.khunor.lifey.ui.EffortContent
import com.khunor.lifey.ui.active.ControlsContent
import com.khunor.lifey.ui.active.ControlsModel
import com.khunor.lifey.ui.active.ExerciseListContent
import com.khunor.lifey.ui.active.ExerciseRow
import com.khunor.lifey.ui.active.LogContent
import com.khunor.lifey.ui.components.GoFlash
import com.khunor.lifey.ui.active.LogModel
import com.khunor.lifey.ui.active.MetricsContent
import com.khunor.lifey.ui.active.RestContent
import com.khunor.lifey.ui.active.RestModel
import com.khunor.lifey.ui.active.MetricsModel
import com.khunor.lifey.ui.components.HeartRateState

/**
 * Fixtures of the Wear strength canvas (`Lifey Watch 3 Wear OS Strength`, frames W1.1–W1.16) — one entry per
 * frame id, rendered with no phone and no session:
 *
 *     adb shell am start -n com.khunor.lifey/.debug.DesignGalleryActivity --es frame W1.1 [--ei width 192]
 *
 * Each X3 step registers the frames of the page it builds.
 */
val w1Frames: Map<String, @Composable () -> Unit> = mapOf(
    "W1.1" to frame { Frame { MetricsContent(strengthModel(), {}, {}) } },
    "W1.2" to frame { Frame { MetricsContent(strengthModel(isPaused = true), {}, {}) } },
    "W1.3" to frame { Frame { MetricsContent(strengthModel(HeartRateState.PermissionDenied), {}, {}) } },
    "W2.16" to frame { Frame { MetricsContent(strengthModel(HeartRateState.Missing), {}, {}) } },
    "W1.5" to frame { Frame { LogContent(logModel(LogSetState.Ready), {}, {}, {}) } },
    "W1.6" to frame { Frame { LogContent(logModel(LogSetState.Confirmed, setsDone = 3), {}, {}, {}) } },
    "W1.7" to frame { Frame { LogContent(logModel(LogSetState.Pending("fixture")), {}, {}, {}) } },
    "W1.7b" to frame { Frame { LogContent(logModel(LogSetState.Failed), {}, {}, {}) } }, // failed: two centred lines
    "W1.7c" to frame { Frame { LogContent(logModel(LogSetState.Ready, phoneUnreachable = true), {}, {}, {}) } },
    "W1.8" to frame { AdjustContent(LogAdjustState(reps = 8, weight = 62.5, field = LogAdjustField.REPS), {}, {}, {}) },
    "W1.9" to frame { AdjustContent(LogAdjustState(reps = 8, weight = 62.5, field = LogAdjustField.WEIGHT), {}, {}, {}) },
    "W1.10" to frame { Frame { RestContent(restModel(47_000L)) } },
    "W1.11" to frame { Frame { RestContent(restModel(4_000L)) } }, // the last five seconds: calories colour + pulse
    "W1.12" to frame { Frame { GoFlash() } },
    "W1.13" to frame { Frame { ControlsContent(ControlsModel(elapsedMs = 12 * 60_000L + 34_000L, isPaused = false), {}, {}, {}) } },
    "W1.14" to frame { Frame { ControlsContent(ControlsModel(12 * 60_000L + 34_000L, isPaused = true, offersExerciseList = true), {}, {}, {}) } },
    "W1.15" to frame {
        ExerciseListContent(
            rows = listOf(
                ExerciseRow(0, "Fekvenyomás", "2/4 szett", isCurrent = true),
                ExerciseRow(1, "Ferde pados nyomás", "0/3 szett", isCurrent = false),
                ExerciseRow(2, "Tárogatás", "0/3 szett", isCurrent = false),
                ExerciseRow(3, "Tricepsz letolás", "0/3 szett", isCurrent = false),
            ),
            onSelect = {},
        )
    },
    "W1.16" to frame { EffortContent(rpe = 7, onRpeChange = {}, onConfirm = {}, onSkip = {}) },
    "W1.4" to frame { Frame { MetricsContent(strengthModel(), {}, {}) } }, // same page at 192 dp: --ei width 192
)

/** Gives the lambda a @Composable function type up front (a bare `"id" to { … }` would be inferred as a plain lambda). */
private fun frame(content: @Composable () -> Unit): @Composable () -> Unit = content

/** The frame chrome: the TimeText every pager page carries. */
@Composable
private fun Frame(content: @Composable () -> Unit) {
    Box(Modifier.fillMaxSize()) {
        content()
        TimeText()
    }
}

private fun strengthModel(heartRate: HeartRateState = HeartRateState.Live(128), isPaused: Boolean = false) = MetricsModel(
    headerLabel = "Erőedzés", elapsedMs = 12 * 60_000L + 34_000L, heartRate = heartRate, kcal = 87,
    exerciseName = "Fekvenyomás", setsDone = 2, setsTotal = 4, freeFormatSets = null, isPaused = isPaused,
)

private fun logModel(state: LogSetState, setsDone: Int = 2, phoneUnreachable: Boolean = false) = LogModel(
    elapsedMs = 12 * 60_000L + 36_000L, exerciseName = "Fekvenyomás", setsDone = setsDone, setsTotal = 4,
    freeFormatSets = null, logState = state, phoneUnreachable = phoneUnreachable,
)

private fun restModel(remainingMs: Long) = RestModel(
    remainingMs = remainingMs, totalSeconds = 90, exerciseName = "Fekvenyomás", setsDone = 2, setsTotal = 4,
    heartRate = HeartRateState.Live(128), kcal = 87,
)
