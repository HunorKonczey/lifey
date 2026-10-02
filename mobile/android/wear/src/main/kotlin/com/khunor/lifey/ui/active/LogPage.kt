package com.khunor.lifey.ui.active
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.clickable
import androidx.compose.material.icons.filled.Timer
import androidx.compose.ui.unit.dp
import com.khunor.lifey.ui.components.CircleButton
import com.khunor.lifey.ui.components.CircleStyle
import com.khunor.lifey.ui.components.PillKind
import com.khunor.lifey.ui.components.StatusPill
import com.khunor.lifey.ui.theme.LifeySpacing
import com.khunor.lifey.ui.theme.LifeyType
import com.khunor.lifey.ui.theme.LocalWatchMetrics

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
 * What the log page shows (frames W1.5–W1.7), as plain data for the DEBUG gallery. [phoneUnreachable] is the
 * best-effort "no connected node" hint — never set for a standalone session, where logging is local.
 */
data class LogModel(
    val elapsedMs: Long,
    val exerciseName: String,
    val setsDone: Int?,
    val setsTotal: Int?,
    val freeFormatSets: Pair<Int, Int>?,
    val logState: LogSetState,
    val phoneUnreachable: Boolean = false,
    val isPaused: Boolean = false,
    val showsStandaloneMark: Boolean = false,
)

/** The one status pill of the log page (priority failed › unreachable › pending › logged), or none. */
fun logPillKind(state: LogSetState, phoneUnreachable: Boolean): PillKind? = when {
    state is LogSetState.Failed -> PillKind.Failed
    state is LogSetState.Ready && phoneUnreachable -> PillKind.Unreachable
    state is LogSetState.Pending -> PillKind.Pending
    state is LogSetState.Confirmed -> PillKind.Logged
    else -> null
}

/**
 * Log page (W1.5): `timer` header with the elapsed time, the "exercise · n/total szett" line, then the
 * primary "+1" circle and the `raised` "Módosítás" circle (clay icon) with their labels *under* them, and the
 * status pill on the bottom chord where the page indicator was. Pending and failed ghost the pair; a logged
 * set turns the +1 circle `success` with a check and "n/total" (W1.6).
 */
@Composable
fun LogContent(
    model: LogModel,
    onLogSet: () -> Unit,
    onAdjust: () -> Unit,
    onOpenExerciseList: (() -> Unit)?,
    modifier: Modifier = Modifier,
) {
    val width = LocalWatchMetrics.current.widthDp
    val state = model.logState
    val pill = logPillKind(state, model.phoneUnreachable)
    val ghostPair = state is LogSetState.Pending || state is LogSetState.Failed || pill == PillKind.Unreachable
    val confirmed = state is LogSetState.Confirmed
    val done = model.setsDone
    val total = model.setsTotal
    val counter = when {
        done != null && total != null -> "$done/$total"
        model.freeFormatSets != null -> model.freeFormatSets.first.toString()
        else -> null
    }
    // "Fekvenyomás · 3/4 szett": the set about to be logged, or — right after a tap — the one just logged.
    val contextLine = if (done != null && total != null) {
        val shown = if (confirmed) done else (done + 1).coerceAtMost(total)
        stringResource(R.string.log_set_context_format, model.exerciseName, shown, total)
    } else {
        model.exerciseName
    }
    Box(modifier.fillMaxSize()) {
        Column(
            Modifier.align(Alignment.TopCenter).padding(top = (width * 0.16f).dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(LifeySpacing.xs),
        ) {
            ActiveHeader(
                icon = Icons.Filled.Timer, label = formatElapsed(model.elapsedMs),
                isPaused = model.isPaused, showsStandaloneMark = model.showsStandaloneMark,
            )
            Text(
                contextLine, style = LifeyType.title(), color = LifeyColors.text, maxLines = 1,
                overflow = TextOverflow.Ellipsis, textAlign = TextAlign.Center,
                modifier = Modifier
                    .widthIn(max = (width * 0.76f).dp)
                    .let { if (onOpenExerciseList != null) it.clickable(onClick = onOpenExerciseList) else it },
            )
        }
        Row(
            Modifier.align(Alignment.Center).padding(top = (width * 0.07f).dp),
            horizontalArrangement = Arrangement.spacedBy(LifeySpacing.md),
        ) {
            CircleButton(
                style = if (confirmed) CircleStyle.SuccessTint else CircleStyle.Primary,
                icon = Icons.Filled.Check,
                label = stringResource(R.string.log_set_circle_label),
                onClick = onLogSet,
                isGhosted = ghostPair,
                centerText = if (confirmed) null else "+1",
                caption = if (confirmed) counter else null,
                a11y = stringResource(R.string.log_set_button_a11y),
            )
            CircleButton(
                style = CircleStyle.Raised,
                icon = Icons.Filled.Tune,
                label = stringResource(R.string.log_adjust_title),
                onClick = onAdjust,
                iconTint = LifeyColors.clay,
                isGhosted = ghostPair,
                a11y = stringResource(R.string.log_adjust_open_a11y),
            )
        }
        if (pill != null) {
            val pillText = stringResource(
                when (pill) {
                    PillKind.Failed -> R.string.log_set_failed
                    PillKind.Unreachable -> R.string.phone_unreachable
                    PillKind.Pending -> R.string.log_set_pending
                    else -> R.string.log_set_logged
                },
            )
            StatusPill(
                kind = pill,
                // The failure breaks deliberately after the dash ("Nem sikerült —" / "próbáld újra", W1.7).
                text = if (pill == PillKind.Failed) pillText.replace(" — ", " —\n") else pillText,
                modifier = Modifier.align(Alignment.BottomCenter).padding(bottom = (width * 0.08f).dp).widthIn(max = (width * 0.7f).dp),
            )
        }
    }
}

/**
 * The stateful log page: the best-effort reachability hint is owned by the caller ([hasConnectedNode],
 * checked once when the page appears — Android has no continuous reachability push), the tap logic is the
 * unchanged F5a/F6a one (docs/watch/43, 44): a set with nothing to prefill opens the stepper, standalone logs
 * locally, otherwise a pending round trip to the phone.
 */
@Composable
internal fun LogPage(
    elapsedMs: Long,
    display: ActiveExerciseDisplay,
    sessionClientId: String?,
    /** Which exercise a tap here should count against, when this watch has a say in it (F6c §7). */
    currentExerciseId: String?,
    logSetState: LogSetState,
    isStandalone: Boolean,
    showsStandaloneBadge: Boolean,
    isPaused: Boolean,
    hasConnectedNode: Boolean,
    canChooseExercise: Boolean,
    onOpenExerciseList: () -> Unit,
) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    // Standalone logging is local — gating on node connectivity would disable the control in exactly the
    // situation F6a exists for. Only the phone-mastered path is a round trip.
    val phoneUnreachable = !isStandalone && !hasConnectedNode
    val canTap = logSetState is LogSetState.Ready && !phoneUnreachable

    LogContent(
        model = LogModel(
            elapsedMs = elapsedMs, exerciseName = display.name,
            setsDone = display.setsDone, setsTotal = display.setsTotal, freeFormatSets = display.freeFormatSets,
            logState = logSetState, phoneUnreachable = phoneUnreachable,
            isPaused = isPaused, showsStandaloneMark = showsStandaloneBadge,
        ),
        onLogSet = {
            if (!canTap) return@LogContent
            // Nothing known to log for this exercise — no planned values, no history, no earlier set this
            // session (SessionStateHolder.hasLogSetPrefill): open the stepper on the defaults instead of
            // recording an empty set.
            if (!SessionStateHolder.hasLogSetPrefill) {
                SessionStateHolder.onLogAdjustOpened()
                return@LogContent
            }
            if (isStandalone) {
                SessionStateHolder.onStandaloneSetLogged()
                return@LogContent
            }
            val currentSessionClientId = sessionClientId ?: return@LogContent
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
        onAdjust = { if (canTap || logSetState is LogSetState.Confirmed) SessionStateHolder.onLogAdjustOpened() },
        onOpenExerciseList = if (canChooseExercise) onOpenExerciseList else null,
    )
}
