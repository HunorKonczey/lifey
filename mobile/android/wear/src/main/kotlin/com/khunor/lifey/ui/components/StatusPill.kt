package com.khunor.lifey.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.ErrorOutline
import androidx.compose.material.icons.filled.HourglassTop
import androidx.compose.material.icons.filled.PhonelinkOff
import androidx.compose.material.icons.filled.Sync
import androidx.compose.material3.Icon
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.wear.compose.material.Text
import com.khunor.lifey.ui.theme.LifeyColors
import com.khunor.lifey.ui.theme.LifeyShapes
import com.khunor.lifey.ui.theme.LifeySpacing
import com.khunor.lifey.ui.theme.LifeyType

/** Kind of [StatusPill] (frame 04/05). */
enum class PillKind(val priority: Int, val icon: ImageVector, val background: Color, val content: Color) {
    Logged(1, Icons.Filled.Check, LifeyColors.tint(LifeyColors.success), LifeyColors.success),
    Pending(2, Icons.Filled.HourglassTop, LifeyColors.nested, LifeyColors.text),
    Unreachable(3, Icons.Filled.PhonelinkOff, LifeyColors.nested, LifeyColors.text2),
    Failed(4, Icons.Filled.ErrorOutline, LifeyColors.tint(LifeyColors.error), LifeyColors.error),
    Handoff(0, Icons.Filled.Sync, LifeyColors.nested, LifeyColors.text2);

    companion object {
        /** One pill at a time: failed › unreachable › pending › logged. */
        fun winner(kinds: Collection<PillKind>): PillKind? = kinds.maxByOrNull { it.priority }
    }
}

/**
 * Status pill (frame 04/05): 28 dp, icon + one line; on the round screen it wraps to **two centred lines**
 * deliberately ("Nem sikerült —" / "próbáld újra", W1.7) and sits on the bottom chord where the page
 * indicator was.
 */
@Composable
fun StatusPill(kind: PillKind, text: String, modifier: Modifier = Modifier) {
    Row(
        modifier = modifier
            .defaultMinSize(minHeight = 28.dp)
            .background(kind.background, LifeyShapes.card)
            .padding(horizontal = LifeySpacing.lg, vertical = LifeySpacing.xs),
        horizontalArrangement = Arrangement.spacedBy(LifeySpacing.xs, Alignment.CenterHorizontally),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(kind.icon, contentDescription = null, tint = kind.content, modifier = Modifier.size(14.dp))
        Text(text, style = LifeyType.body(), color = kind.content, maxLines = 2, textAlign = TextAlign.Center)
    }
}
