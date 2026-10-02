package com.khunor.lifey.ui.active

import android.Manifest
import android.os.SystemClock
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.requiredWidth
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.DirectionsBike
import androidx.compose.material.icons.automirrored.filled.List
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.AirlineSeatReclineNormal
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.DirectionsRun
import androidx.compose.material.icons.filled.DirectionsWalk
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.FitnessCenter
import androidx.compose.material.icons.filled.HeartBroken
import androidx.compose.material.icons.filled.Hiking
import androidx.compose.material.icons.filled.LocalFireDepartment
import androidx.compose.material.icons.filled.MonitorHeart
import androidx.compose.material.icons.filled.Pause
import androidx.compose.material.icons.filled.PedalBike
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Remove
import androidx.compose.material.icons.filled.SignalWifiOff
import androidx.compose.material.icons.filled.SportsBasketball
import androidx.compose.material.icons.filled.SportsSoccer
import androidx.compose.material.icons.filled.Stop
import androidx.compose.material.icons.filled.Sync
import androidx.compose.material.icons.filled.Tune
import androidx.compose.material.icons.filled.Timer
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.foundation.focusable
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.material.icons.filled.PhonelinkOff
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.content.ContextCompat
import androidx.wear.compose.foundation.lazy.ScalingLazyColumn
import androidx.wear.compose.foundation.lazy.rememberScalingLazyListState
import androidx.wear.compose.foundation.pager.HorizontalPager
import androidx.wear.compose.foundation.pager.rememberPagerState
import androidx.wear.compose.foundation.rotary.RotaryScrollableDefaults
import androidx.compose.ui.input.rotary.onRotaryScrollEvent
import androidx.wear.compose.material.ChipDefaults
import androidx.wear.compose.material.Chip
import androidx.wear.compose.material.CompactChip
import androidx.wear.compose.material.Icon
import androidx.wear.compose.material.MaterialTheme
import androidx.wear.compose.material.Text
import com.google.android.gms.wearable.Wearable
import com.khunor.lifey.ActiveExerciseDisplay
import com.khunor.lifey.CardioActiveMetrics
import com.khunor.lifey.CardioActivityFamily
import com.khunor.lifey.ExerciseService
import com.khunor.lifey.LiveMetrics
import com.khunor.lifey.LogAdjustField
import com.khunor.lifey.LogAdjustState
import com.khunor.lifey.LogSetState
import com.khunor.lifey.R
import com.khunor.lifey.SessionMetadata
import com.khunor.lifey.SessionStateHolder
import com.khunor.lifey.StandaloneSessionStore
import com.khunor.lifey.StandaloneTemplate
import com.khunor.lifey.StandaloneTemplateExercise
import com.khunor.lifey.SummarySender
import com.khunor.lifey.ui.theme.LifeyColors
import com.khunor.lifey.ui.theme.LifeyShapes
import java.util.UUID
import kotlin.math.abs
import java.util.Locale
import kotlin.math.roundToInt
import kotlin.math.sign
import java.text.DecimalFormat
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.tasks.await
import com.khunor.lifey.ui.EffortSelectorScreen
import com.khunor.lifey.ui.SCREEN_PADDING_FRACTION
import com.khunor.lifey.ui.LOG_BUTTON_PAIR_DIAMETER_FRACTION
import com.khunor.lifey.ui.isCompactScreen

/** Page 2 of 3 (canvas Wear 02/04): metrics normally, or the rest-hero while
 * a rest timer is running — never any controls, so it always fits one
 * screen without scrolling. */
@Composable
internal fun MetricsOrRestPage(
    resting: Boolean,
    elapsedMs: Long,
    restRemainingMs: Long,
    restTotalSeconds: Int?,
    exerciseName: String,
    setsDone: Int?,
    setsTotal: Int?,
    liveMetrics: LiveMetrics,
    isStandalone: Boolean,
    /** The template/session name in place of the generic "STRENGTH" label,
     * when one is available — see the top-level `activeHeaderLabel`
     * computation's doc comment. Only used on the non-resting branch below;
     * the rest-hero keeps its own "REST" label regardless. */
    headerLabel: String,
    freeFormatSets: Pair<Int, Int>?,
    /** Whether the exercise readout on this page opens the exercise list —
     * this is where the user notices they're on the wrong exercise, and the
     * chip on the log/controls pages is a swipe away from here (F6c §7). */
    canChooseExercise: Boolean,
    onOpenExerciseList: () -> Unit,
    isCompact: Boolean,
    maxWidth: Dp,
) {
    val heroStyle = if (isCompact) MaterialTheme.typography.display3 else MaterialTheme.typography.display2
    val captionStyle = if (isCompact) MaterialTheme.typography.caption2 else MaterialTheme.typography.caption1
    // Shrunk from title3/title2 (§ overflow fix) — at title2, two 3-digit
    // readings (HR + kcal both >= 100) side by side clipped against the
    // round bezel instead of fitting on one line.
    val metricNumberStyle = if (isCompact) MaterialTheme.typography.body2 else MaterialTheme.typography.title3
    val metricIconSize = if (isCompact) 14.dp else 18.dp

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(horizontal = maxWidth * SCREEN_PADDING_FRACTION),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        if (resting) {
            Box(modifier = Modifier.exercisePickerTarget(canChooseExercise, onOpenExerciseList)) {
                RestHero(
                    restRemainingMs = restRemainingMs,
                    restTotalSeconds = restTotalSeconds,
                    exerciseName = exerciseName,
                    setsDone = setsDone,
                    setsTotal = setsTotal,
                    liveMetrics = liveMetrics,
                    isStandalone = isStandalone,
                    isCompact = isCompact,
                )
            }
        } else {
            HeaderChip(
                icon = Icons.Filled.FitnessCenter,
                label = headerLabel,
                isStandalone = isStandalone,
                isCompact = isCompact,
            )
            Text(text = formatElapsed(elapsedMs), style = heroStyle, color = LifeyColors.primary)
            if (liveMetrics.isPaused) {
                Text(
                    text = stringResource(R.string.active_paused_indicator),
                    style = captionStyle,
                    color = LifeyColors.negative,
                )
            }
            Row(horizontalArrangement = Arrangement.spacedBy(if (isCompact) 8.dp else 12.dp)) {
                HeartRateReading(
                    liveMetrics = liveMetrics,
                    iconSize = metricIconSize,
                    valueStyle = metricNumberStyle,
                )
                liveMetrics.activeCalories?.let { kcal ->
                    MetricReading(
                        icon = Icons.Filled.LocalFireDepartment,
                        iconTint = LifeyColors.calories,
                        value = kcal.roundToInt().toString(),
                        iconSize = metricIconSize,
                        valueStyle = metricNumberStyle,
                    )
                }
            }
            if (!liveMetrics.hasHeartRatePermission) {
                val permissionLauncher = rememberLauncherForActivityResult(
                    ActivityResultContracts.RequestMultiplePermissions(),
                ) { /* no-op — ExerciseService re-checks live before the next start */ }
                CompactChip(
                    onClick = { permissionLauncher.launch(HEART_RATE_PERMISSIONS) },
                    icon = {
                        Icon(
                            imageVector = Icons.Filled.HeartBroken,
                            contentDescription = null,
                            tint = LifeyColors.onSurfaceVariant,
                        )
                    },
                    label = {
                        Text(
                            text = stringResource(R.string.active_heart_rate_denied_chip),
                            style = captionStyle,
                            maxLines = 1,
                        )
                    },
                    colors = ChipDefaults.chipColors(
                        backgroundColor = LifeyColors.container,
                        contentColor = LifeyColors.onSurfaceVariant,
                    ),
                )
            }
            Box(modifier = Modifier.exercisePickerTarget(canChooseExercise, onOpenExerciseList)) {
                ExerciseCard(
                    exerciseName = exerciseName,
                    setsDone = setsDone,
                    setsTotal = setsTotal,
                    freeFormatSets = freeFormatSets,
                    isCompact = isCompact,
                )
            }
        }
    }
}

/** Makes the exercise readout open the exercise list — but only while there is
 * something to switch to, so a session without a pushed plan keeps a plain,
 * non-interactive readout instead of a control that opens an empty screen.
 * Mirrors iOS's `ExercisePickerTarget`. */
internal fun Modifier.exercisePickerTarget(
    canChooseExercise: Boolean,
    onOpenExerciseList: () -> Unit,
): Modifier = if (canChooseExercise) clickable(onClick = onOpenExerciseList) else this

/** The exercise-name + set-counter card (canvas AW02/Wear02's `container`-bg
 * pill under the metrics). The exercise name is truncated to one line with
 * an ellipsis (41-watch-design-prompt.md §3.2: "Exercise name may be long...;
 * plan truncation") rather than left to wrap/clip unpredictably. */
@Composable
internal fun ExerciseCard(
    exerciseName: String,
    setsDone: Int?,
    setsTotal: Int?,
    isCompact: Boolean,
    /** Standalone's set-count line (docs/watch/44-watch-f6-standalone-
     * plan.md §3.4, D-F6.3) — no plan, so no "n of total"; just how many
     * sets and their combined reps. Null for phone-mastered sessions, which
     * use [setsDone]/[setsTotal] instead (mirrors iOS's `ExerciseCard
     * .freeFormatSets`). */
    freeFormatSets: Pair<Int, Int>? = null,
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(top = if (isCompact) 8.dp else 12.dp)
            .background(LifeyColors.container, LifeyShapes.card)
            .padding(horizontal = 16.dp, vertical = 12.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(
            text = exerciseName,
            style = if (isCompact) MaterialTheme.typography.body2 else MaterialTheme.typography.title3,
            color = LifeyColors.onSurface,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
        )
        if (freeFormatSets != null) {
            Text(
                text = stringResource(R.string.active_sets_free_format, freeFormatSets.first, freeFormatSets.second),
                style = if (isCompact) MaterialTheme.typography.caption2 else MaterialTheme.typography.caption1,
                color = LifeyColors.onSurfaceVariant,
                maxLines = 1,
            )
        } else if (setsDone != null && setsTotal != null) {
            Text(
                text = stringResource(R.string.active_sets_format, setsDone, setsTotal),
                style = if (isCompact) MaterialTheme.typography.caption2 else MaterialTheme.typography.caption1,
                color = LifeyColors.onSurfaceVariant,
                maxLines = 1,
            )
        }
    }
}
