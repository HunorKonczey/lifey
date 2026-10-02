package com.khunor.lifey.ui.theme

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.wear.compose.material3.ColorScheme
import androidx.wear.compose.material3.MaterialTheme as Material3Theme

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

/** Wraps the app's Compose content in the Lifey brand theme
 * (docs/40-watch-app-plan.md §12.1 B6) — applied once in `MainActivity`. No
 * `themes.xml` exists in this module, so without an explicit background here
 * the dial would render on the platform's default (non-black) window
 * background instead of the AMOLED true-black every canvas frame assumes. */
@Composable
fun LifeyTheme(content: @Composable () -> Unit) {
    // Material 3 only (D-X0.8): the Material 2 layer is gone with X4.16.
    Material3Theme(colorScheme = LifeyM3ColorScheme, typography = LifeyType.m3Typography) {
        BoxWithConstraints(
            modifier = Modifier.fillMaxSize().background(LifeyColors.bg),
        ) {
            // The dial's diameter, once, for every screen below (D-X0.5).
            val metrics = remember(maxWidth.value) { WatchMetrics(maxWidth.value) }
            CompositionLocalProvider(LocalWatchMetrics provides metrics) { content() }
        }
    }
}
