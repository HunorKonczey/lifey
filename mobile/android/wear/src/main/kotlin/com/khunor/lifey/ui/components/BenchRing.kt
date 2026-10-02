package com.khunor.lifey.ui.components

import androidx.compose.foundation.border
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.khunor.lifey.ui.theme.LifeyColors

/**
 * Bench ring (frame 04/13): a 4 dp clay ring around the dial while a team-sport player is on the bench.
 * Ambient: 2 dp at 60 %.
 */
@Composable
fun BenchRing(modifier: Modifier = Modifier, isAmbient: Boolean = false) {
    val color = if (isAmbient) LifeyColors.clay.copy(alpha = 0.6f) else LifeyColors.clay
    Box(modifier.fillMaxSize().border(if (isAmbient) 2.dp else 4.dp, color, CircleShape))
}
