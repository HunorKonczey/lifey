package com.khunor.lifey.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.wear.compose.material3.Text
import com.khunor.lifey.ui.theme.LifeyColors
import com.khunor.lifey.ui.theme.LifeySpacing
import com.khunor.lifey.ui.theme.LifeyType

/**
 * Set segment bar (frame 04/03): the exercise name and "2/4" (PJS-free bold, "/4" in `text3`) over
 * segments instead of dots — readable up to 8 sets. Done = `text`, just logged = `success` (1.2 s, driven by
 * the caller), remaining = `raised`. On the round screen the block is narrow and centred ([width], 96 dp
 * on a 192 dp dial, inside the bottom chord). A session without a plan shows only [freeFormText]
 * ("3. szett · 24 ism."). Wear gains this block — it was missing before.
 */
@Composable
fun SetSegmentBar(
    done: Int,
    total: Int,
    modifier: Modifier = Modifier,
    title: String? = null,
    justLoggedIndex: Int? = null,
    freeFormText: String? = null,
    width: Dp? = null,
) {
    val sized = if (width != null) modifier.widthIn(max = width) else modifier
    if (freeFormText != null) {
        Text(freeFormText, modifier = sized, style = LifeyType.body(), color = LifeyColors.text2, maxLines = 2,
            textAlign = TextAlign.Center, overflow = TextOverflow.Ellipsis)
        return
    }
    Column(sized, verticalArrangement = Arrangement.spacedBy(LifeySpacing.sm)) {
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
            if (title != null) {
                Text(title, style = LifeyType.title(), color = LifeyColors.text, maxLines = 2, overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.weight(1f, fill = false))
            }
            Text(counter(done, total), style = LifeyType.body())
        }
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(LifeySpacing.xs)) {
            for (index in 0 until total.coerceAtLeast(0)) {
                val color: Color = when {
                    index == justLoggedIndex -> LifeyColors.success
                    index < done -> LifeyColors.text
                    else -> LifeyColors.raised
                }
                Box(Modifier.weight(1f).height(6.dp).background(color, CircleShape))
            }
        }
    }
}

/** "2" in `text` followed by "/4" in `text3`. */
internal fun counter(done: Int, total: Int): AnnotatedString = buildAnnotatedString {
    withStyle(SpanStyle(color = LifeyColors.text)) { append("$done") }
    withStyle(SpanStyle(color = LifeyColors.text3)) { append("/$total") }
}
