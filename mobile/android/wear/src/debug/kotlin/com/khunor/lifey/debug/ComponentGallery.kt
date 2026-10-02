package com.khunor.lifey.debug

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Bolt
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.DirectionsRun
import androidx.compose.material.icons.filled.Pause
import androidx.compose.material.icons.filled.Stop
import androidx.compose.material.icons.filled.Tune
import androidx.compose.material.icons.filled.FitnessCenter
import androidx.compose.material.icons.filled.LocalFireDepartment
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.unit.dp
import androidx.wear.compose.material.Text
import com.khunor.lifey.ui.components.BenchRing
import com.khunor.lifey.ui.components.CardioField
import com.khunor.lifey.ui.components.EffortScale
import com.khunor.lifey.ui.components.ListRow
import com.khunor.lifey.ui.components.RowLeading
import com.khunor.lifey.ui.components.StatusScreen
import com.khunor.lifey.ui.components.SummaryTile
import com.khunor.lifey.ui.components.SyncRow
import com.khunor.lifey.ui.components.GoFlash
import com.khunor.lifey.ui.components.RestRing
import com.khunor.lifey.ui.components.ValueStepper
import com.khunor.lifey.ui.theme.LocalWatchMetrics
import androidx.compose.ui.Modifier
import com.khunor.lifey.ui.components.CircleButton
import com.khunor.lifey.ui.components.CircleStyle
import com.khunor.lifey.ui.components.HeaderChip
import com.khunor.lifey.ui.components.PillKind
import com.khunor.lifey.ui.components.StatusPill
import com.khunor.lifey.ui.components.HeartRateSlot
import com.khunor.lifey.ui.components.HeartRateState
import com.khunor.lifey.ui.components.MetricLevel
import com.khunor.lifey.ui.components.MetricReading
import com.khunor.lifey.ui.components.SetSegmentBar
import com.khunor.lifey.ui.components.StandaloneMark
import com.khunor.lifey.ui.theme.LifeyColors
import com.khunor.lifey.ui.theme.LifeySpacing

/** Gallery sections for the 04 components — every state at the gallery's current width (D-X0.11). */
val componentSections: List<GallerySection> = listOf(
    GallerySection("04/01 Header chip") { HeaderChipGallery() },
    GallerySection("04/02 Metric reading · HR slot") { MetricReadingGallery() },
    GallerySection("04/03 Set segment bar") { SegmentBarGallery() },
    GallerySection("04/04 Circle button") { CircleButtonGallery() },
    GallerySection("04/05 Status pill") { StatusPillGallery() },
    GallerySection("04/06 Rest ring") { RestGallery() },
    GallerySection("04/07 Mehet! ring") { GoFlashGallery() },
    GallerySection("04/08 Stepper · 04/11 Effort") { StepperGallery() },
    GallerySection("04/09 List row") { ListRowGallery() },
    GallerySection("04/12 Summary tile · sync row") { SummaryGallery() },
    GallerySection("04/13-15 Bench · field · status") { StructuralGallery() },
)

@Composable
private fun HeaderChipGallery() = Column(verticalArrangement = Arrangement.spacedBy(LifeySpacing.md)) {
    HeaderChip(Icons.Filled.FitnessCenter, "Erőedzés")
    HeaderChip(Icons.Filled.FitnessCenter, "Erőedzés", isPaused = true)
    HeaderChip(Icons.Filled.DirectionsRun, "Futás", accent = LifeyColors.calories)
    HeaderChip(Icons.Filled.FitnessCenter, "Push nap — mell és váll", standaloneMark = StandaloneMark.Idle)
    HeaderChip(Icons.Filled.FitnessCenter, "Push nap", standaloneMark = StandaloneMark.Tapped)
}

@Composable
private fun MetricReadingGallery() = Column(verticalArrangement = Arrangement.spacedBy(LifeySpacing.md)) {
    MetricReading(Icons.Filled.Favorite, LifeyColors.heart, "128", unit = "bpm", level = MetricLevel.Metric)
    MetricReading(Icons.Filled.LocalFireDepartment, LifeyColors.calories, "87", unit = "kcal")
    HeartRateSlot(HeartRateState.Live(128))
    HeartRateSlot(HeartRateState.Missing)
    HeartRateSlot(HeartRateState.PermissionDenied)
}

@Composable
private fun SegmentBarGallery() = Column(verticalArrangement = Arrangement.spacedBy(LifeySpacing.md)) {
    SetSegmentBar(done = 2, total = 4, title = "Fekvenyomás")
    SetSegmentBar(done = 3, total = 4, title = "Fekvenyomás", justLoggedIndex = 2)
    SetSegmentBar(done = 5, total = 8, title = "Guggolás")
    SetSegmentBar(done = 0, total = 0, freeFormText = "3. szett · 24 ism.", modifier = Modifier)
}

@Composable
private fun CircleButtonGallery() = Column(verticalArrangement = Arrangement.spacedBy(LifeySpacing.lg)) {
    Row(horizontalArrangement = Arrangement.spacedBy(LifeySpacing.md)) {
        CircleButton(CircleStyle.Primary, Icons.Filled.Add, "+1 szett", {})
        CircleButton(CircleStyle.Raised, Icons.Filled.Tune, "Módosítás", {}, iconTint = LifeyColors.clay)
    }
    Row(horizontalArrangement = Arrangement.spacedBy(LifeySpacing.md)) {
        CircleButton(CircleStyle.Primary, Icons.Filled.Add, "+1 szett", {}, isGhosted = true)
        CircleButton(CircleStyle.SuccessTint, Icons.Filled.Check, "3/4 szett", {})
    }
    Row(horizontalArrangement = Arrangement.spacedBy(LifeySpacing.md)) {
        CircleButton(CircleStyle.ErrorTint, Icons.Filled.Stop, "Vége", {})
        CircleButton(CircleStyle.Control, Icons.Filled.Pause, "Szünet", {})
    }
}

@Composable
private fun StatusPillGallery() = Column(verticalArrangement = Arrangement.spacedBy(LifeySpacing.sm)) {
    StatusPill(PillKind.Logged, "Naplózva")
    StatusPill(PillKind.Pending, "Naplózás…")
    StatusPill(PillKind.Failed, "Nem sikerült —\npróbáld újra")
    StatusPill(PillKind.Unreachable, "Nincs kapcsolat\na telefonnal")
}

@Composable
private fun RestGallery() = Column(verticalArrangement = Arrangement.spacedBy(LifeySpacing.lg)) {
    Box(Modifier.size(LocalWatchMetrics.current.widthDp.dp)) { RestRing(remainingSeconds = 47, totalSeconds = 90) }
    Box(Modifier.size(LocalWatchMetrics.current.widthDp.dp)) { RestRing(remainingSeconds = 4, totalSeconds = 90) }
}

@Composable
private fun GoFlashGallery() {
    var token by remember { mutableStateOf(0) }
    Column {
        Text("Replay", color = LifeyColors.text, modifier = Modifier.clickable { token++ })
        Box(Modifier.size(LocalWatchMetrics.current.widthDp.dp)) { GoFlash(replayToken = token) }
    }
}

@Composable
private fun StepperGallery() {
    var reps by remember { mutableStateOf(8.0) }
    var weight by remember { mutableStateOf(102.5) }
    var effort by remember { mutableStateOf(7) }
    Column(verticalArrangement = Arrangement.spacedBy(LifeySpacing.lg)) {
        ValueStepper(reps, { reps = it }, 1.0..99.0, 1.0, { it.toInt().toString() }, unit = "ismétlés", confirmLabel = "${reps.toInt()} ismétlés naplózása")
        ValueStepper(1.0, {}, 1.0..99.0, 1.0, { it.toInt().toString() }, unit = "alsó határ")
        ValueStepper(weight, { weight = it }, 0.0..500.0, 2.5, { "%g".format(it).replace('.', ',') }, unit = "kg")
        EffortScale(effort, { effort = it }, "Kihagyás", {})
    }
}

@Composable
private fun ListRowGallery() = Column(verticalArrangement = Arrangement.spacedBy(LifeySpacing.sm)) {
    ListRow("Gyors erőedzés", {}, subtitle = "Terv nélkül is megy", leading = RowLeading.Holder(Icons.Filled.Bolt), isHighlighted = true)
    ListRow("Push nap — mell, vállak és tricepsz", {}, subtitle = "5 gyakorlat")
    ListRow("Futás", {}, leading = RowLeading.Tinted(Icons.Filled.DirectionsRun, LifeyColors.calories))
    ListRow("Fekvenyomás", {}, showsCheck = true, isHighlighted = true)
}

@Composable
private fun SummaryGallery() = Column(verticalArrangement = Arrangement.spacedBy(LifeySpacing.sm)) {
    SummaryTile(148.0, { it.toInt().toString() }, "átlag bpm", tint = LifeyColors.heart)
    SyncRow(isSynced = false, title = "Szinkronizálás a telefonra", subtitle = "2 edzés vár szinkronizálásra")
    SyncRow(isSynced = true, title = "Telefonra szinkronizálva")
}

@Composable
private fun StructuralGallery() = Column(verticalArrangement = Arrangement.spacedBy(LifeySpacing.md)) {
    Box(Modifier.size(LocalWatchMetrics.current.widthDp.dp)) { BenchRing(); Text("Padon", color = LifeyColors.clay, modifier = Modifier.align(Alignment.Center)) }
    CardioField("5:12", "Tempó /km")
    CardioField("148", "Átlagos teljesítmény")
    Box(Modifier.size(LocalWatchMetrics.current.widthDp.dp)) {
        StatusScreen(Icons.Filled.Warning, "Már fut egy edzés", iconTint = LifeyColors.calories, text = "Fejezd be a másikat.", actionLabel = "Rendben")
    }
}
