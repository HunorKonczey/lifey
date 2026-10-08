package com.khunor.lifey.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.shape.CircleShape
import androidx.wear.compose.material3.Icon
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.wear.compose.material3.Text
import androidx.wear.compose.material3.TimeText
import com.khunor.lifey.ui.theme.LifeyColors
import com.khunor.lifey.ui.theme.LifeySpacing
import com.khunor.lifey.ui.theme.LifeyType
import com.khunor.lifey.ui.theme.LocalWatchMetrics

/**
 * Status screen (W2.4 and the cardio "no HR" explanation): a centred icon, a title of at most two lines, a
 * text, and the action as a `control` **EdgeButton** on the bottom arc ([actionLabel]) — acknowledge only.
 */
@Composable
fun StatusScreen(
    icon: ImageVector,
    title: String,
    modifier: Modifier = Modifier,
    iconTint: Color = LifeyColors.text2,
    text: String? = null,
    actionLabel: String? = null,
    onAction: () -> Unit = {},
) {
    val metrics = LocalWatchMetrics.current
    // With an action the EdgeButton owns the bottom arc: the stack centres in what is left above it instead of
    // running its last line under the button (W2.4), and the icon gives up a few dp to make that fit.
    val hasAction = actionLabel != null
    val iconSize = if (hasAction) 36.dp else 44.dp
    // On the compact dial with an action there is room for the title and the explanation, not for the glyph too —
    // the "Rendben" button and the words are what the screen is for (LIF-131 bug 3).
    val showsIcon = !(hasAction && metrics.isCompact)
    Box(modifier.fillMaxSize()) {
        // Centred when it fits; at a big system font the title alone can run to four lines, and then the stack
        // scrolls instead of its last lines being cut by the button (LIF-131 bug 3).
        Box(
            Modifier.fillMaxSize().padding(
                start = metrics.sideMargin, end = metrics.sideMargin,
                top = (metrics.widthDp * 0.14f).dp,
                bottom = if (hasAction) metrics.edgeButtonReserve else metrics.verticalMargin,
            ),
            contentAlignment = Alignment.Center,
        ) {
        Column(
            Modifier.verticalScroll(rememberScrollState()),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(LifeySpacing.xs),
        ) {
            if (showsIcon) {
                Box(Modifier.size(iconSize).background(LifeyColors.tint(iconTint), CircleShape), contentAlignment = Alignment.Center) {
                    Icon(icon, contentDescription = null, tint = iconTint, modifier = Modifier.size(if (hasAction) 20.dp else 24.dp))
                }
            }
            Text(title, style = LifeyType.title(), color = LifeyColors.text, textAlign = TextAlign.Center)
            if (text != null) Text(text, style = LifeyType.body(), color = LifeyColors.text2, textAlign = TextAlign.Center)
        }
        }
        TimeText()
        if (actionLabel != null) {
            // The action only acknowledges: a `control` EdgeButton, never the saturated primary.
            LifeyEdgeButton(onClick = onAction, secondary = true, modifier = Modifier.align(Alignment.BottomCenter)) {
                Text(actionLabel, style = LifeyType.body(), color = LifeyColors.text, maxLines = 1)
            }
        }
    }
}
