package com.khunor.lifey.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.PriorityHigh
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextAlign
import androidx.wear.compose.material.ChipDefaults
import androidx.wear.compose.material.CompactChip
import androidx.wear.compose.material.Icon
import androidx.wear.compose.material.MaterialTheme
import androidx.wear.compose.material.Text
import com.khunor.lifey.R
import com.khunor.lifey.SessionStateHolder
import com.khunor.lifey.ui.theme.LifeyColors

/** The warning-icon badge's diameter as a fraction of the shorter screen
 * dimension — canvas Wear 05. */
private const val ICON_BADGE_SIZE_FRACTION = 0.14f

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
        val badgeSize = minOf(maxWidth, maxHeight) * ICON_BADGE_SIZE_FRACTION
        Column(
            modifier = Modifier.fillMaxSize().padding(maxWidth * SCREEN_PADDING_FRACTION),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(maxWidth * 0.05f, Alignment.CenterVertically),
        ) {
            Box(
                modifier = Modifier
                    .size(badgeSize)
                    .background(LifeyColors.negative.copy(alpha = 0.16f), CircleShape),
                contentAlignment = Alignment.Center,
            ) {
                Icon(
                    imageVector = Icons.Filled.PriorityHigh,
                    contentDescription = null,
                    tint = LifeyColors.negative,
                    modifier = Modifier.size(badgeSize * 0.55f),
                )
            }
            Text(
                text = stringResource(R.string.error_already_running_title),
                style = if (isCompact) MaterialTheme.typography.title3 else MaterialTheme.typography.title2,
                color = LifeyColors.onSurface,
                textAlign = TextAlign.Center,
            )
            Text(
                text = stringResource(R.string.error_already_running_subtitle),
                style = if (isCompact) MaterialTheme.typography.caption2 else MaterialTheme.typography.caption1,
                color = LifeyColors.onSurfaceVariant,
                textAlign = TextAlign.Center,
            )
            CompactChip(
                onClick = { SessionStateHolder.reset() },
                label = { Text(stringResource(R.string.error_ok_button)) },
                colors = ChipDefaults.chipColors(
                    backgroundColor = LifeyColors.containerHighest,
                    contentColor = LifeyColors.onSurface,
                ),
            )
        }
    }
}
