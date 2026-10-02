package com.khunor.lifey.ui.theme

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
        "PlusJakartaSans-Light-numerals.ttf" to "pjs_numerals_light.ttf",
    )

    private val numeralGlyphs = "0123456789:.,+-−–—/~%×  "

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
            val cmap = CmapReader(wear(wearName).readBytes())
            for (ch in numeralGlyphs) {
                assertTrue("$wearName lacks U+%04X".format(ch.code), cmap.has(ch.code))
            }
        }
    }

    @Test
    fun extraBoldAlsoCoversTheWordmark() {
        val cmap = CmapReader(wear("pjs_numerals_extrabold.ttf").readBytes())
        for (ch in "Lifey") assertTrue("wordmark glyph $ch", cmap.has(ch.code))
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

/**
 * A minimal TrueType `cmap` reader (format 4, Unicode BMP) — `java.awt.Font` is not on the Android unit-test
 * classpath, and a glyph-coverage check needs nothing more than "is this code point mapped?".
 */
private class CmapReader(private val data: ByteArray) {
    private fun u16(o: Int) = ((data[o].toInt() and 0xFF) shl 8) or (data[o + 1].toInt() and 0xFF)
    private fun u32(o: Int) = (u16(o).toLong() shl 16) or u16(o + 2).toLong()

    private val subtable: Int = run {
        val tables = u16(4)
        var cmap = -1
        for (i in 0 until tables) {
            val rec = 12 + i * 16
            val tag = String(data, rec, 4, Charsets.US_ASCII)
            if (tag == "cmap") cmap = u32(rec + 8).toInt()
        }
        require(cmap >= 0) { "no cmap table" }
        var found = -1
        for (i in 0 until u16(cmap + 2)) {
            val rec = cmap + 4 + i * 8
            val platform = u16(rec)
            val encoding = u16(rec + 2)
            val offset = cmap + u32(rec + 4).toInt()
            // Unicode (0, any) or Windows Unicode BMP (3, 1), format 4.
            if ((platform == 0 || (platform == 3 && encoding == 1)) && u16(offset) == 4) found = offset
        }
        require(found >= 0) { "no format-4 Unicode cmap subtable" }
        found
    }

    fun has(codePoint: Int): Boolean {
        if (codePoint > 0xFFFF) return false
        val segCount = u16(subtable + 6) / 2
        val endCodes = subtable + 14
        val startCodes = endCodes + segCount * 2 + 2
        val idDeltas = startCodes + segCount * 2
        val idRangeOffsets = idDeltas + segCount * 2
        for (i in 0 until segCount) {
            if (codePoint <= u16(endCodes + i * 2)) {
                if (codePoint < u16(startCodes + i * 2)) return false
                val rangeOffset = u16(idRangeOffsets + i * 2)
                val glyph = if (rangeOffset == 0) {
                    (codePoint + u16(idDeltas + i * 2)) and 0xFFFF
                } else {
                    val g = u16(idRangeOffsets + i * 2 + rangeOffset + (codePoint - u16(startCodes + i * 2)) * 2)
                    if (g == 0) 0 else (g + u16(idDeltas + i * 2)) and 0xFFFF
                }
                return glyph != 0
            }
        }
        return false
    }
}
