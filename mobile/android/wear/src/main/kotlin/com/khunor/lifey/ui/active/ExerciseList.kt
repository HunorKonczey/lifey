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

/**
 * The "which exercise am I logging against" picker (docs/watch/
 * 49-watch-f6b-template-sync-plan.md §3.5, D-F6b.8) — opened from
 * [ExerciseListChip], on either [LogPage] or [ControlsPage]; only ever
 * shown during a template-backed standalone session. Replaces the pager the same way the
 * adjust overlay does (see [ActiveWorkoutScreen]), not a separate
 * Activity/navigation destination. Visually the exact shape
 * [com.khunor.lifey.ui.StandalonePickerScreen]'s rows already established
 * (T4) — a `ScalingLazyColumn` of `surface`-background cards, the selected
 * one highlighted `containerHigh` — not a new component language.
 *
 * Tapping a row **jumps** straight to that exercise, not a "Next" stepper
 * (D-F6b.8's own reasoning: a one-way Next either silently wraps back to
 * exercise 1, logging wrong data, or dead-ends at the last exercise with no
 * way back). No confirmation: this is fully reversible — a mis-tap costs one
 * more tap to undo, not a lost set. Already-logged sets keep whatever
 * `exerciseIndex` they were logged with, permanently; selecting here only
 * changes what the *next* tap counts against.
 */
@Composable
internal fun ExerciseListScreen(
    exercises: List<StandaloneTemplateExercise>,
    currentExerciseId: String?,
    /**
     * How many sets each exercise has, by plan index — resolved by the caller
     * through [SessionMetadata.standaloneSetsDoneAt], not counted from this
     * watch's own set list. A watch-started workout is logged into from the
     * phone too, and only the phone's row holds both halves: counting locally
     * showed a lower number here than the phone had, and a different one than
     * the active page, which already reconciles the two.
     */
    setsDonePerExercise: List<Int>,
    /**
     * Plan positions the phone removed from this session
     * ([SessionMetadata.removedExerciseIndexes]) — skipped when rendering,
     * never renumbered: `index` below stays the position every logged set is
     * attributed by.
     */
    removedExerciseIndexes: Set<Int>,
    isCompact: Boolean,
    maxWidth: Dp,
    onSelect: (Int) -> Unit,
    onBack: () -> Unit,
) {
    val listState = rememberScalingLazyListState()

    BoxWithConstraints(modifier = Modifier.fillMaxSize()) {
        ScalingLazyColumn(
            state = listState,
            modifier = Modifier.fillMaxSize(),
            contentPadding = PaddingValues(
                horizontal = maxWidth * SCREEN_PADDING_FRACTION,
                vertical = maxWidth * 0.14f,
            ),
        ) {
            item {
                Text(
                    text = stringResource(R.string.standalone_exercise_list_title),
                    style = if (isCompact) MaterialTheme.typography.title3 else MaterialTheme.typography.title2,
                    color = LifeyColors.onSurface,
                )
            }
            exercises.forEachIndexed { index, exercise ->
                if (index in removedExerciseIndexes) return@forEachIndexed
                item {
                    ExerciseListRow(
                        exercise = exercise,
                        isCompact = isCompact,
                        isCurrent = exercise.exerciseId == currentExerciseId,
                        setsDone = setsDonePerExercise.getOrElse(index) { 0 },
                        onTap = { onSelect(index) },
                    )
                }
            }
        }

        // Top-start corner, out of the ScalingLazyColumn's flow — mirrors
        // StandalonePickerScreen's identical back affordance.
        Icon(
            imageVector = Icons.AutoMirrored.Filled.ArrowBack,
            contentDescription = stringResource(R.string.effort_selector_back),
            tint = LifeyColors.onSurfaceVariant,
            modifier = Modifier
                .align(Alignment.TopStart)
                .padding(8.dp)
                .clickable(onClick = onBack)
                .size(20.dp),
        )
    }
}

/** One exercise row — reuses [com.khunor.lifey.ui.StandalonePickerScreen]'s
 * `TemplateRow` visual language rather than inventing a new one (see
 * [ExerciseListScreen]'s doc comment), plus the current-exercise highlight
 * `StandalonePickerScreen` doesn't need. */
@Composable
internal fun ExerciseListRow(
    exercise: StandaloneTemplateExercise,
    isCompact: Boolean,
    isCurrent: Boolean,
    setsDone: Int,
    onTap: () -> Unit,
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onTap)
            .background(
                if (isCurrent) LifeyColors.containerHigh else LifeyColors.surface,
                LifeyShapes.card,
            )
            .padding(horizontal = 16.dp, vertical = 12.dp),
    ) {
        Text(
            text = exercise.name,
            style = if (isCompact) MaterialTheme.typography.body2 else MaterialTheme.typography.title3,
            color = LifeyColors.onSurface,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
        )
        val targetSets = exercise.targetSets
        Text(
            text = if (targetSets != null) {
                stringResource(R.string.active_sets_format, setsDone, targetSets)
            } else {
                stringResource(R.string.standalone_exercise_sets_done, setsDone)
            },
            style = if (isCompact) MaterialTheme.typography.caption2 else MaterialTheme.typography.caption1,
            color = LifeyColors.onSurfaceVariant,
            maxLines = 1,
        )
    }
}
