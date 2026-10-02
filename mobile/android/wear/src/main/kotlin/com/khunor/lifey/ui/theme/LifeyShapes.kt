package com.khunor.lifey.ui.theme

import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp

/**
 * Corner-radius scale of Design System v2 (frame 03): tag 8 · control 14 · card 22 · hero 30, plus
 * pill/circle. A nested element's radius is its parent's minus the padding between them
 * ([nested]: 22 − 8 = 14).
 */
object LifeyShapes {
    val tag = RoundedCornerShape(8.dp)
    val control = RoundedCornerShape(14.dp)
    val card = RoundedCornerShape(22.dp)
    val hero = RoundedCornerShape(30.dp)
    val pill = CircleShape
    val circle = CircleShape

    /** The radius of an element inset by [padding] inside a parent of radius [parent]. */
    fun nested(parent: Dp, padding: Dp): RoundedCornerShape =
        RoundedCornerShape(max(parent.value - padding.value, 0f).dp)

    private fun max(a: Float, b: Float) = if (a > b) a else b

    // ---- Legacy aliases (D-X0.1) — remove in X4.16 ----
    @Deprecated("v2", ReplaceWith("tag")) val chip get() = tag
    @Deprecated("v2", ReplaceWith("control")) val button get() = control
    @Deprecated("v2", ReplaceWith("hero")) val cardLarge get() = hero
}
