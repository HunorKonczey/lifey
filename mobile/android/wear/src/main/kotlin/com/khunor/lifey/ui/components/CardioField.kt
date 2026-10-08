package com.khunor.lifey.ui.components

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.sp
import androidx.wear.compose.material3.Text
import com.khunor.lifey.ui.theme.LifeyColors
import com.khunor.lifey.ui.theme.LifeyType

/**
 * Cardio field (frame 04/15, Wear): boxless — the value above (PJS `value`), the phone-supplied label under
 * it, centred, two lines at most. Labels are variable-length, pre-localised text.
 */
@Composable
fun CardioField(value: String, label: String, modifier: Modifier = Modifier, tight: Boolean = false, fill: Boolean = true) {
    // [tight]: one of two fields side by side — each half of a round dial's lower band, where the long phone
    // labels ("ÁTLAG TELJESÍTMÉNY") otherwise ran off the right edge (LIF-131 bug 8). A touch smaller, no tracking.
    val base = LifeyType.label(textCap = if (tight) 1.1f else LifeyType.TEXT_CAP)
    val labelStyle = if (tight) base.copy(fontSize = base.fontSize * 0.9f, letterSpacing = 0.sp) else base
    // [fill] false: the field is as wide as its text, so a row of "heart rate + field" is centred as a unit
    // instead of the field taking all the room and pushing the heart to the dial's edge (LIF-131 bug 9).
    Column(if (fill) modifier.fillMaxWidth() else modifier, horizontalAlignment = Alignment.CenterHorizontally) {
        Text(value, style = LifeyType.value(), color = LifeyColors.text, maxLines = 1, textAlign = TextAlign.Center)
        Text(
            label.uppercase(), style = labelStyle, color = LifeyColors.text2, maxLines = 2,
            overflow = TextOverflow.Ellipsis, textAlign = TextAlign.Center,
        )
    }
}
