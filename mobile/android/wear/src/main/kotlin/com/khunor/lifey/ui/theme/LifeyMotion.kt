package com.khunor.lifey.ui.theme

import android.provider.Settings
import androidx.compose.animation.core.CubicBezierEasing
import androidx.compose.animation.core.Easing
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.platform.LocalContext

/**
 * Motion of the watch design system (frame 07, D-X0.14): the v2 durations and curves on the wrist.
 * Ticking numbers never animate — they swap; only summary tiles count up.
 */
object LifeyMotion {
    /** Durations in milliseconds. */
    const val TAP = 100 // circle scales to 0.96, one tone step up
    const val SET_LOGGED = 250 // circle primary → success tint
    const val COUNT_UP = 600 // summary tiles only
    const val CROSS_FADE = 300 // stepper / rest with the metric page
    const val TINT_SWITCH = 250 // sync row pending → synced, last-5 s colour
    const val GO_IN = 150 // "Mehet!" ring: in
    const val GO_HOLD = 250 //              hold
    const val GO_OUT = 700 //               out
    const val STAGGER = 60 // "Edzés mentve" tiles

    /** "Mehet!" with reduced motion: the ring is shown statically for 1.1 s (150 + 250 + 700 ms). */
    const val GO_STATIC_MS = GO_IN + GO_HOLD + GO_OUT

    /** `cubic(0.2, 0, 0, 1)` */
    val Standard: Easing = CubicBezierEasing(0.2f, 0f, 0f, 1f)
    /** `cubic(0.05, 0.7, 0.1, 1)` */
    val Enter: Easing = CubicBezierEasing(0.05f, 0.7f, 0.1f, 1f)
    /** `cubic(0.3, 0, 0.8, 0.15)` */
    val Exit: Easing = CubicBezierEasing(0.3f, 0f, 0.8f, 0.15f)

    /** [ms] unless reduced motion is on, then 0 (frame 07). */
    fun duration(ms: Int, reducedMotion: Boolean): Int = if (reducedMotion) 0 else ms
}

/** True when the system animator duration scale is 0 (the Wear "reduce motion" equivalent). */
@Composable
fun rememberReducedMotion(): Boolean {
    val resolver = LocalContext.current.contentResolver
    return remember(resolver) {
        Settings.Global.getFloat(resolver, Settings.Global.ANIMATOR_DURATION_SCALE, 1f) == 0f
    }
}
