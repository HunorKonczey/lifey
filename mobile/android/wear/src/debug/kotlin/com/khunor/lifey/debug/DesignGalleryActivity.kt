package com.khunor.lifey.debug

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.clickable
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.wear.compose.foundation.lazy.TransformingLazyColumn
import androidx.wear.compose.material.Text
import com.khunor.lifey.ui.theme.LifeyColors
import com.khunor.lifey.ui.theme.LifeyNumber
import com.khunor.lifey.ui.theme.LifeySpacing
import com.khunor.lifey.ui.theme.LifeyTheme
import com.khunor.lifey.ui.theme.LifeyType
import com.khunor.lifey.ui.theme.LocalWatchMetrics
import com.khunor.lifey.ui.theme.WatchMetrics

/**
 * Debug-only design gallery (redesign plan 79, D-X0.11): every token, type style and component in every
 * state, at the two reference sizes, plus a "Frames" section of canvas fixtures. Exported in debug builds
 * only, so a frame is one `adb` call away:
 *
 *     adb shell am start -n com.khunor.lifey/.debug.DesignGalleryActivity --es frame W1.5
 *
 * With no `frame` extra the full list opens. Later steps add their sections to [gallerySections].
 */
class DesignGalleryActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val frame = intent.getStringExtra("frame")
        setContent { LifeyTheme { Gallery(frame) } }
    }
}

/** One gallery section: a title and its content. */
class GallerySection(val title: String, val content: @Composable () -> Unit)

/** Frame fixtures by canvas id ("W1.5") — X3 / X4 register theirs here. */
val galleryFrames: Map<String, @Composable () -> Unit> = emptyMap()

/** Registry — later steps append their component sections here. */
val gallerySections: List<GallerySection> get() = foundationSections + componentSections

private val foundationSections: List<GallerySection> = listOf(
    GallerySection("01 Tokens") { TokenSwatches() },
    GallerySection("02 Type") { TypeRamp() },
    GallerySection("03 Metrics") { MetricsReadout() },
)

@Composable
private fun Gallery(frame: String?) {
    val widths = listOf(WatchMetrics.REGULAR_REFERENCE_DP, WatchMetrics.COMPACT_REFERENCE_DP)
    var widthIndex by remember { mutableStateOf(0) }
    var ambient by remember { mutableStateOf(false) }
    val width = widths[widthIndex]
    val fixture = frame?.let { galleryFrames[it] }

    CompositionLocalProvider(LocalWatchMetrics provides WatchMetrics(width), LocalGalleryAmbient provides ambient) {
        if (fixture != null) {
            fixture()
            return@CompositionLocalProvider
        }
        TransformingLazyColumn(
            modifier = Modifier.fillMaxWidth(),
            contentPadding = androidx.compose.foundation.layout.PaddingValues(vertical = 40.dp, horizontal = 12.dp),
        ) {
            item {
                Row(horizontalArrangement = Arrangement.spacedBy(LifeySpacing.md), verticalAlignment = Alignment.CenterVertically) {
                    Chip("${width.toInt()} dp") { widthIndex = (widthIndex + 1) % widths.size }
                    Chip(if (ambient) "ambient" else "full") { ambient = !ambient }
                }
            }
            if (frame != null) item { Text("unknown frame $frame", color = LifeyColors.error) }
            for (section in gallerySections) {
                item { Text(section.title, style = LifeyType.label(), color = LifeyColors.text2) }
                item { Box(Modifier.width(width.dp)) { section.content() } }
            }
        }
    }
}

/** True when the gallery's ambient toggle is on (X0w.14 reads it). */
val LocalGalleryAmbient = androidx.compose.runtime.staticCompositionLocalOf { false }

@Composable
private fun Chip(text: String, onClick: () -> Unit) {
    Text(
        text = text, style = LifeyType.label(), color = LifeyColors.text,
        modifier = Modifier
            .background(LifeyColors.control, RoundedCornerShape(50))
            .clickable(onClick = onClick)
            .padding(horizontal = LifeySpacing.lg, vertical = LifeySpacing.md),
    )
}

@Composable
private fun TokenSwatches() {
    val swatches = listOf(
        "bg" to LifeyColors.bg, "card" to LifeyColors.card, "nested" to LifeyColors.nested,
        "control" to LifeyColors.control, "raised" to LifeyColors.raised, "outline" to LifeyColors.outline,
        "text" to LifeyColors.text, "text2" to LifeyColors.text2, "text3" to LifeyColors.text3,
        "ghost" to LifeyColors.ghost, "primary" to LifeyColors.primary, "heart" to LifeyColors.heart,
        "calories" to LifeyColors.calories, "success" to LifeyColors.success, "clay" to LifeyColors.clay,
    )
    Column(verticalArrangement = Arrangement.spacedBy(LifeySpacing.xs)) {
        for (row in swatches.chunked(4)) {
            Row(horizontalArrangement = Arrangement.spacedBy(LifeySpacing.xs)) {
                for ((name, color) in row) {
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        Box(Modifier.width(36.dp).height(22.dp).background(color, RoundedCornerShape(LifeySpacingTag)))
                        Text(name, fontSize = 8.sp, fontFamily = FontFamily.Monospace, color = LifeyColors.text2)
                    }
                }
            }
        }
    }
}

private val LifeySpacingTag = 8.dp

@Composable
private fun TypeRamp() {
    Column(verticalArrangement = Arrangement.spacedBy(LifeySpacing.xs)) {
        Text("12:34", style = LifeyType.hero(), color = LifeyColors.text)
        LifeyNumber("128", unit = "bpm", style = LifeyType.metric(), color = LifeyColors.heart)
        LifeyNumber("62,5", unit = "kg")
        Text("Cím", style = LifeyType.title(), color = LifeyColors.text)
        Text("Törzsszöveg", style = LifeyType.body(), color = LifeyColors.text)
        Text("CÍMKE", style = LifeyType.label(), color = LifeyColors.text2)
    }
}

@Composable
private fun MetricsReadout() {
    val m = LocalWatchMetrics.current
    Column(Modifier.fillMaxWidth().padding(horizontal = LifeySpacing.sm)) {
        for ((name, value) in listOf(
            "hero" to m.heroSp, "hero dense" to m.heroDenseSp, "metric" to m.metricSp, "value" to m.valueSp,
            "circle" to m.circleButton.value, "button" to m.buttonHeight.value,
            "touch" to m.minTouchTarget.value, "side" to m.sideMargin.value, "top/bottom" to m.verticalMargin.value,
        )) {
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                Text(name, fontSize = 10.sp, fontFamily = FontFamily.Monospace, color = LifeyColors.text2)
                Text(value.toInt().toString(), fontSize = 10.sp, fontFamily = FontFamily.Monospace, color = LifeyColors.text2)
            }
        }
    }
}
