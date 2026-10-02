package com.khunor.lifey.ui.theme

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class WatchMetricsTest {
    @Test
    fun regularReferenceReturnsTheCanvasTable() {
        val m = WatchMetrics(227f)
        assertFalse(m.isCompact)
        assertEquals(48f, m.heroSp, 0f)
        assertEquals(48f, m.heroDenseSp, 0f)
        assertEquals(28f, m.metricSp, 0f)
        assertEquals(18f, m.valueSp, 0f)
        assertEquals(78f, m.circleButton.value, 0f)
        assertEquals(74f, m.circleButtonWithEdgeButton.value, 0f)
        assertEquals(52f, m.buttonHeight.value, 0f)
        assertEquals(48f, m.minTouchTarget.value, 0f)
        assertEquals(27f, m.sideMargin.value, 0f) // 12 % of 227 = 27.2
        assertEquals(45f, m.verticalMargin.value, 0f) // 20 % of 227 = 45.4
    }

    @Test
    fun compactReferenceReturnsTheCanvasTable() {
        val m = WatchMetrics(192f)
        assertTrue(m.isCompact)
        assertEquals(40f, m.heroSp, 0f)
        assertEquals(38f, m.heroDenseSp, 0f)
        assertEquals(24f, m.metricSp, 0f)
        assertEquals(16f, m.valueSp, 0f)
        assertEquals(66f, m.circleButton.value, 0f)
        assertEquals(48f, m.buttonHeight.value, 0f)
    }

    @Test
    fun classBoundaryIs200dp() {
        assertTrue(WatchMetrics(199.9f).isCompact)
        assertFalse(WatchMetrics(200f).isCompact)
    }

    @Test
    fun touchTargetsAreNeverUndercut() {
        val m = WatchMetrics(170f)
        assertTrue(m.circleButton.value >= 48f)
        assertTrue(m.buttonHeight.value >= 48f)
        assertEquals(48f, m.minTouchTarget.value, 0f)
    }

    @Test
    fun chordWidthFollowsTheCircle() {
        val m = WatchMetrics(200f)
        assertEquals(200f, m.chordWidth(100f), 0.01f) // the diameter at the centre line
        assertEquals(0f, m.chordWidth(0f), 0.01f) // a point at the very top
        // At the 20 % line: 2 * sqrt(100² − 60²) = 160
        assertEquals(160f, m.chordWidth(40f), 0.01f)
        assertEquals(m.chordWidth(40f), m.chordWidth(160f), 0.01f) // symmetric
        assertEquals(0f, m.chordWidth(-5f), 0f) // outside the dial
    }
}
