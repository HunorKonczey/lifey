package com.khunor.lifey.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Eco
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.wear.compose.material.Icon
import androidx.wear.compose.material.Text
import androidx.wear.compose.material3.Button
import androidx.wear.compose.material3.TimeText
import com.khunor.lifey.R
import com.khunor.lifey.ui.theme.LifeyColors
import com.khunor.lifey.ui.theme.LifeySpacing
import com.khunor.lifey.ui.theme.LifeyType
import com.khunor.lifey.ui.theme.LocalWatchMetrics

/**
 * No active session — the **launcher** (docs/watch/44 §3.1; frame W2.1): a small brand moment — the
 * Material `Eco` leaf in a `nested` holder (one source for both platforms, the hand-drawn `LeafMark` is
 * gone) and the PJS wordmark — over the 52 dp M3 "Edzés indítása" button, which is the screen's only
 * saturated element and opens the picker. The old subtitle stays a quiet line under it.
 */
@Composable
fun IdleScreen(onStartTapped: () -> Unit) {
    val metrics = LocalWatchMetrics.current
    val startA11yLabel = stringResource(R.string.standalone_start_button_a11y)
    Box(Modifier.fillMaxSize()) {
        Column(
            Modifier.align(Alignment.Center).padding(horizontal = metrics.sideMargin).padding(top = LifeySpacing.lg),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(LifeySpacing.md),
        ) {
            Box(
                Modifier.size(44.dp).background(LifeyColors.nested, RoundedCornerShape(14.dp)),
                contentAlignment = Alignment.Center,
            ) {
                Icon(Icons.Filled.Eco, contentDescription = null, tint = LifeyColors.primary, modifier = Modifier.size(24.dp))
            }
            Text(stringResource(R.string.idle_title), style = LifeyType.metric(), color = LifeyColors.text, maxLines = 1)
            Button(
                onClick = onStartTapped,
                modifier = Modifier.fillMaxWidth().height(metrics.buttonHeight).semantics { contentDescription = startA11yLabel },
            ) {
                Text(stringResource(R.string.standalone_start_button), style = LifeyType.title(), color = LifeyColors.onPrimary, maxLines = 1)
            }
            Text(
                stringResource(R.string.standalone_start_caption), style = LifeyType.body(), color = LifeyColors.text2,
                textAlign = TextAlign.Center, maxLines = 2,
            )
        }
        TimeText()
    }
}
