package com.khunor.lifey.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.focusable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Remove
import androidx.compose.material3.Icon
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.input.rotary.onRotaryScrollEvent
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.wear.compose.material.Text
import androidx.wear.compose.material3.EdgeButton
import com.khunor.lifey.LifeyHaptics
import com.khunor.lifey.ui.theme.LifeyColors
import com.khunor.lifey.ui.theme.LifeySpacing
import com.khunor.lifey.ui.theme.LifeyType
import com.khunor.lifey.ui.theme.LocalWatchMetrics

/** One rotary detent ≈ this much scroll = one step (unchanged from the Material 2 stepper). */
const val ROTARY_STEP_DP = 24f

/**
 * Stepper (frame 04/08): ± circles (44 dp; 40 visible / 48 target on a 192 dp dial) with the value in PJS
 * between, a unit line under it, and an **EdgeButton** confirm on the bottom arc ("8 ismétlés naplózása",
 * [confirmLabel]). The rotary input steps one value per ≈ 24 dp with an `EFFECT_TICK`; a reached bound
 * ghosts its button. The number is 34 sp on the compact dial.
 */
@Composable
fun ValueStepper(
    value: Double,
    onValueChange: (Double) -> Unit,
    range: ClosedFloatingPointRange<Double>,
    step: Double,
    format: (Double) -> String,
    modifier: Modifier = Modifier,
    unit: String? = null,
    confirmLabel: String? = null,
    onConfirm: () -> Unit = {},
) {
    val metrics = LocalWatchMetrics.current
    val context = LocalContext.current
    val stepPx = with(LocalDensity.current) { ROTARY_STEP_DP.dp.toPx() }
    val focus = remember { FocusRequester() }
    val carry = remember { floatArrayOf(0f) }
    LaunchedEffect(Unit) { focus.requestFocus() }

    fun change(delta: Double) {
        val next = (value + delta).coerceIn(range)
        if (next != value) {
            onValueChange(next)
            LifeyHaptics.stepperTick(context)
        }
    }

    Column(
        modifier
            .fillMaxWidth()
            .onRotaryScrollEvent {
                carry[0] += it.verticalScrollPixels
                while (carry[0] >= stepPx) { carry[0] -= stepPx; change(step) }
                while (carry[0] <= -stepPx) { carry[0] += stepPx; change(-step) }
                true
            }
            .focusRequester(focus)
            .focusable(),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(LifeySpacing.md),
    ) {
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
            StepButton(Icons.Filled.Remove, ghosted = value <= range.start) { change(-step) }
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Text(
                    format(value),
                    style = LifeyType.metric().copy(fontSize = if (metrics.isCompact) LifeyType.metric().fontSize * 34f / 24f else LifeyType.metric().fontSize),
                    color = LifeyColors.text, maxLines = 1, textAlign = TextAlign.Center,
                )
                if (unit != null) Text(unit, style = LifeyType.label(), color = LifeyColors.text2)
            }
            StepButton(Icons.Filled.Add, ghosted = value >= range.endInclusive) { change(step) }
        }
        if (confirmLabel != null) {
            EdgeButton(onClick = onConfirm) { Text(confirmLabel, style = LifeyType.body(), color = LifeyColors.onPrimary, maxLines = 2) }
        }
    }
}

@Composable
private fun StepButton(icon: androidx.compose.ui.graphics.vector.ImageVector, ghosted: Boolean, onClick: () -> Unit) {
    val metrics = LocalWatchMetrics.current
    // 40 dp visible on the compact dial, 44 dp otherwise; the touch target is always ≥ 48 dp.
    val visible = if (metrics.isCompact) 40.dp else 44.dp
    Box(
        Modifier.size(metrics.minTouchTarget).clickable(enabled = !ghosted, onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {
        Box(
            Modifier.size(visible).background(if (ghosted) LifeyColors.card else LifeyColors.control, CircleShape),
            contentAlignment = Alignment.Center,
        ) {
            Icon(icon, contentDescription = null, tint = if (ghosted) LifeyColors.ghost else LifeyColors.text, modifier = Modifier.size(18.dp))
        }
    }
}
