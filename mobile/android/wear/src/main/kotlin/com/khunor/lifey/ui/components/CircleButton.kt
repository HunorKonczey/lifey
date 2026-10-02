package com.khunor.lifey.ui.components

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.CircleShape
import androidx.wear.compose.material.Icon
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.wear.compose.material.Text
import com.khunor.lifey.ui.theme.DoubleTapGuard
import com.khunor.lifey.ui.theme.LifeyColors
import com.khunor.lifey.ui.theme.LifeyMotion
import com.khunor.lifey.ui.theme.LifeySpacing
import com.khunor.lifey.ui.theme.LifeyType
import com.khunor.lifey.ui.theme.LocalWatchMetrics
import com.khunor.lifey.ui.theme.ghosted
import com.khunor.lifey.ui.theme.ghostedContent
import com.khunor.lifey.ui.theme.rememberReducedMotion

/** Visual style of a [CircleButton] (frame 04/04). */
enum class CircleStyle { Primary, Raised, Control, ErrorTint, SuccessTint }

/**
 * Circle button (frame 04/04): "+1 szett", "Módosítás", "Vége", "Szünet". 78 dp (74 with a secondary
 * EdgeButton, 66 compact) from `WatchMetrics`; the label sits **under** the circle, max two lines. Press =
 * 100 ms scale to 0.96; a 300 ms double-tap guard stays.
 */
@Composable
fun CircleButton(
    style: CircleStyle,
    icon: ImageVector,
    label: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    iconTint: Color? = null,
    isGhosted: Boolean = false,
    diameter: Dp? = null,
    /** Big PJS text in the circle instead of the icon ("+1"). */
    centerText: String? = null,
    /** Small line under the icon inside the circle ("3/4" on the confirmed +1). */
    caption: String? = null,
    /** Spoken description when the circle shows text instead of an icon ("Egy szett naplózása"). */
    a11y: String? = null,
) {
    val metrics = LocalWatchMetrics.current
    val size = diameter ?: metrics.circleButton
    val interaction = remember { MutableInteractionSource() }
    val pressed by interaction.collectIsPressedAsState()
    val reduced = rememberReducedMotion()
    val scale by animateFloatAsState(
        targetValue = if (pressed) 0.96f else 1f,
        animationSpec = tween(LifeyMotion.duration(LifeyMotion.TAP, reduced)),
        label = "circle-press",
    )
    val guard = remember { DoubleTapGuard() }
    val (fill, content) = when (style) {
        CircleStyle.Primary -> LifeyColors.primary to LifeyColors.onPrimary
        CircleStyle.Raised -> LifeyColors.raised to LifeyColors.text
        CircleStyle.Control -> LifeyColors.control to LifeyColors.text
        CircleStyle.ErrorTint -> LifeyColors.tint(LifeyColors.error) to LifeyColors.error
        CircleStyle.SuccessTint -> LifeyColors.tint(LifeyColors.success) to LifeyColors.success
    }
    Column(modifier, horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(LifeySpacing.xs)) {
        Box(
            Modifier
                .size(size)
                .scale(scale)
                .semantics { if (a11y != null) contentDescription = a11y }
                .let { if (isGhosted) it.ghosted(true, CircleShape) else it.background(fill, CircleShape) }
                .clickable(interactionSource = interaction, indication = null, enabled = !isGhosted) {
                    if (guard.accept()) onClick()
                },
            contentAlignment = Alignment.Center,
        ) {
            val tint = ghostedContent(isGhosted, iconTint ?: content)
            if (centerText != null) {
                Text(centerText, style = LifeyType.metric(), color = tint, maxLines = 1)
            } else if (caption != null) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Icon(icon, contentDescription = label, tint = tint, modifier = Modifier.size(size * 0.30f))
                    Text(caption, style = LifeyType.label(), color = tint, maxLines = 1)
                }
            } else {
                Icon(icon, contentDescription = label, tint = tint, modifier = Modifier.size(size * 0.36f))
            }
        }
        Text(
            label, style = LifeyType.label(), color = ghostedContent(isGhosted, LifeyColors.text2),
            textAlign = TextAlign.Center, maxLines = 2, modifier = Modifier.widthIn(max = size + 12.dp),
        )
    }
}
