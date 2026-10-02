package com.khunor.lifey.ui.theme

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.wear.compose.material.Colors
import androidx.wear.compose.material.MaterialTheme
import androidx.wear.compose.material.Typography
import androidx.wear.compose.material3.ColorScheme
import androidx.wear.compose.material3.MaterialTheme as Material3Theme

/**
 * Maps the v2 [LifeyColors] tokens onto Wear Compose Material's [Colors]
 * slots (redesign plan 79, D-X0.2). `background` is [LifeyColors.bg], true
 * `#000`; cards and chips use `card` / `nested` / `control` / `raised`.
 */
private val LifeyWearColors = Colors(
    primary = LifeyColors.primary,
    primaryVariant = LifeyColors.nested,
    secondary = LifeyColors.clay,
    secondaryVariant = LifeyColors.tint(LifeyColors.clay),
    background = LifeyColors.bg,
    surface = LifeyColors.card,
    error = LifeyColors.error,
    onPrimary = LifeyColors.onPrimary,
    onSecondary = LifeyColors.onPrimary,
    onBackground = LifeyColors.text,
    onSurface = LifeyColors.text,
    onSurfaceVariant = LifeyColors.text2,
    onError = LifeyColors.bg,
)

/**
 * The Material 3 colour scheme from the same tokens (D-X0.8): surface containers = card / nested /
 * control / raised, background = bg, outline = outline, onSurface = text, onSurfaceVariant = text2.
 */
internal val LifeyM3ColorScheme = ColorScheme(
    primary = LifeyColors.primary,
    onPrimary = LifeyColors.onPrimary,
    primaryContainer = LifeyColors.nested,
    onPrimaryContainer = LifeyColors.text,
    secondary = LifeyColors.clay,
    onSecondary = LifeyColors.onPrimary,
    secondaryContainer = LifeyColors.tint(LifeyColors.clay),
    onSecondaryContainer = LifeyColors.clay,
    tertiary = LifeyColors.success,
    onTertiary = LifeyColors.onPrimary,
    tertiaryContainer = LifeyColors.tint(LifeyColors.success),
    onTertiaryContainer = LifeyColors.success,
    surfaceContainerLow = LifeyColors.card,
    surfaceContainer = LifeyColors.nested,
    surfaceContainerHigh = LifeyColors.control,
    onSurface = LifeyColors.text,
    onSurfaceVariant = LifeyColors.text2,
    outline = LifeyColors.outline,
    outlineVariant = LifeyColors.raised,
    background = LifeyColors.bg,
    onBackground = LifeyColors.text,
    error = LifeyColors.error,
    onError = LifeyColors.bg,
    errorContainer = LifeyColors.tint(LifeyColors.error),
    onErrorContainer = LifeyColors.error,
)

/**
 * Tabular figures on the numeric-hero styles only (elapsed time, the rest
 * ring's countdown) — 41-watch-design-prompt.md §1 "Big tabular numbers...
 * so digits don't jump as they tick." Everything else (body/caption/button)
 * keeps the platform default; those styles are never used for a ticking
 * number in this app.
 */
private val LifeyWearTypography = Typography().let { base ->
    Typography(
        display1 = base.display1.copy(fontFeatureSettings = "tnum"),
        display2 = base.display2.copy(fontFeatureSettings = "tnum"),
        display3 = base.display3.copy(fontFeatureSettings = "tnum"),
        title1 = base.title1.copy(fontFeatureSettings = "tnum"),
        title2 = base.title2.copy(fontFeatureSettings = "tnum"),
        title3 = base.title3.copy(fontFeatureSettings = "tnum"),
        body1 = base.body1,
        body2 = base.body2,
        button = base.button,
        caption1 = base.caption1,
        caption2 = base.caption2,
        caption3 = base.caption3,
    )
}

/** Wraps the app's Compose content in the Lifey brand theme
 * (docs/40-watch-app-plan.md §12.1 B6) — applied once in `MainActivity`. No
 * `themes.xml` exists in this module, so without an explicit background here
 * the dial would render on the platform's default (non-black) window
 * background instead of the AMOLED true-black every canvas frame assumes. */
@Composable
fun LifeyTheme(content: @Composable () -> Unit) {
    // Material 3 outside, Material 2 inside: both read the same tokens while screens migrate
    // (D-X0.8); the M2 layer is deleted in X4.16.
    Material3Theme(colorScheme = LifeyM3ColorScheme) {
        MaterialTheme(
            colors = LifeyWearColors,
            typography = LifeyWearTypography,
        ) {
            Box(modifier = Modifier.fillMaxSize().background(MaterialTheme.colors.background)) {
                content()
            }
        }
    }
}
