package com.khunor.lifey.debug

import androidx.compose.runtime.Composable
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Bolt
import androidx.compose.material.icons.filled.DirectionsRun
import com.khunor.lifey.ui.ErrorContent
import com.khunor.lifey.ui.IdleScreen
import com.khunor.lifey.ui.active.ExerciseListContent
import com.khunor.lifey.ui.active.ExerciseRow
import com.khunor.lifey.ui.components.StandaloneMark
import com.khunor.lifey.ui.components.HeaderChip
import androidx.compose.material.icons.filled.FitnessCenter
import com.khunor.lifey.ui.active.MetricsContent
import com.khunor.lifey.ui.active.MetricsModel
import com.khunor.lifey.ui.components.HeartRateState
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.compose.foundation.layout.padding
import androidx.wear.compose.material3.TimeText
import com.khunor.lifey.ui.PickerContent
import com.khunor.lifey.ui.PickerRow
import com.khunor.lifey.ui.components.LifeyAppScaffold
import com.khunor.lifey.ui.components.RowLeading
import com.khunor.lifey.ui.theme.LifeyColors

/**
 * Fixtures of the Wear start / standalone / cardio canvas (`Lifey Watch 4 Wear OS Start Standalone Cardio`,
 * frames W2.1–W2.21), registered next to the W1 ones (see [w1Frames]); each X4 step adds its frames.
 *
 *     adb shell am start -n com.khunor.lifey/.debug.DesignGalleryActivity --es frame W2.1 [--ei width 192]
 */
val w2Frames: Map<String, @Composable () -> Unit> = mapOf(
    "W2.1" to frame2 { IdleScreen(onStartTapped = {}) },
    "W2.2" to frame2 {
        LifeyAppScaffold {
            PickerContent(
                title = "Indítás",
                rows = listOf(
                    PickerRow("Gyors erőedzés", "Terv nélkül is megy", RowLeading.Holder(Icons.Filled.Bolt), isHighlighted = true, onClick = {}),
                    PickerRow("Push nap", "5 gyakorlat", RowLeading.None, onClick = {}),
                    PickerRow("Futás", null, RowLeading.Tinted(Icons.Filled.DirectionsRun, LifeyColors.calories), onClick = {}),
                    PickerRow("Összes tevékenység", null, RowLeading.None, onClick = {}),
                ),
                emptyHint = null,
            )
        }
    },
    "W2.3" to frame2 {
        LifeyAppScaffold {
            PickerContent(
                title = "Összes tevékenység",
                rows = listOf(
                    PickerRow("Futás", null, RowLeading.Tinted(Icons.Filled.DirectionsRun, LifeyColors.calories), onClick = {}),
                    PickerRow("Gyaloglás", null, RowLeading.Tinted(Icons.Filled.DirectionsRun, LifeyColors.cardioWalking), onClick = {}),
                    PickerRow("Túrázás", null, RowLeading.Tinted(Icons.Filled.DirectionsRun, LifeyColors.cardioHiking), onClick = {}),
                    PickerRow("Kosárlabda", null, RowLeading.Tinted(Icons.Filled.DirectionsRun, LifeyColors.cardioBasketball), onClick = {}),
                ),
                emptyHint = null,
            )
        }
    },
    "W2.4" to frame2 { ErrorContent(onOk = {}) },
    "W2.5" to frame2 { // standalone quick strength: the mark, and the free-form line on two centred lines
        Box(Modifier.fillMaxSize()) {
            MetricsContent(
                MetricsModel(
                    headerLabel = "Erőedzés", elapsedMs = 12 * 60_000L + 34_000L, heartRate = HeartRateState.Live(128), kcal = 87,
                    exerciseName = "Gyors erőedzés", setsDone = null, setsTotal = null, freeFormatSets = 3 to 24,
                    showsStandaloneMark = true,
                ),
                onRequestHeartRatePermission = {}, onOpenExerciseList = null,
            )
            TimeText()
        }
    },
    "W2.6" to frame2 { // template header (≤ 14 characters + ellipsis) with the sync mark, tapped; the full name tops the list
        Box(Modifier.fillMaxSize()) {
            Box(Modifier.align(Alignment.TopCenter).padding(top = 40.dp)) {
                HeaderChip(Icons.Filled.FitnessCenter, "Push nap — mell és váll", standaloneMark = StandaloneMark.Tapped)
            }
        }
    },
    "W2.6b" to frame2 {
        LifeyAppScaffold {
            ExerciseListContent(
                rows = listOf(ExerciseRow(0, "Fekvenyomás", "2/4 szett", true), ExerciseRow(1, "Tárogatás", "0/3 szett", false)),
                onSelect = {}, title = "Push nap — mell és váll",
            )
        }
    },
    "W2.2b" to frame2 { // no synced templates: the empty hint, centred
        LifeyAppScaffold {
            PickerContent(
                title = "Indítás",
                rows = listOf(PickerRow("Gyors erőedzés", "Terv nélkül is megy", RowLeading.Holder(Icons.Filled.Bolt), isHighlighted = true, onClick = {})),
                emptyHint = "Sablonok a telefonról érkeznek",
            )
        }
    },
)

/** Gives the lambda a @Composable function type up front. */
private fun frame2(content: @Composable () -> Unit): @Composable () -> Unit = content
