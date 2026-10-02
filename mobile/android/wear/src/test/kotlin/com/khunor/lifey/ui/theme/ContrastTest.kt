package com.khunor.lifey.ui.theme

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.toArgb
import kotlin.math.pow
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Port of `mobile/lib/core/theme/contrast.dart`: WCAG 2.x contrast of the watch tokens
 * (redesign plan 79, D-X0.2). `ghost` is exempt — it marks disabled content.
 */
class ContrastTest {
    private fun channel(c: Int): Double {
        val v = c / 255.0
        return if (v <= 0.03928) v / 12.92 else ((v + 0.055) / 1.055).pow(2.4)
    }

    private fun luminance(argb: Int): Double =
        0.2126 * channel(argb shr 16 and 0xFF) +
            0.7152 * channel(argb shr 8 and 0xFF) +
            0.0722 * channel(argb and 0xFF)

    /** Composites a translucent [fg] onto [bg] first, the way it renders. */
    private fun over(fg: Color, bg: Color): Int {
        val a = fg.alpha
        fun mix(shift: Int): Int {
            val f = fg.toArgb() shr shift and 0xFF
            val b = bg.toArgb() shr shift and 0xFF
            return Math.round(f * a + b * (1 - a)).toInt()
        }
        return (0xFF shl 24) or (mix(16) shl 16) or (mix(8) shl 8) or mix(0)
    }

    private fun contrast(fg: Color, bg: Color): Double {
        val l1 = luminance(over(fg, bg))
        val l2 = luminance(bg.toArgb())
        return (maxOf(l1, l2) + 0.05) / (minOf(l1, l2) + 0.05)
    }

    private fun assertAa(name: String, fg: Color, bg: Color) {
        val ratio = contrast(fg, bg)
        assertTrue("$name on its background is $ratio : 1, below 4.5", ratio >= 4.5)
    }

    @Test
    fun textTiersReadOnEverySurface() {
        for (surface in listOf(LifeyColors.bg, LifeyColors.card, LifeyColors.nested)) {
            assertAa("text", LifeyColors.text, surface)
            assertAa("text2", LifeyColors.text2, surface)
            assertAa("text3", LifeyColors.text3, surface)
        }
    }

    @Test
    fun metricAndRoleColoursReadOnTheirOwnTint() {
        val roles = mapOf(
            "heart" to LifeyColors.heart,
            "calories" to LifeyColors.calories,
            "success" to LifeyColors.success,
            "error" to LifeyColors.error,
            "clay" to LifeyColors.clay,
            "primary" to LifeyColors.primary,
            "cardioWalking" to LifeyColors.cardioWalking,
            "cardioHiking" to LifeyColors.cardioHiking,
            "cardioIndoorBike" to LifeyColors.cardioIndoorBike,
            "cardioBasketball" to LifeyColors.cardioBasketball,
            "cardioFootball" to LifeyColors.cardioFootball,
        )
        for ((name, color) in roles) {
            val tint = Color(over(LifeyColors.tint(color), LifeyColors.bg))
            assertAa(name, color, tint)
        }
    }

    @Test
    fun onPrimaryReadsOnPrimary() = assertAa("onPrimary", LifeyColors.onPrimary, LifeyColors.primary)
}
