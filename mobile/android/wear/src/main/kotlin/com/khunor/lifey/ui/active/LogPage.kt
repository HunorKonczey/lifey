package com.khunor.lifey.ui.active
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Spacer
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.material.icons.filled.Timer
import androidx.compose.ui.unit.dp
import com.khunor.lifey.ui.components.CircleButton
import com.khunor.lifey.ui.components.LifeyEdgeButton
import androidx.compose.foundation.layout.width
import androidx.compose.material.icons.automirrored.filled.List
import com.khunor.lifey.ui.components.CircleStyle
import com.khunor.lifey.ui.components.PillKind
import com.khunor.lifey.ui.components.StatusPill
import com.khunor.lifey.ui.theme.LifeySpacing
import com.khunor.lifey.ui.theme.LifeyType
import com.khunor.lifey.ui.theme.LocalWatchMetrics

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Tune
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.wear.compose.material.Icon
import androidx.wear.compose.material.Text
import com.khunor.lifey.ActiveExerciseDisplay
import com.khunor.lifey.LogSetState
import com.khunor.lifey.R
import com.khunor.lifey.SessionStateHolder
import com.khunor.lifey.SummarySender
import com.khunor.lifey.ui.theme.LifeyColors
import java.util.UUID
import kotlin.math.abs
import kotlinx.coroutines.launch


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
    /** Standalone with a plan: the secondary "Gyakorlatok" EdgeButton sits on the bottom arc (W2.7). */
    val offersExerciseList: Boolean = false,
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
    val metrics = LocalWatchMetrics.current
    // Standalone logs locally: the circle's own check + n/total says "logged", and the arc belongs to the list button.
    val pill = if (model.offersExerciseList) null else logPillKind(state, model.phoneUnreachable)
    val diameter = if (model.offersExerciseList) metrics.circleButtonWithEdgeButton else metrics.circleButton
    // Four rows plus two labelled circles do not fit above a 46 dp arc button on the compact dial: no labels there.
    val labelsFit = !(model.offersExerciseList && metrics.isCompact)
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
    // Top-down stack (the canvas lays it out the same way): header, context line, circles, then the pill on
    // the bottom chord — a flexible gap in between, so nothing can overlap on either dial size.
    Box(Modifier.fillMaxSize()) {
        Column(
            modifier.fillMaxSize().padding(top = (width * 0.125f).dp, bottom = (width * 0.085f).dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            ActiveHeader(
                icon = Icons.Filled.Timer, label = formatElapsed(model.elapsedMs),
                isPaused = model.isPaused, showsStandaloneMark = model.showsStandaloneMark,
            )
            Text(
                // "Fekvenyomás" in `text`, " · 3/4 szett" in `text2`.
                text = buildAnnotatedString {
                    append(contextLine)
                    if (done != null && total != null) {
                        addStyle(SpanStyle(color = LifeyColors.text2), model.exerciseName.length.coerceAtMost(contextLine.length), contextLine.length)
                    }
                },
                style = LifeyType.body().copy(fontWeight = FontWeight.SemiBold), color = LifeyColors.text, maxLines = 1,
                overflow = TextOverflow.Ellipsis, textAlign = TextAlign.Center,
                modifier = Modifier
                    .padding(top = LifeySpacing.xs)
                    .widthIn(max = (width * 0.76f).dp)
                    .let { if (onOpenExerciseList != null) it.clickable(onClick = onOpenExerciseList) else it },
            )
            Row(Modifier.padding(top = if (LocalWatchMetrics.current.isCompact) LifeySpacing.xs else LifeySpacing.md), horizontalArrangement = Arrangement.spacedBy(LifeySpacing.md)) {
                CircleButton(
                    style = if (confirmed) CircleStyle.SuccessTint else CircleStyle.Primary,
                    icon = Icons.Filled.Check,
                    label = stringResource(R.string.log_set_circle_label),
                    onClick = onLogSet,
                    isGhosted = ghostPair,
                    centerText = if (confirmed) null else "+1",
                    caption = if (confirmed) counter else null,
                    a11y = stringResource(R.string.log_set_button_a11y),
                    showLabel = !ghostPair && labelsFit,
                    diameter = diameter,
                )
                CircleButton(
                    style = CircleStyle.Raised,
                    icon = Icons.Filled.Tune,
                    label = stringResource(R.string.log_adjust_title),
                    onClick = onAdjust,
                    iconTint = LifeyColors.clay,
                    isGhosted = ghostPair,
                    a11y = stringResource(R.string.log_adjust_open_a11y),
                    showLabel = !ghostPair && labelsFit,
                    diameter = diameter,
                )
            }
            Spacer(Modifier.weight(1f))
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
                    // Failure and "no phone" break deliberately on the round bottom chord (W1.7): after the dash,
                    // or at the space nearest the middle.
                    text = when (pill) {
                        PillKind.Failed -> pillText.replace(" — ", " —\n")
                        PillKind.Unreachable -> balancedBreak(pillText)
                        else -> pillText
                    },
                    modifier = Modifier.widthIn(max = (width * 0.62f).dp),
                )
            }
        }
        if (model.offersExerciseList && onOpenExerciseList != null) {
            Box(Modifier.align(Alignment.BottomCenter)) {
                LifeyEdgeButton(onClick = onOpenExerciseList, secondary = true) {
                    Icon(Icons.AutoMirrored.Filled.List, contentDescription = null, tint = LifeyColors.text, modifier = Modifier.size(18.dp))
                    Spacer(Modifier.width(LifeySpacing.sm))
                    Text(stringResource(R.string.standalone_exercise_list_title), style = LifeyType.body(), color = LifeyColors.text, maxLines = 1)
                }
            }
        }
    }
}

/** [text] with its space nearest the middle turned into a line break (a one-word text is left alone). */
internal fun balancedBreak(text: String): String {
    val spaces = text.indices.filter { text[it] == ' ' }
    if (spaces.isEmpty()) return text
    val at = spaces.minByOrNull { kotlin.math.abs(it - text.length / 2) } ?: return text
    return text.substring(0, at) + "\n" + text.substring(at + 1)
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
            offersExerciseList = isStandalone && canChooseExercise,
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
