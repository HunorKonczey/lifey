package com.khunor.lifey.debug

import androidx.compose.runtime.Composable
import com.khunor.lifey.ui.IdleScreen

/**
 * Fixtures of the Wear start / standalone / cardio canvas (`Lifey Watch 4 Wear OS Start Standalone Cardio`,
 * frames W2.1–W2.21), registered next to the W1 ones (see [w1Frames]); each X4 step adds its frames.
 *
 *     adb shell am start -n com.khunor.lifey/.debug.DesignGalleryActivity --es frame W2.1 [--ei width 192]
 */
val w2Frames: Map<String, @Composable () -> Unit> = mapOf(
    "W2.1" to frame2 { IdleScreen(onStartTapped = {}) },
)

/** Gives the lambda a @Composable function type up front. */
private fun frame2(content: @Composable () -> Unit): @Composable () -> Unit = content
