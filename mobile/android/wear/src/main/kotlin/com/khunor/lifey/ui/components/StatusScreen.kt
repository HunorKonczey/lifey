package com.khunor.lifey.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.wear.compose.material.Icon
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.wear.compose.material.Text
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
    Box(modifier.fillMaxSize()) {
        Column(
            Modifier.align(Alignment.Center).padding(horizontal = metrics.sideMargin, vertical = metrics.verticalMargin),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(LifeySpacing.sm),
        ) {
            Box(Modifier.size(44.dp).background(LifeyColors.tint(iconTint), CircleShape), contentAlignment = Alignment.Center) {
                Icon(icon, contentDescription = null, tint = iconTint, modifier = Modifier.size(24.dp))
            }
            Text(title, style = LifeyType.title(), color = LifeyColors.text, maxLines = 2, textAlign = TextAlign.Center)
            if (text != null) Text(text, style = LifeyType.body(), color = LifeyColors.text2, maxLines = 4, textAlign = TextAlign.Center)
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
