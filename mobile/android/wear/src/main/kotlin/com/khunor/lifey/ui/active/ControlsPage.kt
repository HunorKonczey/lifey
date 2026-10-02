package com.khunor.lifey.ui.active

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.width
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.List
import androidx.compose.material.icons.filled.Pause
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Stop
import androidx.compose.material.icons.filled.Timer
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.wear.compose.material.Icon
import androidx.wear.compose.material.Text
import androidx.wear.compose.material3.ButtonDefaults
import androidx.wear.compose.material3.EdgeButton
import com.khunor.lifey.R
import com.khunor.lifey.ui.components.CircleButton
import com.khunor.lifey.ui.components.CircleStyle
import com.khunor.lifey.ui.theme.LifeyColors
import com.khunor.lifey.ui.theme.LifeySpacing
import com.khunor.lifey.ui.theme.LifeyType
import com.khunor.lifey.ui.theme.LocalWatchMetrics

/** What the controls page shows (W1.13 / W1.14), as plain data. */
data class ControlsModel(
    val elapsedMs: Long,
    val isPaused: Boolean,
    val showsStandaloneMark: Boolean = false,
    /** The secondary "Gyakorlatok" EdgeButton: only while paused and with two or more exercises. */
    val offersExerciseList: Boolean = false,
)

/**
 * Controls page (W1.13 / W1.14): the same two circles as Apple — "Vége" in the error tint and "Szünet"
 * (control). Paused, "Folytatás" is the primary circle and a secondary EdgeButton "Gyakorlatok" opens the
 * exercise list (the circles shrink to 74 dp and the page indicator hides under it). The decorative exercise
 * card of the old page is gone — it said nothing the metric page does not, and meant nothing on cardio.
 */
@Composable
fun ControlsContent(
    model: ControlsModel,
    onEnd: () -> Unit,
    onTogglePause: () -> Unit,
    onOpenExerciseList: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val metrics = LocalWatchMetrics.current
    val width = metrics.widthDp
    Box(modifier.fillMaxSize()) {
        ActiveHeader(
            icon = Icons.Filled.Timer, label = formatElapsed(model.elapsedMs),
            isPaused = model.isPaused, showsStandaloneMark = model.showsStandaloneMark,
            modifier = Modifier.align(Alignment.TopCenter).padding(top = (width * 0.16f).dp),
        )
        Row(
            Modifier.align(Alignment.Center).padding(top = (width * 0.04f).dp),
            horizontalArrangement = Arrangement.spacedBy(LifeySpacing.md),
        ) {
            val diameter = if (model.offersExerciseList) metrics.circleButtonWithEdgeButton else metrics.circleButton
            CircleButton(
                style = CircleStyle.ErrorTint, icon = Icons.Filled.Stop,
                label = stringResource(R.string.active_end_button), onClick = onEnd, diameter = diameter,
            )
            CircleButton(
                style = if (model.isPaused) CircleStyle.Primary else CircleStyle.Control,
                icon = if (model.isPaused) Icons.Filled.PlayArrow else Icons.Filled.Pause,
                label = stringResource(if (model.isPaused) R.string.active_resume_button else R.string.active_pause_button),
                onClick = onTogglePause, diameter = diameter,
            )
        }
        if (model.offersExerciseList) {
            Box(Modifier.align(Alignment.BottomCenter)) {
                EdgeButton(
                    onClick = onOpenExerciseList,
                    colors = ButtonDefaults.filledTonalButtonColors(containerColor = LifeyColors.control, contentColor = LifeyColors.text),
                ) {
                    Icon(Icons.AutoMirrored.Filled.List, contentDescription = null, tint = LifeyColors.text, modifier = Modifier.size(18.dp))
                    Spacer(Modifier.width(LifeySpacing.sm))
                    Text(stringResource(R.string.standalone_exercise_list_title), style = LifeyType.body(), color = LifeyColors.text, maxLines = 1)
                }
            }
        }
    }
}

/** The stateful page: End asks the phone to close (via the effort step), Pause/Resume drive the local session. */
@Composable
internal fun ControlsPage(
    elapsedMs: Long,
    isPaused: Boolean,
    showsStandaloneMark: Boolean,
    offersExerciseList: Boolean,
    onEnd: () -> Unit,
    onTogglePause: () -> Unit,
    onOpenExerciseList: () -> Unit,
) {
    ControlsContent(
        model = ControlsModel(elapsedMs, isPaused, showsStandaloneMark, offersExerciseList),
        onEnd = onEnd, onTogglePause = onTogglePause, onOpenExerciseList = onOpenExerciseList,
    )
}
