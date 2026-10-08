package com.khunor.lifey.ui.theme

import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import kotlin.math.max
import kotlin.math.roundToInt
import kotlin.math.sqrt

/**
 * Size-class values computed once from the real dial diameter (D-X0.5, frame 03). At the two reference
 * widths (227 dp, 192 dp) the canvas table is returned exactly; at any other width the class's table value
 * is scaled by `width / referenceWidth`. Touch targets are never scaled below 48 dp.
 *
 * Mirrors the Apple `WatchMetrics.swift` (Wear columns); keep the formulas line-for-line equal.
 */
class WatchMetrics(val widthDp: Float) {
    /** Below [COMPACT_WIDTH_DP] (the existing threshold) the compact class applies. */
    val isCompact: Boolean get() = widthDp < COMPACT_WIDTH_DP

    private val scale: Float get() = widthDp / if (isCompact) COMPACT_REFERENCE_DP else REGULAR_REFERENCE_DP

    private fun scaled(regular: Float, compact: Float): Float =
        ((if (isCompact) compact else regular) * scale).roundToInt().toFloat()

    // Type sizes in sp (frame 02)
    val heroSp: Float get() = scaled(48f, 40f)
    /** Dense screens (team sport): 38 on compact. */
    val heroDenseSp: Float get() = scaled(48f, 38f)
    val metricSp: Float get() = scaled(28f, 24f)
    val valueSp: Float get() = scaled(18f, 16f)

    // Controls in dp
    val circleButton: Dp get() = max(scaled(78f, 66f), MIN_TOUCH_TARGET_DP).dp
    /** 74 dp on regular when a secondary EdgeButton shares the page (W2.7); the compact size is unchanged. */
    val circleButtonWithEdgeButton: Dp
        get() = max(scaled(74f, 66f), MIN_TOUCH_TARGET_DP).dp
    val buttonHeight: Dp get() = max(scaled(52f, 48f), MIN_TOUCH_TARGET_DP).dp
    val minTouchTarget: Dp get() = MIN_TOUCH_TARGET_DP.dp

    /**
     * What the bottom-arc EdgeButton takes from the page above it: the library's Small (≈ 58 dp as measured on
     * the 227 dp dial) / ExtraSmall (≈ 46 dp) size plus a hair of air. A stack that shares the screen with
     * one reserves this at its bottom instead of guessing a margin (LIF-131 bugs 3, 4). Wear only — the Apple
     * button sizes differ.
     */
    val edgeButtonReserve: Dp get() = (if (isCompact) 48f else 62f).dp

    /** Side margin: 12 % of the width. */
    val sideMargin: Dp get() = (widthDp * 0.12f).roundToInt().dp
    /** Top and bottom margin: 20 % — anything there is at most one short line or an EdgeButton. */
    val verticalMargin: Dp get() = (widthDp * 0.20f).roundToInt().dp

    /**
     * The usable width of the round dial at vertical position [yDp] (from the top): the chord of the circle
     * of diameter [widthDp] at that height (DS 03 chord rule).
     */
    fun chordWidth(yDp: Float): Float {
        val r = widthDp / 2f
        val dy = yDp - r
        val inside = r * r - dy * dy
        return if (inside <= 0f) 0f else 2f * sqrt(inside)
    }

    companion object {
        const val COMPACT_WIDTH_DP = 200f
        const val REGULAR_REFERENCE_DP = 227f
        const val COMPACT_REFERENCE_DP = 192f
        const val MIN_TOUCH_TARGET_DP = 48f
    }
}

/** Provided once from the root dial width in `LifeyTheme`; defaults to the regular reference. */
val LocalWatchMetrics = staticCompositionLocalOf { WatchMetrics(WatchMetrics.REGULAR_REFERENCE_DP) }
