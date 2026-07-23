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
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.wear.compose.material.MaterialTheme
import androidx.wear.compose.material.Text
import com.khunor.lifey.R
import com.khunor.lifey.ui.theme.LifeyColors

/** The badge behind the leaf mark, and the leaf itself within it, as
 * fractions of the shorter screen dimension — canvas Wear 01's badge:leaf
 * ratio is roughly 72:42. */
private const val LEAF_BADGE_SIZE_FRACTION = 0.22f
private const val LEAF_MARK_SIZE_FRACTION = 0.13f

/**
 * No active session — docs/40-watch-app-plan.md §4.4/§5.1 "IdleView"
 * equivalent, now carrying the calm brand-moment the design canvas asks for
 * (§12.1 B5 / 41-watch-design-prompt.md §3.1: "the only screen where brand
 * decoration is allowed to breathe; keep it calm, not salesy") instead of
 * two lines of plain text. Padding and type scale are dial-size-relative,
 * not fixed dp values (§12.1 B4 — see `DynamicSizing.kt`).
 */
@Composable
fun IdleScreen() {
    BoxWithConstraints(modifier = Modifier.fillMaxSize()) {
        val isCompact = isCompactScreen(maxWidth)
        val shortSide = minOf(maxWidth, maxHeight)
        val badgeSize = shortSide * LEAF_BADGE_SIZE_FRACTION
        val leafSize = shortSide * LEAF_MARK_SIZE_FRACTION
        Column(
            modifier = Modifier.fillMaxSize().padding(maxWidth * SCREEN_PADDING_FRACTION),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(badgeSize * 0.35f, Alignment.CenterVertically),
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
            Text(
                text = stringResource(R.string.idle_subtitle),
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
