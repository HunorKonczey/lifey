package com.khunor.lifey.ui.active

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Tune
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.wear.compose.material.Text
import com.khunor.lifey.ui.components.LifeyEdgeButton
import com.khunor.lifey.LogAdjustField
import com.khunor.lifey.LogAdjustState
import com.khunor.lifey.R
import com.khunor.lifey.SessionStateHolder
import com.khunor.lifey.ui.components.DismissibleOverlay
import com.khunor.lifey.ui.components.HeaderChip
import com.khunor.lifey.ui.components.ValueStepper
import com.khunor.lifey.ui.theme.LifeyColors
import com.khunor.lifey.ui.theme.LifeySpacing
import com.khunor.lifey.ui.theme.LifeyType
import com.khunor.lifey.ui.theme.LocalWatchMetrics

/**
 * Stepper steps and bounds, mirrored from `SessionStateHolder` (D-F5b.5): the holder still owns the real
 * step, clamping and the idle-timer reset — this only sizes the [ValueStepper]'s range so a reached bound
 * ghosts its button, and decides the direction of each change.
 */
private const val ADJUST_REPS_MIN = 1.0
private const val ADJUST_REPS_MAX = 99.0
private const val ADJUST_WEIGHT_MIN = 0.0
private const val ADJUST_WEIGHT_MAX = 500.0
private const val ADJUST_WEIGHT_STEP = 2.5

/**
 * The adjust stepper (W1.8 / W1.9): a clay header, a short centred "Ismétlés | Súly" segment, the ± row with
 * the value in PJS (rotary ≈ 24 dp = one step, the tick haptic comes from the service), the value *not* being
 * edited in a caption, and the **EdgeButton** "n ismétlés naplózása" on the bottom arc — the dense full-width
 * chip it replaces is why nothing overhangs the comfortable zone any more.
 */
@Composable
fun AdjustContent(
    state: LogAdjustState,
    onToggleField: () -> Unit,
    onStep: (Int) -> Unit,
    onConfirm: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val width = LocalWatchMetrics.current.widthDp
    val reps = state.field == LogAdjustField.REPS
    Box(modifier.fillMaxSize()) {
        Column(
            Modifier.align(Alignment.TopCenter).padding(top = (width * 0.13f).dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(LifeySpacing.sm),
        ) {
            HeaderChip(Icons.Filled.Tune, stringResource(R.string.log_adjust_title), accent = LifeyColors.clay)
            FieldSegment(reps = reps, onToggle = onToggleField)
            ValueStepper(
                value = if (reps) state.reps.toDouble() else state.weight,
                onValueChange = { next -> onStep(if (next > (if (reps) state.reps.toDouble() else state.weight)) 1 else -1) },
                range = if (reps) ADJUST_REPS_MIN..ADJUST_REPS_MAX else ADJUST_WEIGHT_MIN..ADJUST_WEIGHT_MAX,
                step = if (reps) 1.0 else ADJUST_WEIGHT_STEP,
                format = { if (reps) it.toInt().toString() else formatWeight(it) },
                unit = if (reps) {
                    stringResource(R.string.log_adjust_caption_reps, formatWeight(state.weight))
                } else {
                    stringResource(R.string.log_adjust_caption_weight, state.reps)
                },
                tickOnStep = false,
            )
        }
        Box(Modifier.align(Alignment.BottomCenter)) {
            LifeyEdgeButton(onClick = onConfirm) {
                Text(stringResource(R.string.log_adjust_confirm, state.reps), style = LifeyType.body(), color = LifeyColors.onPrimary, maxLines = 2)
            }
        }
    }
}

/** "Ismétlés | Súly": short, centred, the active segment `raised`; a tap anywhere flips the field. */
@Composable
private fun FieldSegment(reps: Boolean, onToggle: () -> Unit) {
    Row(
        Modifier.background(LifeyColors.nested, CircleShape).padding(3.dp).clickable(onClick = onToggle),
        horizontalArrangement = Arrangement.spacedBy(LifeySpacing.xxs),
    ) {
        Segment(stringResource(R.string.log_adjust_reps), active = reps)
        Segment(stringResource(R.string.log_adjust_weight), active = !reps)
    }
}

@Composable
private fun Segment(label: String, active: Boolean) {
    Text(
        label, style = LifeyType.label(), maxLines = 1,
        color = if (active) LifeyColors.text else LifeyColors.text2,
        modifier = Modifier
            .background(if (active) LifeyColors.raised else androidx.compose.ui.graphics.Color.Transparent, CircleShape)
            .padding(horizontal = LifeySpacing.lg, vertical = LifeySpacing.sm),
    )
}

/**
 * The stateful overlay: replaces the pager while the stepper is open (docs/watch/48 §3.1 — one rotary binding
 * at a time) and closes on swipe or the back key without logging ([SessionStateHolder.onLogAdjustCancelled],
 * the same cancel the idle timeout uses); it never finishes the activity. [onConfirm] is the unchanged
 * confirm-and-log path owned by the strength screen.
 */
@Composable
internal fun AdjustOverlay(state: LogAdjustState, onConfirm: () -> Unit) {
    DismissibleOverlay(onDismiss = { SessionStateHolder.onLogAdjustCancelled() }) {
        AdjustContent(
            state = state,
            onToggleField = { SessionStateHolder.onLogAdjustFieldToggled() },
            onStep = { SessionStateHolder.onLogAdjustStepped(it) },
            onConfirm = onConfirm,
        )
    }
}
