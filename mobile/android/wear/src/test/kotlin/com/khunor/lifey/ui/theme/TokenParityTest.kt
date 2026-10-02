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

    private fun wearToken(name: String): Int {
        val getter = LifeyColors::class.java.getMethod("get" + name.replaceFirstChar { it.uppercase() })
        return (getter.invoke(LifeyColors) as Color).toArgb()
    }

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
