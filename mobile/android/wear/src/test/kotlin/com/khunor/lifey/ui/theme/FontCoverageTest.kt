package com.khunor.lifey.ui.theme

import java.awt.Font
import java.io.File
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/** The numeral subsets (D-X0.6): glyph coverage, Apple/Wear byte-identity, and the font-scale clamp. */
class FontCoverageTest {
    private val root: File = generateSequence(File("").absoluteFile) { it.parentFile }
        .first { File(it, "ios/LifeyWatch/Fonts").isDirectory }

    private val pairs = mapOf(
        "PlusJakartaSans-ExtraBold-numerals.ttf" to "pjs_numerals_extrabold.ttf",
        "PlusJakartaSans-Bold-numerals.ttf" to "pjs_numerals_bold.ttf",
    )

    private val numeralGlyphs = "0123456789:.,+-−–—/~%×   "

    private fun wear(name: String) = File(root, "android/wear/src/main/res/font/$name")
    private fun apple(name: String) = File(root, "ios/LifeyWatch/Fonts/$name")

    @Test
    fun wearAndAppleCopiesAreByteIdentical() {
        for ((appleName, wearName) in pairs) {
            assertArrayEquals("$wearName differs from $appleName", apple(appleName).readBytes(), wear(wearName).readBytes())
        }
    }

    @Test
    fun everySubsetCoversTheNumeralGlyphs() {
        for (wearName in pairs.values) {
            val font = Font.createFont(Font.TRUETYPE_FONT, wear(wearName))
            for (ch in numeralGlyphs) {
                assertTrue("$wearName lacks U+%04X".format(ch.code), font.canDisplay(ch))
            }
        }
    }

    @Test
    fun extraBoldAlsoCoversTheWordmark() {
        val font = Font.createFont(Font.TRUETYPE_FONT, wear("pjs_numerals_extrabold.ttf"))
        for (ch in "Lifey") assertTrue("wordmark glyph $ch", font.canDisplay(ch))
    }

    @Test
    fun fontScaleIsClampedAtTheCap() {
        assertEquals(48f, LifeyType.capped(48f, 1.0f, LifeyType.NUMBER_CAP), 0.001f)
        // At fontScale 1.3 the 115 % cap leaves sp × 1.15 / 1.3 so that the rendered size is base × 1.15.
        assertEquals(48f * 1.15f / 1.3f, LifeyType.capped(48f, 1.3f, LifeyType.NUMBER_CAP), 0.001f)
        // Below the cap the size is untouched.
        assertEquals(15f, LifeyType.capped(15f, 1.3f, LifeyType.TEXT_CAP), 0.001f)
    }
}
