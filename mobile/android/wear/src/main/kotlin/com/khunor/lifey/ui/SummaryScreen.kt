package com.khunor.lifey.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.wear.compose.material.Icon
import androidx.wear.compose.material.Text
import androidx.wear.compose.material3.TimeText
import com.khunor.lifey.R
import com.khunor.lifey.SessionStateHolder
import com.khunor.lifey.StandaloneSessionStore
import com.khunor.lifey.StandaloneSummary
import com.khunor.lifey.ui.components.SummaryTile
import com.khunor.lifey.ui.components.SyncRow
import com.khunor.lifey.ui.theme.LifeyColors
import com.khunor.lifey.ui.theme.LifeySpacing
import com.khunor.lifey.ui.theme.LifeyType
import com.khunor.lifey.ui.theme.LocalWatchMetrics
import kotlin.math.roundToInt

/** What the standalone summary shows (frames W2.8 / W2.9), as plain data for the DEBUG gallery. */
data class SummaryModel(
    val durationSeconds: Int,
    val sets: Int,
    val averageHeartRate: Int?,
    val kcal: Int?,
    val isSynced: Boolean,
    /** Sessions still waiting in the local queue (the "n edzés vár" line shows from two on). */
    val pendingCount: Int,
)

/**
 * "Workout saved" (docs/watch/44 D-F6.7; frames W2.8 / W2.9): the check beside the title, the [SyncRow] right
 * under it in the widest band (pending `nested` ↔ synced success tint, switching live), then four compact
 * centred tiles in a 2 × 2 grid at full size — the old ~85 % squeeze is gone. There is no Health row on Wear:
 * the phone writes Health Connect, as before.
 */
@Composable
fun SummaryContent(model: SummaryModel, modifier: Modifier = Modifier) {
    val metrics = LocalWatchMetrics.current
    val width = metrics.widthDp
    val tiles = buildList {
        add(Tile(model.durationSeconds.toDouble(), { formatDuration(it.toInt()) }, stringResource(R.string.summary_time_label), LifeyColors.text))
        add(Tile(model.sets.toDouble(), { it.roundToInt().toString() }, stringResource(R.string.summary_sets_label), LifeyColors.text))
        model.averageHeartRate?.let {
            add(Tile(it.toDouble(), { v -> v.roundToInt().toString() }, stringResource(R.string.summary_avg_hr_label), LifeyColors.heart))
        }
        model.kcal?.let {
            add(Tile(it.toDouble(), { v -> v.roundToInt().toString() }, stringResource(R.string.active_calories_unit), LifeyColors.calories))
        }
    }
    Box(modifier.fillMaxSize()) {
        Column(
            Modifier.align(Alignment.TopCenter)
                .padding(top = (width * (if (metrics.isCompact) 0.10f else 0.13f)).dp)
                .widthIn(max = (width * 0.78f).dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(if (metrics.isCompact) LifeySpacing.xs else LifeySpacing.sm),
        ) {
            Row(horizontalArrangement = Arrangement.spacedBy(LifeySpacing.sm), verticalAlignment = Alignment.CenterVertically) {
                Icon(Icons.Filled.CheckCircle, contentDescription = null, tint = LifeyColors.success, modifier = Modifier.size(18.dp))
                Text(stringResource(R.string.summary_title), style = LifeyType.title(), color = LifeyColors.text, maxLines = 1)
            }
            SyncRow(
                isSynced = model.isSynced,
                title = stringResource(if (model.isSynced) R.string.sync_done else R.string.sync_pending),
                subtitle = if (model.pendingCount > 1) stringResource(R.string.sync_queue_count, model.pendingCount) else null,
                dense = true,
            )
            tiles.chunked(2).forEach { rowTiles ->
                Row(horizontalArrangement = Arrangement.spacedBy(LifeySpacing.xs)) {
                    rowTiles.forEach { tile ->
                        SummaryTile(tile.number, tile.format, tile.label, modifier = Modifier.weight(1f), tint = tile.tint, dense = true)
                    }
                }
            }
        }
        TimeText()
    }
}

private class Tile(val number: Double, val format: (Double) -> String, val label: String, val tint: Color)

/**
 * The stateful summary, shown once [SessionStateHolder.onStandaloneEnded] moves the phase to SUMMARY, for
 * `ExerciseService`'s ~6 s auto-dismiss (unchanged). The sync state flips live when
 * [SessionStateHolder.standaloneSessionAcked] fires for *this* session's id, not just when the queue empties.
 */
@Composable
fun SummaryScreen() {
    val summary by SessionStateHolder.standaloneSummary.collectAsState()
    val data = summary ?: return
    val context = LocalContext.current

    var isSynced by remember(data.standaloneSessionId) {
        mutableStateOf(
            StandaloneSessionStore.all(context)
                .none { it.optString("standaloneSessionId") == data.standaloneSessionId },
        )
    }
    var pendingCount by remember(data.standaloneSessionId) {
        mutableIntStateOf(StandaloneSessionStore.all(context).size)
    }

    LaunchedEffect(data.standaloneSessionId) {
        SessionStateHolder.standaloneSessionAcked.collect { ackedId ->
            pendingCount = StandaloneSessionStore.all(context).size
            if (ackedId == data.standaloneSessionId) {
                isSynced = true
            }
        }
    }

    SummaryContent(data.toModel(isSynced, pendingCount))
}

private fun StandaloneSummary.toModel(isSynced: Boolean, pendingCount: Int) = SummaryModel(
    durationSeconds = totalDurationSeconds,
    sets = setsCount,
    averageHeartRate = averageHeartRate?.roundToInt(),
    kcal = activeCalories?.roundToInt(),
    isSynced = isSynced,
    pendingCount = pendingCount,
)

private fun formatDuration(totalSeconds: Int): String = "%02d:%02d".format(totalSeconds / 60, totalSeconds % 60)
