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
import androidx.wear.compose.foundation.pager.rememberPagerState
import androidx.wear.compose.foundation.rotary.RotaryScrollableDefaults
import androidx.compose.ui.input.rotary.onRotaryScrollEvent
import androidx.wear.compose.material3.TimeText
import com.khunor.lifey.ui.components.LifeyPager
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
    val elapsedMs = rememberElapsedMs(liveMetrics.startedAtElapsedRealtimeMs)

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
            // D-X0.9: the crown does not page; swipe between the metric page and the controls.
            LifeyPager(state = pagerState, modifier = Modifier.fillMaxSize()) { page ->
                when (page) {
                    0 -> CardioMetricsPage(
                        metadata = metadata, liveMetrics = liveMetrics,
                        onCourt = onCourt,
                        onToggleCourt = {
                            // Only a real change goes over the wire — the holder answers whether this was one.
                            if (SessionStateHolder.setOnCourt(!onCourt)) {
                                val sessionClientId = metadata.sessionClientId
                                if (sessionClientId != null) {
                                    scope.launch {
                                        SummarySender.sendCourtChanged(context, sessionClientId, !onCourt)
                                    }
                                }
                            }
                        },
                    )
                    else -> ControlsPage(
                        elapsedMs = elapsedMs,
                        isPaused = liveMetrics.isPaused,
                        showsStandaloneMark = false,
                        offersExerciseList = false,
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
            TimeText()
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

    val permissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestMultiplePermissions(),
    ) { /* no-op — ExerciseService re-checks live before the next start */ }
    if (family == CardioActivityFamily.GAME) {
        GameContent(
            model = GameModel(
                headerLabel = cardioHeaderLabel(metadata),
                activityIcon = cardioActivityIcon(activityType),
                accent = cardioActivityTint(activityType),
                onCourt = onCourt,
                playLabel = cardioMetrics?.primaryLabel ?: "",
                playTime = formatCardioDuration(movingSeconds.toInt()),
                grossValue = cardioMetrics?.secondaryValue,
                grossLabel = cardioMetrics?.secondaryLabel,
                heartRate = heartRateState(liveMetrics),
                isPaused = liveMetrics.isPaused,
                showsStandaloneMark = metadata.isStandalone && !metadata.isAdopted,
            ),
            onToggleCourt = onToggleCourt,
            onRequestHeartRatePermission = { permissionLauncher.launch(HEART_RATE_PERMISSIONS) },
        )
        return
    }

    val primaryValue = when {
        cardioMetrics == null -> "—"
        family == CardioActivityFamily.DISTANCE -> cardioMetrics.primaryValue
        else -> formatCardioDuration(movingSeconds.toInt())
    }
    val fields = buildList {
        if (cardioMetrics != null) {
            if (family != CardioActivityFamily.DISTANCE && cardioMetrics.secondaryLabel != null) {
                add(CardioFieldModel(cardioMetrics.secondaryValue ?: "—", cardioMetrics.secondaryLabel))
            }
            if (cardioMetrics.tertiaryLabel != null) {
                add(CardioFieldModel(cardioMetrics.tertiaryValue ?: "—", cardioMetrics.tertiaryLabel))
            }
        }
    }
    CardioContent(
        model = CardioModel(
            headerLabel = cardioHeaderLabel(metadata),
            activityIcon = cardioActivityIcon(activityType),
            accent = cardioActivityTint(activityType),
            primaryLabel = cardioMetrics?.primaryLabel ?: "",
            primaryValue = primaryValue,
            heartRate = heartRateState(liveMetrics),
            fields = fields,
            isPaused = liveMetrics.isPaused,
            showsStandaloneMark = metadata.isStandalone && !metadata.isAdopted,
        ),
        onRequestHeartRatePermission = { permissionLauncher.launch(HEART_RATE_PERMISSIONS) },
    )
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
