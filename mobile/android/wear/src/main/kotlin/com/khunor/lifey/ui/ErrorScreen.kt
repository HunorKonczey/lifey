package com.khunor.lifey.ui

import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.PriorityHigh
import androidx.compose.runtime.Composable
import androidx.compose.ui.res.stringResource
import com.khunor.lifey.R
import com.khunor.lifey.SessionStateHolder
import com.khunor.lifey.ui.active.balancedBreak
import com.khunor.lifey.ui.components.StatusScreen
import com.khunor.lifey.ui.theme.LifeyColors

/**
 * "Another app already owns the exercise session" (docs/40-watch-app-plan.md §12.1 B12; frame W2.4): the
 * watch-side counterpart of the phone's `watchStartRejectedMessage` snackbar —
 * [com.khunor.lifey.ExerciseService.startExercise]'s catch branch drives [SessionStateHolder.onStartRejected]
 * into this phase. A [StatusScreen] now: the warning (`calories`, which replaces the v1 orange `negative`)
 * icon, the title on two deliberate lines, the explanation, and "Rendben" as a `control` EdgeButton that
 * just dismisses back to the launcher ([SessionStateHolder.reset]) — there is nothing to retry from here,
 * the phone owns retrying the actual start.
 */
@Composable
fun ErrorScreen() {
    ErrorContent(onOk = { SessionStateHolder.reset() })
}

@Composable
fun ErrorContent(onOk: () -> Unit) {
    StatusScreen(
        icon = Icons.Filled.PriorityHigh,
        title = balancedBreak(stringResource(R.string.error_already_running_title)),
        iconTint = LifeyColors.calories,
        text = stringResource(R.string.error_already_running_subtitle),
        actionLabel = stringResource(R.string.error_ok_button),
        onAction = onOk,
    )
}
