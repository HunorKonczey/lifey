package com.khunor.lifey.debug

import androidx.compose.runtime.Composable
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Bolt
import androidx.compose.material.icons.filled.DirectionsRun
import com.khunor.lifey.ui.ErrorContent
import com.khunor.lifey.LogSetState
import com.khunor.lifey.ui.active.LogContent
import com.khunor.lifey.ui.active.LogModel
import com.khunor.lifey.ui.IdleScreen
import com.khunor.lifey.ui.active.AmbientMetricsContent
import com.khunor.lifey.ui.active.AmbientRestContent
import com.khunor.lifey.ui.theme.AmbientState
import com.khunor.lifey.ui.active.GameContent
import com.khunor.lifey.ui.active.GameModel
import androidx.compose.material.icons.filled.SportsBasketball
import com.khunor.lifey.ui.active.CardioContent
import com.khunor.lifey.ui.active.CardioFieldModel
import com.khunor.lifey.ui.active.CardioModel
import androidx.compose.material.icons.filled.PedalBike
import com.khunor.lifey.ui.SummaryContent
import com.khunor.lifey.ui.SummaryModel
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
    "W2.7" to frame2 { // standalone log page: 74 dp circles, secondary "Gyakorlatok" EdgeButton, no unreachable state
        Box(Modifier.fillMaxSize()) {
            LogContent(
                LogModel(
                    elapsedMs = 12 * 60_000L + 34_000L, exerciseName = "Fekvenyomás", setsDone = 2, setsTotal = 4,
                    freeFormatSets = null, logState = LogSetState.Ready, showsStandaloneMark = true, offersExerciseList = true,
                ),
                onLogSet = {}, onAdjust = {}, onOpenExerciseList = {},
            )
            TimeText()
        }
    },
    "W2.8" to frame2 { SummaryContent(SummaryModel(38 * 60 + 12, 9, 126, 214, isSynced = false, pendingCount = 2)) },
    "W2.9" to frame2 { SummaryContent(SummaryModel(38 * 60 + 12, 9, 126, 214, isSynced = true, pendingCount = 0)) },
    "W2.10" to frame2 { CardioFrame(runModel(HeartRateState.Live(142))) },
    "W2.11" to frame2 {
        CardioFrame(
            CardioModel(
                headerLabel = "Szobakerékpár", activityIcon = Icons.Filled.PedalBike, accent = LifeyColors.cardioIndoorBike,
                primaryLabel = "Mozgásidő", primaryValue = "24:10", heartRate = HeartRateState.Live(131),
                fields = listOf(CardioFieldModel("78 rpm", "Kadencia"), CardioFieldModel("165 W", "Átlag teljesítmény")),
            ),
        )
    },
    "W2.14" to frame2 { CardioFrame(runModel(HeartRateState.Missing)) },
    "W2.14b" to frame2 { CardioFrame(runModel(HeartRateState.PermissionDenied)) }, // the slot is the permission button
    "W2.12" to frame2 { GameFrame(gameModel(onCourt = true, hr = 138)) },
    "W2.13" to frame2 { GameFrame(gameModel(onCourt = false, hr = 118)) },
    "W2.17" to frame2 { AmbientMetricsContent(AmbientState(true, 1), "Erőedzés", 12 * 60 + 34, 128, "Fekvenyomás · 2/4") },
    "W2.18" to frame2 { AmbientRestContent(AmbientState(true, 1), 47, System.currentTimeMillis() + 47_000L, "Következő · Fekvenyomás — 3/4. szett") },
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

private fun runModel(heartRate: HeartRateState) = CardioModel(
    headerLabel = "Futás", activityIcon = Icons.Filled.DirectionsRun, accent = LifeyColors.calories,
    primaryLabel = "Távolság", primaryValue = "3.42 km", heartRate = heartRate,
    fields = listOf(CardioFieldModel("5:23 /km", "Tempó")),
)

@Composable
private fun CardioFrame(model: CardioModel) {
    Box(Modifier.fillMaxSize()) {
        CardioContent(model, onRequestHeartRatePermission = {})
        TimeText()
    }
}

private fun gameModel(onCourt: Boolean, hr: Int) = GameModel(
    headerLabel = "Kosárlabda", activityIcon = Icons.Filled.SportsBasketball, accent = LifeyColors.cardioBasketball,
    onCourt = onCourt, playLabel = "Játékidő", playTime = "12:05", grossValue = "15:40", grossLabel = "Bruttó idő",
    heartRate = HeartRateState.Live(hr),
)

@Composable
private fun GameFrame(model: GameModel) {
    Box(Modifier.fillMaxSize()) {
        GameContent(model, onToggleCourt = {}, onRequestHeartRatePermission = {})
        TimeText()
    }
}
