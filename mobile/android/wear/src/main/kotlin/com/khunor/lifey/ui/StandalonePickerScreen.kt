package com.khunor.lifey.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Bolt
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.wear.compose.foundation.lazy.ScalingLazyColumn
import androidx.wear.compose.foundation.lazy.rememberScalingLazyListState
import androidx.wear.compose.material.Chip
import androidx.wear.compose.material.ChipDefaults
import androidx.wear.compose.material.Icon
import androidx.wear.compose.material.MaterialTheme
import androidx.wear.compose.material.Text
import com.khunor.lifey.R
import com.khunor.lifey.StandaloneSessionStore
import com.khunor.lifey.ui.theme.LifeyColors
import com.khunor.lifey.ui.theme.LifeyShapes
import org.json.JSONObject

/**
 * The pre-start picker (docs/watch/44-watch-f6-standalone-plan.md §3.1,
 * §3.3; docs/watch/49-watch-f6b-template-sync-plan.md D-F6b.7, design canvas
 * W 12; unified with cardio entries by docs/cardio/55-cardio-watch-plan.md
 * §3, canvas W 15 — C5.6). "Quick strength" is always first and always
 * works with zero phone contact; below it, up to 8 ranked entries from
 * [com.khunor.lifey.StandaloneSessionStore] — synced templates (title +
 * exercise count) and cardio activity types (icon + title) interleaved in
 * whatever order the phone already ranked them (§3.1: "nem talál ki saját
 * rendezést") — or, with an empty/stale cache, just `standalone_empty_hint`
 * (F6a's only variant, still the fallback here).
 *
 * [onQuickStrengthTapped] starts the standalone exercise directly —
 * debouncing a double-tap is `ExerciseService.startStandaloneExercise`'s
 * job (a phase guard), not this screen's, since the same protection has to
 * hold regardless of what triggers it. [onBack] mirrors
 * `EffortSelectorScreen`'s own top-start dismiss affordance — not present in
 * the design frame itself, but F6a's picker has exactly one actionable row,
 * so without it a user who opened the picker by mistake would be stuck.
 *
 * [onTemplateTapped] receives the tapped row's raw template `JSONObject` —
 * the same shape a `"TEMPLATE"` entry arrives in — so
 * `MainActivity` can pass it straight through to
 * `ExerciseService.startStandaloneIntent`'s `templateJson` extra without
 * this screen needing to know anything about that wire shape itself
 * (docs/watch/49-watch-f6b-template-sync-plan.md §3.3, T6). Unlike
 * [onQuickStrengthTapped], the actual `startForegroundService` call has to
 * happen in `MainActivity`, not here — starting the service also needs
 * `requestSensorPermissionsIfNeeded()`, which needs the `ComponentActivity`
 * this screen doesn't have.
 *
 * A **cardio** row ([CardioRow]) starts a standalone cardio exercise
 * (docs/cardio/55-cardio-watch-plan.md §5/§7 W-8, C5.7a) — [onCardioTapped]
 * receives the tapped row's `activityType` code, which `MainActivity` passes
 * straight through to `ExerciseService.startStandaloneIntent`'s
 * `activityType` extra, the same "this screen doesn't own the
 * `startForegroundService` call" split [onTemplateTapped] already follows.
 */
@Composable
fun StandalonePickerScreen(
    onQuickStrengthTapped: () -> Unit,
    onBack: () -> Unit,
    onTemplateTapped: (JSONObject) -> Unit,
    onCardioTapped: (String) -> Unit,
) {
    val context = LocalContext.current
    // Read once per composition, not observed live — matches
    // StandaloneSessionStore's existing "read is a point-in-time snapshot"
    // contract everywhere else it's used (SummarySender's pending-count,
    // the summary screen's sync chip). A sync landing while this exact
    // screen is already showing updates on the next time it's opened, not
    // instantly — an acceptable staleness window for a picker the user only
    // glances at before tapping something.
    val entries = remember { StandaloneSessionStore.entries(context) }

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
            if (entries.isEmpty()) {
                item {
                    Text(
                        text = stringResource(R.string.standalone_empty_hint),
                        style = MaterialTheme.typography.caption2,
                        color = LifeyColors.onSurfaceVariant,
                        textAlign = TextAlign.Center,
                        modifier = Modifier.fillMaxWidth(),
                    )
                }
            } else {
                entries.forEach { entry ->
                    when (entry.optString("type")) {
                        "CARDIO" -> item {
                            val activityType = entry.optString("activityType")
                            CardioRow(
                                activityType = activityType,
                                title = entry.optString("title"),
                                isCompact = isCompact,
                                onTap = { onCardioTapped(activityType) },
                            )
                        }
                        // "TEMPLATE", and any future/unknown type this build
                        // doesn't recognize falls back to a template read —
                        // `TemplateRow`'s own `opt*` calls degrade to blank
                        // fields rather than throwing, and costs only this
                        // one row, not the rest of the list.
                        else -> item {
                            TemplateRow(
                                template = entry,
                                isCompact = isCompact,
                                onTap = { onTemplateTapped(entry) },
                            )
                        }
                    }
                }
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

/**
 * One synced-template row (canvas W 12) — plain `surface` background,
 * unlike the quick-strength [Chip]'s highlighted `containerHigh` treatment
 * (D-F6b.7: quick-strength is the one always-works option, these are
 * secondary). No icon, matching the canvas exactly — just title + the
 * existing `standalone_plan_exercises` count string (added in F6a's S1,
 * unused until now). [template] is a `"TEMPLATE"`-typed row from
 * `StandaloneSessionStore.entries()` (this store's raw-JSON convention,
 * unlike iOS's typed `WatchQuickStartEntry`) — read here with `opt*`,
 * matching every other JSON-decode site in this app rather than introducing
 * a data class for a single call site.
 */
@Composable
private fun TemplateRow(template: JSONObject, isCompact: Boolean, onTap: () -> Unit) {
    val exerciseCount = template.optJSONArray("exercises")?.length() ?: 0
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onTap)
            .background(LifeyColors.surface, LifeyShapes.card)
            .padding(horizontal = 16.dp, vertical = 12.dp),
    ) {
        Text(
            text = template.optString("title"),
            style = if (isCompact) MaterialTheme.typography.body2 else MaterialTheme.typography.body1,
            color = LifeyColors.onSurface,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
        )
        Text(
            text = stringResource(R.string.standalone_plan_exercises, exerciseCount),
            style = MaterialTheme.typography.caption2,
            color = LifeyColors.onSurfaceVariant,
            maxLines = 1,
        )
    }
}

/**
 * One ranked cardio activity-type row (canvas W 15) — an icon circle tinted
 * per activity type ([cardioActivityIcon]/[cardioActivityTint],
 * `ActiveWorkoutScreen.kt` — shared with that file's own cardio pages,
 * C5.6), [TemplateRow]'s plain `surface` card otherwise, plus the
 * pre-localized [title]. Tapping starts a standalone cardio exercise
 * (docs/cardio/55-cardio-watch-plan.md §5/§7 W-8, C5.7a) — see
 * [StandalonePickerScreen]'s doc comment.
 */
@Composable
private fun CardioRow(activityType: String, title: String, isCompact: Boolean, onTap: () -> Unit) {
    val tint = cardioActivityTint(activityType)
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onTap)
            .background(LifeyColors.surface, LifeyShapes.card)
            .padding(horizontal = 16.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(13.dp),
    ) {
        Box(
            modifier = Modifier
                .size(40.dp)
                .background(tint.copy(alpha = 0.18f), CircleShape),
            contentAlignment = Alignment.Center,
        ) {
            Icon(
                imageVector = cardioActivityIcon(activityType),
                contentDescription = null,
                tint = tint,
            )
        }
        Text(
            text = title,
            style = if (isCompact) MaterialTheme.typography.body2 else MaterialTheme.typography.body1,
            color = LifeyColors.onSurface,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
        )
    }
}
