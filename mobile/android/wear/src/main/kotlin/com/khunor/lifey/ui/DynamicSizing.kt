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

/** The log-set control's circle, as a fraction of screen width (canvas W 07:
 * a 236 dp circle in a 452 dp round screen) — docs/watch/
 * 43-watch-f5-set-logging-plan.md §3.1's "~244 px ... 5× the 48 px minimum"
 * sizing (iOS's canvas frame; Wear's is 236/452, same proportion within
 * rounding), kept as a fraction rather than a literal figure per B4. Mirrors
 * iOS's `DynamicSizing.logCircleDiameterFraction`. */
internal const val LOG_CIRCLE_DIAMETER_FRACTION = 236f / 452f

/** Below this, treat the display as the compact (~1.2"/41 mm) size class. */
internal val COMPACT_SCREEN_WIDTH: Dp = 200.dp

internal fun isCompactScreen(maxWidth: Dp): Boolean = maxWidth < COMPACT_SCREEN_WIDTH
