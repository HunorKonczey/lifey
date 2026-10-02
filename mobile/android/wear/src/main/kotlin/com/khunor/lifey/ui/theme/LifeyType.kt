package com.khunor.lifey.ui.theme

import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.runtime.Composable
import androidx.compose.runtime.ReadOnlyComposable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.sp
import androidx.wear.compose.material3.Text
import androidx.wear.compose.material3.Typography
import com.khunor.lifey.R

/**
 * Type styles of the watch design system (frame 02, D-X0.6 / D-X0.7): numbers are Plus Jakarta Sans
 * (800 / 700, tabular), every word stays in the system font. Hero and metric grow with the system font
 * scale to at most 115 %, body and label to 135 %.
 *
 * The Light (300) subset is for the ambient numbers ([pjsLight], redesign plan §10 Q4).
 */
object LifeyType {
    const val NUMBER_CAP = 1.15f
    const val TEXT_CAP = 1.35f

    val pjsExtraBold = FontFamily(Font(R.font.pjs_numerals_extrabold, FontWeight.ExtraBold))
    val pjsBold = FontFamily(Font(R.font.pjs_numerals_bold, FontWeight.Bold))
    val pjsLight = FontFamily(Font(R.font.pjs_numerals_light, FontWeight.Light))

    /** `sp` value with the system font scale clamped at [cap]: `base × min(fontScale, cap) / fontScale`. */
    fun capped(base: Float, fontScale: Float, cap: Float): Float =
        if (fontScale <= 0f) base else base * minOf(fontScale, cap) / fontScale

    private const val TNUM = "tnum"

    @Composable @ReadOnlyComposable
    private fun cap(base: Float, cap: Float): TextUnit =
        capped(base, LocalDensity.current.fontScale, cap).sp

    /** `hero` — PJS 800, −2 %, the workout's unit (48 / 40 sp). */
    @Composable @ReadOnlyComposable
    fun hero(metrics: WatchMetrics = LocalWatchMetrics.current, dense: Boolean = false): TextStyle {
        val base = if (dense) metrics.heroDenseSp else metrics.heroSp
        return TextStyle(
            fontFamily = pjsExtraBold, fontWeight = FontWeight.ExtraBold,
            fontSize = cap(base, NUMBER_CAP), letterSpacing = (-base * 0.02f).sp,
            fontFeatureSettings = TNUM,
        )
    }

    /** `metric` — PJS 800 (28 / 24 sp), heart rate. */
    @Composable @ReadOnlyComposable
    fun metric(metrics: WatchMetrics = LocalWatchMetrics.current): TextStyle = TextStyle(
        fontFamily = pjsExtraBold, fontWeight = FontWeight.ExtraBold,
        fontSize = cap(metrics.metricSp, NUMBER_CAP), fontFeatureSettings = TNUM,
    )

    /** `value` — PJS 700 (18 / 16 sp), kcal and tile numbers. */
    @Composable @ReadOnlyComposable
    fun value(metrics: WatchMetrics = LocalWatchMetrics.current): TextStyle = TextStyle(
        fontFamily = pjsBold, fontWeight = FontWeight.Bold,
        fontSize = cap(metrics.valueSp, NUMBER_CAP), fontFeatureSettings = TNUM,
    )

    /** `aod-hero` — PJS 300 in ambient mode. */
    @Composable @ReadOnlyComposable
    fun aodHero(metrics: WatchMetrics = LocalWatchMetrics.current): TextStyle = TextStyle(
        fontFamily = pjsLight, fontWeight = FontWeight.Light,
        fontSize = cap(metrics.heroSp, NUMBER_CAP), letterSpacing = (-metrics.heroSp * 0.02f).sp,
        fontFeatureSettings = TNUM,
    )

    /** `title` — system 600, 16 / 15 sp. */
    @Composable @ReadOnlyComposable
    fun title(metrics: WatchMetrics = LocalWatchMetrics.current): TextStyle = TextStyle(
        fontWeight = FontWeight.SemiBold, fontSize = cap(if (metrics.isCompact) 15f else 16f, TEXT_CAP),
    )

    /** `body` — system 500, 15 / 14 sp. */
    @Composable @ReadOnlyComposable
    fun body(metrics: WatchMetrics = LocalWatchMetrics.current): TextStyle = TextStyle(
        fontWeight = FontWeight.Medium, fontSize = cap(if (metrics.isCompact) 14f else 15f, TEXT_CAP),
    )

    /** `label` — system 700, 12 / 11 sp, +6 % tracking; CAPS only in the header chip and cardio field labels. */
    @Composable @ReadOnlyComposable
    fun label(metrics: WatchMetrics = LocalWatchMetrics.current): TextStyle {
        val base = if (metrics.isCompact) 11f else 12f
        return TextStyle(
            fontWeight = FontWeight.Bold, fontSize = cap(base, TEXT_CAP), letterSpacing = (base * 0.06f).sp,
        )
    }

    /**
     * The Material 3 typography slots the plan binds (D-X0.7): `numeralLarge` = hero, `numeralSmall` =
     * metric, `titleMedium` = value (PJS copy of the title slot is [value]); the rest keeps the platform
     * default. Sizes here are the regular reference; screens use the functions above for the
     * metrics-scaled variants.
     */
    val m3Typography: Typography = Typography(
        numeralLarge = TextStyle(
            fontFamily = pjsExtraBold, fontWeight = FontWeight.ExtraBold, fontSize = 48.sp,
            letterSpacing = (-0.96).sp, fontFeatureSettings = TNUM,
        ),
        numeralSmall = TextStyle(
            fontFamily = pjsExtraBold, fontWeight = FontWeight.ExtraBold, fontSize = 28.sp,
            fontFeatureSettings = TNUM,
        ),
        titleMedium = TextStyle(fontWeight = FontWeight.SemiBold, fontSize = 16.sp),
    )
}

/**
 * A number in PJS followed by its unit in the system label style, `text2` (frame 02: units are never
 * PJS). [description] is the spoken form ("128 beats per minute"); by default "number unit".
 */
@Composable
fun LifeyNumber(
    number: String,
    modifier: Modifier = Modifier,
    unit: String? = null,
    style: TextStyle = LifeyType.value(),
    color: Color = LifeyColors.text,
    description: String? = null,
) {
    Row(
        modifier = modifier.clearAndSetSemantics {
            contentDescription = description ?: listOfNotNull(number, unit).joinToString(" ")
        },
        verticalAlignment = Alignment.Bottom,
        horizontalArrangement = Arrangement.spacedBy(LifeySpacing.xxs),
    ) {
        Text(text = number, style = style, color = color, maxLines = 1)
        if (unit != null) {
            Text(text = unit, style = LifeyType.label(), color = LifeyColors.text2, maxLines = 1)
        }
    }
}
