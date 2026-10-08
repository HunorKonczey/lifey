package com.khunor.lifey.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Pause
import androidx.compose.material.icons.filled.PhonelinkOff
import androidx.compose.material.icons.filled.Sync
import androidx.wear.compose.material3.Icon
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.layout.layout
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.wear.compose.material3.Text
import com.khunor.lifey.R
import com.khunor.lifey.ui.theme.LifeyColors
import com.khunor.lifey.ui.theme.LifeySpacing
import com.khunor.lifey.ui.theme.LifeyType
import com.khunor.lifey.ui.theme.LocalWatchMetrics

private const val MARK_VISUAL_SIZE = 24

/** State of the standalone mark in [HeaderChip] (24 dp visible, 48 dp touch target — W2.5). */
enum class StandaloneMark { Idle, Tapped }

/**
 * Header chip (frame 04/01): icon + CAPS label in `text2` (cardio: the activity [accent]). When [isPaused]
 * the whole chip turns clay and reads "SZÜNETELTETVE". The optional standalone mark is a 24 dp `control`
 * circle with a 48 dp hit area; tapped = `raised` with a sync glyph. A template name longer than 14
 * characters is cut with an ellipsis in the header (W2.6) — [truncate] does that.
 */
@Composable
fun HeaderChip(
    icon: ImageVector,
    label: String,
    modifier: Modifier = Modifier,
    accent: Color? = null,
    isPaused: Boolean = false,
    standaloneMark: StandaloneMark? = null,
    onMarkTap: () -> Unit = {},
) {
    val content = if (isPaused) LifeyColors.clay else accent ?: LifeyColors.text2
    Row(modifier, horizontalArrangement = Arrangement.spacedBy(LifeySpacing.sm), verticalAlignment = Alignment.CenterVertically) {
        Row(
            modifier = Modifier
                .background(if (isPaused) LifeyColors.tint(LifeyColors.clay) else Color.Transparent, CircleShape)
                .padding(horizontal = if (isPaused) LifeySpacing.md else 0.dp, vertical = if (isPaused) LifeySpacing.xs else 0.dp),
            horizontalArrangement = Arrangement.spacedBy(LifeySpacing.xs),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Icon(if (isPaused) Icons.Filled.Pause else icon, contentDescription = null, tint = content, modifier = Modifier.size(14.dp))
            Text(
                text = if (isPaused) stringResource(R.string.active_paused_indicator).uppercase() else truncate(label).uppercase(),
                style = LifeyType.label(), color = content, maxLines = 1, overflow = TextOverflow.Ellipsis,
            )
        }
        if (standaloneMark != null) {
            val tapped = standaloneMark == StandaloneMark.Tapped
            Box(
                modifier = Modifier
                    // The 48 dp touch target is drawn as it is but *reports* only the mark's own 24 dp of height to
                    // the row. As a 48 dp-tall row it pushed every standalone page's stack down ~20 dp, which is what
                    // put the metric page's name on the heart rate and the log page's EdgeButton on the circles
                    // (LIF-131 bugs 2, 4).
                    .layout { measurable, constraints ->
                        val placeable = measurable.measure(constraints)
                        val reported = minOf(placeable.height, MARK_VISUAL_SIZE.dp.roundToPx())
                        layout(placeable.width, reported) { placeable.place(0, (reported - placeable.height) / 2) }
                    }
                    .size(LocalWatchMetrics.current.minTouchTarget)
                    .clickable(onClick = onMarkTap),
                contentAlignment = Alignment.Center,
            ) {
                Box(
                    Modifier.size(MARK_VISUAL_SIZE.dp).background(if (tapped) LifeyColors.raised else LifeyColors.control, CircleShape),
                    contentAlignment = Alignment.Center,
                ) {
                    Icon(
                        if (tapped) Icons.Filled.Sync else Icons.Filled.PhonelinkOff, contentDescription = null,
                        tint = LifeyColors.text2, modifier = Modifier.size(14.dp),
                    )
                }
            }
        }
    }
}

/** Header label cut to [max] characters plus an ellipsis (W2.6: template name ≤ 14 characters). */
fun truncate(label: String, max: Int = 14): String =
    if (label.length <= max) label else label.take(max).trimEnd() + "…"
