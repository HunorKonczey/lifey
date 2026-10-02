package com.khunor.lifey.ui.theme

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.toArgb
import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * The Wear and Apple Watch palettes are value-identical (D-X0.2). Reads
 * `mobile/ios/LifeyWatch/Theme/LifeyColors.swift` and compares every `static let name = Color(hex: 0x…)`
 * with the same-named property of [LifeyColors] by reflection.
 */
class TokenParityTest {
    private val swift: File = generateSequence(File("").absoluteFile) { it.parentFile }
        .map { File(it, "ios/LifeyWatch/Theme/LifeyColors.swift") }
        .first { it.exists() }

    private val appleTokens: Map<String, Int> = Regex("""static let (\w+) = Color\(hex: 0x([0-9A-Fa-f_]+)\)""")
        .findAll(swift.readText())
        .associate { it.groupValues[1] to (0xFF000000.toInt() or it.groupValues[2].replace("_", "").toInt(16)) }

    /**
     * Every palette token by name. [Color] is an inline value class, so its getters are name-mangled and cannot
     * be found by reflection; the map is explicit instead — and the test fails when the Apple file gains a
     * token this map does not know, so a new token has to be added on both sides.
     */
    private val wearTokens: Map<String, Color> = mapOf(
        "bg" to LifeyColors.bg, "card" to LifeyColors.card, "nested" to LifeyColors.nested,
        "control" to LifeyColors.control, "raised" to LifeyColors.raised, "outline" to LifeyColors.outline,
        "text" to LifeyColors.text, "text2" to LifeyColors.text2, "text3" to LifeyColors.text3,
        "ghost" to LifeyColors.ghost, "primary" to LifeyColors.primary, "onPrimary" to LifeyColors.onPrimary,
        "heart" to LifeyColors.heart, "calories" to LifeyColors.calories, "success" to LifeyColors.success,
        "error" to LifeyColors.error, "clay" to LifeyColors.clay,
        "cardioWalking" to LifeyColors.cardioWalking, "cardioHiking" to LifeyColors.cardioHiking,
        "cardioIndoorBike" to LifeyColors.cardioIndoorBike, "cardioBasketball" to LifeyColors.cardioBasketball,
        "cardioFootball" to LifeyColors.cardioFootball,
    )

    private fun wearToken(name: String): Int =
        (wearTokens[name] ?: error("token '$name' exists in LifeyColors.swift but not in the Wear parity map")).toArgb()

    @Test
    fun appleFileHasTheTokens() {
        assertTrue("expected ≥ 17 tokens in ${swift.path}, found ${appleTokens.keys}", appleTokens.size >= 17)
    }

    @Test
    fun everyAppleTokenMatchesWear() {
        for ((name, argb) in appleTokens) {
            assertEquals("token '$name' differs between LifeyColors.swift and LifeyColors.kt",
                argb, wearToken(name))
        }
    }
}
