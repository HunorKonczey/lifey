package com.khunor.lifey.ui.active

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.em
import androidx.wear.compose.material.Text
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
    val width = LocalWatchMetrics.current.widthDp
    val (number, unit) = splitUnit(model.primaryValue)
    Box(modifier.fillMaxSize()) {
        Column(
            Modifier.align(Alignment.TopCenter).padding(top = (width * 0.14f).dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(LifeySpacing.xxs),
        ) {
            ActiveHeader(
                model.activityIcon, model.headerLabel, isPaused = model.isPaused,
                showsStandaloneMark = model.showsStandaloneMark, accent = model.accent,
            )
            Text(model.primaryLabel.uppercase(), style = LifeyType.label(), color = LifeyColors.text2, maxLines = 1)
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
