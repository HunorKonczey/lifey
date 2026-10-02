package com.khunor.lifey.ui.components

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.wear.compose.material.Text
import com.khunor.lifey.ui.theme.LifeyColors
import com.khunor.lifey.ui.theme.LifeyType

/**
 * Cardio field (frame 04/15, Wear): boxless — the value above (PJS `value`), the phone-supplied label under
 * it, centred, two lines at most. Labels are variable-length, pre-localised text.
 */
@Composable
fun CardioField(value: String, label: String, modifier: Modifier = Modifier) {
    Column(modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally) {
        Text(value, style = LifeyType.value(), color = LifeyColors.text, maxLines = 1, textAlign = TextAlign.Center)
        Text(
            label.uppercase(), style = LifeyType.label(), color = LifeyColors.text2, maxLines = 2,
            overflow = TextOverflow.Ellipsis, textAlign = TextAlign.Center,
        )
    }
}
