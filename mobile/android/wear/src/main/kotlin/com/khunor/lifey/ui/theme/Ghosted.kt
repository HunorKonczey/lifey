package com.khunor.lifey.ui.theme

import androidx.compose.foundation.background
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Shape

/**
 * Ghosted (disabled) is a token pair, not alpha (D-X0.10): background `card` + content `ghost`. On black,
 * alpha turns primary into a "dirty green" with unpredictable contrast. Apply the background with this
 * modifier and read [ghostedContent] for icons and text.
 */
fun Modifier.ghosted(isGhosted: Boolean, shape: Shape): Modifier =
    if (isGhosted) background(LifeyColors.card, shape) else this

/** Content colour for a ghosted control, or [normal] when it is enabled. */
fun ghostedContent(isGhosted: Boolean, normal: androidx.compose.ui.graphics.Color) =
    if (isGhosted) LifeyColors.ghost else normal

/** Double-tap guard (docs/watch/43-watch-f5-set-logging-plan.md §4.2): taps within [ms] of the last accepted tap are swallowed. */
class DoubleTapGuard(private val ms: Long = 300) {
    private var last = Long.MIN_VALUE

    /** True if this tap should run; records it. */
    fun accept(nowMs: Long = System.currentTimeMillis()): Boolean {
        if (last != Long.MIN_VALUE && nowMs - last < ms) return false
        last = nowMs
        return true
    }
}
