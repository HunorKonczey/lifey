package com.khunor.lifey.ui

import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp

/**
 * Wear OS dynamic-sizing helpers (docs/40-watch-app-plan.md §12.1 B4 /
 * 41-watch-design-prompt.md canvas "Dynamic sizing" row): paddings and the
 * hero/hero-adjacent type scale are derived from the actual dial size
 * (`BoxWithConstraints`-fractions) rather than fixed dp values tuned for one
 * screen, and checked against both the ~1.2"/41 mm (compact) and ~1.4"/45 mm
 * (regular) round Wear OS size classes.
 */
internal const val SCREEN_PADDING_FRACTION = 0.08f

/** Below this, treat the display as the compact (~1.2"/41 mm) size class. */
internal val COMPACT_SCREEN_WIDTH: Dp = 200.dp

internal fun isCompactScreen(maxWidth: Dp): Boolean = maxWidth < COMPACT_SCREEN_WIDTH
