package com.khunor.lifey.debug

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.wear.compose.material3.TimeText
import com.khunor.lifey.ui.active.MetricsContent
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
    "W1.1" to { Frame { MetricsContent(strengthModel(), {}, {}) } },
    "W1.2" to { Frame { MetricsContent(strengthModel(isPaused = true), {}, {}) } },
    "W1.4" to { Frame { MetricsContent(strengthModel(), {}, {}) } }, // same page at 192 dp: --ei width 192
)

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
