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

/** Page 3 of 3 (canvas Wear 03): End + Pause only, with a dimmed reminder of
 * what's in progress (matching the canvas's faded, scaled-down exercise
 * card) so the page doesn't feel disconnected from the metrics page. */
@Composable
internal fun ControlsPage(
    exerciseName: String,
    setsDone: Int?,
    setsTotal: Int?,
    isPaused: Boolean,
    freeFormatSets: Pair<Int, Int>?,
    /** Only during a template-backed standalone session (docs/watch/
     * 49-watch-f6b-template-sync-plan.md §3.5) — quick-strength and
     * phone-mastered sessions have nothing to switch between. */
    hasStandaloneTemplate: Boolean,
    isCompact: Boolean,
    onEnd: () -> Unit,
    onTogglePause: () -> Unit,
    onOpenExerciseList: () -> Unit,
) {
    Column(
        modifier = Modifier.fillMaxSize().padding(horizontal = 16.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Box(modifier = Modifier.alpha(0.55f)) {
            ExerciseCard(
                exerciseName = exerciseName,
                setsDone = setsDone,
                setsTotal = setsTotal,
                freeFormatSets = freeFormatSets,
                isCompact = true,
            )
        }
        Column(
            modifier = Modifier.fillMaxWidth().padding(top = 14.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Chip(
                onClick = onEnd,
                modifier = Modifier.fillMaxWidth(),
                icon = { Icon(imageVector = Icons.Filled.Stop, contentDescription = null, tint = LifeyColors.negative) },
                label = {
                    Text(
                        stringResource(R.string.active_end_button),
                        color = LifeyColors.negative,
                        maxLines = 1,
                    )
                },
                colors = ChipDefaults.chipColors(
                    backgroundColor = LifeyColors.negative.copy(alpha = 0.16f),
                    contentColor = LifeyColors.negative,
                ),
            )
            Chip(
                onClick = onTogglePause,
                modifier = Modifier.fillMaxWidth(),
                icon = {
                    Icon(
                        imageVector = if (isPaused) Icons.Filled.PlayArrow else Icons.Filled.Pause,
                        contentDescription = null,
                        tint = LifeyColors.onSurface,
                    )
                },
                label = {
                    Text(
                        stringResource(if (isPaused) R.string.active_resume_button else R.string.active_pause_button),
                        color = LifeyColors.onSurface,
                        maxLines = 1,
                    )
                },
                colors = ChipDefaults.chipColors(
                    backgroundColor = LifeyColors.container,
                    contentColor = LifeyColors.onSurface,
                ),
            )
            if (hasStandaloneTemplate) {
                ExerciseListChip(onClick = onOpenExerciseList)
            }
        }
    }
}

/**
 * The "Gyakorlatok" chip that opens [ExerciseListScreen] (docs/watch/
 * 49-watch-f6b-template-sync-plan.md §3.5, D-F6b.8). Shown on both
 * [ControlsPage] and [LogPage] — the log page is where the user actually
 * notices they're on the wrong exercise ("Set 2 of 2" sits right above it),
 * so making them swipe two pages to fix it was the wrong place to hide it.
 * One composable rather than two copies, so the two pages can't drift apart.
 * Only ever rendered during a template-backed standalone session; a
 * quick-strength or phone-mastered one has nothing to switch between.
 * Mirrors iOS's `ExerciseListChip`.
 */
@Composable
internal fun ExerciseListChip(onClick: () -> Unit) {
    CompactChip(
        onClick = onClick,
        icon = {
            Icon(
                imageVector = Icons.AutoMirrored.Filled.List,
                contentDescription = null,
                tint = LifeyColors.onSurfaceVariant,
            )
        },
        label = {
            Text(
                text = stringResource(R.string.standalone_exercise_list_title),
                maxLines = 1,
            )
        },
        colors = ChipDefaults.chipColors(
            backgroundColor = LifeyColors.container,
            contentColor = LifeyColors.onSurfaceVariant,
        ),
    )
}
