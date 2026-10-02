package com.khunor.lifey.ui.active

import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.DirectionsBike
import androidx.compose.material.icons.outlined.AirlineSeatReclineNormal
import androidx.compose.material.icons.outlined.DirectionsRun
import androidx.compose.material.icons.outlined.DirectionsWalk
import androidx.compose.material.icons.outlined.FavoriteBorder
import androidx.compose.material.icons.outlined.Hiking
import androidx.compose.material.icons.outlined.MonitorHeart
import androidx.compose.material.icons.outlined.PedalBike
import androidx.compose.material.icons.outlined.SportsBasketball
import androidx.compose.material.icons.outlined.SportsSoccer
import androidx.compose.material.icons.outlined.FitnessCenter
import androidx.compose.material.icons.outlined.Timer
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.wear.compose.material3.Icon
import androidx.wear.compose.material3.Text
import com.khunor.lifey.R
import com.khunor.lifey.ui.components.BenchRing
import com.khunor.lifey.ui.components.truncate
import com.khunor.lifey.ui.theme.AmbientFormat
import com.khunor.lifey.ui.theme.AmbientState
import com.khunor.lifey.ui.theme.AmbientStyle
import com.khunor.lifey.ui.theme.LifeyColors
import com.khunor.lifey.ui.theme.LifeySpacing
import com.khunor.lifey.ui.theme.LifeyType
import com.khunor.lifey.ui.theme.LocalWatchMetrics
import com.khunor.lifey.ui.theme.ambientBurnInShift

/**
 * The Always-On layouts of the active screens (frames W2.17–W2.19, D-X0.15): pure black, nothing filled, no
 * buttons, pills, page indicator or TimeText, numbers in the light PJS style in `text2`, the metric colours at
 * 60 % with *outlined* icons, time at minute resolution, and a ±4 dp shift that changes every minute against
 * burn-in. They are plain data → UI so the DEBUG gallery can render them; the live screens recompute their
 * inputs from `SystemClock.elapsedRealtime()` on every ambient update (once a minute) and on exit, so no
 * stale frame comes back.
 */

/** The ambient metric page (W2.17): header, "12 p" hero, heart rate at 60 %, a quiet exercise line. */
@Composable
fun AmbientMetricsContent(
    state: AmbientState,
    headerLabel: String,
    elapsedSeconds: Int,
    heartRateBpm: Int?,
    exerciseLine: String,
    modifier: Modifier = Modifier,
    headerIcon: ImageVector = Icons.Outlined.FitnessCenter,
) {
    val width = LocalWatchMetrics.current.widthDp
    Box(modifier.fillMaxSize().ambientBurnInShift(state)) {
        Column(
            Modifier.align(Alignment.TopCenter).padding(top = (width * 0.16f).dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(LifeySpacing.xs),
        ) {
            AmbientHeader(headerIcon, headerLabel)
            Text(
                AmbientFormat.elapsed(elapsedSeconds, stringResource(R.string.aod_minutes), stringResource(R.string.aod_hours_minutes)),
                style = LifeyType.aodHero(), color = AmbientStyle.number, maxLines = 1,
            )
            AmbientHeartRate(heartRateBpm)
        }
        AmbientLine(exerciseLine, Modifier.align(Alignment.BottomCenter).padding(bottom = (width * 0.16f).dp))
    }
}

/** Outlined icon + CAPS label in `text2` (the header of every ambient page). */
@Composable
internal fun AmbientHeader(icon: ImageVector, label: String, tint: androidx.compose.ui.graphics.Color = LifeyColors.text2) {
    androidx.compose.foundation.layout.Row(
        horizontalArrangement = Arrangement.spacedBy(LifeySpacing.xs), verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(icon, contentDescription = null, tint = tint, modifier = Modifier.size(14.dp))
        Text(truncate(label).uppercase(), style = LifeyType.label(), color = tint, maxLines = 1, overflow = TextOverflow.Ellipsis)
    }
}

/** The heart rate at 60 % with the outlined heart; a missing reading draws nothing in ambient. */
@Composable
internal fun AmbientHeartRate(bpm: Int?) {
    if (bpm == null) return
    androidx.compose.foundation.layout.Row(
        horizontalArrangement = Arrangement.spacedBy(LifeySpacing.xs), verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(Icons.Outlined.FavoriteBorder, contentDescription = null, tint = AmbientStyle.metricTint(LifeyColors.heart), modifier = Modifier.size(16.dp))
        Text(bpm.toString(), style = LifeyType.metric(), color = AmbientStyle.metricTint(LifeyColors.heart), maxLines = 1)
    }
}

/** The one quiet line near the bottom chord. */
@Composable
internal fun AmbientLine(text: String, modifier: Modifier = Modifier) {
    val width = LocalWatchMetrics.current.widthDp
    Text(
        text, modifier = modifier.widthIn(max = (width * 0.7f).dp), style = LifeyType.body(), color = LifeyColors.text2,
        textAlign = TextAlign.Center, maxLines = 2, overflow = TextOverflow.Ellipsis,
    )
}

/**
 * The ambient rest page (W2.18): the edge ring is a static 2 dp `text3` outline, the header "PIHENŐ", the
 * remaining time rounded *up* to minutes ("~1 p") with the clock time the rest ends ("Mehet 9:42-kor"), and the
 * "Következő · …" line at the bottom. The end time is computed from the real deadline, so it equals the moment
 * of the expiry vibration, which stays in `ExerciseService`.
 */
@Composable
fun AmbientRestContent(
    state: AmbientState,
    remainingSeconds: Int,
    endsAtEpochMs: Long,
    nextLine: String,
    modifier: Modifier = Modifier,
) {
    val width = LocalWatchMetrics.current.widthDp
    Box(modifier.fillMaxSize().ambientBurnInShift(state)) {
        Box(Modifier.fillMaxSize().padding(2.dp).border(2.dp, LifeyColors.text3, CircleShape))
        Column(
            Modifier.align(Alignment.TopCenter).padding(top = (width * 0.16f).dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(LifeySpacing.xs),
        ) {
            AmbientHeader(Icons.Outlined.Timer, stringResource(R.string.rest_hero_label))
            Text(
                AmbientFormat.remaining(remainingSeconds, stringResource(R.string.aod_minutes)),
                style = LifeyType.aodHero(), color = AmbientStyle.number, maxLines = 1,
            )
            Text(
                AmbientFormat.restUntil(endsAtEpochMs, stringResource(R.string.aod_rest_until)),
                style = LifeyType.title(), color = LifeyColors.text2, maxLines = 1,
            )
        }
        AmbientLine(
            nextLine.replace(" · ", " ·\n"),
            Modifier.align(Alignment.BottomCenter).padding(bottom = (width * 0.14f).dp),
        )
    }
}

/** Outlined counterpart of [cardioActivityIcon] — ambient mode draws no filled shapes. */
fun cardioActivityIconOutlined(activityType: String): ImageVector = when (activityType) {
    "RUNNING" -> Icons.Outlined.DirectionsRun
    "WALKING" -> Icons.Outlined.DirectionsWalk
    "HIKING" -> Icons.Outlined.Hiking
    "CYCLING" -> Icons.AutoMirrored.Outlined.DirectionsBike
    "INDOOR_BIKE" -> Icons.Outlined.PedalBike
    "BASKETBALL" -> Icons.Outlined.SportsBasketball
    "FOOTBALL" -> Icons.Outlined.SportsSoccer
    else -> Icons.Outlined.MonitorHeart
}

/**
 * The ambient cardio page (no Wear canvas frame — derived from AW2.22, noted in the review log): the activity
 * accent at 60 % on the outlined header, the hero centred in the light style in `text2` (a distance keeps its
 * decimals and unit; a duration drops to minutes), the heart rate at 60 %, and one quiet field line.
 */
@Composable
fun AmbientCardioContent(
    state: AmbientState,
    headerLabel: String,
    headerIcon: ImageVector,
    accent: androidx.compose.ui.graphics.Color,
    hero: String,
    heartRateBpm: Int?,
    fieldLine: String?,
    modifier: Modifier = Modifier,
) {
    val width = LocalWatchMetrics.current.widthDp
    Box(modifier.fillMaxSize().ambientBurnInShift(state)) {
        Column(
            Modifier.align(Alignment.TopCenter).padding(top = (width * 0.16f).dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(LifeySpacing.xs),
        ) {
            AmbientHeader(headerIcon, headerLabel, tint = AmbientStyle.metricTint(accent))
            Text(hero, style = LifeyType.aodHero(), color = AmbientStyle.number, maxLines = 1)
            AmbientHeartRate(heartRateBpm)
        }
        if (fieldLine != null) AmbientLine(fieldLine, Modifier.align(Alignment.BottomCenter).padding(bottom = (width * 0.16f).dp))
    }
}

/**
 * The ambient bench page (W2.19): the clay ring at 2 dp / 60 %, "PADON" and "Játékidő — áll" with the stopped
 * play time *with* seconds (it does not tick, so seconds are honest), the heart rate at 60 % and the gross time
 * in minutes ("Bruttó idő 16 p"). No buttons.
 */
@Composable
fun AmbientBenchContent(
    state: AmbientState,
    playTime: String,
    heartRateBpm: Int?,
    grossLine: String?,
    modifier: Modifier = Modifier,
) {
    val width = LocalWatchMetrics.current.widthDp
    Box(modifier.fillMaxSize().ambientBurnInShift(state)) {
        BenchRing(isAmbient = true)
        Column(
            Modifier.align(Alignment.TopCenter).padding(top = (width * 0.16f).dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(LifeySpacing.xs),
        ) {
            AmbientHeader(
                Icons.Outlined.AirlineSeatReclineNormal, stringResource(R.string.cardio_on_bench_header_label),
                tint = AmbientStyle.metricTint(LifeyColors.clay),
            )
            Text(stringResource(R.string.cardio_game_paused_primary_label).uppercase(), style = LifeyType.label(), color = LifeyColors.text2, maxLines = 1)
            Text(playTime, style = LifeyType.aodHero(), color = AmbientStyle.number, maxLines = 1)
            AmbientHeartRate(heartRateBpm)
        }
        if (grossLine != null) AmbientLine(grossLine, Modifier.align(Alignment.BottomCenter).padding(bottom = (width * 0.16f).dp))
    }
}

/** Whole minutes in a "mm:ss" or "h:mm:ss" clock string (the phone's gross time arrives pre-formatted); null if unparsable. */
internal fun clockMinutes(clock: String?): Int? {
    val parts = clock?.split(':')?.mapNotNull { it.trim().toIntOrNull() } ?: return null
    return when (parts.size) {
        2 -> parts[0]
        3 -> parts[0] * 60 + parts[1]
        else -> null
    }
}
