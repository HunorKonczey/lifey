package com.khunor.lifey.ui

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Bolt
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.wear.compose.foundation.lazy.ScalingLazyColumn
import androidx.wear.compose.foundation.lazy.rememberScalingLazyListState
import androidx.wear.compose.material.Chip
import androidx.wear.compose.material.ChipDefaults
import androidx.wear.compose.material.Icon
import androidx.wear.compose.material.MaterialTheme
import androidx.wear.compose.material.Text
import com.khunor.lifey.R
import com.khunor.lifey.ui.theme.LifeyColors

/**
 * F6a's pre-start picker (docs/watch/44-watch-f6-standalone-plan.md §3.1,
 * §3.3, design canvas W 12) — always the "empty/stale cache" variant in F6a:
 * just the "Quick strength" row + `standalone_empty_hint`, since there's no
 * template sync yet (F6b adds synced-plan rows above the hint). Built as a
 * `ScalingLazyColumn` from the start, even with this little content, so
 * F6b's template rows slot in without restructuring this screen.
 *
 * [onQuickStrengthTapped] starts the standalone exercise directly —
 * debouncing a double-tap is `ExerciseService.startStandaloneExercise`'s
 * job (a phase guard), not this screen's, since the same protection has to
 * hold regardless of what triggers it. [onBack] mirrors
 * `EffortSelectorScreen`'s own top-start dismiss affordance — not present in
 * the design frame itself, but F6a's picker has exactly one actionable row,
 * so without it a user who opened the picker by mistake would be stuck.
 */
@Composable
fun StandalonePickerScreen(onQuickStrengthTapped: () -> Unit, onBack: () -> Unit) {
    BoxWithConstraints(modifier = Modifier.fillMaxSize()) {
        val isCompact = isCompactScreen(maxWidth)
        val listState = rememberScalingLazyListState()

        ScalingLazyColumn(
            state = listState,
            modifier = Modifier.fillMaxSize(),
            contentPadding = PaddingValues(
                horizontal = maxWidth * SCREEN_PADDING_FRACTION,
                vertical = maxWidth * 0.14f,
            ),
        ) {
            item {
                Text(
                    text = stringResource(R.string.standalone_picker_title),
                    style = if (isCompact) MaterialTheme.typography.title3 else MaterialTheme.typography.title2,
                    color = LifeyColors.onSurface,
                )
            }
            item {
                Chip(
                    onClick = onQuickStrengthTapped,
                    modifier = Modifier.fillMaxWidth(),
                    icon = {
                        Icon(
                            imageVector = Icons.Filled.Bolt,
                            contentDescription = null,
                            tint = LifeyColors.primary,
                        )
                    },
                    label = {
                        Text(stringResource(R.string.standalone_quick_start), maxLines = 1)
                    },
                    secondaryLabel = {
                        Text(stringResource(R.string.standalone_quick_caption), maxLines = 1)
                    },
                    colors = ChipDefaults.chipColors(
                        backgroundColor = LifeyColors.containerHigh,
                        contentColor = LifeyColors.onSurface,
                    ),
                )
            }
            item {
                Text(
                    text = stringResource(R.string.standalone_empty_hint),
                    style = MaterialTheme.typography.caption2,
                    color = LifeyColors.onSurfaceVariant,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.fillMaxWidth(),
                )
            }
        }

        // Top-start corner, out of the ScalingLazyColumn's flow — dismisses
        // back to the launcher without starting anything.
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
