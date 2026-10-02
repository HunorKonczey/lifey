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
internal fun LogPage(
    elapsedMs: Long,
    exerciseName: String,
    setsDone: Int?,
    setsTotal: Int?,
    sessionClientId: String?,
    /** Which exercise a tap here should count against, when this watch has a
     * say in it (F6c §7) — null leaves the choice entirely to the phone, the
     * pre-F6c behaviour. */
    currentExerciseId: String?,
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
        LegacyHeaderChip(
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
                            exerciseId = currentExerciseId,
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
internal fun LogCircle(
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
internal fun AdjustCircle(
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
internal fun LogStatusLine(
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
internal fun LogStatusPill(
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
internal fun AdjustOverlay(
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
internal fun AdjustStepButton(
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
internal fun AdjustFieldSegment(label: String, isActive: Boolean, isCompact: Boolean) {
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
