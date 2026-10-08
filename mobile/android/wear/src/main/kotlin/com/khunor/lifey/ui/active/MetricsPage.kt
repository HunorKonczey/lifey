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
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.layout.Layout
import androidx.compose.ui.unit.em
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
    // At a large system font the "bpm" and "kcal" are what no longer fit side by side ("87 kca" ran off the dial);
    // the heart and the flame say which number is which.
    val showUnits = LocalDensity.current.fontScale <= LARGE_TEXT_SCALE
    // One column, top to bottom: the readings, a flexible gap, then the exercise block bottom-anchored on the chord.
    // They used to be two independently anchored stacks, so a tall one (a wrapped name, the taller standalone
    // header) was drawn over the other — now what does not fit is clipped, never overdrawn (LIF-131 bugs 1, 2).
    Column(
        modifier.fillMaxSize().padding(top = (width * 0.15f).dp, bottom = (width * 0.10f).dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(LifeySpacing.xs)) {
            ActiveHeader(
                icon = Icons.Filled.FitnessCenter, label = model.headerLabel,
                isPaused = model.isPaused, showsStandaloneMark = model.showsStandaloneMark,
            )
            // Tight line height (the cardio hero's is 1.05) — what gives the exercise block its room.
            Text(
                formatElapsed(model.elapsedMs), style = LifeyType.hero().copy(lineHeight = 1.0.em),
                color = LifeyColors.text, maxLines = 1,
            )
            if (permissionDenied) {
                // The 44 dp button plus a calories row left the exercise block no room at all (W1.3, any font size):
                // the button is what the person has to act on, so the calories wait until the sensors are allowed.
                HeartRateSlot(model.heartRate, onRequestPermission = onRequestHeartRatePermission)
            } else {
                Row(horizontalArrangement = Arrangement.spacedBy(LifeySpacing.lg), verticalAlignment = Alignment.CenterVertically) {
                    HeartRateSlot(model.heartRate, showUnit = showUnits)
                    KcalReading(model.kcal, showUnits)
                }
            }
        }
        Box(Modifier.weight(1f).fillMaxWidth(), contentAlignment = Alignment.BottomCenter) {
            ExerciseBlock(model = model, onOpenExerciseList = onOpenExerciseList)
        }
    }
}

/** The system font scale above which the metric units are dropped (the text caps start at 1.15 / 1.35). */
internal const val LARGE_TEXT_SCALE = 1.15f

@Composable
private fun KcalReading(kcal: Int?, showUnit: Boolean = true) {
    if (kcal != null) {
        MetricReading(
            icon = Icons.Filled.LocalFireDepartment, iconTint = LifeyColors.calories, number = kcal.toString(),
            unit = if (showUnit) stringResource(R.string.active_calories_unit) else null, level = MetricLevel.Value,
        )
    }
}

/**
 * A centred column that places its children top to bottom and **stops at the first one that does not fit whole**
 * in the height it was given: nothing is ever drawn half-cut. The metric page's exercise block lives in whatever
 * the readings above leave, which on a compact dial or at a big font is less than the name plus the count.
 */
@Composable
private fun WholeLinesColumn(modifier: Modifier = Modifier, content: @Composable () -> Unit) {
    Layout(content = content, modifier = modifier) { measurables, constraints ->
        val loose = constraints.copy(minWidth = 0, minHeight = 0)
        val placeables = measurables.map { it.measure(loose) }
        var used = 0
        val kept = placeables.filterIndexed { index, placeable ->
            val fits = index == 0 || used + placeable.height <= constraints.maxHeight
            if (fits) used += placeable.height
            fits
        }
        val width = (kept.maxOfOrNull { it.width } ?: 0).coerceIn(constraints.minWidth, constraints.maxWidth)
        layout(width, used.coerceAtMost(constraints.maxHeight)) {
            var y = 0
            kept.forEach { placeable ->
                placeable.placeRelative((width - placeable.width) / 2, y)
                y += placeable.height
            }
        }
    }
}

/** The narrow exercise block of the bottom chord — also the way into the exercise list when there is one. */
@Composable
private fun ExerciseBlock(model: MetricsModel, onOpenExerciseList: (() -> Unit)?, modifier: Modifier = Modifier) {
    val width = LocalWatchMetrics.current.widthDp
    // A free-form summary ("3. szett · összesen 24 ismétlés") needs two readable centred lines, so its block is
    // wider than the segment bar's (W2.5).
    // The bar's block is as wide as the chord at its bottom edge allows (the name and "2/4" share its top line:
    // "Fekvenyomás" needs ~100 dp, which the old 0.5 × width broke mid-word).
    val blockWidth = (width * (if (model.freeFormatSets != null) 0.68f else 0.62f)).dp
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
            free != null -> WholeLinesColumn(Modifier.widthIn(max = blockWidth)) {
                // Name, then the count: [WholeLinesColumn] draws the second line only when it fits whole, so a tight
                // dial or a big font shows the name rather than half of "Set 3 · 24 reps" (LIF-131 bug 2).
                Text(model.exerciseName, style = LifeyType.title(), color = LifeyColors.text, maxLines = 1, overflow = TextOverflow.Ellipsis,
                    textAlign = TextAlign.Center)
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
