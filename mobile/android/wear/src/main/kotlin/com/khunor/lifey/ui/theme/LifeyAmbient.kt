package com.khunor.lifey.ui.theme

import androidx.compose.foundation.layout.offset
import androidx.compose.runtime.compositionLocalOf
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.unit.dp
import java.text.DateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone
import kotlin.math.ceil

/**
 * Ambient (Always-On) primitives (frame 08, D-X0.15): only the active screens get an ambient variant
 * (metrics, rest, cardio, bench). Pure black, nothing filled, numbers PJS Light in `text2`, metric colours
 * at 60 %, outlined icons, minute resolution, ±4 dp burn-in shift per minute. Registering the observer
 * (`MainActivity`) does not keep a screen visible on wrist-down by itself — screens opt in during X4.13–15.
 */
data class AmbientState(val isAmbient: Boolean = false, val minuteOfDay: Int = 0)

/** Fed by the `AmbientLifecycleObserver` registered in `MainActivity`. */
val LocalAmbientState = compositionLocalOf { AmbientState() }

/** Formatting of ambient strings, pure so it can be unit-tested (templates come from `strings.xml`). */
object AmbientFormat {
    /** "12 p" under an hour, "1 ó 05 p" from an hour on. [minutesFormat] takes `%d`; [hoursMinutesFormat] `%1$d` / `%2$02d`. */
    fun elapsed(seconds: Int, minutesFormat: String, hoursMinutesFormat: String, locale: Locale = Locale.getDefault()): String {
        val minutes = maxOf(seconds, 0) / 60
        return if (minutes < 60) String.format(locale, minutesFormat, minutes)
        else String.format(locale, hoursMinutesFormat, minutes / 60, minutes % 60)
    }

    /** Rest remaining rounded **up** to whole minutes: "~1 p". */
    fun remaining(seconds: Int, minutesFormat: String, locale: Locale = Locale.getDefault()): String {
        val minutes = ceil(maxOf(seconds, 0) / 60.0).toInt()
        return "~" + String.format(locale, minutesFormat, minutes)
    }

    /** "Mehet 9:42-kor": the rest's end time in the device's time zone and 12/24 h convention. */
    fun restUntil(endsAtEpochMs: Long, restUntilFormat: String, timeZone: TimeZone = TimeZone.getDefault(), locale: Locale = Locale.getDefault()): String {
        val time = DateFormat.getTimeInstance(DateFormat.SHORT, locale).apply { this.timeZone = timeZone }.format(Date(endsAtEpochMs))
        return String.format(locale, restUntilFormat, time)
    }

    /** The outlined name of a Material icon family ("Favorite" → "Outlined.Favorite") — callers map their ImageVector pairs. */
    fun outlined(filled: ImageVector, outlined: ImageVector, isAmbient: Boolean): ImageVector = if (isAmbient) outlined else filled
}

object AmbientStyle {
    /** Metric colours dim to 60 % in ambient mode. */
    fun metricTint(color: Color): Color = color.copy(alpha = 0.6f)
    val number: Color get() = LifeyColors.text2
}

/** Burn-in protection: shifts the content by up to ±4 dp, changing once a minute (D-X0.15). */
fun Modifier.ambientBurnInShift(state: AmbientState): Modifier {
    if (!state.isAmbient) return this
    val step = state.minuteOfDay % 4
    // A fixed 4-point orbit: (+4,0) (0,+4) (−4,0) (0,−4)
    val (x, y) = when (step) { 0 -> 4 to 0; 1 -> 0 to 4; 2 -> -4 to 0; else -> 0 to -4 }
    return offset(x.dp, y.dp)
}
