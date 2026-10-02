package com.khunor.lifey.ui.active

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AirlineSeatReclineNormal
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.em
import androidx.wear.compose.material3.Icon
import androidx.wear.compose.material3.Text
import com.khunor.lifey.R
import com.khunor.lifey.ui.components.BenchRing
import com.khunor.lifey.ui.components.LifeyEdgeButton
import com.khunor.lifey.ui.components.CardioField
import com.khunor.lifey.ui.components.HeartRateSlot
import com.khunor.lifey.ui.components.HeartRateState
import com.khunor.lifey.ui.theme.LifeyColors
import com.khunor.lifey.ui.theme.LifeyNumber
import com.khunor.lifey.ui.theme.LifeySpacing
import com.khunor.lifey.ui.theme.LifeyType
import com.khunor.lifey.ui.theme.LocalWatchMetrics

/** One boxless field under the heart rate: the value above, the phone-supplied label under it. */
data class CardioFieldModel(val value: String, val label: String)

/**
 * What a distance or machine cardio page shows (frames W2.10, W2.11, W2.14), as plain data for the DEBUG
 * gallery. [primaryValue] may carry its unit ("3.42 km"); the hero shows the number in PJS and the unit as a
 * label beside it. The activity [accent] is on the header only — the hero is white, like on strength.
 */
data class CardioModel(
    val headerLabel: String,
    val activityIcon: ImageVector,
    val accent: Color,
    val primaryLabel: String,
    val primaryValue: String,
    val heartRate: HeartRateState,
    val fields: List<CardioFieldModel> = emptyList(),
    val isPaused: Boolean = false,
    val showsStandaloneMark: Boolean = false,
)

/** "3.42 km" → ("3.42", "km"); a value without a trailing unit ("24:10") stays whole. */
internal fun splitUnit(value: String): Pair<String, String?> {
    val at = value.lastIndexOf(' ')
    return if (at <= 0) value to null else value.substring(0, at) to value.substring(at + 1)
}

/**
 * Distance / machine cardio page (W2.10 / W2.11): the activity-accent header, the phone's primary label in
 * CAPS, the hero (distance, or the ticking moving time) in white PJS 48 sp, the heart-rate slot at strength's
 * size — level two, with "bpm" — and the supporting values *boxless* under it: one centred pace line for
 * distance, two side by side for a machine, their labels wrapping to two lines instead of clipping
 * ("ÁTLAG / TELJESÍTMÉNY"). A missing heart rate or missing permission is the slot's own state (W2.14).
 */
@Composable
fun CardioContent(
    model: CardioModel,
    onRequestHeartRatePermission: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val metrics = LocalWatchMetrics.current
    val width = metrics.widthDp
    val (number, unit) = splitUnit(model.primaryValue)
    // Two long phone labels ("ÁTLAG / TELJESÍTMÉNY") side by side need the widest band of the dial: the stack above
    // them tightens, and on the compact dial the primary label line goes (the header and hero say the same).
    val twoFields = model.fields.size == 2
    Box(modifier.fillMaxSize()) {
        Column(
            Modifier.align(Alignment.TopCenter).padding(top = (width * (if (twoFields) 0.12f else 0.14f)).dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(if (twoFields) 0.dp else LifeySpacing.xxs),
        ) {
            ActiveHeader(
                model.activityIcon, model.headerLabel, isPaused = model.isPaused,
                showsStandaloneMark = model.showsStandaloneMark, accent = model.accent,
            )
            if (!(twoFields && metrics.isCompact)) {
                Text(model.primaryLabel.uppercase(), style = LifeyType.label(), color = LifeyColors.text2, maxLines = 1)
            }
            CardioHero(number, unit)
            HeartRateSlot(model.heartRate, onRequestPermission = onRequestHeartRatePermission)
            when (model.fields.size) {
                0 -> Unit
                1 -> CardioField(model.fields[0].value, model.fields[0].label, Modifier.padding(top = LifeySpacing.xs))
                else -> Row(
                    Modifier.padding(top = LifeySpacing.xs).fillMaxWidth(0.86f),
                    horizontalArrangement = Arrangement.spacedBy(LifeySpacing.md),
                ) {
                    model.fields.take(2).forEach { CardioField(it.value, it.label, Modifier.weight(1f)) }
                }
            }
        }
    }
}

/** The white PJS hero with its unit beside it; the line height is tight so the stack fits above the bottom chord. */
@Composable
internal fun CardioHero(number: String, unit: String?, dense: Boolean = false) {
    LifeyNumber(
        number = number, unit = unit,
        style = LifeyType.hero(dense = dense).copy(lineHeight = 1.05.em),
        color = LifeyColors.text,
    )
}

/** What a team-sport page shows (frames W2.12, W2.13), as plain data. */
data class GameModel(
    val headerLabel: String,
    val activityIcon: ImageVector,
    val accent: Color,
    val onCourt: Boolean,
    /** The phone's play-time label ("Játékidő"); on the bench the "Játékidő — áll" string replaces it. */
    val playLabel: String,
    val playTime: String,
    val grossValue: String?,
    val grossLabel: String?,
    val heartRate: HeartRateState,
    val isPaused: Boolean = false,
    val showsStandaloneMark: Boolean = false,
)

/**
 * Team-sport page (W2.12 field / W2.13 bench): header, play-time label with the small primary dot, the hero,
 * the heart-rate slot with the gross time beside it — boxless — and the court/bench switch as a primary
 * EdgeButton on the bottom arc ("Padra" with the bench glyph; "Vissza a pályára" with the activity icon).
 * On the bench the header turns clay "PADON", the label reads "Játékidő — áll", the hero is `text2` (the
 * clock is stopped) and a 4 dp clay [BenchRing] hugs the display — the round shape is an advantage here.
 */
@Composable
fun GameContent(
    model: GameModel,
    onToggleCourt: () -> Unit,
    onRequestHeartRatePermission: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val metrics = LocalWatchMetrics.current
    val width = metrics.widthDp
    val bench = !model.onCourt
    val tint = if (bench) LifeyColors.clay else model.accent
    Box(modifier.fillMaxSize()) {
        Column(
            Modifier.align(Alignment.TopCenter).padding(top = (width * 0.14f).dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(LifeySpacing.xxs),
        ) {
            ActiveHeader(
                icon = if (bench) Icons.Filled.AirlineSeatReclineNormal else model.activityIcon,
                label = if (bench) stringResource(R.string.cardio_on_bench_header_label) else model.headerLabel,
                isPaused = model.isPaused, showsStandaloneMark = model.showsStandaloneMark, accent = tint,
            )
            Row(horizontalArrangement = Arrangement.spacedBy(LifeySpacing.sm), verticalAlignment = Alignment.CenterVertically) {
                if (!bench) Box(Modifier.size(6.dp).background(LifeyColors.primary, CircleShape))
                Text(
                    (if (bench) stringResource(R.string.cardio_game_paused_primary_label) else model.playLabel).uppercase(),
                    style = LifeyType.label(), color = LifeyColors.text2, maxLines = 1,
                )
            }
            LifeyNumber(
                number = model.playTime,
                style = LifeyType.hero(dense = true).copy(lineHeight = 1.05.em),
                color = if (bench) LifeyColors.text2 else LifeyColors.text,
            )
            Row(horizontalArrangement = Arrangement.spacedBy(LifeySpacing.lg), verticalAlignment = Alignment.CenterVertically) {
                HeartRateSlot(model.heartRate, onRequestPermission = onRequestHeartRatePermission)
                if (model.grossValue != null && model.grossLabel != null) CardioField(model.grossValue, model.grossLabel)
            }
        }
        Box(Modifier.align(Alignment.BottomCenter)) {
            LifeyEdgeButton(onClick = onToggleCourt) {
                Icon(
                    if (bench) model.activityIcon else Icons.Filled.AirlineSeatReclineNormal, contentDescription = null,
                    tint = LifeyColors.onPrimary, modifier = Modifier.size(18.dp),
                )
                Spacer(Modifier.width(LifeySpacing.sm))
                Text(
                    stringResource(if (bench) R.string.cardio_back_to_court_button else R.string.cardio_go_to_bench_button),
                    style = LifeyType.body(), color = LifeyColors.onPrimary, maxLines = 1,
                )
            }
        }
        if (bench) BenchRing()
    }
}
