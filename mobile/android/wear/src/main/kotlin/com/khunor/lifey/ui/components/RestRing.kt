package com.khunor.lifey.ui.components

import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.scale
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.unit.dp
import androidx.wear.compose.material.Text
import androidx.wear.compose.material3.CircularProgressIndicator
import androidx.wear.compose.material3.ProgressIndicatorDefaults
import com.khunor.lifey.ui.theme.LifeyColors
import com.khunor.lifey.ui.theme.LifeyType
import com.khunor.lifey.ui.theme.rememberReducedMotion

/** Seconds → "m:ss". */
fun formatRest(seconds: Int): String = "%d:%02d".format(maxOf(seconds, 0) / 60, maxOf(seconds, 0) % 60)

/** The last five seconds are the warning window (the warning role is `calories`). */
const val REST_WARNING_SECONDS = 5

/**
 * Rest ring (frame 04/06, Wear variant): a full-screen 6 dp M3 [CircularProgressIndicator] — white on a
 * `control` track — with the hero number in the centre and "/ 1:30" under it. Last 5 s: the ring remainder
 * and the hero turn `calories` and the number pulses 100 → 92 % at 1 Hz (off with reduced motion). Driven
 * by the existing `elapsedRealtime`-based state: [remainingSeconds] comes from there.
 */
@Composable
fun RestRing(remainingSeconds: Int, totalSeconds: Int, modifier: Modifier = Modifier) {
    val reduced = rememberReducedMotion()
    val warning = remainingSeconds in 1..REST_WARNING_SECONDS
    val accent = if (warning) LifeyColors.calories else LifeyColors.text
    val fraction = if (totalSeconds > 0) (remainingSeconds.toFloat() / totalSeconds).coerceIn(0f, 1f) else 0f
    val animated by animateFloatAsState(fraction, tween(if (reduced) 0 else 1000, easing = LinearEasing), label = "rest-drain")
    val pulse = if (warning && !reduced && remainingSeconds % 2 == 0) 0.92f else 1f

    Box(
        modifier.fillMaxSize().clearAndSetSemantics { contentDescription = formatRest(remainingSeconds) },
        contentAlignment = Alignment.Center,
    ) {
        CircularProgressIndicator(
            progress = { animated },
            modifier = Modifier.fillMaxSize().padding(3.dp),
            strokeWidth = 6.dp,
            colors = ProgressIndicatorDefaults.colors(indicatorColor = accent, trackColor = LifeyColors.control),
        )
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Text(formatRest(remainingSeconds), style = LifeyType.hero(), color = accent, modifier = Modifier.scale(pulse))
            Text("/ ${formatRest(totalSeconds)}", style = LifeyType.body(), color = LifeyColors.text2)
        }
    }
}
