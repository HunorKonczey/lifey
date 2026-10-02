package com.khunor.lifey.debug

import androidx.compose.runtime.Composable
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Bolt
import androidx.compose.material.icons.filled.DirectionsRun
import com.khunor.lifey.ui.IdleScreen
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
