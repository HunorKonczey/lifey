package com.khunor.lifey.debug

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.DirectionsRun
import androidx.compose.material.icons.filled.Pause
import androidx.compose.material.icons.filled.Stop
import androidx.compose.material.icons.filled.Tune
import androidx.compose.material.icons.filled.FitnessCenter
import androidx.compose.material.icons.filled.LocalFireDepartment
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.runtime.Composable
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
