package com.khunor.lifey.ui.active

import android.Manifest
import android.os.SystemClock
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.requiredWidth
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.DirectionsBike
import androidx.compose.material.icons.automirrored.filled.List
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.AirlineSeatReclineNormal
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.DirectionsRun
import androidx.compose.material.icons.filled.DirectionsWalk
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.FitnessCenter
import androidx.compose.material.icons.filled.HeartBroken
import androidx.compose.material.icons.filled.Hiking
import androidx.compose.material.icons.filled.LocalFireDepartment
import androidx.compose.material.icons.filled.MonitorHeart
import androidx.compose.material.icons.filled.Pause
import androidx.compose.material.icons.filled.PedalBike
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Remove
import androidx.compose.material.icons.filled.SignalWifiOff
import androidx.compose.material.icons.filled.SportsBasketball
import androidx.compose.material.icons.filled.SportsSoccer
import androidx.compose.material.icons.filled.Stop
import androidx.compose.material.icons.filled.Sync
import androidx.compose.material.icons.filled.Tune
import androidx.compose.material.icons.filled.Timer
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.foundation.focusable
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.material.icons.filled.PhonelinkOff
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.content.ContextCompat
import androidx.wear.compose.foundation.lazy.ScalingLazyColumn
import androidx.wear.compose.foundation.lazy.rememberScalingLazyListState
import androidx.wear.compose.foundation.pager.HorizontalPager
import androidx.wear.compose.foundation.pager.rememberPagerState
import androidx.wear.compose.foundation.rotary.RotaryScrollableDefaults
import androidx.compose.ui.input.rotary.onRotaryScrollEvent
import androidx.wear.compose.material.ChipDefaults
import androidx.wear.compose.material.Chip
import androidx.wear.compose.material.CompactChip
import androidx.wear.compose.material.Icon
import androidx.wear.compose.material.MaterialTheme
import androidx.wear.compose.material.Text
import com.google.android.gms.wearable.Wearable
import com.khunor.lifey.ActiveExerciseDisplay
import com.khunor.lifey.CardioActiveMetrics
import com.khunor.lifey.CardioActivityFamily
import com.khunor.lifey.ExerciseService
import com.khunor.lifey.LiveMetrics
import com.khunor.lifey.LogAdjustField
import com.khunor.lifey.LogAdjustState
import com.khunor.lifey.LogSetState
import com.khunor.lifey.R
import com.khunor.lifey.SessionMetadata
import com.khunor.lifey.SessionStateHolder
import com.khunor.lifey.StandaloneSessionStore
import com.khunor.lifey.StandaloneTemplate
import com.khunor.lifey.StandaloneTemplateExercise
import com.khunor.lifey.SummarySender
import com.khunor.lifey.ui.theme.LifeyColors
import com.khunor.lifey.ui.theme.LifeyShapes
import java.util.UUID
import kotlin.math.abs
import java.util.Locale
import kotlin.math.roundToInt
import kotlin.math.sign
import java.text.DecimalFormat
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.tasks.await
import com.khunor.lifey.ui.EffortSelectorScreen
import com.khunor.lifey.ui.SCREEN_PADDING_FRACTION
import com.khunor.lifey.ui.LOG_BUTTON_PAIR_DIAMETER_FRACTION
import com.khunor.lifey.ui.isCompactScreen

// MARK: - Cardio (docs/cardio/55-cardio-watch-plan.md §4, C5.6)

/**
 * SF-Symbol-equivalent per `ActivityType` — the watchOS side's
 * `cardioActivityIcon` uses `figure.run`/`figure.walk`/etc.; here it's
 * whatever `material-icons-extended` actually ships (verified against the
 * 1.7.8 AAR, not guessed): `DirectionsRun`/`DirectionsWalk`/`Hiking`/
 * `PedalBike`/`SportsBasketball`/`SportsSoccer`. An unrecognized code (a
 * future activity type this build predates) falls back to `MonitorHeart`,
 * the same generic glyph `OTHER_CARDIO` itself uses. Shared with
 * `StandalonePickerScreen`'s `CardioRow` — both live in this module, so this
 * is `internal` (the package default), not duplicated the way the
 * `Runner`/`WatchBridge.kt` (iOS) copy has to be across targets.
 */
fun cardioActivityIcon(activityType: String): ImageVector = when (activityType) {
    "RUNNING" -> Icons.Filled.DirectionsRun
    "WALKING" -> Icons.Filled.DirectionsWalk
    "HIKING" -> Icons.Filled.Hiking
    // Outdoor cycling (docs/cardio/62-cardio-cycling-plan.md A5) — distinct
    // from INDOOR_BIKE's PedalBike below, mirroring the mobile app's same
    // DirectionsBike-vs-PedalBike split (`activity_type.dart`).
    // `Icons.Filled.DirectionsBike` is deprecated/hidden in this
    // material-icons-extended version (1.7.8) in favor of the AutoMirrored
    // one — same family `ArrowBack`/`List` already use in this file.
    "CYCLING" -> Icons.AutoMirrored.Filled.DirectionsBike
    "INDOOR_BIKE" -> Icons.Filled.PedalBike
    "BASKETBALL" -> Icons.Filled.SportsBasketball
    "FOOTBALL" -> Icons.Filled.SportsSoccer
    else -> Icons.Filled.MonitorHeart
}

/** Mirrors the mobile app's `activityTypeColor` (`activity_type.dart`) — see
 * `LifeyColors`'s "Cardio activity-type accents" section for which mobile
 * `MetricColors` token each hex reuses. */
fun cardioActivityTint(activityType: String): Color = when (activityType) {
    "RUNNING" -> LifeyColors.calories
    "WALKING" -> LifeyColors.cardioWalking
    "HIKING" -> LifeyColors.cardioHiking
    "CYCLING" -> LifeyColors.secondary // mirrors mobile's colorScheme.secondary
    "INDOOR_BIKE" -> LifeyColors.cardioIndoorBike
    "BASKETBALL" -> LifeyColors.cardioBasketball
    "FOOTBALL" -> LifeyColors.cardioFootball
    else -> LifeyColors.onSurfaceVariant
}

/**
 * The cardio counterpart of [StrengthActiveWorkoutScreen] — two swipeable
 * pages ([CardioMetricsPage], then the reused [ControlsPage]), no log-set/
 * adjust/exercise-list overlays. Duplicates [StrengthActiveWorkoutScreen]'s
 * small effort-selector wiring rather than sharing it — the two active
 * screens otherwise share almost nothing (no pager pages, no rest timer, no
 * log-set state), so splitting this one slice out on its own would cost more
 * indirection than the ~20 duplicated lines are worth.
 *
 * [ControlsPage] is reused **unmodified** — `hasStandaloneTemplate = false`
 * here always (a cardio session has no exercise plan), which already hides
 * its "Gyakorlatok" chip on its own; nothing about that composable is
 * STRENGTH-specific beyond that one already-conditional chip.
 */
@Composable
internal fun CardioActiveScreen() {
    val metadata by SessionStateHolder.metadata.collectAsState()
    val liveMetrics by SessionStateHolder.liveMetrics.collectAsState()
    val context = LocalContext.current
    val scope = rememberCoroutineScope()

    var showEffortSelector by remember { mutableStateOf(false) }
    var effortRpe by remember { mutableIntStateOf(5) }
    // W 19's edge border — the watch's answer to the phone's top rail (M07)
    // — is drawn around the whole screen, not just the metrics column, so
    // this is read here rather than inside GameMetricsContent. It lives on
    // `SessionStateHolder`, not in a `remember`: the phone shows the same
    // switch and either side can flip it (docs/cardio/55-cardio-watch-plan.md
    // §7, W-9).
    val onCourt = metadata.isOnCourt

    BoxWithConstraints(modifier = Modifier.fillMaxSize()) {
        val isCompact = isCompactScreen(maxWidth)

        if (showEffortSelector) {
            val sessionClientId = metadata.sessionClientId
            EffortSelectorScreen(
                rpe = effortRpe,
                onRpeChange = { effortRpe = it },
                onConfirm = {
                    if (sessionClientId != null) {
                        scope.launch { SummarySender.sendEndRequested(context, sessionClientId, effortRpe) }
                    }
                    showEffortSelector = false
                },
                onSkip = {
                    if (sessionClientId != null) {
                        scope.launch { SummarySender.sendEndRequested(context, sessionClientId, rpe = null) }
                    }
                    showEffortSelector = false
                },
                onBack = { showEffortSelector = false },
            )
        } else {
            val pagerState = rememberPagerState(initialPage = 0, pageCount = { 2 })
            val display = activeExerciseDisplay(metadata)
            HorizontalPager(
                state = pagerState,
                modifier = Modifier.fillMaxSize(),
                rotaryScrollableBehavior = RotaryScrollableDefaults.snapBehavior(pagerState),
            ) { page ->
                when (page) {
                    0 -> CardioMetricsPage(
                        metadata = metadata, liveMetrics = liveMetrics, isCompact = isCompact, maxWidth = maxWidth,
                        onCourt = onCourt,
                        onToggleCourt = {
                            // Only a real change goes over the wire — the
                            // holder answers whether this was one.
                            if (SessionStateHolder.setOnCourt(!onCourt)) {
                                val sessionClientId = metadata.sessionClientId
                                if (sessionClientId != null) {
                                    scope.launch {
                                        SummarySender.sendCourtChanged(
                                            context, sessionClientId, !onCourt,
                                        )
                                    }
                                }
                            }
                        },
                    )
                    else -> ControlsPage(
                        exerciseName = display.name,
                        setsDone = display.setsDone,
                        setsTotal = display.setsTotal,
                        isPaused = liveMetrics.isPaused,
                        freeFormatSets = display.freeFormatSets,
                        hasStandaloneTemplate = false,
                        isCompact = isCompact,
                        onEnd = { showEffortSelector = true },
                        onTogglePause = {
                            val paused = liveMetrics.isPaused
                            scope.launch {
                                if (paused) ExerciseService.resume(context) else ExerciseService.pause(context)
                            }
                        },
                        onOpenExerciseList = {},
                    )
                }
            }
            PageDots(
                pageCount = 2, selectedPage = pagerState.currentPage,
                modifier = Modifier.align(Alignment.BottomCenter).padding(bottom = 16.dp),
            )
            // "A barna keret a képernyő szélén ... csuklóemeléskor, fél
            // másodperc alatt is látszik, hogy a mérés pihen" (W 19).
            if (metadata.cardioFamily == CardioActivityFamily.GAME && !onCourt) {
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .border(5.dp, LifeyColors.secondary, CircleShape),
                )
            }
        }
    }
}

/**
 * The family-dispatching cardio metrics page (canvas W 16–19) — `GAME` gets
 * its own layout ([GameMetricsContent], the pályán/padon toggle and its
 * single "bruttó" box), everything else shares [DistanceMachineMetricsContent]
 * (two boxes, no toggle). [movingSeconds] ticks once a second from
 * [CardioActiveMetrics.movingSecondsBase]/[CardioActiveMetrics
 * .movingAnchorElapsedRealtimeMs] — see that class's doc for why this can't
 * just display whatever string the phone last pushed for the moving/game-time
 * slot.
 */
/**
 * This watch's own live cardio metrics, for a session **it** started — the
 * fallback behind `metadata.cardioMetrics`, which only ever arrives from a
 * phone-mastered session's state sync.
 *
 * Without it a watch-started walk had nothing to show at all: no time, no
 * distance, just the heart-rate row under a header reading "STRENGTH" (the
 * generic `active_header_label`, since a standalone session had no title
 * either) — while Health Services was handing [ExerciseService] every number
 * the page needed.
 *
 * Same slots, same order, same rules as the phone fills them with
 * (`CardioSessionScreen._cardioLiveMetrics`), so the standalone screens are
 * the *same* screens rather than a second design:
 * - `DISTANCE`: distance leads once there is one, moving time before that,
 *   pace third;
 * - `MACHINE`: moving time alone — the phone's other two slots come from
 *   cadence/power sensors this watch doesn't have, and a box reading "—" for
 *   a whole session is worse than no box;
 * - `GAME`: playing time alone, for the same reason (gross time only differs
 *   once something pauses the accounting, which standalone can't do — see
 *   [CardioActiveScreen]'s `onCourt` doc).
 *
 * Time is anchored, not stored: `movingSecondsBase = 0` plus the session's
 * own start mark means the ticking slot counts real elapsed seconds. The
 * anchor is never dropped for a paused session, matching what a paused
 * *phone-mastered* one already does — pausing stops the sensors, not the
 * clock (docs/40-watch-app-plan.md §4.4/§5.3).
 */
@Composable
internal fun localCardioMetrics(
    metadata: SessionMetadata,
    family: CardioActivityFamily,
    liveMetrics: LiveMetrics,
): CardioActiveMetrics? {
    val startedAt = liveMetrics.startedAtElapsedRealtimeMs ?: return null
    val imperial = StandaloneSessionStore.isImperial(LocalContext.current)
    val movingTimeLabel = stringResource(R.string.cardio_moving_time_label)
    val distanceLabel = stringResource(R.string.cardio_distance_label)
    val paceLabel = stringResource(R.string.cardio_pace_label)
    val playingTimeLabel = stringResource(R.string.cardio_playing_time_label)
    val elapsedSeconds = ((SystemClock.elapsedRealtime() - startedAt) / 1000L).toInt()
    val duration = formatCardioDuration(elapsedSeconds)
    val meters = liveMetrics.distanceMeters ?: 0.0
    val hasDistance = meters > 0
    return when (family) {
        CardioActivityFamily.DISTANCE -> CardioActiveMetrics(
            primaryLabel = if (hasDistance) distanceLabel else movingTimeLabel,
            primaryValue = if (hasDistance) formatDistance(meters, imperial) else duration,
            secondaryLabel = if (hasDistance) movingTimeLabel else distanceLabel,
            secondaryValue = if (hasDistance) duration else "—",
            tertiaryLabel = paceLabel,
            tertiaryValue = formatPace(meters, elapsedSeconds, imperial) ?: "—",
            movingSecondsBase = 0,
            movingAnchorElapsedRealtimeMs = startedAt,
        )
        CardioActivityFamily.MACHINE -> CardioActiveMetrics(
            primaryLabel = movingTimeLabel,
            primaryValue = duration,
            movingSecondsBase = 0,
            movingAnchorElapsedRealtimeMs = startedAt,
        )
        // The one family whose playing time is *not* the elapsed time:
        // benched minutes don't count (W-9), so the hero counts from this
        // watch's own accumulator and the gross box next to it keeps the wall
        // clock.
        CardioActivityFamily.GAME -> CardioActiveMetrics(
            primaryLabel = playingTimeLabel,
            primaryValue = formatCardioDuration(SessionStateHolder.localPlayingSeconds()),
            secondaryLabel = stringResource(R.string.cardio_gross_time_label),
            secondaryValue = duration,
            onCourt = metadata.isOnCourt,
            movingSecondsBase = metadata.localMovingSecondsBase,
            movingAnchorElapsedRealtimeMs = metadata.localMovingAnchorElapsedRealtimeMs,
        )
    }
}

/** "5:12" under an hour, "1:05:12" from an hour up — a deliberate
 * transcription of the phone's `CardioFormatter.duration`
 * (`mobile/lib/core/format/cardio_formatter.dart`), so the same walk reads
 * the same on both screens. */
internal fun formatCardioDuration(totalSeconds: Int): String {
    val hours = totalSeconds / 3600
    val minutes = (totalSeconds % 3600) / 60
    val seconds = totalSeconds % 60
    val ss = seconds.toString().padStart(2, '0')
    return if (hours > 0) "$hours:${minutes.toString().padStart(2, '0')}:$ss" else "$minutes:$ss"
}

/** "5.23 km" / "3.25 mi" — `CardioFormatter.distance`, transcribed. */
internal fun formatDistance(meters: Double, imperial: Boolean): String {
    val unitMeters = if (imperial) 1609.344 else 1000.0
    val suffix = if (imperial) "mi" else "km"
    return String.format(Locale.US, "%.2f %s", meters / unitMeters, suffix)
}

/** "5:12 /km" / "8:22 /mi", or null with no distance to derive one from —
 * `CardioFormatter.pace`, transcribed (including its "never surface 0:00"
 * rule). */
internal fun formatPace(meters: Double, seconds: Int, imperial: Boolean): String? {
    if (meters <= 0 || seconds <= 0) return null
    val unitMeters = if (imperial) 1609.344 else 1000.0
    val secondsPerUnit = seconds / (meters / unitMeters)
    if (!secondsPerUnit.isFinite()) return null
    val minutes = (secondsPerUnit / 60).toInt()
    val rest = (secondsPerUnit % 60).roundToInt()
    val suffix = if (imperial) "/mi" else "/km"
    return "$minutes:${rest.toString().padStart(2, '0')} $suffix"
}

@Composable
internal fun CardioMetricsPage(
    metadata: SessionMetadata,
    liveMetrics: LiveMetrics,
    isCompact: Boolean,
    maxWidth: Dp,
    onCourt: Boolean,
    onToggleCourt: () -> Unit,
) {
    val activityType = metadata.cardioActivityType ?: "OTHER_CARDIO"
    val family = metadata.cardioFamily ?: CardioActivityFamily.DISTANCE
    val cardioMetrics = metadata.cardioMetrics ?: localCardioMetrics(metadata, family, liveMetrics)

    var movingSeconds by remember { mutableLongStateOf(0L) }
    LaunchedEffect(cardioMetrics) {
        while (true) {
            movingSeconds = when {
                cardioMetrics == null -> 0L
                cardioMetrics.movingAnchorElapsedRealtimeMs == null -> cardioMetrics.movingSecondsBase.toLong()
                else -> cardioMetrics.movingSecondsBase +
                    (SystemClock.elapsedRealtime() - cardioMetrics.movingAnchorElapsedRealtimeMs) / 1000
            }
            delay(1000)
        }
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(horizontal = maxWidth * SCREEN_PADDING_FRACTION),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        if (family == CardioActivityFamily.GAME) {
            GameMetricsContent(
                metadata = metadata, cardioMetrics = cardioMetrics, liveMetrics = liveMetrics,
                activityType = activityType, movingSeconds = movingSeconds, isCompact = isCompact,
                onCourt = onCourt, onToggleCourt = onToggleCourt,
            )
        } else {
            DistanceMachineMetricsContent(
                metadata = metadata, cardioMetrics = cardioMetrics, liveMetrics = liveMetrics, family = family,
                activityType = activityType, movingSeconds = movingSeconds, isCompact = isCompact,
            )
        }
    }
}

/** The `activeHeaderLabel` computation `StrengthActiveWorkoutScreen` does
 * inline, minus the `standaloneTemplate` branch (always null for a
 * phone-mastered cardio session) — the phone's own `title`
 * (`activityTypeLabel(l10n, _activityType)`, `cardio_session_screen.dart`)
 * is already the right localized activity name, just sentence-case; this
 * uppercases it to match the design's header treatment the same way
 * STRENGTH's `active_header_label` string is *authored* uppercase (there's
 * no Compose `Text` case-transform to lean on the way SwiftUI's
 * `.textCase(.uppercase)` does). */
@Composable
internal fun cardioHeaderLabel(metadata: SessionMetadata): String =
    metadata.title?.takeIf { it.isNotBlank() }?.uppercase()
        ?: stringResource(R.string.active_header_label)

/** AW/W 17–18 (DISTANCE/MACHINE) — header, primary label+value (tinted, the
 * ticking moving-time slot per family), the heart-rate row
 * ([CardioHeartRateRow]), and up to two supporting boxes. */
@Composable
internal fun DistanceMachineMetricsContent(
    metadata: SessionMetadata,
    cardioMetrics: CardioActiveMetrics?,
    liveMetrics: LiveMetrics,
    family: CardioActivityFamily,
    activityType: String,
    movingSeconds: Long,
    isCompact: Boolean,
) {
    val tint = cardioActivityTint(activityType)
    val heroStyle = if (isCompact) MaterialTheme.typography.display3 else MaterialTheme.typography.display2
    LegacyHeaderChip(
        icon = cardioActivityIcon(activityType),
        label = cardioHeaderLabel(metadata),
        isStandalone = false,
        isCompact = isCompact,
        tint = tint,
    )
    if (cardioMetrics == null) {
        // No `cardio` push has landed yet — right after the exercise starts,
        // the watch's own Health Services session can begin before the
        // first state sync arrives. Degrades to just the header + heart
        // rate, never a blank/zero-valued distance.
        CardioHeartRateRow(liveMetrics = liveMetrics, isCompact = isCompact)
        return
    }
    Text(
        // DISTANCE shows the phone's own `primaryLabel` (distance doesn't
        // tick locally — it only changes on a fresh GPS fix, so the last
        // string the phone pushed is always current); MACHINE ticks the
        // primary itself (moving time), so its label is fixed regardless —
        // only the value below switches to the local ticking one.
        text = cardioMetrics.primaryLabel,
        style = if (isCompact) MaterialTheme.typography.caption3 else MaterialTheme.typography.caption2,
        color = LifeyColors.onSurfaceVariant,
        letterSpacing = 0.5.sp,
        maxLines = 1,
    )
    Text(
        text = if (family == CardioActivityFamily.DISTANCE) {
            cardioMetrics.primaryValue
        } else {
            formatCardioDuration(movingSeconds.toInt())
        },
        style = heroStyle,
        color = tint,
    )
    CardioHeartRateRow(liveMetrics = liveMetrics, isCompact = isCompact)
    Row(
        modifier = Modifier.padding(top = if (isCompact) 6.dp else 10.dp),
        horizontalArrangement = Arrangement.spacedBy(if (isCompact) 8.dp else 10.dp),
    ) {
        // MACHINE/GAME's own primary/secondary swap (`family !=
        // CardioActivityFamily.DISTANCE` above) means the secondary box
        // shown here is `secondaryLabel`/`Value` as-is for every family
        // except the one already spent on ticking it above.
        if (family != CardioActivityFamily.DISTANCE && cardioMetrics.secondaryLabel != null) {
            CardioMetricBox(
                label = cardioMetrics.secondaryLabel, value = cardioMetrics.secondaryValue ?: "—",
                isCompact = isCompact,
            )
        }
        if (cardioMetrics.tertiaryLabel != null) {
            CardioMetricBox(
                label = cardioMetrics.tertiaryLabel, value = cardioMetrics.tertiaryValue ?: "—",
                isCompact = isCompact,
            )
        }
    }
}

/**
 * AW/W 19–20 (on court / on bench) — a dot+label primary caption instead of
 * the plain grey one [DistanceMachineMetricsContent] uses (GAME's primary is
 * *always* the ticking moving/game time, unlike DISTANCE, so there's no swap
 * to reason about here), a single "bruttó" box (GAME's `tertiaryValue` is a
 * placeholder the phone never fills — see [CardioActiveMetrics]'s Dart-side
 * counterpart's doc — so only `secondaryLabel`/`Value` renders), and the
 * pályán/padon toggle.
 *
 * [onCourt] is **two-way synced** with the phone (docs/cardio/
 * 55-cardio-watch-plan.md §7, W-9) and therefore lives on
 * `SessionStateHolder`, not in a screen-local `remember`: a tap here reaches
 * the phone (`SummarySender.sendCourtChanged` → `CardioSessionScreen
 * ._setOnCourt`), and the phone's own switch reaches this screen on its next
 * state push. It is a real accounting switch on both sides now — benched
 * minutes stop counting towards playing time while gross time keeps running
 * — not just a choice between W 19's and W 20's layouts. Mirrors iOS's
 * identical `CardioActiveContent`/`isOnCourt` choice.
 */
@Composable
internal fun GameMetricsContent(
    metadata: SessionMetadata,
    cardioMetrics: CardioActiveMetrics?,
    liveMetrics: LiveMetrics,
    activityType: String,
    movingSeconds: Long,
    isCompact: Boolean,
    onCourt: Boolean,
    onToggleCourt: () -> Unit,
) {
    val activityTint = cardioActivityTint(activityType)
    val tint = if (onCourt) activityTint else LifeyColors.secondary
    val heroStyle = if (isCompact) MaterialTheme.typography.display3 else MaterialTheme.typography.display2

    LegacyHeaderChip(
        icon = if (onCourt) cardioActivityIcon(activityType) else Icons.Filled.AirlineSeatReclineNormal,
        label = if (onCourt) cardioHeaderLabel(metadata) else stringResource(R.string.cardio_on_bench_header_label),
        isStandalone = false,
        isCompact = isCompact,
        tint = tint,
    )
    if (cardioMetrics == null) {
        CardioHeartRateRow(liveMetrics = liveMetrics, isCompact = isCompact)
        return
    }
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(7.dp)) {
        if (onCourt) {
            Box(modifier = Modifier.size(8.dp).background(LifeyColors.primary, CircleShape))
        }
        Text(
            text = if (onCourt) cardioMetrics.primaryLabel else stringResource(R.string.cardio_game_paused_primary_label),
            style = if (isCompact) MaterialTheme.typography.caption3 else MaterialTheme.typography.caption2,
            color = tint,
            letterSpacing = 0.5.sp,
            maxLines = 1,
        )
    }
    Text(
        text = formatCardioDuration(movingSeconds.toInt()),
        style = heroStyle,
        color = if (onCourt) tint else LifeyColors.onSurfaceVariant,
    )
    CardioHeartRateRow(liveMetrics = liveMetrics, isCompact = isCompact)
    if (cardioMetrics.secondaryLabel != null) {
        Box(modifier = Modifier.padding(top = if (isCompact) 6.dp else 10.dp)) {
            CardioMetricBox(
                label = cardioMetrics.secondaryLabel, value = cardioMetrics.secondaryValue ?: "—",
                isCompact = isCompact, valueTint = if (onCourt) null else LifeyColors.secondary,
            )
        }
    }
    Chip(
        onClick = onToggleCourt,
        modifier = Modifier.fillMaxWidth().padding(top = if (isCompact) 8.dp else 12.dp),
        icon = {
            Icon(
                imageVector = if (onCourt) Icons.Filled.AirlineSeatReclineNormal else cardioActivityIcon(activityType),
                contentDescription = null,
                tint = if (onCourt) LifeyColors.onPrimary else LifeyColors.onSurface,
            )
        },
        label = {
            Text(
                text = stringResource(
                    if (onCourt) R.string.cardio_go_to_bench_button else R.string.cardio_back_to_court_button,
                ),
                color = if (onCourt) LifeyColors.onPrimary else LifeyColors.onSurface,
                maxLines = 1,
            )
        },
        colors = ChipDefaults.chipColors(
            backgroundColor = if (onCourt) LifeyColors.primary else LifeyColors.secondary,
            contentColor = if (onCourt) LifeyColors.onPrimary else LifeyColors.onSurface,
        ),
    )
}

/**
 * The heart-rate row every cardio layout shares — a real reading when
 * [LiveMetrics.heartRateBpm] has one (this watch's own Health Services
 * session, same sensor the STRENGTH pages already read), or the degraded
 * "—" / `cardio_no_heart_rate_label` / strap hint (canvas W 21) when it
 * doesn't. Unlike the STRENGTH pages' [HeartRateReading] (simply omitted
 * when there's nothing to show), this row's **space is always reserved** —
 * the design's own reasoning for M10's GPS chip applies here too: "a hely
 * megmarad, hogy az elrendezés ne ugráljon, és látszódjon, hogy hiányzik."
 * Deliberately doesn't reuse [HeartRateReading]'s permission-denied branch
 * either — cardio's "—" fallback covers *both* "denied" and "no sample yet"
 * the same way, where STRENGTH's only ever covers the former.
 */
@Composable
internal fun CardioHeartRateRow(liveMetrics: LiveMetrics, isCompact: Boolean) {
    val valueStyle = if (isCompact) MaterialTheme.typography.title2 else MaterialTheme.typography.title1
    val hasReading = liveMetrics.hasHeartRatePermission && liveMetrics.heartRateBpm != null
    Column(
        modifier = Modifier.padding(top = if (isCompact) 6.dp else 8.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(if (isCompact) 8.dp else 12.dp)) {
            Icon(
                imageVector = Icons.Filled.Favorite,
                contentDescription = null,
                tint = if (hasReading) LifeyColors.heart else LifeyColors.ghostedOnSurface,
                modifier = Modifier.size(if (isCompact) 24.dp else 28.dp),
            )
            if (hasReading) {
                Text(
                    text = liveMetrics.heartRateBpm!!.roundToInt().toString(),
                    style = valueStyle,
                    color = LifeyColors.onSurface,
                )
            } else {
                Text(text = "—", style = valueStyle, color = LifeyColors.ghostedOnSurface)
                Text(
                    text = stringResource(R.string.cardio_no_heart_rate_label),
                    style = MaterialTheme.typography.caption2,
                    color = LifeyColors.onSurfaceVariant,
                )
            }
        }
        if (!hasReading) {
            Text(
                text = stringResource(R.string.cardio_no_heart_rate_hint),
                style = MaterialTheme.typography.caption2,
                color = LifeyColors.onSurfaceVariant,
                textAlign = TextAlign.Center,
                modifier = Modifier.padding(top = 4.dp),
            )
        }
    }
}

/**
 * One of [DistanceMachineMetricsContent]/[GameMetricsContent]'s supporting
 * boxes (canvas W 17/18's two-box row, W 19/20's single "bruttó" one) —
 * [valueTint] overrides the value's color for GAME's on-bench state (muted
 * `secondary` instead of the default `onSurface`), `null` everywhere else.
 */
@Composable
internal fun CardioMetricBox(label: String, value: String, isCompact: Boolean, valueTint: Color? = null) {
    Column(
        modifier = Modifier
            .background(
                valueTint?.copy(alpha = 0.16f) ?: LifeyColors.surface,
                LifeyShapes.card,
            )
            .padding(horizontal = if (isCompact) 10.dp else 14.dp, vertical = if (isCompact) 8.dp else 12.dp),
    ) {
        Text(
            text = value,
            style = if (isCompact) MaterialTheme.typography.body2 else MaterialTheme.typography.title3,
            color = LifeyColors.onSurface,
            maxLines = 1,
        )
        Text(
            text = label,
            style = MaterialTheme.typography.caption2,
            color = valueTint ?: LifeyColors.onSurfaceVariant,
            maxLines = 1,
        )
    }
}

/**
 * A minimal 2-dot page indicator (canvas AW02/AW04's page-dots row, adapted
 * for Wear). `HorizontalPageIndicator` from `androidx.wear.compose.material`
 * was tried first, but on a round emulator it rendered nothing at all — its
 * default curved-style layout apparently needs more than just a `BoxScope`
 * to find its arc, and chasing that further wasn't worth it for something
 * this simple. Two plain circles, hand-drawn like [IdleScreen]'s leaf mark,
 * are trivially correct instead. */
@Composable
internal fun PageDots(pageCount: Int, selectedPage: Int, modifier: Modifier = Modifier) {
    Row(modifier = modifier, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
        repeat(pageCount) { index ->
            Box(
                modifier = Modifier
                    .size(6.dp)
                    .background(
                        if (index == selectedPage) LifeyColors.onSurface else LifeyColors.outline,
                        CircleShape,
                    ),
            )
        }
    }
}

/**
 * The "STRENGTH"/"REST" uppercase icon+label row that anchors the top of the
 * metrics and rest-hero states (canvas AW02/Wear02, AW03/Wear04) — the one
 * bit of letter-spacing tracking the design calls for (41-watch-design-
 * prompt.md §1: "uppercase labels tracked +0.5") is applied here directly
 * rather than through the shared `Typography`, since every other caption in
 * this screen is mixed-case body copy that tracking would only cramp.
 */
@Composable
internal fun LegacyHeaderChip(
    icon: ImageVector,
    label: String,
    isStandalone: Boolean,
    isCompact: Boolean,
    /** `CardioMetricsPage` (docs/cardio/55-cardio-watch-plan.md §4.2, C5.6)
     * tints this per activity type instead of the STRENGTH default — "a
     * domináns szám az aktivitás akcentjét viseli... nem a primaryt" applies
     * to the header row too, not just the big number below it. Defaults to
     * the original `LifeyColors.primary` — every pre-cardio call site is
     * unaffected. (Unlike iOS, `ControlsPage` here has no `HeaderChip` of its
     * own to fix — it shows a dimmed `ExerciseCard` and the End/Pause chips
     * only, see [ControlsPage]'s own composition.) */
    tint: Color = LifeyColors.primary,
) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            tint = tint,
            modifier = Modifier.size(if (isCompact) 16.dp else 18.dp),
        )
        Text(
            text = label,
            style = if (isCompact) MaterialTheme.typography.caption3 else MaterialTheme.typography.caption2,
            color = tint,
            letterSpacing = 0.5.sp,
            maxLines = 1,
            // A template name can run long, unlike the fixed "STRENGTH"/"REST"
            // labels this chip otherwise shows — `weight(fill = false)` gives
            // Text a bounded width to truncate against (a bare `Row` child
            // would otherwise just overflow, since nothing constrains it),
            // while still leaving room for the trailing standalone icon and
            // not force-expanding for a short label.
            overflow = TextOverflow.Ellipsis,
            modifier = Modifier.weight(1f, fill = false),
        )
        if (isStandalone) {
            // Standalone mode indicator (docs/watch/44-watch-f6-standalone-
            // plan.md §3.4, canvas W 13) — a quiet glyph, no chip/background/
            // copy of its own ("mode, not alarm"), so every page's header
            // carries it consistently rather than singling out the
            // STRENGTH-label page alone (mirrors iOS's identical `HeaderChip`).
            //
            // It doubles as a "sync with my phone now" button: the state it
            // reports (this workout has no phone behind it) is exactly the one
            // the user wants to act on, so a separate control would be
            // busywork. Most useful when the phone app simply wasn't running
            // at start — one tap sends the whole snapshot, already-logged sets
            // included, and the phone opens the workout.
            // A cardio session's badge does the same thing, and means the
            // same thing: the phone joins the walk/run live (its own
            // `CardioSessionScreen`, GPS and all) instead of only importing
            // it once it ends.
            val context = LocalContext.current
            val scope = rememberCoroutineScope()
            var isSyncing by remember { mutableStateOf(false) }
            val a11yLabel = stringResource(R.string.standalone_sync_retry_a11y)
            Icon(
                imageVector = if (isSyncing) Icons.Filled.Sync else Icons.Filled.PhonelinkOff,
                contentDescription = null,
                tint = LifeyColors.standaloneIndicator,
                modifier = Modifier
                    // `clickable` ahead of `padding`, so the padding counts
                    // as part of the tap target rather than sitting outside
                    // it — the glyph itself is only 14–16 dp, too small to
                    // hit reliably on a wrist.
                    .clickable(enabled = !isSyncing) {
                        scope.launch {
                            isSyncing = true
                            SummarySender.sendAdoptionRequestIfNeeded(context)
                            // The send itself usually returns in well under a
                            // frame, so hold the glyph long enough for the tap
                            // to have visibly done something. What a
                            // *successful* sync looks like is this badge
                            // disappearing (the phone's adoptionAck flips
                            // `isAdopted`), not this spinner.
                            delay(ADOPTION_RETRY_FEEDBACK_MS)
                            isSyncing = false
                        }
                    }
                    .semantics { contentDescription = a11yLabel }
                    .padding(vertical = 6.dp, horizontal = 4.dp)
                    .size(if (isCompact) 14.dp else 16.dp),
            )
        }
    }
}

/** The heart-rate reading, or its degraded "--" state when the sensor
 * permission was denied (§12.1 B13) — split out from [MetricReading] because
 * it also needs the small variant used inside [RestHero]. */
@Composable
internal fun LegacyHeartRateReading(
    liveMetrics: LiveMetrics,
    iconSize: Dp,
    valueStyle: TextStyle,
) {
    if (liveMetrics.hasHeartRatePermission) {
        liveMetrics.heartRateBpm?.let { bpm ->
            LegacyMetricReading(
                icon = Icons.Filled.Favorite,
                iconTint = LifeyColors.heart,
                value = bpm.roundToInt().toString(),
                iconSize = iconSize,
                valueStyle = valueStyle,
            )
        }
    } else {
        // §12.1 B13: permission denied looks intentional (a muted
        // placeholder + broken-heart glyph), not like a missing/late
        // reading — distinct from heartRateBpm == null above, which just
        // means "no sample yet".
        LegacyMetricReading(
            icon = Icons.Filled.HeartBroken,
            iconTint = LifeyColors.outline,
            value = stringResource(R.string.active_heart_rate_denied_placeholder),
            iconSize = iconSize,
            valueStyle = valueStyle,
            valueColor = LifeyColors.onSurfaceVariant,
        )
    }
}

/** One icon + number metric reading (HR or kcal, canvas AW02/Wear02) — no
 * unit suffix next to the number; the icon itself already disambiguates HR
 * vs. kcal, and dropping the unit keeps the reading compact on a small
 * round display. [maxLines]/no-wrap on the value: a multi-digit number could
 * otherwise wrap mid-word onto its own second line. */
@Composable
internal fun LegacyMetricReading(
    icon: ImageVector,
    iconTint: Color,
    value: String,
    iconSize: Dp,
    valueStyle: TextStyle,
    valueColor: Color = LifeyColors.onSurface,
) {
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
        Icon(imageVector = icon, contentDescription = null, tint = iconTint, modifier = Modifier.size(iconSize))
        Text(text = value, style = valueStyle, color = valueColor, maxLines = 1, softWrap = false)
    }
}
