package com.khunor.lifey.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.wear.compose.material.Text
import com.khunor.lifey.ui.components.LifeyEdgeButton
import androidx.wear.compose.material3.TimeText
import com.khunor.lifey.R
import com.khunor.lifey.ui.components.DismissibleOverlay
import com.khunor.lifey.ui.components.EffortScale
import com.khunor.lifey.ui.theme.LifeyColors
import com.khunor.lifey.ui.theme.LifeySpacing
import com.khunor.lifey.ui.theme.LifeyType
import com.khunor.lifey.ui.theme.LocalWatchMetrics

/**
 * Effort overlay shown right after the watch's End control, before anything is sent to the phone
 * (docs/40-watch-app-plan.md §8.2 decision (b) — the round trip that stops the sensors is unchanged, only
 * *where* the effort rating is collected moves here). [onSkip] closes the workout with no rating at all;
 * [onConfirm] with the chosen one; [onBack] — swipe-to-dismiss or the back key, which replace the invisible
 * corner arrow — returns to the workout without ending anything. Used by the strength and cardio screens.
 */
@Composable
fun EffortSelectorScreen(
    rpe: Int,
    onRpeChange: (Int) -> Unit,
    onConfirm: () -> Unit,
    onSkip: () -> Unit,
    onBack: () -> Unit,
) {
    DismissibleOverlay(onDismiss = onBack) {
        EffortContent(rpe = rpe, onRpeChange = onRpeChange, onConfirm = onConfirm, onSkip = onSkip)
    }
}

/**
 * Effort page (W1.16): "Milyen nehéz volt?", the white effort number with ± and a 10-segment bar (rotary steps
 * 1–10), a real 40 dp "Kihagyás" button, and "Edzés lezárása" as the primary EdgeButton on the bottom arc.
 */
@Composable
fun EffortContent(
    rpe: Int,
    onRpeChange: (Int) -> Unit,
    onConfirm: () -> Unit,
    onSkip: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val width = LocalWatchMetrics.current.widthDp
    Box(modifier.fillMaxSize()) {
        Column(
            Modifier.align(Alignment.TopCenter).padding(top = (width * 0.11f).dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(LifeySpacing.xs),
        ) {
            Text(
                stringResource(R.string.effort_selector_title), style = LifeyType.title(),
                color = LifeyColors.text, textAlign = TextAlign.Center, maxLines = 2,
            )
            EffortScale(
                value = rpe, onValueChange = onRpeChange,
                skipLabel = stringResource(R.string.effort_selector_skip), onSkip = onSkip,
            )
        }
        Box(Modifier.align(Alignment.BottomCenter)) {
            LifeyEdgeButton(onClick = onConfirm) {
                Text(
                    stringResource(R.string.effort_selector_confirm), style = LifeyType.body(),
                    color = LifeyColors.onPrimary, maxLines = 2, textAlign = TextAlign.Center,
                )
            }
        }
        TimeText()
    }
}
