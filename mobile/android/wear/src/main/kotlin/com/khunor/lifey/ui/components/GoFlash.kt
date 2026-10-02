package com.khunor.lifey.ui.components

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.tween
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.wear.compose.material.Text
import com.khunor.lifey.R
import com.khunor.lifey.ui.theme.LifeyColors
import com.khunor.lifey.ui.theme.LifeyMotion
import com.khunor.lifey.ui.theme.LifeyType
import com.khunor.lifey.ui.theme.rememberReducedMotion
import kotlinx.coroutines.delay

/**
 * "Mehet!" ring (frame 04/07, D3): instead of a full green screen, a 9 dp primary ring where the rest ring
 * was and a white "Mehet!" in the middle. 150 ms in · 250 ms hold · 700 ms out — unchanged timing. Reduced
 * motion: the ring is shown statically for 1.1 s. The haptic fires independently in `ExerciseService`.
 * Replaying = changing [replayToken].
 */
@Composable
fun GoFlash(modifier: Modifier = Modifier, replayToken: Int = 0) {
    val reduced = rememberReducedMotion()
    val alpha = remember { Animatable(0f) }
    LaunchedEffect(replayToken) {
        if (reduced) {
            alpha.snapTo(1f)
            delay(LifeyMotion.GO_STATIC_MS.toLong())
            alpha.snapTo(0f)
        } else {
            alpha.snapTo(0f)
            alpha.animateTo(1f, tween(LifeyMotion.GO_IN, easing = LifeyMotion.Enter))
            delay(LifeyMotion.GO_HOLD.toLong())
            alpha.animateTo(0f, tween(LifeyMotion.GO_OUT, easing = LifeyMotion.Exit))
        }
    }
    Box(
        modifier.fillMaxSize().graphicsLayer { this.alpha = alpha.value }.border(9.dp, LifeyColors.primary, CircleShape),
        contentAlignment = Alignment.Center,
    ) {
        Text(stringResource(R.string.rest_go_label), style = LifeyType.hero(dense = true), color = LifeyColors.text, maxLines = 1)
    }
}
