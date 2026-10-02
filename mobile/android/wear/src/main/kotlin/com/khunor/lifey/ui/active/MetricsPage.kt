package com.khunor.lifey.ui.active

import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.FitnessCenter
import androidx.compose.material.icons.filled.LocalFireDepartment
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.wear.compose.material3.Text
import com.khunor.lifey.LiveMetrics
import com.khunor.lifey.R
import com.khunor.lifey.ui.components.HeartRateState
import com.khunor.lifey.ui.components.HeartRateSlot
import com.khunor.lifey.ui.components.MetricLevel
import com.khunor.lifey.ui.components.MetricReading
import com.khunor.lifey.ui.components.SetSegmentBar
import com.khunor.lifey.ui.theme.LifeyColors
import com.khunor.lifey.ui.theme.LifeySpacing
import com.khunor.lifey.ui.theme.LifeyType
import com.khunor.lifey.ui.theme.LocalWatchMetrics
import kotlin.math.roundToInt

/**
 * Everything the metric page shows (frames W1.1–W1.4), as plain data so the DEBUG gallery can render a
 * canvas frame without a running session. The stateful page ([MetricsOrRestPage]) fills it from
 * `SessionStateHolder`.
 */
data class MetricsModel(
    val headerLabel: String,
    val elapsedMs: Long,
    val heartRate: HeartRateState,
    val kcal: Int?,
    val exerciseName: String,
    val setsDone: Int?,
    val setsTotal: Int?,
    /** (set count, total reps) when there is no target to count towards. */
    val freeFormatSets: Pair<Int, Int>?,
    val isPaused: Boolean = false,
    /** The "this workout has no phone behind it" mark in the header. */
    val showsStandaloneMark: Boolean = false,
    /** The segment that turns `success` for 1.2 s after a set was logged. */
    val justLoggedIndex: Int? = null,
)

/** The heart-rate slot state from the live metrics — the *cause* of a missing reading is existing state. */
fun heartRateState(live: LiveMetrics): HeartRateState = when {
    !live.hasHeartRatePermission -> HeartRateState.PermissionDenied
    else -> live.heartRateBpm?.let { HeartRateState.Live(it.roundToInt()) } ?: HeartRateState.Missing
}

/**
 * Metric page (W1.1, W1.4 at 192 dp): header chip, the elapsed time as the white hero, heart rate (level two,
 * with "bpm") beside the calories, and a narrow exercise block with the set segment bar in the bottom chord.
 * Nothing scrolls and nothing sits in the top 16 % where [androidx.wear.compose.material3.TimeText] lives.
 */
@Composable
fun MetricsContent(
    model: MetricsModel,
    onRequestHeartRatePermission: () -> Unit,
    onOpenExerciseList: (() -> Unit)?,
    modifier: Modifier = Modifier,
) {
    val width = LocalWatchMetrics.current.widthDp
    val permissionDenied = model.heartRate == HeartRateState.PermissionDenied
    Box(modifier.fillMaxSize()) {
        Column(
            Modifier.align(Alignment.TopCenter).padding(top = (width * 0.16f).dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(LifeySpacing.xs),
        ) {
            ActiveHeader(
                icon = Icons.Filled.FitnessCenter, label = model.headerLabel,
                isPaused = model.isPaused, showsStandaloneMark = model.showsStandaloneMark,
            )
            Text(formatElapsed(model.elapsedMs), style = LifeyType.hero(), color = LifeyColors.text, maxLines = 1)
            if (permissionDenied) {
                HeartRateSlot(model.heartRate, onRequestPermission = onRequestHeartRatePermission)
                KcalReading(model.kcal)
            } else {
                Row(horizontalArrangement = Arrangement.spacedBy(LifeySpacing.lg), verticalAlignment = Alignment.CenterVertically) {
                    HeartRateSlot(model.heartRate)
                    KcalReading(model.kcal)
                }
            }
        }
        ExerciseBlock(
            model = model, onOpenExerciseList = onOpenExerciseList,
            modifier = Modifier.align(Alignment.BottomCenter).padding(bottom = (width * 0.11f).dp),
        )
    }
}

@Composable
private fun KcalReading(kcal: Int?) {
    if (kcal != null) {
        MetricReading(
            icon = Icons.Filled.LocalFireDepartment, iconTint = LifeyColors.calories, number = kcal.toString(),
            unit = stringResource(R.string.active_calories_unit), level = MetricLevel.Value,
        )
    }
}

/** The narrow exercise block of the bottom chord — also the way into the exercise list when there is one. */
@Composable
private fun ExerciseBlock(model: MetricsModel, onOpenExerciseList: (() -> Unit)?, modifier: Modifier = Modifier) {
    val width = LocalWatchMetrics.current.widthDp
    // A free-form summary ("3. szett · összesen 24 ismétlés") needs two readable centred lines, so its block is
    // wider than the segment bar's (W2.5).
    val blockWidth = (width * (if (model.freeFormatSets != null) 0.68f else 0.5f)).dp
    val target = if (onOpenExerciseList != null) modifier.clickable(onClick = onOpenExerciseList) else modifier
    val done = model.setsDone
    val total = model.setsTotal
    val free = model.freeFormatSets
    Column(target, horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(LifeySpacing.xs)) {
        when {
            done != null && total != null && total > 0 -> SetSegmentBar(
                done = done, total = total, title = model.exerciseName,
                justLoggedIndex = model.justLoggedIndex, width = blockWidth,
            )
            free != null -> {
                Text(model.exerciseName, style = LifeyType.title(), color = LifeyColors.text, maxLines = 1, overflow = TextOverflow.Ellipsis,
                    textAlign = TextAlign.Center, modifier = Modifier.widthIn(max = blockWidth))
                SetSegmentBar(
                    done = 0, total = 0, width = blockWidth,
                    freeFormText = stringResource(R.string.active_sets_free_format, free.first, free.second),
                )
            }
            else -> Text(model.exerciseName, style = LifeyType.title(), color = LifeyColors.text, maxLines = 2, overflow = TextOverflow.Ellipsis,
                textAlign = TextAlign.Center, modifier = Modifier.widthIn(max = blockWidth))
        }
    }
}

/**
 * Page 2 of 3: the metric page, or the rest hero while a rest timer runs (the old Material 2 rest hero stays
 * until X3.9). Owns the heart-rate permission launcher — the slot's tap is the system permission request.
 */
@Composable
internal fun MetricsOrRestPage(
    resting: Boolean,
    restRemainingMs: Long,
    restTotalSeconds: Int?,
    model: MetricsModel,
    canChooseExercise: Boolean,
    onOpenExerciseList: () -> Unit,
) {
    if (resting) {
        Box(Modifier.fillMaxSize().exercisePickerTarget(canChooseExercise, onOpenExerciseList)) {
            RestContent(
                RestModel(
                    remainingMs = restRemainingMs,
                    totalSeconds = restTotalSeconds,
                    exerciseName = model.exerciseName,
                    setsDone = model.setsDone,
                    setsTotal = model.setsTotal,
                    heartRate = model.heartRate,
                    kcal = model.kcal,
                    showsStandaloneMark = model.showsStandaloneMark,
                ),
            )
        }
        return
    }
    val permissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestMultiplePermissions(),
    ) { /* no-op — ExerciseService re-checks live before the next start */ }
    MetricsContent(
        model = model,
        onRequestHeartRatePermission = { permissionLauncher.launch(HEART_RATE_PERMISSIONS) },
        onOpenExerciseList = if (canChooseExercise) onOpenExerciseList else null,
    )
}

/** Makes the exercise readout open the exercise list — but only while there is
 * something to switch to, so a session without a pushed plan keeps a plain,
 * non-interactive readout instead of a control that opens an empty screen.
 * Mirrors iOS's `ExercisePickerTarget`. */
internal fun Modifier.exercisePickerTarget(
    canChooseExercise: Boolean,
    onOpenExerciseList: () -> Unit,
): Modifier = if (canChooseExercise) clickable(onClick = onOpenExerciseList) else this
