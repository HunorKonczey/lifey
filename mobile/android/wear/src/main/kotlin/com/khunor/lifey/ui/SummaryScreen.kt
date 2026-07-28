package com.khunor.lifey.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.CloudUpload
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
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.wear.compose.material.Icon
import androidx.wear.compose.material.MaterialTheme
import androidx.wear.compose.material.Text
import com.khunor.lifey.R
import com.khunor.lifey.SessionStateHolder
import com.khunor.lifey.StandaloneSessionStore
import com.khunor.lifey.StandaloneSummary
import com.khunor.lifey.ui.theme.LifeyColors
import com.khunor.lifey.ui.theme.LifeyShapes
import kotlin.math.roundToInt
import kotlinx.coroutines.flow.collect

/**
 * "Workout saved" (docs/watch/44-watch-f6-standalone-plan.md D-F6.7, canvas
 * W 14) — shown once [SessionStateHolder.onStandaloneEnded] moves the phase
 * to [com.khunor.lifey.SessionPhase.SUMMARY], for `ExerciseService`'s ~6 s
 * auto-dismiss before falling back to the launcher on its own (mirrors
 * iOS's `SummaryView`, S11). Unlike iOS, there's no "Saved to Health" pill —
 * Android never writes Health Connect from the watch, only the phone does
 * (D-F6.5) — so this is just the 2×2 stat grid plus the sync-status chip.
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

    BoxWithConstraints(modifier = Modifier.fillMaxSize()) {
        val isCompact = isCompactScreen(maxWidth)

        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(horizontal = maxWidth * SCREEN_PADDING_FRACTION),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center,
        ) {
            Icon(
                imageVector = Icons.Filled.CheckCircle,
                contentDescription = null,
                tint = LifeyColors.primary,
                modifier = Modifier.padding(bottom = 4.dp).size(if (isCompact) 32.dp else 40.dp),
            )
            Text(
                text = stringResource(R.string.summary_title),
                style = if (isCompact) MaterialTheme.typography.caption1 else MaterialTheme.typography.title3,
                color = LifeyColors.onSurface,
            )
            val tiles = statTiles(data)
            LazyVerticalGrid(
                columns = GridCells.Fixed(2),
                modifier = Modifier.padding(top = 8.dp),
                horizontalArrangement = Arrangement.spacedBy(6.dp),
                verticalArrangement = Arrangement.spacedBy(6.dp),
                userScrollEnabled = false,
            ) {
                items(tiles) { tile -> StatTile(tile = tile, isCompact = isCompact) }
            }
            SyncChip(
                isSynced = isSynced,
                pendingCount = pendingCount,
                isCompact = isCompact,
                modifier = Modifier.padding(top = 10.dp),
            )
        }
    }
}

private data class SummaryStatTile(val value: String, val label: String, val valueColor: Color)

/** The 4 tiles (canvas W 14: time / sets / avg bpm / kcal) — sets is always
 * present for a standalone summary, unlike iOS's optional `setsCount` tile,
 * since [StandaloneSummary.setsCount] is non-nullable here. */
@Composable
private fun statTiles(data: StandaloneSummary): List<SummaryStatTile> {
    val timeLabel = stringResource(R.string.summary_time_label)
    val setsLabel = stringResource(R.string.summary_sets_label)
    val avgHrLabel = stringResource(R.string.summary_avg_hr_label)
    val kcalLabel = stringResource(R.string.active_calories_unit)
    return buildList {
        add(SummaryStatTile(formatDuration(data.totalDurationSeconds), timeLabel, LifeyColors.onSurface))
        add(SummaryStatTile(data.setsCount.toString(), setsLabel, LifeyColors.onSurface))
        data.averageHeartRate?.let { add(SummaryStatTile(it.roundToInt().toString(), avgHrLabel, LifeyColors.heart)) }
        data.activeCalories?.let { add(SummaryStatTile(it.roundToInt().toString(), kcalLabel, LifeyColors.calories)) }
    }
}

@Composable
private fun StatTile(tile: SummaryStatTile, isCompact: Boolean) {
    Column(
        modifier = Modifier
            .background(LifeyColors.container, LifeyShapes.card)
            .padding(horizontal = 8.dp, vertical = 8.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(
            text = tile.value,
            style = if (isCompact) MaterialTheme.typography.caption1 else MaterialTheme.typography.body1,
            color = tile.valueColor,
        )
        Text(
            text = tile.label,
            style = MaterialTheme.typography.caption3,
            color = LifeyColors.onSurfaceVariant,
        )
    }
}

/** `sync_pending`/`sync_done` chip + the optional `sync_queue_count` line
 * (docs/watch/44-watch-f6-standalone-plan.md §3.6) — flips live once
 * [SessionStateHolder.standaloneSessionAcked] fires for *this* session's id,
 * not just "the queue emptied" (mirrors iOS's identical `.onReceive`). */
@Composable
private fun SyncChip(isSynced: Boolean, pendingCount: Int, isCompact: Boolean, modifier: Modifier = Modifier) {
    Column(modifier = modifier, horizontalAlignment = Alignment.CenterHorizontally) {
        Row(
            modifier = Modifier
                .background(
                    if (isSynced) LifeyColors.tertiaryContainer else LifeyColors.container,
                    LifeyShapes.pill,
                )
                .padding(horizontal = 14.dp, vertical = 6.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            Icon(
                imageVector = if (isSynced) Icons.Filled.CheckCircle else Icons.Filled.CloudUpload,
                contentDescription = null,
                tint = if (isSynced) LifeyColors.tertiary else LifeyColors.onSurfaceVariant,
                modifier = Modifier.size(if (isCompact) 14.dp else 16.dp),
            )
            Text(
                text = stringResource(if (isSynced) R.string.sync_done else R.string.sync_pending),
                style = MaterialTheme.typography.caption3,
                color = if (isSynced) LifeyColors.tertiary else LifeyColors.onSurfaceVariant,
                textAlign = TextAlign.Center,
            )
        }
        if (pendingCount > 1) {
            Text(
                text = stringResource(R.string.sync_queue_count, pendingCount),
                style = MaterialTheme.typography.caption3,
                color = LifeyColors.onSurfaceVariant,
                modifier = Modifier.padding(top = 4.dp),
            )
        }
    }
}

private fun formatDuration(totalSeconds: Int): String = "%02d:%02d".format(totalSeconds / 60, totalSeconds % 60)
