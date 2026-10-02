package com.khunor.lifey.ui.components

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CloudDone
import androidx.compose.material.icons.filled.CloudUpload
import androidx.compose.material3.Icon
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.animation.animateColorAsState
import androidx.wear.compose.material.Text
import com.khunor.lifey.ui.theme.LifeyColors
import com.khunor.lifey.ui.theme.LifeyMotion
import com.khunor.lifey.ui.theme.LifeyNumber
import com.khunor.lifey.ui.theme.LifeyShapes
import com.khunor.lifey.ui.theme.LifeySpacing
import com.khunor.lifey.ui.theme.LifeyType
import com.khunor.lifey.ui.theme.rememberReducedMotion

/**
 * Summary tile (frame 04/12): a PJS `metric` number with a one-line `text2` label ("átlag bpm"), centred on
 * the round screen. The number counts up over 600 ms when it appears (summary tiles only — ticking numbers
 * never animate).
 */
@Composable
fun SummaryTile(
    number: Double,
    format: (Double) -> String,
    label: String,
    modifier: Modifier = Modifier,
    tint: Color = LifeyColors.text,
) {
    val reduced = rememberReducedMotion()
    val shown = remember { Animatable(if (reduced) number.toFloat() else 0f) }
    LaunchedEffect(number) { shown.animateTo(number.toFloat(), tween(LifeyMotion.duration(LifeyMotion.COUNT_UP, reduced), easing = LifeyMotion.Standard)) }
    Column(
        modifier.fillMaxWidth().background(LifeyColors.nested, LifeyShapes.card).padding(LifeySpacing.md),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        LifeyNumber(format(shown.value.toDouble()), style = LifeyType.metric(), color = tint)
        Text(label, style = LifeyType.label(), color = LifeyColors.text2, maxLines = 1, textAlign = TextAlign.Center)
    }
}

/**
 * Sync row (frame 04/12) under the standalone summary's title, centred: pending (`nested`, upload glyph,
 * title and a "n edzés vár szinkronizálásra" second line) or synced (success tint). The tint switches in
 * 250 ms.
 */
@Composable
fun SyncRow(isSynced: Boolean, title: String, modifier: Modifier = Modifier, subtitle: String? = null) {
    val reduced = rememberReducedMotion()
    val bg by animateColorAsState(
        if (isSynced) LifeyColors.tint(LifeyColors.success) else LifeyColors.nested,
        tween(LifeyMotion.duration(LifeyMotion.TINT_SWITCH, reduced)), label = "sync-tint",
    )
    val content = if (isSynced) LifeyColors.success else LifeyColors.text
    Row(
        modifier.fillMaxWidth().background(bg, LifeyShapes.card).padding(horizontal = LifeySpacing.lg, vertical = LifeySpacing.md),
        horizontalArrangement = Arrangement.spacedBy(LifeySpacing.md, Alignment.CenterHorizontally),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(if (isSynced) Icons.Filled.CloudDone else Icons.Filled.CloudUpload, contentDescription = null, tint = content, modifier = Modifier.size(18.dp))
        Column {
            Text(title, style = LifeyType.body(), color = content, maxLines = 2)
            if (subtitle != null && !isSynced) Text(subtitle, style = LifeyType.label(), color = LifeyColors.text2, maxLines = 2)
        }
    }
}
