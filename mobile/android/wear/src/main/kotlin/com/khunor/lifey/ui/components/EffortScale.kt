package com.khunor.lifey.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.wear.compose.material.Text
import androidx.wear.compose.material3.Button
import androidx.wear.compose.material3.ButtonDefaults
import androidx.wear.compose.material3.EdgeButton
import com.khunor.lifey.ui.theme.LifeyColors
import com.khunor.lifey.ui.theme.LifeySpacing
import com.khunor.lifey.ui.theme.LifeyType

/**
 * Effort scale (frame 04/11): a [ValueStepper] 1–10 plus a 10-segment bar; the number is white (effort has
 * no metric colour). "Kihagyás" is a real 40 dp secondary [Button] ([skipLabel]) and "Edzés lezárása" the
 * bottom EdgeButton ([finishLabel]) — W1.16.
 */
@Composable
fun EffortScale(
    value: Int,
    onValueChange: (Int) -> Unit,
    skipLabel: String,
    onSkip: () -> Unit,
    finishLabel: String,
    onFinish: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Column(modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(LifeySpacing.md)) {
        ValueStepper(
            value = value.toDouble(), onValueChange = { onValueChange(it.toInt()) },
            range = 1.0..10.0, step = 1.0, format = { it.toInt().toString() },
        )
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(LifeySpacing.xxs)) {
            for (index in 1..10) {
                Box(Modifier.weight(1f).height(6.dp).background(if (index <= value) LifeyColors.text else LifeyColors.raised, CircleShape))
            }
        }
        Button(
            onClick = onSkip, modifier = Modifier.height(40.dp),
            colors = ButtonDefaults.filledTonalButtonColors(containerColor = LifeyColors.control, contentColor = LifeyColors.text),
        ) { Text(skipLabel, style = LifeyType.body(), color = LifeyColors.text, maxLines = 1) }
        EdgeButton(onClick = onFinish) { Text(finishLabel, style = LifeyType.body(), color = LifeyColors.onPrimary, maxLines = 2) }
    }
}
