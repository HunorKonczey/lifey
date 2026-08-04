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
import androidx.compose.material.icons.automirrored.filled.List
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.FitnessCenter
import androidx.compose.material.icons.filled.HeartBroken
import androidx.compose.material.icons.filled.LocalFireDepartment
import androidx.compose.material.icons.filled.Pause
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Remove
import androidx.compose.material.icons.filled.SignalWifiOff
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
import com.khunor.lifey.ExerciseService
import com.khunor.lifey.LiveMetrics
import com.khunor.lifey.LogAdjustField
import com.khunor.lifey.LogAdjustState
import com.khunor.lifey.LogSetState
import com.khunor.lifey.R
import com.khunor.lifey.SessionMetadata
import com.khunor.lifey.SessionStateHolder
import com.khunor.lifey.StandaloneTemplate
import com.khunor.lifey.StandaloneTemplateExercise
import com.khunor.lifey.SummarySender
import com.khunor.lifey.ui.theme.LifeyColors
import com.khunor.lifey.ui.theme.LifeyShapes
import java.util.UUID
import kotlin.math.abs
import kotlin.math.roundToInt
import kotlin.math.sign
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

/** How many dp of accumulated rotary scroll count as one adjust-stepper
 * step. Wear's rotary input reports continuous pixel deltas, not discrete
 * detents — firing a step on every single [onRotaryScrollEvent] (the
 * previous approach) meant a physical rotation could produce a wildly
 * different number of steps depending on how many small events the OS
 * happened to batch it into, which read as "inconsistent" in practice.
 * Accumulating to a fixed dp threshold before firing exactly one step (and
 * carrying the remainder forward, not discarding it) makes one rotation
 * consistently equal one step regardless of event granularity. */
private const val LOG_ADJUST_ROTARY_STEP_DP = 24f

/** Width of the adjust stepper's −/value/+ row, as a fraction of the screen
 * — deliberately wider than the [SCREEN_PADDING_FRACTION] inset the rest of
 * that column keeps (0.84), reaching ~60% of the way into it on both sides.
 * That row sits at the vertical center of the dial, where the round screen
 * is at its widest and the safety margin isn't earning anything — and since
 * the two buttons are fixed-size, every dp reclaimed goes to the number
 * between them. Mirrors iOS's `-padding * 0.6` on the same row. */
private const val ADJUST_ROW_WIDTH_FRACTION = 0.936f

/** How long the standalone badge shows its "syncing" glyph after a tap —
 * see [HeaderChip]'s own comment for why this is a fixed duration rather
 * than real progress. Mirrors iOS's `adoptionRetryFeedbackSeconds`. */
private const val ADOPTION_RETRY_FEEDBACK_MS = 1_500L

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
 * Three swipeable pages, not one scrolling column: [LogPage] (leftmost —
 * docs/watch/43-watch-f5-set-logging-plan.md §3.1 decision (b)),
 * [MetricsOrRestPage] (metrics or the rest-hero — the pager's default, one
 * swipe/rotary-turn from the log page), and [ControlsPage] (End/Pause). An
 * earlier version put metrics and controls in a single
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
/**
 * See [ActiveExerciseDisplay]'s doc comment. Three branches, in priority
 * order: (1) a template exercise with a `targetSets` falls back to the
 * exact phone-mastered `setsDone`/`setsTotal` presentation (§3.4: "van
 * cél-szettszám!"); (2) a template exercise with none uses the free-format
 * count+reps line, scoped to that exercise's own sets; (3) Quick strength
 * (no template at all) keeps F6a's original all-sets free-format behavior
 * unchanged. Phone-mastered sessions fall through to the final branch,
 * which reproduces the pre-F6b computation exactly — a superset, not a
 * behavior change, for that path (docs/watch/
 * 49-watch-f6b-template-sync-plan.md §3.4). `@Composable` (not a plain
 * function on [SessionMetadata]) because it needs `stringResource`.
 */
@Composable
private fun activeExerciseDisplay(metadata: SessionMetadata): ActiveExerciseDisplay {
    val template = metadata.standaloneTemplate
    val currentExercise = template?.exercises?.getOrNull(metadata.standaloneExerciseIndex)
    if (currentExercise != null) {
        val setsForExercise = metadata.standaloneSets.filter { it.exerciseIndex == metadata.standaloneExerciseIndex }
        // Both counts include what the phone logged into this same session —
        // see SessionMetadata.standaloneSetsDoneAt / phoneSetsTotal.
        val setsDone = metadata.standaloneSetsDoneAt(metadata.standaloneExerciseIndex)
        val targetSets =
            metadata.phoneSetsTotal.takeIf { metadata.phoneSetsExerciseIndex == metadata.standaloneExerciseIndex }
                ?: currentExercise.targetSets
        return if (targetSets != null) {
            ActiveExerciseDisplay(
                name = currentExercise.name, setsDone = setsDone, setsTotal = targetSets,
                freeFormatSets = null,
            )
        } else {
            // No target to count towards: the set count still includes the
            // phone's, but the rep total can only sum the sets this watch
            // itself logged — it never receives the others' reps.
            ActiveExerciseDisplay(
                name = currentExercise.name, setsDone = null, setsTotal = null,
                freeFormatSets = setsDone to setsForExercise.sumOf { it.reps },
            )
        }
    }
    if (metadata.isStandalone) {
        return ActiveExerciseDisplay(
            name = stringResource(R.string.standalone_quick_start), setsDone = null, setsTotal = null,
            freeFormatSets = metadata.standaloneSets.size to metadata.standaloneSets.sumOf { it.reps },
        )
    }
    return ActiveExerciseDisplay(
        name = metadata.exerciseName ?: stringResource(R.string.active_default_exercise),
        setsDone = metadata.setsDone, setsTotal = metadata.setsTotal, freeFormatSets = null,
    )
}

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

    val resting = restRemainingMs > 0
    val isStandalone = metadata.isStandalone
    // Whether HeaderChip's "not connected" badge should show — a genuinely
    // disconnected standalone session, not one the phone has already joined
    // (live bridging). Once adopted, the phone IS tracking the session live,
    // so the icon implying otherwise would be actively misleading. Kept
    // separate from `isStandalone` itself, which still gates real logic
    // (e.g. LogPage's requiresPhone) that must stay true regardless of
    // adoption — set-logging stays watch-local always (D-F6's guarantee).
    val showsStandaloneBadge = isStandalone && !metadata.isAdopted
    // The metrics page's header label: the template/session name when one is
    // available (`standaloneTemplate.title` for a template-backed standalone
    // session, `title` for a phone-mastered one — never both at once, since
    // `title` is never set for standalone, D-F6.2), the generic
    // active_header_label ("STRENGTH"/"ERŐ") otherwise (Quick strength, or no
    // name at all). HeaderChip's own `maxLines = 1` + `TextOverflow.Ellipsis`
    // already truncates a too-long name with a trailing "…".
    val activeHeaderLabel = metadata.standaloneTemplate?.title?.takeIf { it.isNotBlank() }
        ?: metadata.title?.takeIf { it.isNotBlank() }
        ?: stringResource(R.string.active_header_label)
    // One computation for "current exercise + set progress", shared by every
    // page below instead of each re-deriving the same three-way branch
    // (docs/watch/49-watch-f6b-template-sync-plan.md §3.4).
    val display = activeExerciseDisplay(metadata)

    // Starts on METRICS_PAGE — the calorie/HR/exercise readout is what a
    // glance should land on; the log-set page is one swipe/rotary-turn away.
    val pagerState = rememberPagerState(initialPage = METRICS_PAGE, pageCount = { PAGE_COUNT })
    // Whether ExerciseListScreen is showing instead of the pager (docs/watch/
    // 49-watch-f6b-template-sync-plan.md §3.5, D-F6b.8) — opened from
    // the "Gyakorlatok" chip on either the log or the controls page, only
    // ever true during a template-backed standalone session.
    var showExerciseList by remember { mutableStateOf(false) }

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
            // the pager comes back exactly where it was.
            AdjustOverlay(
                state = logAdjustState!!,
                isCompact = isCompact,
                maxWidth = maxWidth,
                onConfirm = {
                    val adjust = logAdjustState!!
                    val currentSessionClientId = metadata.sessionClientId
                    SessionStateHolder.onLogAdjustCancelled()
                    if (isStandalone) {
                        // No phone to round-trip against — logs straight to
                        // the local set list, same as the plain tap.
                        SessionStateHolder.onStandaloneSetLogged(
                            reps = adjust.reps,
                            weight = adjust.weight,
                        )
                    } else if (currentSessionClientId != null) {
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
        } else if (showExerciseList && metadata.standaloneTemplate != null) {
            ExerciseListScreen(
                template = metadata.standaloneTemplate!!,
                currentExerciseIndex = metadata.standaloneExerciseIndex,
                setsDonePerExercise = List(metadata.standaloneTemplate!!.exercises.size) {
                    metadata.standaloneSetsDoneAt(it)
                },
                isCompact = isCompact,
                maxWidth = maxWidth,
                onSelect = { index ->
                    SessionStateHolder.onStandaloneExerciseSelected(index)
                    showExerciseList = false
                },
                onBack = { showExerciseList = false },
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
                        exerciseName = display.name,
                        setsDone = display.setsDone,
                        setsTotal = display.setsTotal,
                        sessionClientId = metadata.sessionClientId,
                        logSetState = logSetState,
                        isStandalone = isStandalone,
                        showsStandaloneBadge = showsStandaloneBadge,
                        freeFormatSets = display.freeFormatSets,
                        hasStandaloneTemplate = metadata.standaloneTemplate != null,
                        onOpenExerciseList = { showExerciseList = true },
                        isCompact = isCompact,
                        maxWidth = maxWidth,
                    )
                    METRICS_PAGE -> MetricsOrRestPage(
                        resting = resting,
                        elapsedMs = elapsedMs,
                        restRemainingMs = restRemainingMs,
                        restTotalSeconds = metadata.restTotalSeconds,
                        exerciseName = display.name,
                        setsDone = display.setsDone,
                        setsTotal = display.setsTotal,
                        liveMetrics = liveMetrics,
                        isStandalone = showsStandaloneBadge,
                        headerLabel = activeHeaderLabel,
                        freeFormatSets = display.freeFormatSets,
                        isCompact = isCompact,
                        maxWidth = maxWidth,
                    )
                    CONTROLS_PAGE -> ControlsPage(
                        exerciseName = display.name,
                        setsDone = display.setsDone,
                        setsTotal = display.setsTotal,
                        isPaused = liveMetrics.isPaused,
                        freeFormatSets = display.freeFormatSets,
                        hasStandaloneTemplate = metadata.standaloneTemplate != null,
                        isCompact = isCompact,
                        onEnd = { showEffortSelector = true },
                        onTogglePause = {
                            val paused = liveMetrics.isPaused
                            scope.launch {
                                if (paused) ExerciseService.resume(context) else ExerciseService.pause(context)
                            }
                        },
                        onOpenExerciseList = { showExerciseList = true },
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
 * The leftmost page (docs/watch/43-watch-f5-set-logging-plan.md
 * §3.1 decision (b), canvas W 07/08/10): two same-sized circular controls
 * side by side — "+1" on the left, the adjust stepper's launcher on the
 * right (replaces the original single big circle + long-press-to-adjust
 * design: the long press went undiscovered in practice, so a
 * plain-tap-reachable second button replaces it entirely — no more
 * `combinedClickable`). [logSetState] (docs/watch/43-watch-f5-set-logging-plan.md
 * §3.2) drives the "+1" circle's four visuals: Ready (primary ring +
 * context line), Pending (ghosted + "Logging…"), Confirmed (check + "Set n
 * of total" + "Logged" pill), Failed (ghosted + red toast) — plus a fifth,
 * independent ghosted state when [hasConnectedNode] is false: a tap can't
 * even start a Pending round-trip with no phone node to answer it. The
 * adjust button shares the same Ready-only enabled gate, since it starts
 * the same round trip once confirmed. Mirrors iOS's `LogPage`.
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
    /** Whether HeaderChip's "not connected" badge should show — distinct
     * from [isStandalone] itself, which this page also uses for real logic
     * ([requiresPhone]) that must stay true regardless of live-bridging
     * adoption. See the top-level `showsStandaloneBadge` computation. */
    showsStandaloneBadge: Boolean,
    freeFormatSets: Pair<Int, Int>?,
    /** Whether to offer the exercise-list chip under the status line — true
     * only during a template-backed standalone session, same gate
     * [ControlsPage] uses for its own copy of it. */
    hasStandaloneTemplate: Boolean,
    /** Opens the exercise list in place of the pager — the same callback
     * [ControlsPage] gets, so both entry points land on one screen and one
     * piece of state. */
    onOpenExerciseList: () -> Unit,
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
    // Standalone logging is local — there is no phone to reach, and gating on
    // node connectivity would disable the control in exactly the situation
    // F6a exists for (docs/watch/44-watch-f6-standalone-plan.md §11/8). Only
    // the phone-mastered path needs a connected node, since that one's tap is
    // a round-trip.
    val requiresPhone = !isStandalone
    val canTap = logSetState is LogSetState.Ready && (hasConnectedNode || !requiresPhone)

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
            isStandalone = showsStandaloneBadge,
            isCompact = isCompact,
        )
        val ghosted = logSetState is LogSetState.Pending ||
            logSetState is LogSetState.Failed ||
            (logSetState is LogSetState.Ready && requiresPhone && !hasConnectedNode)
        val buttonDiameter = maxWidth * LOG_BUTTON_PAIR_DIAMETER_FRACTION
        Row(
            horizontalArrangement = Arrangement.spacedBy(if (isCompact) 10.dp else 14.dp),
        ) {
            LogCircle(
                logSetState = logSetState,
                ghosted = ghosted,
                diameter = buttonDiameter,
                setsDone = setsDone,
                setsTotal = setsTotal,
                freeFormatSets = freeFormatSets,
                isCompact = isCompact,
                enabled = canTap,
                onTap = {
                    val now = SystemClock.elapsedRealtime()
                    if (now - lastTapAtMs < LOG_SET_TAP_DEBOUNCE_MS) return@LogCircle
                    lastTapAtMs = now
                    // Nothing known to log for this exercise — no planned
                    // values, no history, no earlier set this session (see
                    // [SessionStateHolder.hasLogSetPrefill]). A plain tap would
                    // record a set with nothing in it, so open the stepper on
                    // the defaults and let the user dial in the first values;
                    // every later tap for this exercise then has that set to
                    // carry forward.
                    if (!SessionStateHolder.hasLogSetPrefill) {
                        SessionStateHolder.onLogAdjustOpened()
                        return@LogCircle
                    }
                    if (isStandalone) {
                        // No phone to round-trip against — logs straight to
                        // the local set list (docs/watch/
                        // 44-watch-f6-standalone-plan.md §2.1, §3.2).
                        SessionStateHolder.onStandaloneSetLogged()
                        return@LogCircle
                    }
                    val currentSessionClientId = sessionClientId ?: return@LogCircle
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
            AdjustCircle(
                diameter = buttonDiameter,
                isCompact = isCompact,
                // The adjust stepper works the same way in standalone as
                // phone-mastered now — both log through LogCircle's own
                // isStandalone branch above.
                enabled = canTap,
                onTap = { SessionStateHolder.onLogAdjustOpened() },
            )
        }
        LogStatusLine(
            logSetState = logSetState,
            hasConnectedNode = hasConnectedNode,
            exerciseName = exerciseName,
            setsDone = setsDone,
            setsTotal = setsTotal,
            isStandalone = isStandalone,
            isCompact = isCompact,
        )
        // Directly under the "<exercise> · Set 2 of 2" line — that line is
        // where the user notices they've finished an exercise, so the way to
        // switch belongs next to it, not two swipes away on [ControlsPage].
        // The Column is centre-arranged, so the two circles above simply ride
        // up to make room; nothing here is pinned to the dial.
        if (hasStandaloneTemplate) {
            Box(modifier = Modifier.padding(top = if (isCompact) 6.dp else 8.dp)) {
                ExerciseListChip(onClick = onOpenExerciseList)
            }
        }
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
    onTap: () -> Unit,
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

    Box(
        modifier = Modifier
            .padding(top = if (isCompact) 8.dp else 12.dp)
            .size(diameter)
            .background(backgroundColor, CircleShape)
            .border(3.dp, borderColor, CircleShape)
            .clickable(enabled = enabled, onClick = onTap)
            .semantics { contentDescription = a11yLabel },
        contentAlignment = Alignment.Center,
    ) {
        if (logSetState is LogSetState.Confirmed) {
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Icon(
                    imageVector = Icons.Filled.Check,
                    contentDescription = null,
                    tint = LifeyColors.primary,
                    modifier = Modifier.size(if (isCompact) 24.dp else 28.dp),
                )
                if (freeFormatSets != null) {
                    Text(
                        text = stringResource(
                            R.string.active_sets_free_format, freeFormatSets.first, freeFormatSets.second,
                        ),
                        style = if (isCompact) MaterialTheme.typography.caption2 else MaterialTheme.typography.caption1,
                        color = LifeyColors.onSurface,
                        maxLines = 1,
                    )
                } else if (setsDone != null && setsTotal != null) {
                    Text(
                        text = stringResource(R.string.active_sets_format, setsDone, setsTotal),
                        style = if (isCompact) MaterialTheme.typography.caption2 else MaterialTheme.typography.caption1,
                        color = LifeyColors.onSurface,
                        maxLines = 1,
                    )
                }
            }
        } else {
            Text(
                text = stringResource(R.string.log_set_button),
                style = if (isCompact) MaterialTheme.typography.title3 else MaterialTheme.typography.title2,
                color = contentColor,
                textAlign = TextAlign.Center,
                maxLines = 2,
                modifier = Modifier.padding(horizontal = 4.dp),
            )
        }
    }
}

/** The right-hand button that opens the adjust stepper — same enabled/
 * ghosted split as [LogCircle]'s Ready/ghosted states, tinted `secondary`
 * (brown) to read as the side path, matching the adjust screen's own header
 * tint. Mirrors iOS's `adjustButtonContent`. */
@Composable
private fun AdjustCircle(
    diameter: Dp,
    isCompact: Boolean,
    enabled: Boolean,
    onTap: () -> Unit,
) {
    val contentColor = if (enabled) LifeyColors.secondary else LifeyColors.ghostedOnSurface
    val borderColor = if (enabled) LifeyColors.secondary.copy(alpha = 0.55f) else LifeyColors.outline
    val a11yLabel = stringResource(R.string.log_adjust_open_a11y)

    Box(
        modifier = Modifier
            .padding(top = if (isCompact) 8.dp else 12.dp)
            .size(diameter)
            .background(LifeyColors.container, CircleShape)
            .border(3.dp, borderColor, CircleShape)
            .clickable(enabled = enabled, onClick = onTap)
            .semantics { contentDescription = a11yLabel }
            .alpha(if (enabled) 1f else 0.75f),
        contentAlignment = Alignment.Center,
    ) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Icon(
                imageVector = Icons.Filled.Tune,
                contentDescription = null,
                tint = contentColor,
                modifier = Modifier.size(if (isCompact) 20.dp else 24.dp),
            )
            Text(
                text = stringResource(R.string.log_adjust_title),
                style = if (isCompact) MaterialTheme.typography.caption2 else MaterialTheme.typography.caption1,
                fontWeight = FontWeight.Bold,
                color = contentColor,
                maxLines = 1,
                modifier = Modifier.padding(top = 4.dp),
            )
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
        // Not shown in standalone: the header already carries the standalone
        // badge, and repeating "phone not reachable" there would read as an
        // error during a deliberately phone-less workout (§11/8).
        logSetState is LogSetState.Ready && !isStandalone && !hasConnectedNode -> LogStatusPill(
            icon = Icons.Filled.SignalWifiOff,
            text = stringResource(R.string.phone_unreachable),
            tint = LifeyColors.onSurfaceVariant,
            background = LifeyColors.container,
            isCompact = isCompact,
        )
        logSetState is LogSetState.Ready -> {
            // exerciseName/setsDone/setsTotal already come from
            // activeExerciseDisplay (docs/watch/49-watch-f6b-template-sync-plan.md
            // §3.4) — no separate isStandalone branch needed here any more:
            // Quick strength arrives with setsTotal == null (falls to the
            // plain-name case below, mirrors iOS's simplified `contextLine`),
            // a template exercise with a targetSets gets the same "next set
            // of total" preview a phone-mastered exercise would.
            val nextSet = if (setsDone != null && setsTotal != null) {
                (setsDone + 1).coerceAtMost(setsTotal)
            } else {
                null
            }
            val text = if (nextSet != null && setsTotal != null) {
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
 * §3.3) — reached by tapping the dedicated adjust button next to the log
 * control ([AdjustCircle]), never by the one-tap "+1" flow. Replaces the
 * pager while it's up (see [ActiveWorkoutScreen]), so the
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
    val stepThresholdPx = with(LocalDensity.current) { LOG_ADJUST_ROTARY_STEP_DP.dp.toPx() }
    var rotaryAccumulatorPx by remember { mutableFloatStateOf(0f) }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(horizontal = maxWidth * SCREEN_PADDING_FRACTION)
            // Accumulates raw scroll pixels and fires exactly one step per
            // LOG_ADJUST_ROTARY_STEP_DP crossed, carrying the remainder
            // forward — see that constant's doc comment for why a
            // one-step-per-raw-event mapping was inconsistent. SessionStateHolder
            // still owns the step size, bounds and clamping (D-F5b.5); this
            // only decides *how often* to call it. Positive scroll pixels
            // mean "scrolling down", which reads as decreasing here.
            .onRotaryScrollEvent { event ->
                rotaryAccumulatorPx += event.verticalScrollPixels
                while (abs(rotaryAccumulatorPx) >= stepThresholdPx) {
                    val step = if (rotaryAccumulatorPx > 0) -1 else 1
                    SessionStateHolder.onLogAdjustStepped(step)
                    rotaryAccumulatorPx -= stepThresholdPx * sign(rotaryAccumulatorPx)
                }
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
        // −  value  + (docs/watch/48-watch-f5b-set-adjust-plan.md §3.3
        // follow-up): the rotary alone left the stepper undiscoverable-by-
        // touch, so both buttons sit permanently either side of the number,
        // one step per tap through the same [SessionStateHolder.onLogAdjustStepped]
        // the rotary drives — so clamping, the idle-timer reset and the tick
        // haptic all come along unchanged. The number takes `weight(1f)`
        // rather than hugging the buttons, so the two tap targets stay put
        // instead of shifting as the value's digit count changes.
        Row(
            // `requiredWidth`, so this one row can overflow the screen
            // padding the rest of the column keeps — see
            // [ADJUST_ROW_WIDTH_FRACTION]. The enclosing Column centers it,
            // so the overflow is split evenly across both sides.
            modifier = Modifier
                .requiredWidth(maxWidth * ADJUST_ROW_WIDTH_FRACTION)
                .padding(top = 4.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            AdjustStepButton(
                icon = Icons.Filled.Remove,
                a11yLabel = stringResource(R.string.log_adjust_decrement_a11y),
                enabled = state.canDecrement,
                isCompact = isCompact,
                onClick = { SessionStateHolder.onLogAdjustStepped(-1) },
            )
            Text(
                text = when (state.field) {
                    LogAdjustField.REPS -> state.reps.toString()
                    LogAdjustField.WEIGHT -> formatWeight(state.weight)
                },
                // One step down from the pre-button display1/display2 pair —
                // the number no longer has the full width to itself, and at
                // the old size a 3-digit weight collided with the buttons on
                // the compact size class.
                style = if (isCompact) MaterialTheme.typography.display3 else MaterialTheme.typography.display2,
                color = LifeyColors.onSurface,
                textAlign = TextAlign.Center,
                maxLines = 1,
                modifier = Modifier.weight(1f),
            )
            AdjustStepButton(
                icon = Icons.Filled.Add,
                a11yLabel = stringResource(R.string.log_adjust_increment_a11y),
                enabled = state.canIncrement,
                isCompact = isCompact,
                onClick = { SessionStateHolder.onLogAdjustStepped(1) },
            )
        }
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

/** One of the stepper's two −/+ buttons. Sized above the 48 dp tap-target
 * minimum on the regular size class and as close to it as the compact dial
 * allows once the number between them keeps its own width; tinted
 * `secondary` (brown) like the rest of the adjust screen, and ghosted (not
 * hidden) once the active field sits at the end of its range, so the control
 * stays in place instead of the row reflowing at a bound. Mirrors iOS's
 * `AdjustPage.stepButton`. */
@Composable
private fun AdjustStepButton(
    icon: ImageVector,
    a11yLabel: String,
    enabled: Boolean,
    isCompact: Boolean,
    onClick: () -> Unit,
) {
    val tint = if (enabled) LifeyColors.secondary else LifeyColors.ghostedOnSurface
    val borderColor = if (enabled) LifeyColors.secondary.copy(alpha = 0.55f) else LifeyColors.outline

    Box(
        modifier = Modifier
            .size(if (isCompact) 44.dp else 52.dp)
            .alpha(if (enabled) 1f else 0.5f)
            .background(LifeyColors.container, CircleShape)
            .border(2.dp, borderColor, CircleShape)
            .clip(CircleShape)
            .clickable(enabled = enabled, onClick = onClick)
            .semantics { contentDescription = a11yLabel },
        contentAlignment = Alignment.Center,
    ) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            tint = tint,
            modifier = Modifier.size(if (isCompact) 20.dp else 24.dp),
        )
    }
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
    /** The template/session name in place of the generic "STRENGTH" label,
     * when one is available — see the top-level `activeHeaderLabel`
     * computation's doc comment. Only used on the non-resting branch below;
     * the rest-hero keeps its own "REST" label regardless. */
    headerLabel: String,
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
private fun ExerciseListChip(onClick: () -> Unit) {
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
private fun ExerciseListScreen(
    template: StandaloneTemplate,
    currentExerciseIndex: Int,
    /**
     * How many sets each exercise has, by plan index — resolved by the caller
     * through [SessionMetadata.standaloneSetsDoneAt], not counted from this
     * watch's own set list. A watch-started workout is logged into from the
     * phone too, and only the phone's row holds both halves: counting locally
     * showed a lower number here than the phone had, and a different one than
     * the active page, which already reconciles the two.
     */
    setsDonePerExercise: List<Int>,
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
            template.exercises.forEachIndexed { index, exercise ->
                item {
                    ExerciseListRow(
                        exercise = exercise,
                        isCompact = isCompact,
                        isCurrent = index == currentExerciseIndex,
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
private fun ExerciseListRow(
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
            // A template name can run long, unlike the fixed "STRENGTH"/"REST"
            // labels this chip otherwise shows — `weight(fill = false)` gives
            // Text a bounded width to truncate against (a bare `Row` child
            // would otherwise just overflow, since nothing constrains it),
            // while still leaving room for the trailing standalone icon and
            // not force-expanding for a short label.
            overflow = TextOverflow.Ellipsis,
            modifier = Modifier.weight(1f, fill = false),
        )
        if (isStandalone) {
            // Standalone mode indicator (docs/watch/44-watch-f6-standalone-
            // plan.md §3.4, canvas W 13) — a quiet glyph, no chip/background/
            // copy of its own ("mode, not alarm"), so every page's header
            // carries it consistently rather than singling out the
            // STRENGTH-label page alone (mirrors iOS's identical `HeaderChip`).
            //
            // It doubles as a "sync with my phone now" button: the state it
            // reports (this workout has no phone behind it) is exactly the one
            // the user wants to act on, so a separate control would be
            // busywork. Most useful when the phone app simply wasn't running
            // at start — one tap sends the whole snapshot, already-logged sets
            // included, and the phone opens the workout.
            val context = LocalContext.current
            val scope = rememberCoroutineScope()
            var isSyncing by remember { mutableStateOf(false) }
            val a11yLabel = stringResource(R.string.standalone_sync_retry_a11y)
            Icon(
                imageVector = if (isSyncing) Icons.Filled.Sync else Icons.Filled.PhonelinkOff,
                contentDescription = null,
                tint = LifeyColors.standaloneIndicator,
                modifier = Modifier
                    // `clickable` ahead of `padding`, so the padding counts
                    // as part of the tap target rather than sitting outside
                    // it — the glyph itself is only 14–16 dp, too small to
                    // hit reliably on a wrist.
                    .clickable(enabled = !isSyncing) {
                        scope.launch {
                            isSyncing = true
                            SummarySender.sendAdoptionRequestIfNeeded(context)
                            // The send itself usually returns in well under a
                            // frame, so hold the glyph long enough for the tap
                            // to have visibly done something. What a
                            // *successful* sync looks like is this badge
                            // disappearing (the phone's adoptionAck flips
                            // `isAdopted`), not this spinner.
                            delay(ADOPTION_RETRY_FEEDBACK_MS)
                            isSyncing = false
                        }
                    }
                    .semantics { contentDescription = a11yLabel }
                    .padding(vertical = 6.dp, horizontal = 4.dp)
                    .size(if (isCompact) 14.dp else 16.dp),
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
