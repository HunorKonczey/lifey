package com.khunor.lifey.ui.components

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.size
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.Info
import androidx.wear.compose.material3.Icon
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.wear.compose.material3.Text
import androidx.wear.compose.material3.AlertDialog
import androidx.wear.compose.material3.Button
import androidx.wear.compose.material3.ButtonDefaults
import com.khunor.lifey.R
import com.khunor.lifey.ui.theme.LifeyColors
import com.khunor.lifey.ui.theme.LifeyShapes
import com.khunor.lifey.ui.theme.LifeySpacing
import com.khunor.lifey.ui.theme.LifeyType
import com.khunor.lifey.ui.theme.LocalWatchMetrics

/** What the heart-rate slot shows. The *cause* of a missing reading is existing state; the slot only reads it. */
sealed interface HeartRateState {
    data class Live(val bpm: Int) : HeartRateState
    /** No sample yet / strap loose: ghost slot, tap explains. */
    object Missing : HeartRateState
    /** The body-sensors permission is missing: the slot itself is the way to grant it (W1.3, W2.14). */
    object PermissionDenied : HeartRateState
}

/**
 * Heart-rate slot (frame 04/02 + DS 06, D-X0.4): level two of every active screen, in a fixed place and
 * size. Live = heart icon + PJS number + "bpm". Missing = ghost heart + ghost "—" + `text3` "nincs pulzus"
 * + ⓘ; tap opens the explanation as an M3 [AlertDialog] (W2.16). Permission denied = an M3 [Button] (44 dp)
 * with two deliberate lines "Pulzusmérés ki" / "érzékelők engedélyezése"; tap = [onRequestPermission], the
 * existing system permission request.
 */
@Composable
fun HeartRateSlot(
    state: HeartRateState,
    modifier: Modifier = Modifier,
    onRequestPermission: () -> Unit = {},
) {
    val metrics = LocalWatchMetrics.current
    var explaining by remember { mutableStateOf(false) }
    // One frame for every state so the layout never jumps.
    val slot = modifier.defaultMinSize(minHeight = (metrics.metricSp * 1.25f).dp)

    when (state) {
        is HeartRateState.Live -> MetricReading(
            icon = Icons.Filled.Favorite, iconTint = LifeyColors.heart, number = state.bpm.toString(),
            unit = stringResource(R.string.active_heart_rate_unit), level = MetricLevel.Metric, modifier = slot,
        )
        HeartRateState.Missing -> Row(
            slot.clickable { explaining = true },
            horizontalArrangement = Arrangement.spacedBy(LifeySpacing.xs),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            GhostHeartDash()
            Text(stringResource(R.string.cardio_no_heart_rate_label), style = LifeyType.body(), color = LifeyColors.text3, maxLines = 1)
            Icon(Icons.Filled.Info, contentDescription = null, tint = LifeyColors.text3, modifier = Modifier.size(14.dp))
        }
        HeartRateState.PermissionDenied -> Button(
            onClick = onRequestPermission,
            modifier = slot.height(44.dp),
            colors = ButtonDefaults.filledTonalButtonColors(containerColor = LifeyColors.card, contentColor = LifeyColors.text),
        ) {
            Row(horizontalArrangement = Arrangement.spacedBy(LifeySpacing.xs), verticalAlignment = Alignment.CenterVertically) {
                GhostHeartDash()
                Column {
                    Text(stringResource(R.string.active_heart_rate_denied_title), style = LifeyType.label(), color = LifeyColors.text, maxLines = 1)
                    Text(stringResource(R.string.active_heart_rate_denied_action), style = LifeyType.label(), color = LifeyColors.text2, maxLines = 1)
                }
            }
        }
    }

    AlertDialog(
        visible = explaining,
        onDismissRequest = { explaining = false },
        title = { Text(stringResource(R.string.cardio_no_heart_rate_label), textAlign = TextAlign.Center) },
        text = { Text(stringResource(R.string.cardio_no_heart_rate_hint), textAlign = TextAlign.Center) },
        confirmButton = { /* the dialog's default confirm uses the existing "Rendben" key */ ExplanationOk { explaining = false } },
    )
}

@Composable
private fun GhostHeartDash() {
    Icon(Icons.Filled.Favorite, contentDescription = null, tint = LifeyColors.ghost, modifier = Modifier.size(16.dp))
    Text("—", style = LifeyType.metric(), color = LifeyColors.ghost)
}

@Composable
private fun ExplanationOk(onClick: () -> Unit) {
    Button(onClick = onClick, shape = LifeyShapes.pill) { Text(stringResource(R.string.error_ok_button)) }
}
