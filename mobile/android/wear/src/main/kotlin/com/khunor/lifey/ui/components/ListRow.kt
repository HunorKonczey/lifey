package com.khunor.lifey.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material3.Icon
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.wear.compose.material.Text
import androidx.wear.compose.material3.Button
import androidx.wear.compose.material3.ButtonDefaults
import com.khunor.lifey.ui.theme.LifeyColors
import com.khunor.lifey.ui.theme.LifeySpacing
import com.khunor.lifey.ui.theme.LifeyType
import com.khunor.lifey.ui.theme.LocalWatchMetrics

/** Leading element of a [ListRow]. */
sealed interface RowLeading {
    object None : RowLeading
    /** 36 dp `control` holder with a `primary` glyph (quick strength, all types). */
    data class Holder(val icon: ImageVector) : RowLeading
    /** Cardio type: icon in an accent @ 16 % circle. */
    data class Tinted(val icon: ImageVector, val accent: Color) : RowLeading
}

/**
 * List row (frame 04/09): an M3 [Button] pill for **every** row, quick strength included (one component
 * language). Highlighted / selected = `raised` + an icon circle; a selected exercise shows a check. 52 dp
 * (48 compact), the title wraps to two lines.
 */
@Composable
fun ListRow(
    title: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    subtitle: String? = null,
    leading: RowLeading = RowLeading.None,
    isHighlighted: Boolean = false,
    showsCheck: Boolean = false,
) {
    val metrics = LocalWatchMetrics.current
    Button(
        onClick = onClick,
        modifier = modifier.fillMaxWidth().defaultMinSize(minHeight = metrics.buttonHeight),
        colors = ButtonDefaults.filledTonalButtonColors(
            containerColor = if (isHighlighted) LifeyColors.raised else LifeyColors.card,
            contentColor = LifeyColors.text,
        ),
    ) {
        Row(horizontalArrangement = Arrangement.spacedBy(LifeySpacing.md), verticalAlignment = Alignment.CenterVertically) {
            when (leading) {
                RowLeading.None -> Unit
                is RowLeading.Holder -> Holder(leading.icon, LifeyColors.primary, LifeyColors.control)
                is RowLeading.Tinted -> Holder(leading.icon, leading.accent, LifeyColors.tint(leading.accent))
            }
            Column(Modifier.weight(1f, fill = false)) {
                Text(title, style = LifeyType.title(), color = LifeyColors.text, maxLines = 2, overflow = TextOverflow.Ellipsis)
                if (subtitle != null) Text(subtitle, style = LifeyType.label(), color = LifeyColors.text2, maxLines = 1)
            }
            if (showsCheck) Icon(Icons.Filled.Check, contentDescription = null, tint = LifeyColors.text, modifier = Modifier.size(16.dp))
        }
    }
}

@Composable
private fun Holder(icon: ImageVector, tint: Color, background: Color) {
    Box(Modifier.size(36.dp).background(background, CircleShape), contentAlignment = Alignment.Center) {
        Icon(icon, contentDescription = null, tint = tint, modifier = Modifier.size(18.dp))
    }
}
