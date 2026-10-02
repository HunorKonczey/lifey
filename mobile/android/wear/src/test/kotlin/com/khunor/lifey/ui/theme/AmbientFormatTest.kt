package com.khunor.lifey.ui.theme

import java.time.ZoneId
import java.time.ZonedDateTime
import java.util.Locale
import java.util.TimeZone
import org.junit.Assert.assertEquals
import org.junit.Test

class AmbientFormatTest {
    private val huMinutes = "%d p"
    private val huHours = "%1\$d ó %2\$02d p"
    private val enMinutes = "%d min"
    private val enHours = "%1\$d h %2\$02d min"
    private val hu = Locale("hu", "HU")
    private val en = Locale.US

    @Test
    fun elapsedUnderAnHour() {
        assertEquals("12 p", AmbientFormat.elapsed(12 * 60 + 34, huMinutes, huHours, hu))
        assertEquals("0 p", AmbientFormat.elapsed(59, huMinutes, huHours, hu))
        assertEquals("59 p", AmbientFormat.elapsed(59 * 60 + 59, huMinutes, huHours, hu))
        assertEquals("12 min", AmbientFormat.elapsed(12 * 60, enMinutes, enHours, en))
    }

    @Test
    fun elapsedFromAnHourOn() {
        assertEquals("1 ó 05 p", AmbientFormat.elapsed(65 * 60 + 10, huMinutes, huHours, hu))
        assertEquals("1 h 05 min", AmbientFormat.elapsed(65 * 60 + 10, enMinutes, enHours, en))
        assertEquals("2 ó 00 p", AmbientFormat.elapsed(120 * 60, huMinutes, huHours, hu))
    }

    @Test
    fun remainingRoundsUp() {
        assertEquals("~1 p", AmbientFormat.remaining(59, huMinutes, hu))
        assertEquals("~1 p", AmbientFormat.remaining(60, huMinutes, hu))
        assertEquals("~2 p", AmbientFormat.remaining(61, huMinutes, hu))
        assertEquals("~0 p", AmbientFormat.remaining(0, huMinutes, hu))
    }

    @Test
    fun restEndTimeUsesTheLocalZoneAcrossMidnight() {
        val budapest = ZoneId.of("Europe/Budapest")
        val at = ZonedDateTime.of(2026, 10, 2, 23, 59, 30, 0, budapest).plusSeconds(90).toInstant().toEpochMilli()
        // 23:59:30 + 90 s = 00:01:00 the next day, in Budapest.
        val text = AmbientFormat.restUntil(at, "Mehet %s-kor", TimeZone.getTimeZone(budapest), hu)
        assertEquals("Mehet 0:01-kor", text.replace(" ", " ").replace("00:01", "0:01"))
        val us = AmbientFormat.restUntil(at, "Go at %s", TimeZone.getTimeZone("America/New_York"), en)
        assertEquals("Go at 6:01 PM", us.replace(" ", " "))
    }
}
