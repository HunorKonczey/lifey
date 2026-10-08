package com.khunor.lifey.ui.active

import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.wear.compose.foundation.lazy.TransformingLazyColumn
import androidx.wear.compose.foundation.lazy.rememberTransformingLazyColumnState
import androidx.wear.compose.material3.Text
import com.khunor.lifey.R
import com.khunor.lifey.StandaloneTemplateExercise
import com.khunor.lifey.ui.components.DismissibleOverlay
import com.khunor.lifey.ui.components.LifeyScreen
import com.khunor.lifey.ui.components.ListRow
import com.khunor.lifey.ui.theme.LifeyColors
import com.khunor.lifey.ui.theme.LifeySpacing
import com.khunor.lifey.ui.theme.LifeyType
import com.khunor.lifey.ui.theme.LocalWatchMetrics

/** One row of the exercise list: [index] is the plan position every logged set is attributed by. */
data class ExerciseRow(val index: Int, val name: String, val subtitle: String, val isCurrent: Boolean)

/**
 * Exercise list (W1.15): M3 [ListRow] pills "Fekvenyomás · 2/4 szett", the current one `raised` with a check,
 * in a [TransformingLazyColumn] whose ScrollIndicator comes from the screen scaffold; the crown scrolls it.
 * No top-left arrow — back is swipe-to-dismiss or the back key ([ExerciseListScreen]). A tap switches at once
 * (fully reversible: already-logged sets keep the exercise they were logged with).
 */
@Composable
fun ExerciseListContent(
    rows: List<ExerciseRow>,
    onSelect: (Int) -> Unit,
    modifier: Modifier = Modifier,
    /** The full template name when the session has one (the header truncates it at 14 characters, W2.6). */
    title: String? = null,
) {
    val state = rememberTransformingLazyColumnState()
    LifeyScreen(scrollState = state, modifier = modifier) { contentPadding ->
        TransformingLazyColumn(state = state, contentPadding = contentPadding) {
            item {
                Text(
                    title ?: stringResource(R.string.standalone_exercise_list_title), style = LifeyType.title(), color = LifeyColors.text,
                    // Below the clock and inside the chord: at the very top of the dial it is ~150 dp wide, which cut
                    // the first letter of "Push nap — mell és váll." off (LIF-131 bug 5).
                    textAlign = TextAlign.Center, maxLines = 2,
                    modifier = Modifier.fillMaxWidth().padding(
                        top = (LocalWatchMetrics.current.widthDp * 0.12f).dp,
                        start = LocalWatchMetrics.current.sideMargin, end = LocalWatchMetrics.current.sideMargin,
                        bottom = LifeySpacing.md,
                    ),
                )
            }
            rows.forEach { row ->
                item {
                    ListRow(
                        title = row.name, onClick = { onSelect(row.index) }, subtitle = row.subtitle,
                        isHighlighted = row.isCurrent, showsCheck = row.isCurrent,
                        modifier = Modifier.padding(bottom = LifeySpacing.sm),
                    )
                }
            }
        }
    }
}

/**
 * The "which exercise am I logging against" picker (docs/watch/49 §3.5, D-F6b.8) — replaces the pager like
 * the adjust overlay does. Tapping a row **jumps** straight to that exercise (no confirmation: a mis-tap costs
 * one more tap). [setsDonePerExercise] is resolved by the caller through
 * `SessionMetadata.standaloneSetsDoneAt` so the number matches the active page, and
 * [removedExerciseIndexes] (planned exercises the phone removed) are skipped, never renumbered.
 */
@Composable
internal fun ExerciseListScreen(
    exercises: List<StandaloneTemplateExercise>,
    currentExerciseId: String?,
    setsDonePerExercise: List<Int>,
    removedExerciseIndexes: Set<Int>,
    onSelect: (Int) -> Unit,
    onBack: () -> Unit,
    title: String? = null,
) {
    val rows = exercises.mapIndexedNotNull { index, exercise ->
        if (index in removedExerciseIndexes) return@mapIndexedNotNull null
        val setsDone = setsDonePerExercise.getOrElse(index) { 0 }
        val target = exercise.targetSets
        ExerciseRow(
            index = index,
            name = exercise.name,
            subtitle = if (target != null) {
                stringResource(R.string.active_sets_format, setsDone, target)
            } else {
                stringResource(R.string.standalone_exercise_sets_done, setsDone)
            },
            isCurrent = exercise.exerciseId == currentExerciseId,
        )
    }
    DismissibleOverlay(onDismiss = onBack) {
        ExerciseListContent(rows = rows, onSelect = onSelect, title = title)
    }
}
