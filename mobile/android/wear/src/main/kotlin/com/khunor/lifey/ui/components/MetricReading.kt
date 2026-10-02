package com.khunor.lifey.ui.components

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.size
import androidx.compose.material3.Icon
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.unit.dp
import com.khunor.lifey.ui.theme.LifeyColors
import com.khunor.lifey.ui.theme.LifeyNumber
import com.khunor.lifey.ui.theme.LifeySpacing
import com.khunor.lifey.ui.theme.LifeyType
import com.khunor.lifey.ui.theme.LocalWatchMetrics

/** Level of a [MetricReading]: `metric` for heart rate, `value` for kcal. */
enum class MetricLevel { Metric, Value }

/**
 * Metric reading (frame 04/02): icon + PJS number (+ unit — Wear gains "bpm") at `metric` or `value`
 * level. The number is `text`; the icon carries the metric colour.
 */
@Composable
fun MetricReading(
    icon: ImageVector,
    iconTint: Color,
    number: String,
    modifier: Modifier = Modifier,
    unit: String? = null,
    level: MetricLevel = MetricLevel.Value,
    description: String? = null,
) {
    val metrics = LocalWatchMetrics.current
    Row(modifier, horizontalArrangement = Arrangement.spacedBy(LifeySpacing.xs), verticalAlignment = Alignment.CenterVertically) {
        Icon(
            icon, contentDescription = null, tint = iconTint,
            modifier = Modifier.size(((if (level == MetricLevel.Metric) metrics.metricSp else metrics.valueSp) * 0.8f).dp),
        )
        LifeyNumber(
            number = number, unit = unit, description = description,
            style = if (level == MetricLevel.Metric) LifeyType.metric() else LifeyType.value(),
            color = LifeyColors.text,
        )
    }
}
