package com.khunor.lifey.ui

import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Bolt
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextAlign
import androidx.wear.compose.foundation.lazy.TransformingLazyColumn
import androidx.wear.compose.foundation.lazy.rememberTransformingLazyColumnState
import androidx.wear.compose.material.Text
import com.khunor.lifey.R
import com.khunor.lifey.StandaloneSessionStore
import com.khunor.lifey.ui.active.cardioActivityIcon
import com.khunor.lifey.ui.active.cardioActivityTint
import com.khunor.lifey.ui.components.DismissibleOverlay
import com.khunor.lifey.ui.components.LifeyAppScaffold
import com.khunor.lifey.ui.components.LifeyScreen
import com.khunor.lifey.ui.components.ListRow
import com.khunor.lifey.ui.components.RowLeading
import com.khunor.lifey.ui.theme.LifeyColors
import com.khunor.lifey.ui.theme.LifeySpacing
import com.khunor.lifey.ui.theme.LifeyType
import org.json.JSONObject

/** One row of the picker pages (W2.2 / W2.3). */
data class PickerRow(
    val title: String,
    val subtitle: String?,
    val leading: RowLeading,
    val isHighlighted: Boolean = false,
    val onClick: () -> Unit,
)

/**
 * The picker list (W2.2 / W2.3): a centred title that scrolls away under the `TimeText`, then **every** row an
 * M3 [ListRow] pill — quick strength included (highlighted: `raised` + a holder), templates (title + exercise
 * count), cardio types (accent icon circle) and the "all types" page — in a [TransformingLazyColumn] whose
 * ScrollIndicator comes from the screen scaffold. The Chip-and-card mix and the corner arrow are gone; back is
 * a swipe. With nothing synced yet, [emptyHint] is shown centred under the quick-strength row.
 */
@Composable
fun PickerContent(title: String, rows: List<PickerRow>, emptyHint: String?, modifier: Modifier = Modifier) {
    val state = rememberTransformingLazyColumnState()
    LifeyScreen(scrollState = state, modifier = modifier) { contentPadding ->
        TransformingLazyColumn(state = state, contentPadding = contentPadding) {
            item {
                Text(
                    title, style = LifeyType.title(), color = LifeyColors.text, textAlign = TextAlign.Center, maxLines = 1,
                    modifier = Modifier.fillMaxWidth().padding(bottom = LifeySpacing.md),
                )
            }
            rows.forEach { row ->
                item {
                    ListRow(
                        title = row.title, onClick = row.onClick, subtitle = row.subtitle, leading = row.leading,
                        isHighlighted = row.isHighlighted, modifier = Modifier.padding(bottom = LifeySpacing.sm),
                    )
                }
            }
            if (emptyHint != null) {
                item {
                    Text(
                        emptyHint, style = LifeyType.body(), color = LifeyColors.text2, textAlign = TextAlign.Center,
                        modifier = Modifier.fillMaxWidth(),
                    )
                }
            }
        }
    }
}

/**
 * The pre-start picker (docs/watch/44 §3.1, 49 D-F6b.7, cardio 55 §3): "Quick strength" is always first and
 * works with zero phone contact; below it up to 8 ranked entries from [StandaloneSessionStore] — synced
 * templates and cardio activity types interleaved in the phone's own order — or just the empty hint when
 * nothing has synced; at the end one row to the page with every activity type. [onTemplateTapped] gets the
 * raw template `JSONObject` and [onCardioTapped] the activity code plus its pre-localised title, so
 * `MainActivity` (which owns `requestSensorPermissionsIfNeeded` and the `startForegroundService` call)
 * stays the only place that starts a service. Swipe / the back key = [onBack] (the launcher).
 */
@Composable
fun StandalonePickerScreen(
    onQuickStrengthTapped: () -> Unit,
    onBack: () -> Unit,
    onTemplateTapped: (JSONObject) -> Unit,
    onCardioTapped: (String, String) -> Unit,
) {
    val context = LocalContext.current
    // Local UI navigation only: the phase never changes while browsing, so this stays here.
    var showAllTypes by remember { mutableStateOf(false) }
    val allCardio = remember { StandaloneSessionStore.allCardio(context) }
    // A point-in-time snapshot, like every other read of the store.
    val entries = remember { StandaloneSessionStore.entries(context) }

    LifeyAppScaffold {
        if (showAllTypes) {
            DismissibleOverlay(onDismiss = { showAllTypes = false }) {
                PickerContent(
                    title = stringResource(R.string.standalone_all_types),
                    rows = allCardio.mapNotNull { entry ->
                        val activityType = entry.optString("activityType")
                        if (activityType.isEmpty()) null else cardioRow(activityType, entry.optString("title"), onCardioTapped)
                    },
                    emptyHint = null,
                )
            }
        } else {
            DismissibleOverlay(onDismiss = onBack) {
                val rows = buildList {
                    add(
                        PickerRow(
                            title = stringResource(R.string.standalone_quick_start),
                            subtitle = stringResource(R.string.standalone_quick_caption),
                            leading = RowLeading.Holder(Icons.Filled.Bolt),
                            isHighlighted = true,
                            onClick = onQuickStrengthTapped,
                        ),
                    )
                    entries.forEach { entry ->
                        when (entry.optString("type")) {
                            "CARDIO" -> add(cardioRow(entry.optString("activityType"), entry.optString("title"), onCardioTapped))
                            // "TEMPLATE" and any future type this build does not know: read as a template — the
                            // opt* calls degrade to blank fields rather than throwing, costing only this row.
                            else -> add(
                                PickerRow(
                                    title = entry.optString("title"),
                                    subtitle = stringResource(R.string.standalone_plan_exercises, entry.optJSONArray("exercises")?.length() ?: 0),
                                    leading = RowLeading.None,
                                    onClick = { onTemplateTapped(entry) },
                                ),
                            )
                        }
                    }
                    // The ranked list is capped at 8 shared rows, so cardio can be missing from it entirely —
                    // this row is the way to every type. Hidden while the cache is empty.
                    if (allCardio.isNotEmpty()) {
                        add(
                            PickerRow(
                                title = stringResource(R.string.standalone_all_types), subtitle = null,
                                leading = RowLeading.None, onClick = { showAllTypes = true },
                            ),
                        )
                    }
                }
                PickerContent(
                    title = stringResource(R.string.standalone_picker_title),
                    rows = rows,
                    emptyHint = if (entries.isEmpty()) stringResource(R.string.standalone_empty_hint) else null,
                )
            }
        }
    }
}

private fun cardioRow(activityType: String, title: String, onTap: (String, String) -> Unit) = PickerRow(
    title = title,
    subtitle = null,
    leading = RowLeading.Tinted(cardioActivityIcon(activityType), cardioActivityTint(activityType)),
    onClick = { onTap(activityType, title) },
)
