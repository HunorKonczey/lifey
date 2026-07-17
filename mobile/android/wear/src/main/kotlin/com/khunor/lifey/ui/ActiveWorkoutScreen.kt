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
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.wear.compose.material.Button
import androidx.wear.compose.material.CircularProgressIndicator
import androidx.wear.compose.material.CompactChip
import androidx.wear.compose.material.MaterialTheme
import androidx.wear.compose.material.PositionIndicator
import androidx.wear.compose.material.Text
import com.khunor.lifey.ExerciseService
import com.khunor.lifey.R
import com.khunor.lifey.SessionStateHolder
import com.khunor.lifey.SummarySender
import kotlin.math.roundToInt
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/** 41-watch-design-prompt.md §2.6 `primary` — the rest ring's normal color. */
private val RestRingColor = Color(0xFF9DAE6B)

/** 41-watch-design-prompt.md §2.6 `negative` — final-5-seconds color shift. */
private val RestRingNegativeColor = Color(0xFFE08A52)

/** 41-watch-design-prompt.md §2.3 `onPrimary` — text on the GO flash's primary fill. */
private val OnPrimaryColor = Color(0xFF161611)

/** 41-watch-design-prompt.md §2.3 `onSurfaceVariant` — the muted "--" HR placeholder (§12.1 B13). */
private val MutedTextColor = Color(0xFFA8A899)

/** Re-requested by the "allow sensors" chip (§12.1 B13) — the same pair
 * [com.khunor.lifey.ExerciseService.startExercise] checks before adding
 * `HEART_RATE_BPM` to the exercise config. */
private val HEART_RATE_PERMISSIONS = arrayOf(
    Manifest.permission.BODY_SENSORS,
    "android.permission.health.READ_HEART_RATE",
)

private const val REST_RING_NEGATIVE_THRESHOLD_MS = 5_000L

/** Total on-screen time for the rest-end "GO" flash (§3.4: "1–2 s flash/transition"). */
private const val GO_FLASH_HOLD_MS = 1_300

/** The rest-hero progress ring's diameter as a fraction of the shorter screen dimension (§12.1 B4). */
private const val REST_RING_SIZE_FRACTION = 0.42f

/**
 * Live workout screen — elapsed time, heart rate, calories, current
 * exercise/set counter, rest-timer countdown (docs/40-watch-app-plan.md
 * §4.4/§5.1 "ActiveWorkoutView" equivalent; the haptic at rest-end is
 * scheduled independently in [com.khunor.lifey.ExerciseService], not here —
 * it needs to fire even while this screen isn't composed). The End button
 * only *asks* the phone to close the session (§8.2 decision (b)) — it never
 * touches [com.khunor.lifey.ExerciseService] directly. Pause/Resume (§12.1
 * B3) is the one control that *does* command [com.khunor.lifey.ExerciseService]
 * directly — it only affects the local sensor session, nothing the phone
 * needs to know about.
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

    val scrollState = rememberScrollState()

    BoxWithConstraints(modifier = Modifier.fillMaxSize()) {
        val isCompact = isCompactScreen(maxWidth)
        val heroStyle = if (isCompact) MaterialTheme.typography.display3 else MaterialTheme.typography.display2
        val captionStyle = if (isCompact) MaterialTheme.typography.caption2 else MaterialTheme.typography.caption1
        val ringSize = minOf(maxWidth, maxHeight) * REST_RING_SIZE_FRACTION

        // §12.1 B11: metrics on top, controls (Pause/Resume + End) scrolled
        // down below rather than crammed into one fixed screen. A plain
        // scrollable Column, not ScalingLazyColumn — that component's
        // default auto-centering is built for short chip-sized list items,
        // and centers `initialCenterItemIndex` (default 1, i.e. our *second*
        // item, the controls row) in the viewport on first composition. With
        // only two items and a tall first item (the metrics/rest-hero
        // block), that pushed the metrics' own top off-screen at launch,
        // with no gesture — a real bug, not just a cosmetic default (§12.1
        // bugfix). A plain Column always starts scrolled to offset 0, so the
        // metrics are visible top-first without requiring any scroll.
        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(scrollState)
                .padding(horizontal = maxWidth * SCREEN_PADDING_FRACTION),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            if (resting) {
                RestHero(
                    restRemainingMs = restRemainingMs,
                    restTotalSeconds = metadata.restTotalSeconds,
                    exerciseName = metadata.exerciseName
                        ?: stringResource(R.string.active_default_exercise),
                    setsDone = setsDone,
                    setsTotal = setsTotal,
                    isCompact = isCompact,
                    ringSize = ringSize,
                )
            } else {
                Text(text = formatElapsed(elapsedMs), style = heroStyle)
                Text(
                    text = metadata.exerciseName ?: stringResource(R.string.active_default_exercise),
                    style = if (isCompact) MaterialTheme.typography.caption1 else MaterialTheme.typography.body1,
                )
                if (setsDone != null && setsTotal != null) {
                    Text(
                        text = stringResource(R.string.active_sets_format, setsDone, setsTotal),
                        style = captionStyle,
                    )
                }
            }
            if (liveMetrics.isPaused) {
                Text(
                    text = stringResource(R.string.active_paused_indicator),
                    style = captionStyle,
                    color = RestRingNegativeColor,
                )
            }
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                if (liveMetrics.hasHeartRatePermission) {
                    liveMetrics.heartRateBpm?.let { bpm ->
                        Text(
                            text = "${bpm.roundToInt()} ${stringResource(R.string.active_heart_rate_unit)}",
                            style = captionStyle,
                        )
                    }
                } else {
                    // §12.1 B13: permission denied looks intentional (a
                    // muted placeholder), not like a missing/late reading —
                    // distinct from heartRateBpm == null above, which just
                    // means "no sample yet".
                    Text(
                        text = stringResource(R.string.active_heart_rate_denied_placeholder),
                        style = captionStyle,
                        color = MutedTextColor,
                    )
                }
                liveMetrics.activeCalories?.let { kcal ->
                    Text(
                        text = "${kcal.roundToInt()} ${stringResource(R.string.active_calories_unit)}",
                        style = captionStyle,
                    )
                }
            }
            if (!liveMetrics.hasHeartRatePermission) {
                val permissionLauncher = rememberLauncherForActivityResult(
                    ActivityResultContracts.RequestMultiplePermissions(),
                ) { /* no-op — ExerciseService re-checks live before the next start */ }
                CompactChip(
                    onClick = { permissionLauncher.launch(HEART_RATE_PERMISSIONS) },
                    label = {
                        Text(
                            text = stringResource(R.string.active_heart_rate_denied_chip),
                            style = captionStyle,
                        )
                    },
                )
            }
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Button(onClick = {
                    val paused = liveMetrics.isPaused
                    scope.launch {
                        if (paused) ExerciseService.resume(context) else ExerciseService.pause(context)
                    }
                }) {
                    Text(
                        stringResource(
                            if (liveMetrics.isPaused) R.string.active_resume_button else R.string.active_pause_button,
                        ),
                    )
                }
                Button(onClick = {
                    val sessionClientId = metadata.sessionClientId ?: return@Button
                    scope.launch { SummarySender.sendEndRequested(context, sessionClientId) }
                }) {
                    Text(stringResource(R.string.active_end_button))
                }
            }
        }
        PositionIndicator(
            scrollState = scrollState,
            modifier = Modifier.align(Alignment.CenterEnd),
        )
        if (showGoFlash) {
            GoFlash(modifier = Modifier.fillMaxSize())
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
        modifier = modifier.background(RestRingColor.copy(alpha = alpha.value)),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = stringResource(R.string.rest_go_label),
            style = MaterialTheme.typography.display1,
            color = OnPrimaryColor.copy(alpha = alpha.value),
        )
    }
}

/**
 * Rest-as-hero state (docs/40-watch-app-plan.md §12.1 B1 / 41-watch-design-
 * prompt.md §3.3): a drain-down progress ring takes the metrics page's hero
 * slot instead of the countdown being a small caption line, with a "of
 * <total>" target below it and a "Next · <exercise> — Set n of total" line
 * for what resumes once rest ends. Color shifts to [RestRingNegativeColor]
 * for the final 5 seconds, matching the haptic that fires at 0
 * ([com.khunor.lifey.ExerciseService]'s independently-scheduled vibration).
 * [ringSize] and the [isCompact] type-scale switch come from the caller's
 * `BoxWithConstraints` (§12.1 B4) — this composable has no size opinion of
 * its own.
 */
@Composable
private fun RestHero(
    restRemainingMs: Long,
    restTotalSeconds: Int?,
    exerciseName: String,
    setsDone: Int?,
    setsTotal: Int?,
    isCompact: Boolean,
    ringSize: Dp,
) {
    val ringColor = if (restRemainingMs <= REST_RING_NEGATIVE_THRESHOLD_MS) {
        RestRingNegativeColor
    } else {
        RestRingColor
    }
    val progress = restTotalSeconds
        ?.takeIf { it > 0 }
        ?.let { (restRemainingMs.toFloat() / (it * 1000)).coerceIn(0f, 1f) }
        ?: 1f
    val captionStyle = if (isCompact) MaterialTheme.typography.caption2 else MaterialTheme.typography.caption1
    val ringNumberStyle = if (isCompact) MaterialTheme.typography.title3 else MaterialTheme.typography.display3

    Text(
        text = stringResource(R.string.rest_hero_label),
        style = if (isCompact) MaterialTheme.typography.caption3 else MaterialTheme.typography.caption2,
    )
    Box(modifier = Modifier.size(ringSize), contentAlignment = Alignment.Center) {
        CircularProgressIndicator(
            progress = progress,
            modifier = Modifier.fillMaxSize(),
            indicatorColor = ringColor,
        )
        Text(text = formatElapsed(restRemainingMs), style = ringNumberStyle)
    }
    if (restTotalSeconds != null) {
        Text(
            text = stringResource(R.string.rest_hero_total_format, formatElapsed(restTotalSeconds * 1000L)),
            style = if (isCompact) MaterialTheme.typography.caption3 else MaterialTheme.typography.caption2,
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
        )
    } else {
        Text(
            text = stringResource(R.string.rest_hero_next_format, exerciseName),
            style = captionStyle,
        )
    }
}

private fun formatElapsed(totalMs: Long): String {
    val totalSeconds = totalMs / 1000
    val minutes = totalSeconds / 60
    val seconds = totalSeconds % 60
    return "%02d:%02d".format(minutes, seconds)
}
