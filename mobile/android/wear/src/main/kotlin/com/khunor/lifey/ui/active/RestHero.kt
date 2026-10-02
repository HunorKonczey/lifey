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
 * Rest-end haptic moment's visual half (docs/40-watch-app-plan.md §12.1 B2 /
 * 41-watch-design-prompt.md §3.4): a brief primary-color fill pulse with a
 * "GO" wordmark, covering the whole dial for ~1.3 s before the screen snaps
 * back to the plain metrics view. The haptic itself fires independently in
 * [com.khunor.lifey.ExerciseService] — this is purely decorative.
 */
@Composable
internal fun GoFlash(modifier: Modifier = Modifier) {
    val alpha = remember { Animatable(0f) }
    LaunchedEffect(Unit) {
        alpha.animateTo(1f, animationSpec = tween(durationMillis = 150))
        alpha.animateTo(0f, animationSpec = tween(durationMillis = 700, delayMillis = 250))
    }
    Box(
        modifier = modifier.background(LifeyColors.primary.copy(alpha = alpha.value)),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = stringResource(R.string.rest_go_label),
            style = MaterialTheme.typography.display1,
            color = LifeyColors.onPrimary.copy(alpha = alpha.value),
        )
    }
}

/**
 * Rest-as-hero state (docs/40-watch-app-plan.md §12.1 B1 / 41-watch-design-
 * prompt.md §3.3): a drain-down progress ring takes the metrics page's hero
 * slot instead of the countdown being a small caption line, with a "of
 * <total>" target below it and a "Next · <exercise> — Set n of total" line
 * for what resumes once rest ends, plus a small HR+kcal reading underneath
 * (canvas Wear 04 — rest doesn't mean the metrics disappear, just shrink).
 * Color shifts to the `negative` token for the final 5 seconds, matching the
 * haptic that fires at 0 ([com.khunor.lifey.ExerciseService]'s independently-
 * scheduled vibration). [ringSize] and the [isCompact] type-scale switch come
 * from the caller's `BoxWithConstraints` (§12.1 B4) — this composable has no
 * size opinion of its own.
 */
@Composable
internal fun RestHero(
    restRemainingMs: Long,
    restTotalSeconds: Int?,
    exerciseName: String,
    setsDone: Int?,
    setsTotal: Int?,
    liveMetrics: LiveMetrics,
    isStandalone: Boolean,
    isCompact: Boolean,
) {
    val ringColor = if (restRemainingMs <= REST_RING_NEGATIVE_THRESHOLD_MS) {
        LifeyColors.negative
    } else {
        LifeyColors.primary
    }
    val progress = restTotalSeconds
        ?.takeIf { it > 0 }
        ?.let { (restRemainingMs.toFloat() / (it * 1000)).coerceIn(0f, 1f) }
        ?: 1f
    val captionStyle = if (isCompact) MaterialTheme.typography.caption2 else MaterialTheme.typography.caption1
    val ringNumberStyle = if (isCompact) MaterialTheme.typography.title2 else MaterialTheme.typography.display2
    // Shrunk from caption1/title3 (§ overflow fix, mirrors the metrics-page
    // row above) — same 3-digit clipping risk for the small HR/kcal reading
    // under the rest ring.
    val smallMetricStyle = if (isCompact) MaterialTheme.typography.caption2 else MaterialTheme.typography.body2
    val smallMetricIconSize = if (isCompact) 14.dp else 16.dp
    // A wide, short bar rather than a ring (a round dial leaves the ring's
    // corners empty; a full-width bar uses that space and reads bigger at a
    // glance) — docs/40-watch-app-plan.md §12.1 B1 follow-up feedback.
    val barHeight = if (isCompact) 60.dp else 78.dp

    HeaderChip(
        icon = Icons.Filled.Timer,
        label = stringResource(R.string.rest_hero_label),
        isStandalone = isStandalone,
        isCompact = isCompact,
    )
    BoxWithConstraints(
        modifier = Modifier
            .fillMaxWidth()
            .height(barHeight)
            .padding(top = 8.dp),
    ) {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(LifeyColors.container, LifeyShapes.cardLarge),
        )
        Box(
            modifier = Modifier
                .width(maxWidth * progress)
                .fillMaxHeight()
                .background(ringColor, LifeyShapes.cardLarge),
        )
        Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
            Text(text = formatElapsed(restRemainingMs), style = ringNumberStyle, color = LifeyColors.onSurface)
        }
    }
    if (restTotalSeconds != null) {
        Text(
            text = stringResource(R.string.rest_hero_total_format, formatElapsed(restTotalSeconds * 1000L)),
            style = if (isCompact) MaterialTheme.typography.caption3 else MaterialTheme.typography.caption2,
            color = LifeyColors.onSurfaceVariant,
            maxLines = 1,
        )
    }
    if (setsDone != null && setsTotal != null) {
        Text(
            text = stringResource(
                R.string.rest_hero_next_with_sets_format,
                exerciseName,
                (setsDone + 1).coerceAtMost(setsTotal),
                setsTotal,
            ),
            style = captionStyle,
            color = LifeyColors.onSurfaceVariant,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
        )
    } else {
        Text(
            text = stringResource(R.string.rest_hero_next_format, exerciseName),
            style = captionStyle,
            color = LifeyColors.onSurfaceVariant,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
        )
    }
    Row(
        modifier = Modifier.padding(top = 8.dp),
        horizontalArrangement = Arrangement.spacedBy(if (isCompact) 8.dp else 12.dp),
    ) {
        HeartRateReading(
            liveMetrics = liveMetrics,
            iconSize = smallMetricIconSize,
            valueStyle = smallMetricStyle,
        )
        liveMetrics.activeCalories?.let { kcal ->
            MetricReading(
                icon = Icons.Filled.LocalFireDepartment,
                iconTint = LifeyColors.calories,
                value = kcal.roundToInt().toString(),
                iconSize = smallMetricIconSize,
                valueStyle = smallMetricStyle,
            )
        }
    }
}
