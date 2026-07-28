package com.khunor.lifey.ui

import android.Manifest
import android.os.SystemClock
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.FitnessCenter
import androidx.compose.material.icons.filled.HeartBroken
import androidx.compose.material.icons.filled.LocalFireDepartment
import androidx.compose.material.icons.filled.Pause
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.SignalWifiOff
import androidx.compose.material.icons.filled.Stop
import androidx.compose.material.icons.filled.Tune
import androidx.compose.material.icons.filled.Timer
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
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
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.material.icons.filled.PhonelinkOff
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.content.ContextCompat
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
import com.khunor.lifey.ExerciseService
import com.khunor.lifey.LiveMetrics
import com.khunor.lifey.LogAdjustField
import com.khunor.lifey.LogAdjustState
import com.khunor.lifey.LogSetState
import com.khunor.lifey.R
import com.khunor.lifey.SessionStateHolder
import com.khunor.lifey.SummarySender
import com.khunor.lifey.ui.theme.LifeyColors
import com.khunor.lifey.ui.theme.LifeyShapes
import java.util.UUID
import kotlin.math.roundToInt
import java.text.DecimalFormat
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.tasks.await

private const val REST_RING_NEGATIVE_THRESHOLD_MS = 5_000L

/** Total on-screen time for the rest-end "GO" flash (§3.4: "1–2 s flash/transition"). */
private const val GO_FLASH_HOLD_MS = 1_300

private const val LOG_PAGE = 0
private const val METRICS_PAGE = 1
private const val CONTROLS_PAGE = 2
private const val PAGE_COUNT = 3

/** 300 ms tap-debounce for the log-set control (docs/watch/
 * 43-watch-f5-set-logging-plan.md §4.2) — belt-and-braces alongside
 * [LogSetState] itself disabling the control the instant it leaves
 * [LogSetState.Ready]; this just also swallows a double-tap landing in the
 * same frame, before that state change has propagated back to `.clickable`. */
private const val LOG_SET_TAP_DEBOUNCE_MS = 300L

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
 * Three swipeable pages, not one scrolling column: [LogPage] (leftmost/
 * default — docs/watch/43-watch-f5-set-logging-plan.md §3.1 decision (b)),
 * [MetricsOrRestPage] (metrics or the rest-hero), and [ControlsPage]
 * (End/Pause). An earlier version put metrics and controls in a single
 * scrollable `Column`, but on a round display the End chip ended up peeking
 * in at the bottom of *every* metrics/rest view without any scroll gesture,
 * visibly clipped by the bezel — confusing and ugly on real hardware even
 * though it matched the canvas's own scroll-then-see-controls intent in
 * principle. A `HorizontalPager` (with a page-dot [PageDots]) gives the same
 * section-per-page structure the design canvas frames (Wear 07 log page,
 * Wear 02 metrics, Wear 03 controls) without that clipping, at the cost of a
 * swipe instead of a scroll to reach controls.
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
    val logSetState by SessionStateHolder.logSetState.collectAsState()
    val logAdjustState by SessionStateHolder.logAdjustState.collectAsState()
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
    val isStandalone = metadata.isStandalone
    // Standalone's own fallback (docs/watch/44-watch-f6-standalone-plan.md
    // §3.4/§3.5, mirrors iOS's `restExerciseName`) — F6a never sets
    // `exerciseName` for a standalone session (no plan), so every page
    // that would otherwise show `active_default_exercise` shows
    // `standalone_quick_start` instead.
    val exerciseName = metadata.exerciseName ?: stringResource(
        if (isStandalone) R.string.standalone_quick_start else R.string.active_default_exercise,
    )
    // No plan/total to report against in standalone (D-F6.3) — count +
    // combined reps instead of "n of total" (mirrors iOS's identical
    // `freeFormatSets` computation).
    val freeFormatSets = if (isStandalone) {
        metadata.standaloneSets.size to metadata.standaloneSets.sumOf { it.reps }
    } else {
        null
    }

    val pagerState = rememberPagerState(pageCount = { PAGE_COUNT })

    // Local, watch-only UI step (docs/40-watch-app-plan.md §8.2 decision (b)
    // still holds — nothing here talks to ExerciseService or the phone until
    // Confirm/Skip): intercepts the End press before
    // SummarySender.sendEndRequested is ever called, so the effort rating
    // (or a deliberate skip) is already final by the time the phone hears
    // about it.
    var showEffortSelector by remember { mutableStateOf(false) }
    var effortRpe by remember { mutableIntStateOf(5) }

    BoxWithConstraints(modifier = Modifier.fillMaxSize()) {
        val isCompact = isCompactScreen(maxWidth)

        if (showEffortSelector) {
            val sessionClientId = metadata.sessionClientId
            EffortSelectorScreen(
                rpe = effortRpe,
                onRpeChange = { effortRpe = it },
                onConfirm = {
                    // Standalone owns its own close (D-F6.2) — no phone-
                    // mastered session to ask, unlike the `sendEndRequested`
                    // branch below (docs/watch/44-watch-f6-standalone-plan.md
                    // §3.1, mirrors iOS's `beginEffortSelection` routing
                    // inside `WorkoutManager` itself).
                    if (isStandalone) {
                        ContextCompat.startForegroundService(
                            context,
                            ExerciseService.endStandaloneIntent(context, effortRpe),
                        )
                    } else if (sessionClientId != null) {
                        scope.launch { SummarySender.sendEndRequested(context, sessionClientId, effortRpe) }
                    }
                    showEffortSelector = false
                },
                onSkip = {
                    if (isStandalone) {
                        ContextCompat.startForegroundService(
                            context,
                            ExerciseService.endStandaloneIntent(context, rpe = null),
                        )
                    } else if (sessionClientId != null) {
                        scope.launch { SummarySender.sendEndRequested(context, sessionClientId, rpe = null) }
                    }
                    showEffortSelector = false
                },
                onBack = { showEffortSelector = false },
            )
        } else if (logAdjustState != null) {
            // The adjust stepper *replaces* the pager rather than layering
            // over it (docs/watch/48-watch-f5b-set-adjust-plan.md §3.1): both
            // want the rotary, and swapping means only one rotary binding
            // exists at a time — no focus fight. `pagerState` survives, so
            // the pager comes back on the log page exactly where it was.
            AdjustOverlay(
                state = logAdjustState!!,
                isCompact = isCompact,
                maxWidth = maxWidth,
                onConfirm = {
                    val adjust = logAdjustState!!
                    val currentSessionClientId = metadata.sessionClientId
                    SessionStateHolder.onLogAdjustCancelled()
                    if (currentSessionClientId != null) {
                        // Same send path as the plain tap — the pending/ack
                        // lifecycle, timeout and haptics are all F5a's code.
                        val eventId = UUID.randomUUID().toString()
                        SessionStateHolder.onLogSetRequested(eventId)
                        scope.launch {
                            SummarySender.sendLogSet(
                                context = context,
                                sessionClientId = currentSessionClientId,
                                eventId = eventId,
                                loggedAtEpochMs = System.currentTimeMillis(),
                                reps = adjust.reps,
                                weight = adjust.weight,
                            )
                        }
                    }
                },
            )
        } else {
            HorizontalPager(
                state = pagerState,
                modifier = Modifier.fillMaxSize(),
                // Lets the rotating bezel/crown page between metrics and
                // controls too, not just a swipe (mirrors the watchOS side's
                // `.digitalCrownRotation`).
                rotaryScrollableBehavior = RotaryScrollableDefaults.snapBehavior(pagerState),
            ) { page ->
                when (page) {
                    LOG_PAGE -> LogPage(
                        elapsedMs = elapsedMs,
                        exerciseName = exerciseName,
                        setsDone = setsDone,
                        setsTotal = setsTotal,
                        sessionClientId = metadata.sessionClientId,
                        logSetState = logSetState,
                        isStandalone = isStandalone,
                        freeFormatSets = freeFormatSets,
                        isCompact = isCompact,
                        maxWidth = maxWidth,
                    )
                    METRICS_PAGE -> MetricsOrRestPage(
                        resting = resting,
                        elapsedMs = elapsedMs,
                        restRemainingMs = restRemainingMs,
                        restTotalSeconds = metadata.restTotalSeconds,
                        exerciseName = exerciseName,
                        setsDone = setsDone,
                        setsTotal = setsTotal,
                        liveMetrics = liveMetrics,
                        isStandalone = isStandalone,
                        freeFormatSets = freeFormatSets,
                        isCompact = isCompact,
                        maxWidth = maxWidth,
                    )
                    CONTROLS_PAGE -> ControlsPage(
                        exerciseName = exerciseName,
                        setsDone = setsDone,
                        setsTotal = setsTotal,
                        isPaused = liveMetrics.isPaused,
                        freeFormatSets = freeFormatSets,
                        isCompact = isCompact,
                        onEnd = { showEffortSelector = true },
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

/**
 * The leftmost/default page (docs/watch/43-watch-f5-set-logging-plan.md
 * §3.1 decision (b), canvas W 07/08/10): a single large circular "+1 set"
 * control that fills nearly the whole safe area — a dedicated page turns
 * the entire tap target into one ~5×-minimum circle, with zero mis-tap risk
 * near End/Pause (that's why [MetricsOrRestPage] stays deliberately
 * button-free — same B4/B6 heritage as the metrics page's own layout).
 * [logSetState] (docs/watch/43-watch-f5-set-logging-plan.md §3.2) drives
 * four visuals: Ready (primary ring + context line), Pending (ghosted +
 * "Logging…"), Confirmed (check + "Set n of total" + "Logged" pill), Failed
 * (ghosted + red toast) — plus a fifth, independent ghosted state when
 * [hasConnectedNode] is false: a tap can't even start a Pending round-trip
 * with no phone node to answer it. Mirrors iOS's `LogPage`.
 */
@Composable
private fun LogPage(
    elapsedMs: Long,
    exerciseName: String,
    setsDone: Int?,
    setsTotal: Int?,
    sessionClientId: String?,
    logSetState: LogSetState,
    isStandalone: Boolean,
    freeFormatSets: Pair<Int, Int>?,
    isCompact: Boolean,
    maxWidth: Dp,
) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()

    // Best-effort pre-tap hint, not a continuously-updated signal — Android
    // has no reliable continuous reachability push, unlike iOS's
    // `WCSession.isReachable`/`reachabilityChanged` (docs/watch/
    // 43-watch-f5-set-logging-plan.md §4.4's Android branch). Checked once
    // when this page appears; a tap that turns out to be wrong anyway just
    // surfaces via the normal ack-timeout → Failed path, same as any other
    // send that doesn't land.
    var hasConnectedNode by remember { mutableStateOf(true) }
    LaunchedEffect(Unit) {
        hasConnectedNode = try {
            Wearable.getNodeClient(context).connectedNodes.await().isNotEmpty()
        } catch (_: Exception) {
            true
        }
    }

    var lastTapAtMs by remember { mutableLongStateOf(0L) }
    val canTap = logSetState is LogSetState.Ready && hasConnectedNode

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(horizontal = maxWidth * SCREEN_PADDING_FRACTION),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        HeaderChip(
            icon = Icons.Filled.FitnessCenter,
            label = formatElapsed(elapsedMs),
            isStandalone = isStandalone,
            isCompact = isCompact,
        )
        val ghosted = logSetState is LogSetState.Pending ||
            logSetState is LogSetState.Failed ||
            (logSetState is LogSetState.Ready && !hasConnectedNode)
        LogCircle(
            logSetState = logSetState,
            ghosted = ghosted,
            diameter = maxWidth * LOG_CIRCLE_DIAMETER_FRACTION,
            setsDone = setsDone,
            setsTotal = setsTotal,
            freeFormatSets = freeFormatSets,
            isCompact = isCompact,
            enabled = canTap,
            // The adjust stepper is a phone-mastered-only path in F5b —
            // standalone still logs a fixed reps count (D-F6.8), and binding
            // the stepper there is F6b's job (D-F5b.8).
            // `SessionStateHolder.onLogAdjustOpened()` guards this too;
            // mirrored here so the hint glyph isn't advertised when the long
            // press would do nothing.
            adjustEnabled = canTap && !isStandalone,
            onLongPress = { SessionStateHolder.onLogAdjustOpened() },
            onTap = {
                val currentSessionClientId = sessionClientId ?: return@LogCircle
                val now = SystemClock.elapsedRealtime()
                if (now - lastTapAtMs < LOG_SET_TAP_DEBOUNCE_MS) return@LogCircle
                lastTapAtMs = now
                val eventId = UUID.randomUUID().toString()
                SessionStateHolder.onLogSetRequested(eventId)
                scope.launch {
                    SummarySender.sendLogSet(
                        context = context,
                        sessionClientId = currentSessionClientId,
                        eventId = eventId,
                        loggedAtEpochMs = System.currentTimeMillis(),
                    )
                }
            },
        )
        LogStatusLine(
            logSetState = logSetState,
            hasConnectedNode = hasConnectedNode,
            exerciseName = exerciseName,
            setsDone = setsDone,
            setsTotal = setsTotal,
            isStandalone = isStandalone,
            isCompact = isCompact,
        )
    }
}

/** The circular control itself — ready/confirmed get the primary tint,
 * everything else (pending/failed/unreachable) shares one ghosted look
 * ([ghosted]), matching iOS's identical `ghostedCircle` collapsing of those
 * three states into one visual. */
@Composable
private fun LogCircle(
    logSetState: LogSetState,
    ghosted: Boolean,
    diameter: Dp,
    setsDone: Int?,
    setsTotal: Int?,
    freeFormatSets: Pair<Int, Int>?,
    isCompact: Boolean,
    enabled: Boolean,
    adjustEnabled: Boolean,
    onTap: () -> Unit,
    onLongPress: () -> Unit,
) {
    val backgroundColor = if (logSetState is LogSetState.Confirmed) {
        LifeyColors.primary.copy(alpha = 0.18f)
    } else if (ghosted) {
        LifeyColors.surface
    } else {
        LifeyColors.container
    }
    val borderColor = if (logSetState is LogSetState.Confirmed) {
        LifeyColors.primary
    } else if (ghosted) {
        LifeyColors.outline
    } else {
        LifeyColors.primary.copy(alpha = 0.55f)
    }
    val contentColor = if (ghosted) LifeyColors.ghostedOnSurface else LifeyColors.primary
    val a11yLabel = stringResource(R.string.log_set_button_a11y)
    val adjustA11yLabel = stringResource(R.string.log_adjust_open_a11y)

    Box(
        modifier = Modifier
            .padding(top = if (isCompact) 8.dp else 12.dp)
            .size(diameter)
            .background(backgroundColor, CircleShape)
            .border(3.dp, borderColor, CircleShape)
            // `combinedClickable` routes the long press to the adjust view
            // and the tap to the plain log — unlike a naive tap+long-press
            // pairing, it never fires both (docs/watch/
            // 48-watch-f5b-set-adjust-plan.md D-F5b.1's implementation trap).
            .combinedClickable(
                enabled = enabled,
                onClick = onTap,
                onLongClick = if (adjustEnabled) onLongPress else null,
                onLongClickLabel = adjustA11yLabel,
            )
            .semantics { contentDescription = a11yLabel },
        contentAlignment = Alignment.Center,
    ) {
        if (logSetState is LogSetState.Confirmed) {
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Icon(
                    imageVector = Icons.Filled.Check,
                    contentDescription = null,
                    tint = LifeyColors.primary,
                    modifier = Modifier.size(if (isCompact) 40.dp else 48.dp),
                )
                if (freeFormatSets != null) {
                    Text(
                        text = stringResource(
                            R.string.active_sets_free_format, freeFormatSets.first, freeFormatSets.second,
                        ),
                        style = if (isCompact) MaterialTheme.typography.body2 else MaterialTheme.typography.title3,
                        color = LifeyColors.onSurface,
                    )
                } else if (setsDone != null && setsTotal != null) {
                    Text(
                        text = stringResource(R.string.active_sets_format, setsDone, setsTotal),
                        style = if (isCompact) MaterialTheme.typography.body2 else MaterialTheme.typography.title3,
                        color = LifeyColors.onSurface,
                    )
                }
            }
        } else {
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Text(
                    text = stringResource(R.string.log_set_button),
                    style = if (isCompact) MaterialTheme.typography.title2 else MaterialTheme.typography.display3,
                    color = contentColor,
                    textAlign = TextAlign.Center,
                    maxLines = 2,
                )
                if (adjustEnabled) {
                    // The long-press affordance (D-F5b.1): a small,
                    // non-interactive hint in the same secondary brown the
                    // adjust view uses for its own header, so the two read as
                    // one side path. Costs no tap area — the whole circle
                    // stays the target.
                    Icon(
                        imageVector = Icons.Filled.Tune,
                        contentDescription = null,
                        tint = LifeyColors.secondary,
                        modifier = Modifier.padding(top = 4.dp).size(if (isCompact) 12.dp else 14.dp),
                    )
                }
            }
        }
    }
}

/** The line below the circle — context/status copy that changes with
 * [logSetState] (and, while Ready, with [hasConnectedNode]). Mirrors iOS's
 * `belowCircleContent`. */
@Composable
private fun LogStatusLine(
    logSetState: LogSetState,
    hasConnectedNode: Boolean,
    exerciseName: String,
    setsDone: Int?,
    setsTotal: Int?,
    isStandalone: Boolean,
    isCompact: Boolean,
) {
    val captionStyle = if (isCompact) MaterialTheme.typography.caption2 else MaterialTheme.typography.caption1
    when {
        logSetState is LogSetState.Ready && !hasConnectedNode -> LogStatusPill(
            icon = Icons.Filled.SignalWifiOff,
            text = stringResource(R.string.phone_unreachable),
            tint = LifeyColors.onSurfaceVariant,
            background = LifeyColors.container,
            isCompact = isCompact,
        )
        logSetState is LogSetState.Ready -> {
            val nextSet = if (setsDone != null && setsTotal != null) {
                (setsDone + 1).coerceAtMost(setsTotal)
            } else {
                null
            }
            val text = if (isStandalone) {
                // No plan, so no "next set of total" to preview — just
                // names the session (docs/watch/44-watch-f6-standalone-
                // plan.md §3.4, mirrors iOS's `contextLine`).
                stringResource(R.string.standalone_quick_start)
            } else if (nextSet != null && setsTotal != null) {
                stringResource(R.string.log_set_context_format, exerciseName, nextSet, setsTotal)
            } else {
                exerciseName
            }
            Text(
                text = text,
                style = captionStyle,
                color = LifeyColors.onSurfaceVariant,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                modifier = Modifier.padding(top = 8.dp),
            )
        }
        logSetState is LogSetState.Pending -> Text(
            text = stringResource(R.string.log_set_pending),
            style = captionStyle,
            color = LifeyColors.onSurfaceVariant,
            modifier = Modifier.padding(top = 8.dp),
        )
        logSetState is LogSetState.Confirmed -> LogStatusPill(
            icon = null,
            text = stringResource(R.string.log_set_logged),
            tint = LifeyColors.primary,
            background = LifeyColors.primary.copy(alpha = 0.14f),
            isCompact = isCompact,
        )
        logSetState is LogSetState.Failed -> LogStatusPill(
            icon = null,
            text = stringResource(R.string.log_set_failed),
            tint = LifeyColors.onErrorContainer,
            background = LifeyColors.errorContainer,
            isCompact = isCompact,
        )
    }
}

@Composable
private fun LogStatusPill(
    icon: ImageVector?,
    text: String,
    tint: Color,
    background: Color,
    isCompact: Boolean,
) {
    Row(
        modifier = Modifier
            .padding(top = 8.dp)
            .background(background, CircleShape)
            .padding(horizontal = 12.dp, vertical = 6.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        if (icon != null) {
            Icon(
                imageVector = icon,
                contentDescription = null,
                tint = tint,
                modifier = Modifier.size(if (isCompact) 13.dp else 15.dp),
            )
        }
        Text(
            text = text,
            style = if (isCompact) MaterialTheme.typography.caption2 else MaterialTheme.typography.caption1,
            color = tint,
            maxLines = 1,
        )
    }
}

/**
 * The adjust stepper (canvas W 09, docs/watch/48-watch-f5b-set-adjust-plan.md
 * §3.3) — reached by long-pressing the log control, never by the one-tap
 * flow. Replaces the pager while it's up (see [ActiveWorkoutScreen]), so the
 * rotary drives the value here instead of paging. Tinted
 * `LifeyColors.secondary` (brown) to mark it as the side path, and nothing is
 * logged until "Log {n} reps" is tapped (0.5).
 */
@Composable
private fun AdjustOverlay(
    state: LogAdjustState,
    isCompact: Boolean,
    maxWidth: Dp,
    onConfirm: () -> Unit,
) {
    val focusRequester = remember { FocusRequester() }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(horizontal = maxWidth * SCREEN_PADDING_FRACTION)
            // Only the rotation's *direction* is used — SessionStateHolder
            // owns the step size, bounds and clamping (D-F5b.5). Taken from
            // the sign rather than `toInt()`, which would round a sub-pixel
            // detent down to 0 and silently swallow slow rotations. One
            // event = one step, so a fast spin doesn't overshoot a 2.5 kg
            // grid by ten increments at once. Positive scroll pixels mean
            // "scrolling down", which reads as decreasing here.
            .onRotaryScrollEvent { event ->
                val steps = when {
                    event.verticalScrollPixels > 0f -> -1
                    event.verticalScrollPixels < 0f -> 1
                    else -> 0
                }
                if (steps != 0) SessionStateHolder.onLogAdjustStepped(steps)
                true
            }
            .focusRequester(focusRequester)
            .focusable(),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            Icon(
                imageVector = Icons.Filled.Tune,
                contentDescription = null,
                tint = LifeyColors.secondary,
                modifier = Modifier.size(if (isCompact) 14.dp else 16.dp),
            )
            Text(
                text = stringResource(R.string.log_adjust_title),
                style = if (isCompact) {
                    MaterialTheme.typography.caption3
                } else {
                    MaterialTheme.typography.caption2
                },
                color = LifeyColors.secondary,
                letterSpacing = 0.5.sp,
                maxLines = 1,
            )
        }
        Row(
            modifier = Modifier.padding(top = 6.dp),
            horizontalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            AdjustFieldSegment(
                label = stringResource(R.string.log_adjust_reps),
                isActive = state.field == LogAdjustField.REPS,
                isCompact = isCompact,
            )
            AdjustFieldSegment(
                label = stringResource(R.string.log_adjust_weight),
                isActive = state.field == LogAdjustField.WEIGHT,
                isCompact = isCompact,
            )
        }
        Text(
            text = when (state.field) {
                LogAdjustField.REPS -> state.reps.toString()
                LogAdjustField.WEIGHT -> formatWeight(state.weight)
            },
            style = if (isCompact) MaterialTheme.typography.display2 else MaterialTheme.typography.display1,
            color = LifeyColors.onSurface,
            maxLines = 1,
            modifier = Modifier.padding(top = 4.dp),
        )
        // The value *not* being edited, prefixed by the big number's own unit
        // — the design's "reps · 60 kg" (0.4). Two keys because the order
        // flips with the active field (§11/2).
        Text(
            text = when (state.field) {
                LogAdjustField.REPS ->
                    stringResource(R.string.log_adjust_caption_reps, formatWeight(state.weight))
                LogAdjustField.WEIGHT ->
                    stringResource(R.string.log_adjust_caption_weight, state.reps)
            },
            style = if (isCompact) MaterialTheme.typography.caption2 else MaterialTheme.typography.caption1,
            color = LifeyColors.onSurfaceVariant,
            maxLines = 1,
        )
        Chip(
            onClick = onConfirm,
            modifier = Modifier.fillMaxWidth().padding(top = 10.dp),
            label = {
                Text(
                    text = stringResource(R.string.log_adjust_confirm, state.reps),
                    color = LifeyColors.onPrimary,
                    maxLines = 1,
                )
            },
            colors = ChipDefaults.chipColors(
                backgroundColor = LifeyColors.primary,
                contentColor = LifeyColors.onPrimary,
            ),
        )
    }

    LaunchedEffect(Unit) { focusRequester.requestFocus() }
}

/** One of the Reps/Weight segments (0.2) — tapping either flips the active
 * field, so both share the same click handler. */
@Composable
private fun AdjustFieldSegment(label: String, isActive: Boolean, isCompact: Boolean) {
    Text(
        text = label,
        style = if (isCompact) MaterialTheme.typography.caption2 else MaterialTheme.typography.caption1,
        color = if (isActive) LifeyColors.onSurface else LifeyColors.onSurfaceVariant,
        maxLines = 1,
        modifier = Modifier
            .background(
                color = if (isActive) LifeyColors.containerHighest else Color.Transparent,
                shape = CircleShape,
            )
            .border(
                width = 1.dp,
                color = if (isActive) Color.Transparent else LifeyColors.outline,
                shape = CircleShape,
            )
            .clip(CircleShape)
            .clickable { SessionStateHolder.onLogAdjustFieldToggled() }
            .padding(horizontal = 12.dp, vertical = 6.dp),
    )
}

/** Page 2 of 3 (canvas Wear 02/04): metrics normally, or the rest-hero while
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
    isStandalone: Boolean,
    freeFormatSets: Pair<Int, Int>?,
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
        } else {
            HeaderChip(
                icon = Icons.Filled.FitnessCenter,
                label = stringResource(R.string.active_header_label),
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

/** Page 3 of 3 (canvas Wear 03): End + Pause only, with a dimmed reminder of
 * what's in progress (matching the canvas's faded, scaled-down exercise
 * card) so the page doesn't feel disconnected from the metrics page. */
@Composable
private fun ControlsPage(
    exerciseName: String,
    setsDone: Int?,
    setsTotal: Int?,
    isPaused: Boolean,
    freeFormatSets: Pair<Int, Int>?,
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
    isStandalone: Boolean,
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
        if (isStandalone) {
            // Standalone mode indicator (docs/watch/44-watch-f6-standalone-
            // plan.md §3.4, canvas W 13) — a quiet glyph, no chip/background/
            // copy of its own ("mode, not alarm"), so every page's header
            // carries it consistently rather than singling out the
            // STRENGTH-label page alone (mirrors iOS's identical `HeaderChip`).
            Icon(
                imageVector = Icons.Filled.PhonelinkOff,
                contentDescription = stringResource(R.string.standalone_badge),
                tint = LifeyColors.standaloneIndicator,
                modifier = Modifier.size(if (isCompact) 14.dp else 16.dp),
            )
        }
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
) {
    if (liveMetrics.hasHeartRatePermission) {
        liveMetrics.heartRateBpm?.let { bpm ->
            MetricReading(
                icon = Icons.Filled.Favorite,
                iconTint = LifeyColors.heart,
                value = bpm.roundToInt().toString(),
                iconSize = iconSize,
                valueStyle = valueStyle,
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
            iconSize = iconSize,
            valueStyle = valueStyle,
            valueColor = LifeyColors.onSurfaceVariant,
        )
    }
}

/** One icon + number metric reading (HR or kcal, canvas AW02/Wear02) — no
 * unit suffix next to the number; the icon itself already disambiguates HR
 * vs. kcal, and dropping the unit keeps the reading compact on a small
 * round display. [maxLines]/no-wrap on the value: a multi-digit number could
 * otherwise wrap mid-word onto its own second line. */
@Composable
private fun MetricReading(
    icon: ImageVector,
    iconTint: Color,
    value: String,
    iconSize: Dp,
    valueStyle: TextStyle,
    valueColor: Color = LifeyColors.onSurface,
) {
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
        Icon(imageVector = icon, contentDescription = null, tint = iconTint, modifier = Modifier.size(iconSize))
        Text(text = value, style = valueStyle, color = valueColor, maxLines = 1, softWrap = false)
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

/**
 * Weight display for the adjust stepper (docs/watch/48-watch-f5b-set-adjust-plan.md
 * §5): whole numbers stay whole ("60"), anything else gets a single decimal
 * ("62,5"), and the decimal separator follows the device locale. Kept in one
 * place rather than formatted inline at each call site.
 */
private val weightFormat = DecimalFormat("0.#")

private fun formatWeight(weight: Double): String = weightFormat.format(weight)

private fun formatElapsed(totalMs: Long): String {
    val totalSeconds = totalMs / 1000
    val minutes = totalSeconds / 60
    val seconds = totalSeconds % 60
    return "%02d:%02d".format(minutes, seconds)
}
