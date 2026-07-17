package com.khunor.lifey.ui

import android.Manifest
import android.os.SystemClock
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.FitnessCenter
import androidx.compose.material.icons.filled.HeartBroken
import androidx.compose.material.icons.filled.LocalFireDepartment
import androidx.compose.material.icons.filled.Pause
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Stop
import androidx.compose.material.icons.filled.Timer
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.wear.compose.material.ChipDefaults
import androidx.wear.compose.material.Chip
import androidx.wear.compose.material.CircularProgressIndicator
import androidx.wear.compose.material.CompactChip
import androidx.wear.compose.material.Icon
import androidx.wear.compose.material.MaterialTheme
import androidx.wear.compose.material.Text
import com.khunor.lifey.ExerciseService
import com.khunor.lifey.LiveMetrics
import com.khunor.lifey.R
import com.khunor.lifey.SessionStateHolder
import com.khunor.lifey.SummarySender
import com.khunor.lifey.ui.theme.LifeyColors
import com.khunor.lifey.ui.theme.LifeyShapes
import kotlin.math.roundToInt
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

private const val REST_RING_NEGATIVE_THRESHOLD_MS = 5_000L

/** Total on-screen time for the rest-end "GO" flash (§3.4: "1–2 s flash/transition"). */
private const val GO_FLASH_HOLD_MS = 1_300

/** The rest-hero progress ring's diameter as a fraction of the shorter screen dimension (§12.1 B4). */
private const val REST_RING_SIZE_FRACTION = 0.42f

private const val METRICS_PAGE = 0
private const val PAGE_COUNT = 2

/** Re-requested by the "allow sensors" chip (§12.1 B13) — the same pair
 * [com.khunor.lifey.ExerciseService.startExercise] checks before adding
 * `HEART_RATE_BPM` to the exercise config. */
private val HEART_RATE_PERMISSIONS = arrayOf(
    Manifest.permission.BODY_SENSORS,
    "android.permission.health.READ_HEART_RATE",
)

/**
 * Live workout screen — elapsed time, heart rate, calories, current
 * exercise/set counter, rest-timer countdown (docs/40-watch-app-plan.md
 * §4.4/§5.1 "ActiveWorkoutView" equivalent; the haptic at rest-end is
 * scheduled independently in [com.khunor.lifey.ExerciseService], not here —
 * it needs to fire even while this screen isn't composed).
 *
 * Two swipeable pages, not one scrolling column: [MetricsOrRestPage] (metrics
 * or the rest-hero) and [ControlsPage] (End/Pause). An earlier version put
 * both in a single scrollable `Column`, but on a round display the End chip
 * ended up peeking in at the bottom of *every* metrics/rest view without any
 * scroll gesture, visibly clipped by the bezel — confusing and ugly on real
 * hardware even though it matched the canvas's own scroll-then-see-controls
 * intent in principle. A `HorizontalPager` (with a page-dot
 * [HorizontalPageIndicator]) gives the same two-section structure the design
 * canvas frames (Wear 02 vs. Wear 03) without that clipping, at the cost of
 * a swipe instead of a scroll to reach the controls.
 *
 * The End button only *asks* the phone to close the session (§8.2 decision
 * (b)) — it never touches [com.khunor.lifey.ExerciseService] directly.
 * Pause/Resume (§12.1 B3) is the one control that *does* command
 * [com.khunor.lifey.ExerciseService] directly — it only affects the local
 * sensor session, nothing the phone needs to know about.
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
    // Flips true for GO_FLASH_HOLD_MS the instant a countdown naturally
    // reaches zero (docs/40-watch-app-plan.md §12.1 B2 / 41-watch-design-
    // prompt.md §3.4) — stays false if the rest was skipped/replaced instead
    // (that path re-keys this LaunchedEffect on a new restDeadlineElapsedRealtimeMs
    // before the `while` loop's `break` is ever reached). Anchored to the
    // same deadline as ExerciseService's independently-scheduled haptic
    // (both derive it from SessionStateHolder), so the flash and the buzz
    // land together without needing any cross-process signal. The deadline
    // itself is this device's own SystemClock.elapsedRealtime() — never
    // System.currentTimeMillis() — so the countdown can't go wrong just
    // because the watch's and phone's wall clocks disagree (§12.1 bugfix;
    // see SessionStateHolder.SessionMetadata's doc comment).
    var showGoFlash by remember { mutableStateOf(false) }
    LaunchedEffect(metadata.restDeadlineElapsedRealtimeMs) {
        val deadlineElapsedRealtimeMs = metadata.restDeadlineElapsedRealtimeMs
        if (deadlineElapsedRealtimeMs == null) {
            restRemainingMs = 0L
            showGoFlash = false
            return@LaunchedEffect
        }
        while (true) {
            val remaining = deadlineElapsedRealtimeMs - SystemClock.elapsedRealtime()
            restRemainingMs = remaining
            if (remaining <= 0) break
            delay(1000)
        }
        restRemainingMs = 0L
        showGoFlash = true
        delay(GO_FLASH_HOLD_MS.toLong())
        showGoFlash = false
    }

    val setsDone = metadata.setsDone
    val setsTotal = metadata.setsTotal
    val resting = restRemainingMs > 0

    val pagerState = rememberPagerState(pageCount = { PAGE_COUNT })

    BoxWithConstraints(modifier = Modifier.fillMaxSize()) {
        val isCompact = isCompactScreen(maxWidth)

        HorizontalPager(
            state = pagerState,
            modifier = Modifier.fillMaxSize(),
        ) { page ->
            when (page) {
                METRICS_PAGE -> MetricsOrRestPage(
                    resting = resting,
                    elapsedMs = elapsedMs,
                    restRemainingMs = restRemainingMs,
                    restTotalSeconds = metadata.restTotalSeconds,
                    exerciseName = metadata.exerciseName ?: stringResource(R.string.active_default_exercise),
                    setsDone = setsDone,
                    setsTotal = setsTotal,
                    liveMetrics = liveMetrics,
                    isCompact = isCompact,
                    maxWidth = maxWidth,
                    maxHeight = maxHeight,
                )
                else -> ControlsPage(
                    exerciseName = metadata.exerciseName ?: stringResource(R.string.active_default_exercise),
                    setsDone = setsDone,
                    setsTotal = setsTotal,
                    isPaused = liveMetrics.isPaused,
                    isCompact = isCompact,
                    onEnd = {
                        val sessionClientId = metadata.sessionClientId ?: return@ControlsPage
                        scope.launch { SummarySender.sendEndRequested(context, sessionClientId) }
                    },
                    onTogglePause = {
                        val paused = liveMetrics.isPaused
                        scope.launch {
                            if (paused) ExerciseService.resume(context) else ExerciseService.pause(context)
                        }
                    },
                )
            }
        }
        PageDots(
            pageCount = PAGE_COUNT,
            selectedPage = pagerState.currentPage,
            modifier = Modifier.align(Alignment.BottomCenter).padding(bottom = 16.dp),
        )
        if (showGoFlash) {
            GoFlash(modifier = Modifier.fillMaxSize())
        }
    }
}

/**
 * A minimal 2-dot page indicator (canvas AW02/AW04's page-dots row, adapted
 * for Wear). `HorizontalPageIndicator` from `androidx.wear.compose.material`
 * was tried first, but on a round emulator it rendered nothing at all — its
 * default curved-style layout apparently needs more than just a `BoxScope`
 * to find its arc, and chasing that further wasn't worth it for something
 * this simple. Two plain circles, hand-drawn like [IdleScreen]'s leaf mark,
 * are trivially correct instead. */
@Composable
private fun PageDots(pageCount: Int, selectedPage: Int, modifier: Modifier = Modifier) {
    Row(modifier = modifier, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
        repeat(pageCount) { index ->
            Box(
                modifier = Modifier
                    .size(6.dp)
                    .background(
                        if (index == selectedPage) LifeyColors.onSurface else LifeyColors.outline,
                        CircleShape,
                    ),
            )
        }
    }
}

/** Page 1 of 2 (canvas Wear 02/04): metrics normally, or the rest-hero while
 * a rest timer is running — never any controls, so it always fits one
 * screen without scrolling. */
@Composable
private fun MetricsOrRestPage(
    resting: Boolean,
    elapsedMs: Long,
    restRemainingMs: Long,
    restTotalSeconds: Int?,
    exerciseName: String,
    setsDone: Int?,
    setsTotal: Int?,
    liveMetrics: LiveMetrics,
    isCompact: Boolean,
    maxWidth: Dp,
    maxHeight: Dp,
) {
    val heroStyle = if (isCompact) MaterialTheme.typography.display3 else MaterialTheme.typography.display2
    val captionStyle = if (isCompact) MaterialTheme.typography.caption2 else MaterialTheme.typography.caption1
    val metricNumberStyle = if (isCompact) MaterialTheme.typography.title3 else MaterialTheme.typography.title2
    val metricIconSize = if (isCompact) 18.dp else 22.dp
    val ringSize = minOf(maxWidth, maxHeight) * REST_RING_SIZE_FRACTION

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(horizontal = maxWidth * SCREEN_PADDING_FRACTION),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        if (resting) {
            RestHero(
                restRemainingMs = restRemainingMs,
                restTotalSeconds = restTotalSeconds,
                exerciseName = exerciseName,
                setsDone = setsDone,
                setsTotal = setsTotal,
                liveMetrics = liveMetrics,
                isCompact = isCompact,
                ringSize = ringSize,
            )
        } else {
            HeaderChip(
                icon = Icons.Filled.FitnessCenter,
                label = stringResource(R.string.active_header_label),
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
            Row(horizontalArrangement = Arrangement.spacedBy(if (isCompact) 12.dp else 18.dp)) {
                HeartRateReading(
                    liveMetrics = liveMetrics,
                    iconSize = metricIconSize,
                    valueStyle = metricNumberStyle,
                    unitStyle = captionStyle,
                )
                liveMetrics.activeCalories?.let { kcal ->
                    MetricReading(
                        icon = Icons.Filled.LocalFireDepartment,
                        iconTint = LifeyColors.calories,
                        value = kcal.roundToInt().toString(),
                        unit = stringResource(R.string.active_calories_unit),
                        iconSize = metricIconSize,
                        valueStyle = metricNumberStyle,
                        unitStyle = captionStyle,
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
            ExerciseCard(
                exerciseName = exerciseName,
                setsDone = setsDone,
                setsTotal = setsTotal,
                isCompact = isCompact,
            )
        }
    }
}

/** Page 2 of 2 (canvas Wear 03): End + Pause only, with a dimmed reminder of
 * what's in progress (matching the canvas's faded, scaled-down exercise
 * card) so the page doesn't feel disconnected from page 1. */
@Composable
private fun ControlsPage(
    exerciseName: String,
    setsDone: Int?,
    setsTotal: Int?,
    isPaused: Boolean,
    isCompact: Boolean,
    onEnd: () -> Unit,
    onTogglePause: () -> Unit,
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
        }
    }
}

/**
 * The "STRENGTH"/"REST" uppercase icon+label row that anchors the top of the
 * metrics and rest-hero states (canvas AW02/Wear02, AW03/Wear04) — the one
 * bit of letter-spacing tracking the design calls for (41-watch-design-
 * prompt.md §1: "uppercase labels tracked +0.5") is applied here directly
 * rather than through the shared `Typography`, since every other caption in
 * this screen is mixed-case body copy that tracking would only cramp.
 */
@Composable
private fun HeaderChip(
    icon: ImageVector,
    label: String,
    isCompact: Boolean,
) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            tint = LifeyColors.primary,
            modifier = Modifier.size(if (isCompact) 16.dp else 18.dp),
        )
        Text(
            text = label,
            style = if (isCompact) MaterialTheme.typography.caption3 else MaterialTheme.typography.caption2,
            color = LifeyColors.primary,
            letterSpacing = 0.5.sp,
            maxLines = 1,
        )
    }
}

/** The heart-rate reading, or its degraded "--" state when the sensor
 * permission was denied (§12.1 B13) — split out from [MetricReading] because
 * it also needs the small variant used inside [RestHero]. */
@Composable
private fun HeartRateReading(
    liveMetrics: LiveMetrics,
    iconSize: Dp,
    valueStyle: TextStyle,
    unitStyle: TextStyle,
) {
    if (liveMetrics.hasHeartRatePermission) {
        liveMetrics.heartRateBpm?.let { bpm ->
            MetricReading(
                icon = Icons.Filled.Favorite,
                iconTint = LifeyColors.heart,
                value = bpm.roundToInt().toString(),
                unit = stringResource(R.string.active_heart_rate_unit),
                iconSize = iconSize,
                valueStyle = valueStyle,
                unitStyle = unitStyle,
            )
        }
    } else {
        // §12.1 B13: permission denied looks intentional (a muted
        // placeholder + broken-heart glyph), not like a missing/late
        // reading — distinct from heartRateBpm == null above, which just
        // means "no sample yet".
        MetricReading(
            icon = Icons.Filled.HeartBroken,
            iconTint = LifeyColors.outline,
            value = stringResource(R.string.active_heart_rate_denied_placeholder),
            unit = null,
            iconSize = iconSize,
            valueStyle = valueStyle,
            unitStyle = unitStyle,
            valueColor = LifeyColors.onSurfaceVariant,
        )
    }
}

/** One icon + number + muted unit metric reading (HR or kcal, canvas
 * AW02/Wear02) — [unit] is null for the degraded-HR placeholder, which has
 * no unit to show next to "--" (§12.1 B13). [maxLines]/no-wrap on both value
 * and unit: on a narrow round display a two-word unit like "kcal" could
 * otherwise wrap onto its own second line mid-word instead of staying on
 * one line next to the number. */
@Composable
private fun MetricReading(
    icon: ImageVector,
    iconTint: Color,
    value: String,
    unit: String?,
    iconSize: Dp,
    valueStyle: TextStyle,
    unitStyle: TextStyle,
    valueColor: Color = LifeyColors.onSurface,
) {
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
        Icon(imageVector = icon, contentDescription = null, tint = iconTint, modifier = Modifier.size(iconSize))
        Text(text = value, style = valueStyle, color = valueColor, maxLines = 1, softWrap = false)
        if (unit != null) {
            Text(text = unit, style = unitStyle, color = LifeyColors.onSurfaceVariant, maxLines = 1, softWrap = false)
        }
    }
}

/** The exercise-name + set-counter card (canvas AW02/Wear02's `container`-bg
 * pill under the metrics). The exercise name is truncated to one line with
 * an ellipsis (41-watch-design-prompt.md §3.2: "Exercise name may be long...;
 * plan truncation") rather than left to wrap/clip unpredictably. */
@Composable
private fun ExerciseCard(
    exerciseName: String,
    setsDone: Int?,
    setsTotal: Int?,
    isCompact: Boolean,
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
        if (setsDone != null && setsTotal != null) {
            Text(
                text = stringResource(R.string.active_sets_format, setsDone, setsTotal),
                style = if (isCompact) MaterialTheme.typography.caption2 else MaterialTheme.typography.caption1,
                color = LifeyColors.onSurfaceVariant,
                maxLines = 1,
            )
        }
    }
}

/**
 * Rest-end haptic moment's visual half (docs/40-watch-app-plan.md §12.1 B2 /
 * 41-watch-design-prompt.md §3.4): a brief primary-color fill pulse with a
 * "GO" wordmark, covering the whole dial for ~1.3 s before the screen snaps
 * back to the plain metrics view. The haptic itself fires independently in
 * [com.khunor.lifey.ExerciseService] — this is purely decorative.
 */
@Composable
private fun GoFlash(modifier: Modifier = Modifier) {
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
private fun RestHero(
    restRemainingMs: Long,
    restTotalSeconds: Int?,
    exerciseName: String,
    setsDone: Int?,
    setsTotal: Int?,
    liveMetrics: LiveMetrics,
    isCompact: Boolean,
    ringSize: Dp,
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
    val ringNumberStyle = if (isCompact) MaterialTheme.typography.title3 else MaterialTheme.typography.display3
    val smallMetricStyle = if (isCompact) MaterialTheme.typography.caption1 else MaterialTheme.typography.title3
    val smallMetricIconSize = if (isCompact) 16.dp else 18.dp

    HeaderChip(
        icon = Icons.Filled.Timer,
        label = stringResource(R.string.rest_hero_label),
        isCompact = isCompact,
    )
    Box(modifier = Modifier.size(ringSize).padding(top = 8.dp), contentAlignment = Alignment.Center) {
        CircularProgressIndicator(
            progress = progress,
            modifier = Modifier.fillMaxSize(),
            indicatorColor = ringColor,
            trackColor = LifeyColors.container,
        )
        Text(text = formatElapsed(restRemainingMs), style = ringNumberStyle, color = LifeyColors.onSurface)
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
        horizontalArrangement = Arrangement.spacedBy(if (isCompact) 12.dp else 18.dp),
    ) {
        HeartRateReading(
            liveMetrics = liveMetrics,
            iconSize = smallMetricIconSize,
            valueStyle = smallMetricStyle,
            unitStyle = captionStyle,
        )
        liveMetrics.activeCalories?.let { kcal ->
            MetricReading(
                icon = Icons.Filled.LocalFireDepartment,
                iconTint = LifeyColors.calories,
                value = kcal.roundToInt().toString(),
                unit = null,
                iconSize = smallMetricIconSize,
                valueStyle = smallMetricStyle,
                unitStyle = captionStyle,
            )
        }
    }
}

private fun formatElapsed(totalMs: Long): String {
    val totalSeconds = totalMs / 1000
    val minutes = totalSeconds / 60
    val seconds = totalSeconds % 60
    return "%02d:%02d".format(minutes, seconds)
}
