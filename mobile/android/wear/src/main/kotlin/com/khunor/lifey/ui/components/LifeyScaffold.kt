package com.khunor.lifey.ui.components

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.wear.compose.foundation.lazy.TransformingLazyColumnState
import androidx.wear.compose.foundation.pager.HorizontalPager
import androidx.wear.compose.foundation.pager.PagerState
import androidx.wear.compose.material.SwipeToDismissBox
import androidx.wear.compose.foundation.rememberSwipeToDismissBoxState
import androidx.wear.compose.material3.AppScaffold
import androidx.wear.compose.material3.HorizontalPageIndicator
import androidx.wear.compose.material3.ScreenScaffold
import androidx.wear.compose.material3.TimeText

/**
 * Round-screen scaffolding (redesign plan 79, X0w.9 / D-X0.9, D-X0.12). One place for the Wear M3
 * structure every screen of X3 / X4 sits in: TimeText on top, a ScrollIndicator for scrolling pages, an
 * optional EdgeButton on the bottom arc, a pager that never reacts to the rotary input, and swipe-to-dismiss
 * overlays that never close the activity mid-workout.
 */

/** App root: M3 [AppScaffold] with the [TimeText] shared by every screen. */
@Composable
fun LifeyAppScaffold(content: @Composable BoxScope.() -> Unit) {
    AppScaffold(timeText = { TimeText() }, content = content)
}

/**
 * One screen: M3 [ScreenScaffold] over a [TransformingLazyColumnState] (its ScrollIndicator appears on the
 * right whenever the page scrolls) with an optional [edgeButton] on the bottom arc.
 */
@Composable
fun LifeyScreen(
    scrollState: TransformingLazyColumnState,
    modifier: Modifier = Modifier,
    edgeButton: (@Composable BoxScope.() -> Unit)? = null,
    content: @Composable BoxScope.(PaddingValues) -> Unit,
) {
    if (edgeButton != null) {
        ScreenScaffold(scrollState = scrollState, modifier = modifier, edgeButton = edgeButton, content = content)
    } else {
        ScreenScaffold(scrollState = scrollState, modifier = modifier, content = content)
    }
}

/**
 * Edge-row transformation (D-X0.12): rows at the top and bottom of a list shrink by at most 12 % and fade
 * to no less than 80 % (the screen frames W1.15 / W2.2, which win over the DS frame 05's 85 % / 70 %).
 *
 * UNVERIFIED offline: the library's default transformation is used until a compile is available to build
 * the custom `TransformationVariableSpec` with these numbers.
 */
object LifeyTransformation {
    const val MIN_SCALE = 0.88f
    const val MIN_ALPHA = 0.80f
}

/**
 * The pager of the active workout (strength 3 pages, cardio 2): the wear-foundation [HorizontalPager] with
 * rotary paging **off** — the crown steps values and scrolls lists, it never pages (D-X0.9). The M3
 * [HorizontalPageIndicator] is hidden while an EdgeButton or status pill occupies the bottom arc
 * ([bottomSlotOccupied]).
 */
@Composable
fun LifeyPager(
    state: PagerState,
    modifier: Modifier = Modifier,
    bottomSlotOccupied: Boolean = false,
    page: @Composable (Int) -> Unit,
) {
    Box(modifier) {
        HorizontalPager(state = state, rotaryScrollableBehavior = null) { index -> page(index) }
        if (!bottomSlotOccupied) HorizontalPageIndicator(pagerState = state)
    }
}

/**
 * An overlay (effort, exercise list, adjust, all-types) that closes by swipe-to-dismiss and by the hardware
 * back key, calling [onDismiss] — and never finishes the activity, so a swipe cannot end a running workout.
 */
@Composable
fun DismissibleOverlay(
    onDismiss: () -> Unit,
    modifier: Modifier = Modifier,
    content: @Composable () -> Unit,
) {
    BackHandler(onBack = onDismiss)
    SwipeToDismissBox(
        state = rememberSwipeToDismissBoxState(),
        modifier = modifier,
        onDismissed = onDismiss,
    ) { isBackground ->
        if (!isBackground) content()
    }
}
