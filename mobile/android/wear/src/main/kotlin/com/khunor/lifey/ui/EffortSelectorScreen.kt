package com.khunor.lifey.ui

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Remove
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.wear.compose.material.Chip
import androidx.wear.compose.material.ChipDefaults
import androidx.wear.compose.material.CompactChip
import androidx.wear.compose.material.Icon
import androidx.wear.compose.material.MaterialTheme
import androidx.wear.compose.material.Text
import com.khunor.lifey.R
import com.khunor.lifey.ui.theme.LifeyColors

private const val RPE_MIN = 1
private const val RPE_MAX = 10

/**
 * Shown as a full-screen overlay right after the watch's End button is
 * pressed, before anything is sent to the phone (docs/40-watch-app-plan.md
 * §8.2 decision (b) — the round-trip that actually stops the sensors is
 * unchanged, only *where* the effort rating is collected moves here instead
 * of the phone's [com.khunor.lifey] counterpart's feedback sheet). A big
 * stepper rather than the phone's 10-chip row: a row of 10 numbered chips
 * doesn't fit legibly on a round dial. [onSkip] closes the workout with no
 * rating at all — the comment/note is never collected here either way, it
 * always stays empty for a watch-closed session. [onBack] dismisses this
 * screen without ending the workout at all — nothing is sent to the phone,
 * the session just resumes on [ActiveWorkoutScreen] exactly as it was.
 */
@Composable
fun EffortSelectorScreen(
    rpe: Int,
    onRpeChange: (Int) -> Unit,
    onConfirm: () -> Unit,
    onSkip: () -> Unit,
    onBack: () -> Unit,
) {
    BoxWithConstraints(modifier = Modifier.fillMaxSize()) {
        val isCompact = isCompactScreen(maxWidth)
        val numberStyle = MaterialTheme.typography.display1
        val titleStyle = if (isCompact) MaterialTheme.typography.caption1 else MaterialTheme.typography.title3

        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(horizontal = maxWidth * SCREEN_PADDING_FRACTION),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center,
        ) {
            Text(
                text = stringResource(R.string.effort_selector_title),
                style = titleStyle,
                color = LifeyColors.onSurface,
                textAlign = TextAlign.Center,
            )
            Row(
                modifier = Modifier.padding(top = 4.dp, bottom = 4.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                CompactChip(
                    onClick = { if (rpe > RPE_MIN) onRpeChange(rpe - 1) },
                    icon = { Icon(imageVector = Icons.Filled.Remove, contentDescription = null, tint = LifeyColors.onSurface) },
                    colors = ChipDefaults.chipColors(
                        backgroundColor = LifeyColors.container,
                        contentColor = LifeyColors.onSurface,
                    ),
                )
                Text(
                    text = rpe.toString(),
                    style = numberStyle,
                    color = LifeyColors.primary,
                )
                CompactChip(
                    onClick = { if (rpe < RPE_MAX) onRpeChange(rpe + 1) },
                    icon = { Icon(imageVector = Icons.Filled.Add, contentDescription = null, tint = LifeyColors.onSurface) },
                    colors = ChipDefaults.chipColors(
                        backgroundColor = LifeyColors.container,
                        contentColor = LifeyColors.onSurface,
                    ),
                )
            }
            Chip(
                onClick = onConfirm,
                modifier = Modifier.fillMaxWidth().padding(top = 4.dp),
                icon = { Icon(imageVector = Icons.Filled.Check, contentDescription = null, tint = LifeyColors.onPrimary) },
                label = {
                    Text(
                        stringResource(R.string.effort_selector_confirm),
                        color = LifeyColors.onPrimary,
                        maxLines = 1,
                    )
                },
                colors = ChipDefaults.chipColors(
                    backgroundColor = LifeyColors.primary,
                    contentColor = LifeyColors.onPrimary,
                ),
            )
            Text(
                text = stringResource(R.string.effort_selector_skip),
                style = MaterialTheme.typography.caption1,
                color = LifeyColors.onSurfaceVariant,
                modifier = Modifier
                    .padding(top = 10.dp)
                    .clickable(onClick = onSkip),
            )
        }

        // Top-start corner, out of the centered Column's flow — dismisses
        // back to the normal active-workout view without ending anything.
        Icon(
            imageVector = Icons.AutoMirrored.Filled.ArrowBack,
            contentDescription = stringResource(R.string.effort_selector_back),
            tint = LifeyColors.onSurfaceVariant,
            modifier = Modifier
                .align(Alignment.TopStart)
                .padding(8.dp)
                .clickable(onClick = onBack)
                .size(20.dp),
        )
    }
}
