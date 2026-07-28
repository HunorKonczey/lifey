package com.khunor.lifey.ui

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.wear.compose.material.ChipDefaults
import androidx.wear.compose.material.CompactChip
import androidx.wear.compose.material.MaterialTheme
import androidx.wear.compose.material.Text
import com.khunor.lifey.R
import com.khunor.lifey.ui.theme.LifeyColors

/** The badge behind the leaf mark, and the leaf itself within it, as
 * fractions of the shorter screen dimension — slightly smaller than the
 * original idle screen's (canvas Wear 01: 0.22/0.13) to make room for the
 * launcher's "Start workout" button below (canvas W 11: "brand moment
 * kept... slightly compacted", mirrors iOS's identical S10 adjustment). */
private const val LEAF_BADGE_SIZE_FRACTION = 0.19f
private const val LEAF_MARK_SIZE_FRACTION = 0.11f

/**
 * No active session — now a **launcher**, not just a status screen
 * (docs/watch/44-watch-f6-standalone-plan.md §3.1, design canvas W 11). The
 * calm brand-moment the design canvas asks for (§12.1 B5 /
 * 41-watch-design-prompt.md §3.1) is kept — leaf badge + "Lifey" wordmark —
 * but compacted, since the `primary`-fill "Start workout" button is now the
 * screen's only saturated element, opening `StandalonePickerScreen`. The old
 * `idle_subtitle` demotes to a quiet second line under the button
 * (`standalone_start_caption`) — the key itself stays in the string
 * resources (harmless, unreferenced) rather than being deleted. Padding and
 * type scale are dial-size-relative, not fixed dp values (§12.1 B4 — see
 * `DynamicSizing.kt`).
 */
@Composable
fun IdleScreen(onStartTapped: () -> Unit) {
    BoxWithConstraints(modifier = Modifier.fillMaxSize()) {
        val isCompact = isCompactScreen(maxWidth)
        val shortSide = minOf(maxWidth, maxHeight)
        val badgeSize = shortSide * LEAF_BADGE_SIZE_FRACTION
        val leafSize = shortSide * LEAF_MARK_SIZE_FRACTION
        val startA11yLabel = stringResource(R.string.standalone_start_button_a11y)
        Column(
            modifier = Modifier.fillMaxSize().padding(maxWidth * SCREEN_PADDING_FRACTION),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(badgeSize * 0.3f, Alignment.CenterVertically),
        ) {
            Box(
                modifier = Modifier
                    .size(badgeSize)
                    .background(LifeyColors.surface, RoundedCornerShape(badgeSize * 0.3f)),
                contentAlignment = Alignment.Center,
            ) {
                LeafMark(size = leafSize)
            }
            Text(
                text = stringResource(R.string.idle_title),
                style = if (isCompact) MaterialTheme.typography.title3 else MaterialTheme.typography.title2,
                color = LifeyColors.onSurface,
            )
            CompactChip(
                onClick = onStartTapped,
                modifier = Modifier.semantics { contentDescription = startA11yLabel },
                label = {
                    Text(
                        text = stringResource(R.string.standalone_start_button),
                        style = if (isCompact) MaterialTheme.typography.caption1 else MaterialTheme.typography.button,
                    )
                },
                colors = ChipDefaults.chipColors(
                    backgroundColor = LifeyColors.primary,
                    contentColor = LifeyColors.onPrimary,
                ),
            )
            Text(
                text = stringResource(R.string.standalone_start_caption),
                style = if (isCompact) MaterialTheme.typography.caption2 else MaterialTheme.typography.caption1,
                color = LifeyColors.onSurfaceVariant,
                textAlign = TextAlign.Center,
            )
        }
    }
}

/**
 * A minimal drawn leaf/eco mark (§12.1 B5) — no image asset exists for
 * Lifey's brand yet, so this is a plain vector shape (a pointed lens/almond
 * silhouette + center vein) in the brand's moss-olive accent, sized relative
 * to the dial rather than a fixed dp value (§12.1 B4).
 */
@Composable
private fun LeafMark(size: Dp) {
    Canvas(modifier = Modifier.size(size)) {
        val w = this.size.width
        val h = this.size.height
        val leafPath = Path().apply {
            moveTo(w / 2f, 0f)
            cubicTo(w * 0.95f, h * 0.28f, w * 0.95f, h * 0.72f, w / 2f, h)
            cubicTo(w * 0.05f, h * 0.72f, w * 0.05f, h * 0.28f, w / 2f, 0f)
            close()
        }
        drawPath(leafPath, color = LifeyColors.primary)
        drawLine(
            color = LifeyColors.primary.copy(alpha = 0.45f),
            start = Offset(w / 2f, h * 0.1f),
            end = Offset(w / 2f, h * 0.9f),
            strokeWidth = w * 0.05f,
        )
    }
}
