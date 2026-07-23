package com.khunor.lifey.ui.theme

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.wear.compose.material.Colors
import androidx.wear.compose.material.MaterialTheme
import androidx.wear.compose.material.Typography

/**
 * Maps [LifeyColors] onto Wear Compose Material's [Colors] slots
 * (docs/40-watch-app-plan.md §12.1 B6 / 41-watch-design-prompt.md §2) —
 * `primaryContainer`/`container` share one hex in the prompt's own token
 * table, so `primaryVariant` reuses [LifeyColors.container] rather than
 * inventing a darker primary shade. `background` is true black, not
 * [LifeyColors.bg]: every canvas frame renders the dial content directly on
 * `#000`, using `bg`/`surface`/`container` only for specific chips and cards
 * (§2.1's own note: "on watch: may sit on #000000").
 */
private val LifeyWearColors = Colors(
    primary = LifeyColors.primary,
    primaryVariant = LifeyColors.container,
    secondary = LifeyColors.secondary,
    secondaryVariant = LifeyColors.secondaryContainer,
    background = LifeyColors.trueBlack,
    surface = LifeyColors.surface,
    error = LifeyColors.error,
    onPrimary = LifeyColors.onPrimary,
    onSecondary = LifeyColors.onPrimary,
    onBackground = LifeyColors.onSurface,
    onSurface = LifeyColors.onSurface,
    onSurfaceVariant = LifeyColors.onSurfaceVariant,
    onError = LifeyColors.onError,
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
    MaterialTheme(
        colors = LifeyWearColors,
        typography = LifeyWearTypography,
    ) {
        Box(modifier = Modifier.fillMaxSize().background(MaterialTheme.colors.background)) {
            content()
        }
    }
}
