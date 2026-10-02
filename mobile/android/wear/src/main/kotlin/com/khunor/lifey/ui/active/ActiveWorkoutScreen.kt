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
import androidx.wear.compose.material3.TimeText
import com.khunor.lifey.ui.components.GoFlash
import com.khunor.lifey.ui.components.LifeyAppScaffold
import com.khunor.lifey.ui.components.LifeyPager
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

internal const val REST_RING_NEGATIVE_THRESHOLD_MS = 5_000L

/** Total on-screen time for the rest-end "GO" flash (§3.4: "1–2 s flash/transition"). */
internal const val GO_FLASH_HOLD_MS = 1_150

internal const val LOG_PAGE = 0
internal const val METRICS_PAGE = 1
internal const val CONTROLS_PAGE = 2
internal const val PAGE_COUNT = 3

/** 300 ms tap-debounce for the log-set control (docs/watch/
 * 43-watch-f5-set-logging-plan.md §4.2) — belt-and-braces alongside
 * [LogSetState] itself disabling the control the instant it leaves
 * [LogSetState.Ready]; this just also swallows a double-tap landing in the
 * same frame, before that state change has propagated back to `.clickable`. */
internal const val LOG_SET_TAP_DEBOUNCE_MS = 300L

/** How many dp of accumulated rotary scroll count as one adjust-stepper
 * step. Wear's rotary input reports continuous pixel deltas, not discrete
 * detents — firing a step on every single [onRotaryScrollEvent] (the
 * previous approach) meant a physical rotation could produce a wildly
 * different number of steps depending on how many small events the OS
 * happened to batch it into, which read as "inconsistent" in practice.
 * Accumulating to a fixed dp threshold before firing exactly one step (and
 * carrying the remainder forward, not discarding it) makes one rotation
 * consistently equal one step regardless of event granularity. */
internal const val LOG_ADJUST_ROTARY_STEP_DP = 24f

/** Width of the adjust stepper's −/value/+ row, as a fraction of the screen
 * — deliberately wider than the [SCREEN_PADDING_FRACTION] inset the rest of
 * that column keeps (0.84), reaching ~60% of the way into it on both sides.
 * That row sits at the vertical center of the dial, where the round screen
 * is at its widest and the safety margin isn't earning anything — and since
 * the two buttons are fixed-size, every dp reclaimed goes to the number
 * between them. Mirrors iOS's `-padding * 0.6` on the same row. */
internal const val ADJUST_ROW_WIDTH_FRACTION = 0.936f

/** How long the standalone badge shows its "syncing" glyph after a tap —
 * see [HeaderChip]'s own comment for why this is a fixed duration rather
 * than real progress. Mirrors iOS's `adoptionRetryFeedbackSeconds`. */
internal const val ADOPTION_RETRY_FEEDBACK_MS = 1_500L

/** How long the just-logged set segment stays `success` (frame 04/03). */
internal const val JUST_LOGGED_SEGMENT_MS = 1_200L

/** Re-requested by the "allow sensors" chip (§12.1 B13) — the same pair
 * [com.khunor.lifey.ExerciseService.startExercise] checks before adding
 * `HEART_RATE_BPM` to the exercise config. */
internal val HEART_RATE_PERMISSIONS = arrayOf(
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
internal fun activeExerciseDisplay(metadata: SessionMetadata): ActiveExerciseDisplay {
    // The phone's live session plan when it has pushed one, the cached
    // template otherwise (F6c) — same list every other decision reads.
    val currentExercise = metadata.standaloneCurrentExercise
    if (currentExercise != null) {
        val setsForExercise = metadata.standaloneSetsForCurrentExercise
        // Both counts include what the phone logged into this same session —
        // see SessionMetadata.standaloneSetsDoneAt / phoneSetsTotal.
        val setsDone = metadata.standaloneSetsDoneAt(metadata.standaloneExerciseIndex)
        val phoneCountsThisExercise = if (metadata.phoneSetsExerciseId != null) {
            metadata.phoneSetsExerciseId == currentExercise.exerciseId
        } else {
            metadata.phoneSetsExerciseIndex == metadata.standaloneExerciseIndex
        }
        val targetSets =
            metadata.phoneSetsTotal.takeIf { phoneCountsThisExercise }
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

/**
 * Top-level dispatcher (docs/cardio/55-cardio-watch-plan.md §4, C5.6) — a
 * cardio session gets its own, much simpler screen ([CardioActiveScreen]):
 * no log-set/adjust/exercise-list overlays, none of which mean anything
 * without sets to log or a plan to pick from.
 */
@Composable
fun ActiveWorkoutScreen() {
    val metadata by SessionStateHolder.metadata.collectAsState()
    if (metadata.isCardio) {
        CardioActiveScreen()
    } else {
        StrengthActiveWorkoutScreen()
    }
}

/** Whole elapsed workout time, ticking once a second from the session's own `elapsedRealtime` start mark. */
@Composable
internal fun rememberElapsedMs(startedAtElapsedRealtimeMs: Long?): Long {
    var elapsedMs by remember { mutableLongStateOf(0L) }
    LaunchedEffect(startedAtElapsedRealtimeMs) {
        val startedAt = startedAtElapsedRealtimeMs ?: return@LaunchedEffect
        while (true) {
            elapsedMs = SystemClock.elapsedRealtime() - startedAt
            delay(1000)
        }
    }
    return elapsedMs
}

@Composable
internal fun StrengthActiveWorkoutScreen() {
    val metadata by SessionStateHolder.metadata.collectAsState()
    val liveMetrics by SessionStateHolder.liveMetrics.collectAsState()
    val logSetState by SessionStateHolder.logSetState.collectAsState()
    val logAdjustState by SessionStateHolder.logAdjustState.collectAsState()
    val context = LocalContext.current
    val scope = rememberCoroutineScope()

    val elapsedMs = rememberElapsedMs(liveMetrics.startedAtElapsedRealtimeMs)

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

    // Best-effort pre-tap hint, not a continuously-updated signal — Android has no reliable continuous
    // reachability push, unlike iOS's `WCSession.isReachable` (docs/watch/43-watch-f5-set-logging-plan.md
    // §4.4's Android branch). Checked once when the screen appears; a tap that turns out to be wrong anyway
    // surfaces via the normal ack-timeout → Failed path.
    var hasConnectedNode by remember { mutableStateOf(true) }
    LaunchedEffect(Unit) {
        hasConnectedNode = try {
            Wearable.getNodeClient(context).connectedNodes.await().isNotEmpty()
        } catch (_: Exception) {
            true
        }
    }

    // The segment of the set that was just logged turns `success` for 1.2 s (frame 04/03).
    var justLogged by remember { mutableStateOf(false) }
    LaunchedEffect(logSetState) {
        if (logSetState is LogSetState.Confirmed) {
            justLogged = true
            delay(JUST_LOGGED_SEGMENT_MS)
            justLogged = false
        }
    }

    val resting = restRemainingMs > 0
    // The secondary 'Gyakorlatok' EdgeButton on the paused controls page: only with two or more exercises.
    val offersExerciseList = liveMetrics.isPaused && metadata.canChooseExercise &&
        metadata.activePlanExercises.size - metadata.removedExerciseIndexes.size >= 2
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

    LifeyAppScaffold {
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
                                    exerciseId = metadata.currentExerciseId,
                                )
                            }
                        }
                    },
                )
            } else if (showExerciseList && metadata.canChooseExercise) {
                ExerciseListScreen(
                    // The phone's live session plan when it has pushed one, the
                    // cached template otherwise (F6c) — the same list every other
                    // "which exercise" decision reads, so what's on screen and
                    // what a tap logs into can't drift apart.
                    exercises = metadata.activePlanExercises,
                    currentExerciseId = metadata.currentExerciseId,
                    setsDonePerExercise = List(metadata.activePlanExercises.size) {
                        metadata.standaloneSetsDoneAt(it)
                    },
                    removedExerciseIndexes = metadata.removedExerciseIndexes,
                    title = metadata.standaloneTemplate?.title?.takeIf { it.isNotBlank() },
                    onSelect = { index ->
                        if (metadata.isStandalone) {
                            SessionStateHolder.onStandaloneExerciseSelected(index)
                        } else {
                            // Phone-mastered: the phone owns the decision, this
                            // only reports the pick (F6c §7).
                            val sessionId = metadata.sessionClientId
                            val exerciseId = SessionStateHolder.onPhoneExerciseSelected(index)
                            if (sessionId != null && exerciseId != null) {
                                scope.launch {
                                    SummarySender.sendExerciseSelected(context, sessionId, exerciseId)
                                }
                            }
                        }
                        showExerciseList = false
                    },
                    onBack = { showExerciseList = false },
                )
            } else {
                // D-X0.9: the crown no longer pages (it steps values and scrolls
                // lists); swipe is the only way between the three pages.
                LifeyPager(
                    state = pagerState,
                    modifier = Modifier.fillMaxSize(),
                    bottomSlotOccupied = (pagerState.currentPage == LOG_PAGE &&
                        (if (isStandalone && metadata.canChooseExercise) true else
                            logPillKind(logSetState, !isStandalone && !hasConnectedNode) != null)) ||
                        (pagerState.currentPage == CONTROLS_PAGE && offersExerciseList),
                ) { page ->
                    when (page) {
                        LOG_PAGE -> LogPage(
                            elapsedMs = elapsedMs,
                            display = display,
                            sessionClientId = metadata.sessionClientId,
                            currentExerciseId = metadata.currentExerciseId,
                            logSetState = logSetState,
                            isStandalone = isStandalone,
                            showsStandaloneBadge = showsStandaloneBadge,
                            isPaused = liveMetrics.isPaused,
                            hasConnectedNode = hasConnectedNode,
                            canChooseExercise = metadata.canChooseExercise,
                            onOpenExerciseList = { showExerciseList = true },
                        )
                        METRICS_PAGE -> MetricsOrRestPage(
                            resting = resting,
                            restRemainingMs = restRemainingMs,
                            restTotalSeconds = metadata.restTotalSeconds,
                            model = MetricsModel(
                                headerLabel = activeHeaderLabel,
                                elapsedMs = elapsedMs,
                                heartRate = heartRateState(liveMetrics),
                                kcal = liveMetrics.activeCalories?.roundToInt(),
                                exerciseName = display.name,
                                setsDone = display.setsDone,
                                setsTotal = display.setsTotal,
                                freeFormatSets = display.freeFormatSets,
                                isPaused = liveMetrics.isPaused,
                                showsStandaloneMark = showsStandaloneBadge,
                                justLoggedIndex = display.setsDone?.takeIf { justLogged && it > 0 }?.minus(1),
                            ),
                            canChooseExercise = metadata.canChooseExercise,
                            onOpenExerciseList = { showExerciseList = true },
                        )
                        CONTROLS_PAGE -> ControlsPage(
                            elapsedMs = elapsedMs,
                            isPaused = liveMetrics.isPaused,
                            showsStandaloneMark = showsStandaloneBadge,
                            offersExerciseList = offersExerciseList,
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
                TimeText()
                if (showGoFlash) {
                    GoFlash(modifier = Modifier.fillMaxSize())
                }
            }
        }
    }
}

/**
 * Weight display for the adjust stepper (docs/watch/48-watch-f5b-set-adjust-plan.md
 * §5): whole numbers stay whole ("60"), anything else gets a single decimal
 * ("62,5"), and the decimal separator follows the device locale. Kept in one
 * place rather than formatted inline at each call site.
 */
internal val weightFormat = DecimalFormat("0.#")

internal fun formatWeight(weight: Double): String = weightFormat.format(weight)

/** mm:ss — the **rest timer's** format, and only that: a cardio duration goes
 * through [formatCardioDuration] instead, which rolls over into hours (a
 * 90-minute walk reading "90:00" is exactly what that split avoids). */
internal fun formatElapsed(totalMs: Long): String {
    val totalSeconds = totalMs / 1000
    val minutes = totalSeconds / 60
    val seconds = totalSeconds % 60
    return "%02d:%02d".format(minutes, seconds)
}
