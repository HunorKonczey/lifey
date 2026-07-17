package com.khunor.lifey.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextAlign
import androidx.wear.compose.material.Button
import androidx.wear.compose.material.MaterialTheme
import androidx.wear.compose.material.Text
import com.khunor.lifey.R
import com.khunor.lifey.SessionStateHolder

/**
 * "Another app already owns the exercise session" (docs/40-watch-app-plan.md
 * §12.1 B12 / 41-watch-design-prompt.md §3.6, canvas Wear 05): the watch-side
 * counterpart of the phone's `watchStartRejectedMessage` snackbar —
 * [com.khunor.lifey.ExerciseService.startExercise]'s catch branch drives
 * [SessionStateHolder.onStartRejected] into this phase. OK just dismisses
 * back to [IdleScreen] ([SessionStateHolder.reset]); there's nothing to
 * retry from here — the phone owns retrying the actual start.
 */
@Composable
fun ErrorScreen() {
    BoxWithConstraints(modifier = Modifier.fillMaxSize()) {
        val isCompact = isCompactScreen(maxWidth)
        Column(
            modifier = Modifier.fillMaxSize().padding(maxWidth * SCREEN_PADDING_FRACTION),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(maxWidth * 0.06f, Alignment.CenterVertically),
        ) {
            Text(
                text = stringResource(R.string.error_already_running_title),
                style = if (isCompact) MaterialTheme.typography.title3 else MaterialTheme.typography.title2,
                textAlign = TextAlign.Center,
            )
            Button(onClick = { SessionStateHolder.reset() }) {
                Text(stringResource(R.string.error_ok_button))
            }
        }
    }
}
