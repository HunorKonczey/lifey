package com.khunor.lifey.ui.active

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.LocalFireDepartment
import androidx.compose.material.icons.filled.Timer
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.wear.compose.material.MaterialTheme
import androidx.wear.compose.material.Text
import com.khunor.lifey.R
import com.khunor.lifey.ui.components.HeartRateState
import com.khunor.lifey.ui.components.MetricLevel
import com.khunor.lifey.ui.components.MetricReading
import com.khunor.lifey.ui.components.RestRing
import com.khunor.lifey.ui.theme.LifeyColors
import com.khunor.lifey.ui.theme.LifeySpacing
import com.khunor.lifey.ui.theme.LifeyType
import com.khunor.lifey.ui.theme.LocalWatchMetrics

/** What the rest page shows (frames W1.10 / W1.11), as plain data for the DEBUG gallery. */
data class RestModel(
    val remainingMs: Long,
    /** Null for a rest that has no known total: the ring then stays full and the "/ 1:30" line is omitted. */
    val totalSeconds: Int?,
    val exerciseName: String,
    val setsDone: Int?,
    val setsTotal: Int?,
    val heartRate: HeartRateState,
    val kcal: Int?,
    val showsStandaloneMark: Boolean = false,
)

/**
 * Rest page (W1.10 / W1.11): a 6 dp [RestRing] at the display edge instead of the horizontal bar, the hero
 * "0:47" with "/ 1:30" under it, "Következő · …" on two centred lines, and the HR + kcal row at `value` level
 * on the bottom chord — numbers only, the icons say which is which, so the row fits the chord at 192 dp. The last five seconds turn the ring remainder and the hero `calories` and pulse once a
 * second (inside [RestRing]). The 400 ms expiry vibration stays in the foreground service.
 */
@Composable
fun RestContent(model: RestModel, modifier: Modifier = Modifier) {
    val width = LocalWatchMetrics.current.widthDp
    val seconds = (model.remainingMs / 1000).toInt()
    val nextLine = if (model.setsDone != null && model.setsTotal != null) {
        stringResource(
            R.string.rest_hero_next_with_sets_format,
            model.exerciseName, (model.setsDone + 1).coerceAtMost(model.setsTotal), model.setsTotal,
        )
    } else {
        stringResource(R.string.rest_hero_next_format, model.exerciseName)
    }
    Box(modifier.fillMaxSize()) {
        RestRing(
            remainingSeconds = seconds,
            totalSeconds = model.totalSeconds ?: seconds,
            showTotal = model.totalSeconds != null,
            heroOffset = -(width * 0.09f).dp,
        )
        ActiveHeader(
            icon = Icons.Filled.Timer, label = stringResource(R.string.rest_hero_label),
            showsStandaloneMark = model.showsStandaloneMark,
            modifier = Modifier.align(Alignment.TopCenter).padding(top = (width * 0.14f).dp),
        )
        Text(
            // Two deliberate lines: "Következő ·" / "Fekvenyomás — 3/4. szett".
            text = nextLine.replace(" · ", " ·\n"),
            style = LifeyType.body(), color = LifeyColors.text, textAlign = TextAlign.Center,
            maxLines = 2, overflow = TextOverflow.Ellipsis,
            modifier = Modifier.align(Alignment.Center).offset(y = (width * 0.17f).dp).widthIn(max = (width * 0.72f).dp),
        )
        Row(
            Modifier.align(Alignment.BottomCenter).padding(bottom = (width * 0.13f).dp),
            horizontalArrangement = Arrangement.spacedBy(LifeySpacing.lg),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            val heart = model.heartRate
            if (heart is HeartRateState.Live) {
                MetricReading(Icons.Filled.Favorite, LifeyColors.heart, heart.bpm.toString(), level = MetricLevel.Value)
            } else {
                // Missing or denied: the one missing-HR rule — a ghost heart and a dash, never a gap.
                MetricReading(Icons.Filled.Favorite, LifeyColors.ghost, "—", level = MetricLevel.Value)
            }
            model.kcal?.let {
                MetricReading(Icons.Filled.LocalFireDepartment, LifeyColors.calories, it.toString(), level = MetricLevel.Value)
            }
        }
    }
}
