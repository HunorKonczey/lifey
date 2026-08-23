package com.khunor.lifey

import android.os.SystemClock
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.update

/**
 * [ERROR] is `startExercise` having been rejected because another app
 * already owns the Health Services exercise session (docs/40-watch-app-plan.md
 * §12.1 B12) — shown as a dedicated screen with an OK button, the watch-side
 * counterpart of the phone's `startRejected` snackbar. [SUMMARY] only exists
 * for a standalone session (docs/watch/44-watch-f6-standalone-plan.md
 * D-F6.7) — a phone-mastered session never enters it (no summary screen ever
 * existed on Wear before F6, see [StandaloneSummary]'s doc comment for how
 * its data is carried, since a Kotlin `enum` can't attach an associated
 * value the way iOS's `WorkoutPhase.summary(WorkoutSummaryData)` does).
 */
enum class SessionPhase { IDLE, ACTIVE, SUMMARY, ERROR }

/**
 * DISTANCE/MACHINE/GAME grouping for a cardio `ActivityType` code — mirrors
 * Dart's `ActivityFamily`/`activityFamilyFor`
 * (mobile/lib/features/workouts/domain/activity_type.dart). The watch
 * derives this itself from `activityType` rather than the phone sending it,
 * the same "no activity-type dictionary of its own" choice the cardio
 * icon/tint maps (`ui/ActiveWorkoutScreen.kt`'s `cardioActivityIcon`/
 * `cardioActivityTint`) already make — docs/cardio/55-cardio-watch-plan.md
 * §2's table, minus the `ExerciseType`/`dataTypes` columns, which only
 * `ExerciseService` needs.
 */
enum class CardioActivityFamily { DISTANCE, MACHINE, GAME }

fun cardioActivityFamily(activityType: String): CardioActivityFamily = when (activityType) {
    "INDOOR_BIKE" -> CardioActivityFamily.MACHINE
    "BASKETBALL", "FOOTBALL", "OTHER_CARDIO" -> CardioActivityFamily.GAME
    else -> CardioActivityFamily.DISTANCE // RUNNING, WALKING, HIKING, CYCLING — and any future/unknown code
}

/**
 * One `WorkoutSessionState.cardio` push — `CardioLiveMetrics` in
 * `mobile/lib/core/workout_session_notifier/workout_session_notifier_service.dart`
 * — decoded into what the watch's own active screens need
 * (docs/cardio/55-cardio-watch-plan.md §4.2, C5.6). `primaryLabel`/`primaryValue`/
 * `secondaryLabel`/`secondaryValue`/`tertiaryLabel`/`tertiaryValue` are
 * pre-formatted, pre-localized strings — the watch needs no `CardioFormatter`
 * of its own — **except** for whichever slot holds the moving/game-time
 * duration (`ui/ActiveWorkoutScreen.kt`'s `CardioMetricsPage` decides which
 * one by family), which is stale between phone pushes by design
 * (`movingSecondsBase`'s own Dart doc: "hogy a natív felület magától
 * ketyegjen, frissítés-kvóta nélkül") and is re-rendered from
 * [movingSecondsBase]/[movingAnchorElapsedRealtimeMs] instead.
 */
data class CardioActiveMetrics(
    val primaryLabel: String,
    val primaryValue: String,
    val secondaryLabel: String? = null,
    val secondaryValue: String? = null,
    val tertiaryLabel: String? = null,
    val tertiaryValue: String? = null,
    /** GAME only — whether the phone says the player is on court or on the
     * bench (`CardioLiveMetrics.onCourt`, docs/cardio/55-cardio-watch-plan.md
     * §7, W-9). True for every other family and for a phone build that
     * predates the field, which is what keeps a non-GAME session's screens
     * exactly as they were. */
    val onCourt: Boolean = true,
    /** The moving/game-time checkpoint the ticking slot counts up from —
     * plain relative seconds, so (unlike the Dart source's `movingSinceEpochMs`,
     * which this class deliberately drops) it's safe to use directly
     * regardless of whether the watch's and phone's wall clocks agree. */
    val movingSecondsBase: Int = 0,
    /** This device's own `SystemClock.elapsedRealtime()` at the moment this
     * snapshot was applied, or `null` when paused — mirrors
     * [SessionMetadata.restDeadlineElapsedRealtimeMs]'s pattern exactly:
     * converts the phone's cross-device (and therefore clock-skew-prone)
     * "ticking since epoch X" signal into a same-device monotonic anchor the
     * instant it arrives, instead of ever comparing the phone's
     * `movingSinceEpochMs` against this device's own wall clock. */
    val movingAnchorElapsedRealtimeMs: Long? = null,
)

/** D-F6.8 — no reps input on the watch yet in F6a; every locally logged
 * standalone set uses this fixed value, the user corrects it on the phone
 * later. Carried per-set on the wire already so a future watch-side stepper
 * (F5b/F6b) won't need a protocol change. */
/** How long a local court/bench tap wins over a contradicting phone push —
 * see [SessionStateHolder.applyPhoneOnCourt]. Long enough to cover the round
 * trip, short enough that a tap the phone refused can't strand this watch. */
private const val PENDING_COURT_ECHO_MS = 5_000L

private const val STANDALONE_DEFAULT_REPS = 10
/** §3.5 — standalone has no phone-driven rest timer, so the watch starts
 * its own fixed-length one on every logged set. */
private const val STANDALONE_REST_SECONDS = 90

/** One set logged during a standalone session (docs/watch/
 * 44-watch-f6-standalone-plan.md §4.1) — [reps]/[weight] default to
 * [STANDALONE_DEFAULT_REPS]/`null` unless the F5b adjust stepper was used
 * (now wired up for standalone too). [exerciseIndex] is null outside a
 * template session; F6b resolves it against the synced template's exercise
 * list. */
data class StandaloneSet(
    val loggedAtEpochMs: Long,
    val reps: Int,
    val weight: Double? = null,
    val exerciseIndex: Int? = null,
    /** The exercise's clientId, as the phone sent it in the session plan or
     * the synced template (docs/watch/50-watch-f6c-session-plan-sync-plan.md)
     * — the identity this set is attributed by, and what makes the exercise
     * list free to change mid-session: a position means whatever the current
     * list says, an id means the same exercise forever. Null for a set logged
     * by a pre-F6c build or outside any plan; [exerciseIndex] stays alongside
     * as the fallback for exactly those. Mirrors iOS's `StandaloneSet`. */
    val exerciseId: String? = null,
)

/** One exercise of a template as the watch received it (docs/watch/
 * 49-watch-f6b-template-sync-plan.md §4.1, D-F6b.4, T6) — [restSeconds] is
 * never null here: the watch knows neither the `Exercises` table nor
 * `UserSettings`, so the phone always resolves it before sending. Mirrors
 * iOS's `CachedTemplateExercise`. */
data class StandaloneTemplateExercise(
    val exerciseId: String,
    val name: String,
    val restSeconds: Int,
    val targetSets: Int? = null,
    /** How many sets the **session** already has for this exercise, counting
     * both devices' — only ever present when this entry came from the phone's
     * live session plan (F6c); a synced template has no such thing. The watch
     * takes the larger of this and its own count, exactly the reconciliation
     * [SessionMetadata.phoneSetsDonePerExercise] did before. */
    val setsDone: Int? = null,
    /**
     * What was logged for this exercise the last time it was trained,
     * heaviest first, as the phone resolved it (`previousSetsFor` in
     * `watch_template_sync.dart`) — a standalone session's stand-in for the
     * `nextSetReps`/`nextSetWeight` prefill a phone-mastered session gets on
     * every state sync (48-doc D-F5b.2). Without it the watch could only log
     * a hardcoded 10 reps with no weight. Defaults to empty so a cache
     * written by an older build still parses.
     */
    val previousSets: List<StandalonePreviousSet> = emptyList(),
)

/** One set of [StandaloneTemplateExercise.previousSets]. */
data class StandalonePreviousSet(
    val weight: Double,
    val reps: Int,
)

/**
 * A template as the watch received it, decoded once (in [ExerciseService])
 * out of [StandaloneSessionStore]'s untyped JSON — kept as a typed model
 * from here on, unlike the store itself, because a running session needs to
 * *reason* about it (which exercise, what rest length), not just relay it.
 * Mirrors iOS's `CachedTemplate`. [exercises]' array position is what a
 * logged [StandaloneSet.exerciseIndex] refers back to.
 */
data class StandaloneTemplate(
    val templateId: String,
    val title: String,
    val exercises: List<StandaloneTemplateExercise>,
)

/**
 * What the active screen should show for "current exercise + set progress"
 * (docs/watch/49-watch-f6b-template-sync-plan.md §3.4) — mirrors iOS's
 * `ActiveExerciseDisplay`/`WorkoutManager.activeExerciseDisplay`. Computed by
 * `ActiveWorkoutScreen.kt`'s `activeExerciseDisplay(metadata)` (a
 * `@Composable` function, since it needs `stringResource` — this data class
 * itself stays a plain Kotlin type, matching [StandaloneSet]/
 * [StandaloneSummary]'s placement here rather than in the UI layer).
 */
data class ActiveExerciseDisplay(
    val name: String,
    val setsDone: Int?,
    val setsTotal: Int?,
    /** Standalone's set-count line when there's no `targetSets` to compare
     * against (44-doc §3.4, D-F6.3) — mutually exclusive with
     * `setsDone`/`setsTotal` being non-null. */
    val freeFormatSets: Pair<Int, Int>?,
)

/**
 * The closed-out standalone session's stats (docs/watch/
 * 44-watch-f6-standalone-plan.md D-F6.7, canvas AW 15/W 14) — carried
 * separately from [SessionPhase.SUMMARY] rather than as an associated
 * value (Kotlin `enum class` can't hold one the way iOS's
 * `WorkoutPhase.summary(WorkoutSummaryData)` does), so [SessionStateHolder
 * .onStandaloneEnded] sets both together. [standaloneSessionId] is what a
 * summary screen (S17) checks [StandaloneSessionStore]/
 * [SessionStateHolder.standaloneSessionAcked] against to render its own
 * `sync_pending`/`sync_done` chip.
 */
data class StandaloneSummary(
    val standaloneSessionId: String,
    val totalDurationSeconds: Int,
    val setsCount: Int,
    val averageHeartRate: Double?,
    val activeCalories: Double?,
)

/**
 * The tap-to-ack lifecycle of the watch's "+1 set" control (docs/watch/
 * 43-watch-f5-set-logging-plan.md §3.2). [Pending]'s [Pending.eventId] is
 * the tap's id — [SessionStateHolder.onLogSetAck]/[SessionStateHolder
 * .onLogSetTimeout] only act on a match against this exact id, so a stale
 * ack/timeout for an already-settled/superseded tap is a no-op.
 */
sealed interface LogSetState {
    data object Ready : LogSetState
    data class Pending(val eventId: String) : LogSetState
    data object Confirmed : LogSetState
    data object Failed : LogSetState
}

/** Which of the two values the adjust stepper is editing (docs/watch/
 * 48-watch-f5b-set-adjust-plan.md 0.2) — one at a time, the other stays
 * visible in the caption line. */
enum class LogAdjustField { REPS, WEIGHT }

/**
 * The live state of the "+1 set" adjust stepper (canvas W 09). Non-null
 * exactly while the stepper is on screen; null means the plain log page.
 * Deliberately independent of [LogSetState]: the adjust lives entirely
 * *before* a tap is committed, and hands over to the existing pending/ack
 * lifecycle only on confirm — which is also what lets F6b reuse it for the
 * standalone path without rewriting it (D-F5b.8).
 *
 * [interactions] counts every step/toggle. It exists because this state is
 * consumed by *observing* a `StateFlow` (the idle timer and the tick haptic
 * live in [ExerciseService], not in the UI — S11), and a `StateFlow`
 * conflates equal values: stepping while already clamped at a bound would
 * otherwise produce no emission at all, so the idle timer wouldn't restart
 * and the view could dismiss itself under an actively rotating finger.
 */
data class LogAdjustState(
    val reps: Int,
    /** Always kg, matching the phone's own workout UI (D-F5b.4). */
    val weight: Double,
    val field: LogAdjustField,
    val interactions: Int = 0,
) {
    /** Whether a −/+ tap on the active field would still move the value —
     * drives the disabled/ghosted look of the stepper's two buttons. The
     * rotary has no equivalent need (it just clamps silently against a stop),
     * so these exist purely so a *button* can show it's at the end of its
     * range instead of looking tappable and doing nothing. Kept here rather
     * than in the UI so the bounds stay in one place, next to
     * [SessionStateHolder.onLogAdjustStepped]'s own clamping. */
    // `this.field`, not a bare `field` — inside a property getter that
    // identifier is Kotlin's backing-field keyword, not this data class's own
    // `field` property.
    val canDecrement: Boolean
        get() = when (this.field) {
            LogAdjustField.REPS -> reps > LOG_ADJUST_REPS_MIN
            LogAdjustField.WEIGHT -> weight > LOG_ADJUST_WEIGHT_MIN
        }

    val canIncrement: Boolean
        get() = when (this.field) {
            LogAdjustField.REPS -> reps < LOG_ADJUST_REPS_MAX
            LogAdjustField.WEIGHT -> weight < LOG_ADJUST_WEIGHT_MAX
        }
}

/** Stepper steps and bounds (D-F5b.5) — mirrors the watchOS constants. The
 * reps floor of 1 matches the phone's own validator; weight allows 0 for
 * bodyweight work. */
private const val LOG_ADJUST_REPS_STEP = 1
private const val LOG_ADJUST_WEIGHT_STEP = 2.5
private const val LOG_ADJUST_REPS_MIN = 1
private const val LOG_ADJUST_REPS_MAX = 99
private const val LOG_ADJUST_WEIGHT_MIN = 0.0
private const val LOG_ADJUST_WEIGHT_MAX = 500.0
/** Used when the phone sent no prefill at all (D-F5b.2's 4th branch). */
private const val LOG_ADJUST_DEFAULT_REPS = 10
private const val LOG_ADJUST_DEFAULT_WEIGHT = 0.0

data class SessionMetadata(
    val sessionClientId: String? = null,
    val title: String? = null,
    val exerciseName: String? = null,
    val setsDone: Int? = null,
    val setsTotal: Int? = null,
    /**
     * The rest timer's target end time, anchored to *this device's own*
     * `SystemClock.elapsedRealtime()` — null when no rest is active
     * (docs/39-rest-timer-plan.md). Deliberately not an absolute epoch
     * timestamp: [onStateSynced] converts the phone's relative
     * "seconds remaining" into this local monotonic deadline the instant a
     * sync arrives, so the countdown never depends on the watch's wall
     * clock agreeing with the phone's — two paired devices' wall clocks can
     * be meaningfully unsynced (seen in practice on paired emulators, hours
     * apart), which used to make this countdown wildly wrong
     * (docs/40-watch-app-plan.md §12.1 bugfix). Unlike the fields above,
     * [onStateSynced] always overwrites this one rather than preserving the
     * old value when absent — see its doc comment for why. */
    val restDeadlineElapsedRealtimeMs: Long? = null,
    /** The rest timer's full configured duration in seconds — null exactly
     * when [restDeadlineElapsedRealtimeMs] is null (docs/40-watch-app-plan.md
     * §12.1 B1). Same always-overwritten treatment. */
    val restTotalSeconds: Int? = null,
    /** What the F5b adjust stepper should start from — computed by the phone
     * for the exact row a "+1 set" tap would log into, and re-sent on every
     * state sync (docs/watch/48-watch-f5b-set-adjust-plan.md D-F5b.2, §4.2).
     * Null when the phone has nothing to go on; the stepper then starts from
     * its own default. [nextSetWeight] is in kg (D-F5b.4). Always overwritten
     * on sync, like the rest fields above — "no prefill any more" is a real
     * state that has to be able to clear a stale one. */
    val nextSetReps: Int? = null,
    val nextSetWeight: Double? = null,
    /** Whether the running session is watch-only (docs/watch/
     * 44-watch-f6-standalone-plan.md §1) rather than phone-mastered —
     * `false` for every pre-F6 flow. Gates [SessionStateHolder.onStateSynced]'s
     * phone-state rejection (D-F6.2) and which end path applies. */
    val isStandalone: Boolean = false,
    /** Whether the phone has acknowledged a live-bridging adoption request
     * for this standalone session ([SessionStateHolder.onAdoptionAcked]) —
     * meaningless outside [isStandalone]. Deliberately does **not** change
     * how sets are logged: that stays watch-local/instant always for a
     * standalone session, adopted or not (the whole reliability point of
     * F6). It only relaxes the phone-originated `end` message's guard in
     * [PhoneListenerService], so an adopted session can be ended from either
     * side. */
    val isAdopted: Boolean = false,
    /** The standalone session's own set log — the only record of it until
     * `ExerciseService.endStandaloneExercise` queues it (docs/watch/
     * 44-watch-f6-standalone-plan.md §3.1). Empty outside standalone mode;
     * phone-mastered sessions track their set count via [setsDone]/
     * [setsTotal] instead, which the phone itself owns. */
    val standaloneSets: List<StandaloneSet> = emptyList(),
    /** The template this standalone session is running against, or `null`
     * for the F6a "Quick strength" flow (docs/watch/
     * 49-watch-f6b-template-sync-plan.md §3.3, D-F6b.8) — a **snapshot**
     * taken once at start (`ExerciseService.startStandaloneExercise`), not a
     * live reference to `StandaloneSessionStore`'s cache: a `templateSync`
     * landing mid-session must not be able to change a *running* session's
     * gyakorlatnév/restSeconds out from under it. */
    val standaloneTemplate: StandaloneTemplate? = null,
    /** The phone's live session plan (docs/watch/50-watch-f6c-session-plan-sync-plan.md),
     * once it has pushed one — the session's *own* exercise list, which wins
     * over [standaloneTemplate]'s snapshot from then on. That's the only list
     * that can express an exercise added or removed on the phone mid-workout.
     *
     * Null until (and unless) one arrives: an older phone build, a phone out
     * of range, or a session it isn't mirroring all leave the watch on its
     * cached template, which is exactly the pre-F6c behaviour. */
    val sessionPlanExercises: List<StandaloneTemplateExercise>? = null,
    /** Which exercise the **phone** says is current, by clientId — the
     * phone-mastered counterpart of [standaloneExerciseIndex] (docs/watch/
     * 50-watch-f6c-session-plan-sync-plan.md §7). Pushed on every state sync. */
    val phoneCurrentExerciseId: String? = null,
    /** The exercise the user picked from this watch's own list during a
     * phone-mastered session, until the phone's next push confirms it — an
     * optimistic local override so the list highlight and the next tap follow
     * the finger immediately, without waiting for the round trip. */
    val phoneSelectedExerciseId: String? = null,
    /** Which of [standaloneTemplate]'s exercises new sets log against —
     * always 0 and unused outside a template session. Changed only by
     * [SessionStateHolder.onStandaloneExerciseSelected] (§3.5's
     * gyakorlat-lista, wired in T7); never by anything synced from the
     * phone. */
    val standaloneExerciseIndex: Int = 0,
    /** Set by [SessionStateHolder.onStandaloneExerciseSelected], cleared by
     * the next locally logged set — "the user picked this exercise by hand,
     * don't move off it".
     *
     * Only the *phone-count-driven* [advancedStandaloneExerciseIndex] call
     * site ([SessionStateHolder.onStateSynced]) honours it, and it exists for
     * one case: picking an exercise that already has all its planned sets, to
     * add one more. That exercise is complete by definition, so the very next
     * state sync would otherwise bounce the selection straight on to the first
     * unfinished one — leaving the user unable to select it at all. A set
     * logged into it clears the flag, so the normal auto-advance takes over
     * again from there. In-memory only: after a process death the recovered
     * session simply auto-advances as usual. */
    val standaloneExerciseManuallySelected: Boolean = false,
    /** What the phone reports for the exercise at [phoneSetsExerciseIndex]:
     * how many sets its copy of this session has for it, and how many its
     * plan holds. Both null until a state sync names an exercise this watch
     * agrees is the current one.
     *
     * A watch-started session is logged into from *both* sides — the phone's
     * mirror screen stays editable — but only the phone's row holds both
     * halves; [standaloneSets] is this watch's own half alone. Without these
     * the counter on the wrist silently ignored every set logged on the
     * phone, and [advancedStandaloneExerciseIndex] kept offering an exercise
     * that was already finished there. */
    val phoneSetsDone: Int? = null,
    val phoneSetsTotal: Int? = null,
    /** Which exercise the two values above are about — the phone echoes back
     * the index this watch sent it (`currentExerciseIndex` in the adoption
     * payload), so a count computed for a different exercise is never applied
     * to the current one. Null whenever the phone had nothing matching to
     * say. */
    val phoneSetsExerciseIndex: Int? = null,
    /** Which exercise [phoneSetsDone]/[phoneSetsTotal] are about, by clientId
     * (F6c) — preferred over [phoneSetsExerciseIndex], which is a position in
     * the *template* and therefore meaningless once the phone's session plan
     * is what this watch lists. */
    val phoneSetsExerciseId: String? = null,
    /** The phone's set count for **every** exercise of the plan, in this
     * watch's own index order (see `WorkoutSessionState.setsDonePerExercise`).
     *
     * [phoneSetsDone] above only describes the current exercise, which is
     * enough to render its counter but not to decide when to move on:
     * [advancedStandaloneExerciseIndex] judges *every* exercise, and from this
     * watch's own set list every exercise finished on the phone still looks
     * unfinished — so it kept hopping between already-finished ones. */
    val phoneSetsDonePerExercise: List<Int>? = null,
    /** Plan positions the user removed from this session on the phone (see
     * `WorkoutSessionState.removedExerciseIndexes`) — hidden from the exercise
     * list and never advanced into. Empty for every session the phone hasn't
     * said otherwise about, including an older phone build's.
     *
     * The watch's cached template stays the index space, deliberately: every
     * set already logged carries a position in it, so the list can only ever
     * *hide* entries here, never renumber them. An exercise added to the
     * session on the phone has no position at all and so can't appear — that
     * needs the session's own plan as the index space (docs/watch/
     * 50-watch-f6c-session-plan-sync-plan.md). */
    val removedExerciseIndexes: Set<Int> = emptySet(),
    /** `"STRENGTH"` or `"CARDIO"` — mirrors `WorkoutSessionState.kind`
     * (docs/cardio/55-cardio-watch-plan.md §4.1, C5.6). Only ever set by
     * [SessionStateHolder.onStateSynced]'s phone-mastered path; a
     * watch-started (standalone) session stays `"STRENGTH"` here regardless
     * — standalone cardio support is `C5.7`'s "óra-oldali indítás"
     * (docs/cardio/55-cardio-watch-plan.md §7, W-8), not this step's. */
    val kind: String = "STRENGTH",
    /** One of `activity_type.dart`'s `kActivityTypes` — non-null exactly
     * when [kind] is `"CARDIO"`, mirroring `WorkoutSessionState.activityType`. */
    val cardioActivityType: String? = null,
    /** The session's live cardio metrics, or `null` for a STRENGTH session
     * (and, briefly, for a CARDIO one before its first state sync lands).
     * See [CardioActiveMetrics]. */
    val cardioMetrics: CardioActiveMetrics? = null,
    /** GAME only — whether the player is on court or on the bench
     * (docs/cardio/55-cardio-watch-plan.md §7, W-9). **Not** a screen-local
     * `remember` any more: the same switch exists on the phone and the two
     * have to agree, so it lives where both directions can reach it — the
     * wrist's own tap ([SessionStateHolder.setOnCourt]) and the phone's
     * pushed state ([CardioActiveMetrics.onCourt]). */
    val isOnCourt: Boolean = true,
    /** The **standalone** session's own playing-time accumulator: seconds
     * banked on court, plus (while on court) the time since
     * [localMovingAnchorElapsedRealtimeMs]. A phone-mastered session takes
     * both numbers from the phone instead — it owns that session's clock.
     * The pair mirrors the phone's own `movingSeconds`/`movingSinceEpochMs`
     * (frozen anchor = benched), which is what lets a benched watch session
     * report real playing time when it closes instead of the wall-clock
     * fallback the phone would otherwise compute. */
    val localMovingSecondsBase: Int = 0,
    val localMovingAnchorElapsedRealtimeMs: Long? = null,
) {
    val isCardio: Boolean get() = kind == "CARDIO"
    val cardioFamily: CardioActivityFamily? get() = cardioActivityType?.let(::cardioActivityFamily)


    /** [sessionClientId] doubles as the standalone session's own id during
     * standalone mode — reused rather than a separate `standaloneSessionId`
     * field (mirrors iOS's `WorkoutManager.sessionClientId`), so every
     * existing call site reading this field already picks it up. */
    val standaloneSessionId: String? get() = if (isStandalone) sessionClientId else null

    /** The exercise new sets currently log against, or `null` for a Quick
     * strength session — the safe-indexed lookup, so callers don't repeat
     * the bounds check. Mirrors iOS's `standaloneCurrentExercise`. */
    val standaloneCurrentExercise: StandaloneTemplateExercise?
        get() = activePlanExercises.getOrNull(standaloneExerciseIndex)

    /** The exercise list this session actually works against: the phone's live
     * plan when there is one, the cached template otherwise (F6c). Every
     * "which exercise" decision reads this rather than [standaloneTemplate]
     * directly, so both sources behave identically everywhere downstream.
     * Mirrors iOS's `activePlanExercises`. */
    val activePlanExercises: List<StandaloneTemplateExercise>
        get() = sessionPlanExercises ?: standaloneTemplate?.exercises ?: emptyList()

    /** The clientId of the exercise the next set counts against — what the
     * watch now sends with every logged set and adoption snapshot instead of
     * relying on its position (F6c). */
    val standaloneCurrentExerciseId: String?
        get() = standaloneCurrentExercise?.exerciseId

    /** The exercise the next set counts against, whoever is mastering the
     * session: the wrist's own position in standalone mode, and in a
     * phone-mastered one the user's local pick if there is one, else whatever
     * the phone last named (F6c §7). Mirrors iOS's `currentExerciseId`. */
    val currentExerciseId: String?
        get() = if (isStandalone) {
            standaloneCurrentExerciseId
        } else {
            phoneSelectedExerciseId ?: phoneCurrentExerciseId
        }

    /** Whether this watch may offer its exercise list: a plan-backed
     * standalone session as before, and now a phone-mastered one too as soon
     * as the phone has pushed the session's exercises (F6c §7). A
     * single-exercise list is not worth a chip — nothing to switch to. */
    val canChooseExercise: Boolean
        get() = activePlanExercises.size > 1 || (isStandalone && standaloneTemplate != null)

    /** [standaloneSets] narrowed to the current exercise. Outside a template
     * session (Quick strength) every set is one pool, matching F6a exactly.
     * Mirrors iOS's `standaloneSetsForCurrentExercise`. */
    val standaloneSetsForCurrentExercise: List<StandaloneSet>
        get() = if (activePlanExercises.isEmpty()) {
            standaloneSets
        } else {
            val currentId = standaloneCurrentExerciseId
            // Id-first, position as the fallback: a set logged before the
            // phone's plan arrived (or by a pre-F6c build) carries only its
            // position.
            standaloneSets.filter { set ->
                if (set.exerciseId != null && currentId != null) {
                    set.exerciseId == currentId
                } else {
                    set.exerciseIndex == standaloneExerciseIndex
                }
            }
        }

    /**
     * What the *next* standalone set should default to for the current
     * exercise — the standalone counterpart of the phone-pushed
     * [nextSetReps]/[nextSetWeight] (48-doc D-F5b.2), which a phone-less
     * session never receives. Same priority order the phone uses for its own
     * "+1" prefill (`LogSessionScreen._handleAddSet`,
     * `StandaloneSessionProcessor._resolveWeights`), so a set logged here and
     * the row the phone would have produced agree:
     *
     * 0. what the phone last pushed for this session, once it has adopted it
     *    (live bridging) — the *same* `watchSetPrefill` computation a
     *    phone-started session receives, so both paths behave identically,
     *    which is the whole point. It wins because the phone sees the real
     *    history and the real row the set will land in; the watch only
     *    approximates that from the cached template. Repushed after every set
     *    the watch logs, so it doesn't lag — but it does freeze if the phone
     *    goes out of range, which is what the fallbacks below are for;
     * 1. the positional entry from the synced template's [previousSets] — the
     *    last workout's *n*-th set of this exercise, for the *n*-th set about
     *    to be logged now;
     * 2. otherwise the last set already logged for this exercise in *this*
     *    session (a run of taps stays at the working weight);
     * 3. otherwise [STANDALONE_DEFAULT_REPS] and no weight — a Quick strength
     *    session with no history, i.e. F6a's original behavior.
     */
    val standalonePrefill: StandalonePrefill
        get() {
            if (nextSetReps != null) {
                return StandalonePrefill(reps = nextSetReps, weight = nextSetWeight)
            }
            val sets = standaloneSetsForCurrentExercise
            val previousSets = standaloneCurrentExercise?.previousSets ?: emptyList()
            if (sets.size < previousSets.size) {
                val hint = previousSets[sets.size]
                return StandalonePrefill(reps = hint.reps, weight = hint.weight)
            }
            val last = sets.lastOrNull()
            if (last != null) return StandalonePrefill(reps = last.reps, weight = last.weight)
            return StandalonePrefill(reps = STANDALONE_DEFAULT_REPS, weight = null)
        }

    /**
     * Whether the template exercise at [index] has had every set it planned
     * for. A null `targetSets` counts as **one** set rather than "never
     * complete" — that's what the phone effectively does with a plan-less
     * exercise (`LogSessionScreen._rebuildBlocks` gives it a single row), and
     * without it [advancedStandaloneExerciseIndex] would bounce back to a
     * target-less exercise forever.
     */
    private fun isStandaloneExerciseComplete(index: Int): Boolean {
        val exercise = activePlanExercises.getOrNull(index) ?: return false
        // Removed from the session on the phone — not somewhere to land, so it
        // counts as finished for every "where do we go next" decision.
        if (isStandaloneExerciseRemoved(index)) return true
        return standaloneSetsDoneAt(index) >= (exercise.targetSets ?: 1)
    }

    /** Whether the phone has removed the plan's [index]-th exercise from this
     * session — see [removedExerciseIndexes]. */
    fun isStandaloneExerciseRemoved(index: Int): Boolean {
        // Meaningless once the phone's own plan is what we're listing: those
        // positions are the *template's*, and a plan that has an exercise at
        // all has it because the session still contains it.
        if (sessionPlanExercises != null) return false
        return index in removedExerciseIndexes
    }

    /**
     * How many sets this session has for the exercise at [index], counting
     * the ones logged on the phone's mirror screen — see [phoneSetsDone].
     *
     * The larger of the two counts, not the phone's: its copy is at best one
     * sync behind, so right after a tap on the wrist this watch's own list is
     * the higher (and correct) one, and taking the phone's would make the
     * counter visibly jump backwards. The phone's is higher exactly when it
     * knows about sets this watch never logged, which is the case this exists
     * for. Mirrors iOS's `standaloneSetsDone(at:)`.
     */
    fun standaloneSetsDoneAt(index: Int): Int {
        val exercise = activePlanExercises.getOrNull(index)
        val exerciseId = exercise?.exerciseId
        // Id-first, position as the fallback — see
        // [standaloneSetsForCurrentExercise].
        var best = standaloneSets.count { set ->
            if (set.exerciseId != null && exerciseId != null) {
                set.exerciseId == exerciseId
            } else {
                set.exerciseIndex == index
            }
        }
        // The phone's own count for this exercise. From its session plan it
        // comes keyed by id; the positional list is the template-space
        // fallback and must not be read once the plan is what we're listing.
        exercise?.setsDone?.let { best = maxOf(best, it) }
        if (sessionPlanExercises == null) {
            phoneSetsDonePerExercise?.getOrNull(index)?.let { best = maxOf(best, it) }
        }
        // The single-exercise value can be a sync fresher than the array (it is
        // recomputed for the exercise this watch named), so it still gets a
        // look in.
        val matchesPhoneExercise = if (phoneSetsExerciseId != null && exerciseId != null) {
            phoneSetsExerciseId == exerciseId
        } else {
            phoneSetsExerciseId == null && index == phoneSetsExerciseIndex
        }
        if (matchesPhoneExercise && phoneSetsDone != null) {
            best = maxOf(best, phoneSetsDone)
        }
        return best
    }

    /**
     * [standaloneExerciseIndex] moved on once the current exercise has all
     * the sets its plan asked for, so a tap after "Set 2 of 2" starts the
     * *next* exercise instead of piling a third set onto the finished one —
     * the watch-standalone counterpart of what the phone-mastered path has
     * always done (`selectWatchSetLogTarget`'s rule (b): the first block with
     * a not-done row). Same destination rule as that function, deliberately:
     * the first incomplete exercise scanning from the top, not simply
     * `index + 1`, so an exercise skipped or left half-finished earlier is
     * picked back up rather than stranded.
     *
     * Only ever read right after a set is logged, so a manual pick from the
     * exercise list ([SessionStateHolder.onStandaloneExerciseSelected]) still
     * holds for as long as that exercise has sets left. Returns the index
     * unchanged outside a template session (nothing to advance through), when
     * the current exercise has no `targetSets` (no way to know it's
     * finished), and when every exercise is complete — that last case keeps
     * logging into the current one, matching `selectWatchSetLogTarget`'s own
     * rule (c).
     */
    /** The first exercise of [activePlanExercises] that isn't finished yet, or
     * 0 when they all are — where a session lands when the exercise it was on
     * disappears from the plan. */
    val firstUnfinishedStandaloneExerciseIndex: Int
        get() = activePlanExercises.indices.firstOrNull { !isStandaloneExerciseComplete(it) } ?: 0

    val advancedStandaloneExerciseIndex: Int
        get() {
            val exercises = activePlanExercises.ifEmpty { return standaloneExerciseIndex }
            // The `targetSets` requirement is what keeps a plan-less exercise
            // from being declared finished after one set — but an exercise
            // *removed* on the phone has to be left regardless, target or no
            // target.
            if (!isStandaloneExerciseRemoved(standaloneExerciseIndex)) {
                if (standaloneCurrentExercise?.targetSets == null) return standaloneExerciseIndex
                if (!isStandaloneExerciseComplete(standaloneExerciseIndex)) {
                    return standaloneExerciseIndex
                }
            }
            return exercises.indices.firstOrNull { !isStandaloneExerciseComplete(it) }
                ?: standaloneExerciseIndex
        }
}

/** See [SessionMetadata.standalonePrefill]. */
data class StandalonePrefill(
    val reps: Int,
    val weight: Double?,
)

data class LiveMetrics(
    val heartRateBpm: Double? = null,
    val activeCalories: Double? = null,
    /** Health Services' `DATA_TYPE_DISTANCE_TOTAL` for this session, in
     * metres — null for a STRENGTH session and for a cardio one that doesn't
     * request the type at all (GAME), or before the first sample. Published
     * here, not just kept inside `ExerciseService` for the closing payload,
     * because a **watch-started** cardio session formats its own metrics
     * page from it (`localCardioMetrics` in `ActiveWorkoutScreen`): there is
     * no phone pushing pre-formatted strings into a standalone session. */
    val distanceMeters: Double? = null,
    val startedAtElapsedRealtimeMs: Long? = null,
    /** Mirrors `ExerciseUpdate.exerciseStateInfo.state.isPaused` — true for
     * both `USER_PAUSED` and `AUTO_PAUSED` (docs/40-watch-app-plan.md §12.1
     * B3). Only the *sensor* session is paused; the elapsed-time display
     * keeps ticking, matching the phone-session's timing (§4.4/§5.3: "csak a
     * szenzor-sessiont pauzálja, a telefon-session időzítését nem"). */
    val isPaused: Boolean = false,
    /** Whether `startExercise` was able to request `HEART_RATE_BPM` — false
     * means the sensor permission was denied, not just "no sample yet"
     * (docs/40-watch-app-plan.md §12.1 B13). Defaults to true (optimistic)
     * so the metrics page doesn't flash a denial before the first exercise
     * start has even run. */
    val hasHeartRatePermission: Boolean = true,
)

/**
 * Process-wide state shared between [PhoneListenerService] (the phone's
 * "last known state" DataItem sync, docs/40-watch-app-plan.md §D2),
 * [ExerciseService] (live Health Services metrics, §5.3), and the Compose UI
 * (§5.1) — this is the single in-process source of truth all three read from
 * or write into.
 */
object SessionStateHolder {
    private val _phase = MutableStateFlow(SessionPhase.IDLE)
    val phase: StateFlow<SessionPhase> = _phase

    private val _metadata = MutableStateFlow(SessionMetadata())
    val metadata: StateFlow<SessionMetadata> = _metadata

    private val _liveMetrics = MutableStateFlow(LiveMetrics())
    val liveMetrics: StateFlow<LiveMetrics> = _liveMetrics

    /** Set once [onStandaloneEnded] moves [phase] to [SessionPhase.SUMMARY]
     * — see [StandaloneSummary]'s doc comment for why this can't just be an
     * associated value on [phase] itself. Null outside that phase. */
    /** See [applyPhoneOnCourt] — a local court/bench tap the phone hasn't
     * echoed back yet, and when it was made. */
    private var pendingOnCourt: Boolean? = null
    private var pendingOnCourtAtElapsedRealtimeMs = 0L

    private val _standaloneSummary = MutableStateFlow<StandaloneSummary?>(null)
    val standaloneSummary: StateFlow<StandaloneSummary?> = _standaloneSummary

    private val _logSetState = MutableStateFlow<LogSetState>(LogSetState.Ready)
    val logSetState: StateFlow<LogSetState> = _logSetState

    /** The adjust stepper's live state — non-null exactly while it's on
     * screen (docs/watch/48-watch-f5b-set-adjust-plan.md §3.1). See
     * [LogAdjustState]. */
    private val _logAdjustState = MutableStateFlow<LogAdjustState?>(null)
    val logAdjustState: StateFlow<LogAdjustState?> = _logAdjustState

    /**
     * Emits a `standaloneSessionId` the instant its `standaloneSessionAck`
     * arrives (docs/watch/44-watch-f6-standalone-plan.md §4.2) — lets a
     * summary screen (S17) flip its own `sync_pending`/`sync_done` chip
     * without polling [StandaloneSessionStore]. A `SharedFlow`, not a
     * `StateFlow`: this is a one-shot event per ack, not a state that a late
     * collector should replay (mirrors iOS's `.standaloneSessionAcked`
     * `NotificationCenter` post, S8).
     */
    private val _standaloneSessionAcked = MutableSharedFlow<String>(extraBufferCapacity = 4)
    val standaloneSessionAcked: SharedFlow<String> = _standaloneSessionAcked

    /**
     * Applied from the phone's synced state message/DataItem — never clears
     * [SessionMetadata.title]/[SessionMetadata.exerciseName]/
     * [SessionMetadata.setsDone]/[SessionMetadata.setsTotal] if the new
     * payload didn't include them.
     *
     * [restRemainingSeconds] is the phone's own "seconds left" at the moment
     * it built the payload — converted here, on receipt, into
     * [SessionMetadata.restDeadlineElapsedRealtimeMs] by adding it to this
     * device's *own* `elapsedRealtime()`. That's the fix for the countdown
     * being wildly wrong: the old code stored the phone's absolute epoch
     * target and compared it against `System.currentTimeMillis()` on every
     * tick, which is only correct if the two devices' wall clocks agree.
     *
     * [restDeadlineElapsedRealtimeMs]/[SessionMetadata.restTotalSeconds] are
     * the exception to the "preserve if absent" rule above: they toggle
     * between a value and null constantly within a single session (rest
     * starts/ends), and null is indistinguishable on the wire from "key
     * absent" (`WatchBridge.kt`'s `toDataMap()` skips null values entirely)
     * — so unlike the other fields, these are always overwritten with the
     * new value, never preserved from the previous state.
     */
    fun onStateSynced(
        sessionClientId: String,
        title: String?,
        exerciseName: String?,
        setsDone: Int?,
        setsTotal: Int?,
        restRemainingSeconds: Int?,
        restTotalSeconds: Int?,
        nextSetReps: Int?,
        nextSetWeight: Double?,
        setsDoneExerciseIndex: Int?,
        setsDonePerExercise: List<Int>?,
        removedExerciseIndexes: List<Int>? = null,
        setsDoneExerciseId: String? = null,
        sessionPlan: List<StandaloneTemplateExercise>? = null,
        kind: String? = null,
        cardioActivityType: String? = null,
        cardioMetrics: CardioActiveMetrics? = null,
    ) {
        if (_metadata.value.isStandalone) {
            // A *different* session's state can't touch the watch's own
            // standalone one (docs/watch/44-watch-f6-standalone-plan.md
            // D-F6.2) — [PhoneListenerService]'s `/start` handling is what
            // turns that case into an explicit `sendStartRejected` (it has
            // access to `SummarySender`, this object doesn't).
            if (sessionClientId != _metadata.value.sessionClientId) return
            // Matching id = the phone's live mirror of *this* session (live
            // bridging), pushing state for the workout the watch is running.
            // Take the prefill and nothing else: those two fields are the
            // phone answering "what should the next set default to", which
            // it can answer better than the watch (it holds the full
            // history) — and taking them here is what finally makes a
            // watch-started session prefill exactly like a phone-started
            // one. Everything else stays watch-owned: the exercise/set
            // counters and the rest timer all describe the session the watch
            // itself drives, and the phone's copy is at best a sync behind.
            // The set counts come along too, but only when the phone says
            // which exercise they are about *and* it's the one this watch is
            // logging into. The phone's row is the only place both sides'
            // sets meet (its mirror screen stays editable), so this is the
            // one thing it genuinely knows better — unlike the exercise name
            // and the rest timer, which describe the session the watch itself
            // drives and stay watch-owned. [standaloneSetsDoneAt] is what
            // reconciles the phone's number with this watch's own.
            // F6c: the phone's own exercise list for this session, which
            // replaces the cached template as what this watch lists and logs
            // against. Applied first, so everything below already judges
            // against the new list.
            applySessionPlan(sessionPlan)
            // The phone's own court/bench state for a session this watch
            // started and the phone joined (W-9) — deliberately applied
            // inside the standalone branch, unlike everything else the phone
            // pushes about a watch-owned session: this one isn't a
            // measurement the watch already knows better, it's the user's own
            // switch, and either screen can flip it.
            cardioMetrics?.let { applyPhoneOnCourt(it.onCourt) }
            // Id-first (F6c): a position only means the same thing on both
            // sides while the list can't change, which is exactly what the
            // session plan undoes. Both sides carry the id whenever they can —
            // a template's `exerciseId` *is* the exercise's clientId — so this
            // is the normal route, and the index comparison is the pre-F6c
            // fallback.
            val currentExerciseId = _metadata.value.standaloneCurrentExerciseId
            val matchesCurrent = if (setsDoneExerciseId != null && currentExerciseId != null) {
                setsDoneExerciseId == currentExerciseId
            } else {
                setsDoneExerciseIndex != null &&
                    setsDoneExerciseIndex == _metadata.value.standaloneExerciseIndex
            }
            // The prefill is only taken when the phone is answering about the
            // exercise this watch is actually on. [setsDoneExerciseIndex] is
            // the phone echoing back the index it computed this whole payload
            // for (null in a template-less Quick strength session, where there
            // is no index to disagree about) — a mismatch means the payload was
            // built before the phone learned about a hand-picked exercise, and
            // applying it would open the stepper on another exercise's numbers.
            // Cleared rather than kept in that case: a stale value is about the
            // wrong exercise too, and [standalonePrefill]'s local fallbacks
            // answer for the right one.
            val prefillDescribesCurrentExercise =
                matchesCurrent ||
                    (setsDoneExerciseIndex == null && _metadata.value.standaloneTemplate == null)
            _metadata.update { current ->
                current.copy(
                    nextSetReps = if (prefillDescribesCurrentExercise) nextSetReps else null,
                    nextSetWeight = if (prefillDescribesCurrentExercise) nextSetWeight else null,
                    // Index-keyed, so unlike the three below it needs no
                    // agreement about which exercise is current.
                    phoneSetsDonePerExercise = setsDonePerExercise,
                    phoneSetsExerciseIndex = if (matchesCurrent) setsDoneExerciseIndex else null,
                    phoneSetsExerciseId = if (matchesCurrent) setsDoneExerciseId else null,
                    phoneSetsDone = if (matchesCurrent) setsDone else null,
                    phoneSetsTotal = if (matchesCurrent) setsTotal else null,
                    // Applied in the same copy the advance below reads, so one
                    // payload can both remove an exercise and move off it.
                    removedExerciseIndexes = removedExerciseIndexes?.toSet() ?: emptySet(),
                )
                    // A set logged on the phone can be the one that completes
                    // this exercise, and until now only a tap on the wrist ever
                    // re-evaluated that ([onStandaloneSetLogged]) — so the watch
                    // sat on a finished exercise offering to add yet another set
                    // to it. Read off the *updated* copy, so the phone's count
                    // counts towards the target it may have completed. Skipped
                    // right after a hand-picked exercise (see
                    // [SessionMetadata.standaloneExerciseManuallySelected]),
                    // which this would otherwise undo before the user got to
                    // log into it.
                    // A hand-picked exercise that has since been *deleted* on
                    // the phone is not somewhere to keep the user, so the
                    // stickiness doesn't apply to that case.
                    .let {
                        if (it.standaloneExerciseManuallySelected &&
                            !it.isStandaloneExerciseRemoved(it.standaloneExerciseIndex)
                        ) {
                            it
                        } else {
                            it.withAdvancedExercise()
                        }
                    }
            }
            return
        }
        val restDeadlineElapsedRealtimeMs = restRemainingSeconds?.let {
            SystemClock.elapsedRealtime() + it * 1_000L
        }
        // F6c §7: the phone's exercise list and its current exercise reach a
        // phone-mastered session too now — that's what its own picker lists,
        // and what tells this watch when the phone has moved on by itself.
        applySessionPlan(sessionPlan)
        _metadata.update { current ->
            current.copy(
                phoneCurrentExerciseId = setsDoneExerciseId ?: current.phoneCurrentExerciseId,
                // The local pick has served its purpose once the phone reports
                // the same exercise — or a different one the user has since
                // chosen *there*, which is the more recent instruction either
                // way.
                phoneSelectedExerciseId = current.phoneSelectedExerciseId
                    ?.takeIf { setsDoneExerciseId == null || setsDoneExerciseId != it },
                sessionClientId = sessionClientId,
                title = title ?: current.title,
                exerciseName = exerciseName ?: current.exerciseName,
                setsDone = setsDone ?: current.setsDone,
                setsTotal = setsTotal ?: current.setsTotal,
                restDeadlineElapsedRealtimeMs = restDeadlineElapsedRealtimeMs,
                restTotalSeconds = restTotalSeconds,
                nextSetReps = nextSetReps,
                nextSetWeight = nextSetWeight,
                // Always overwritten, like the rest fields above — `kind` is
                // never actually absent on a real push
                // (`WorkoutSessionState.toJson()` always includes it,
                // defaulted to `"STRENGTH"` Dart-side), so `?: current.kind`
                // is purely defensive against a malformed/ancient payload.
                // `cardioMetrics` in particular must be able to go back to
                // `null` — a stale distance/heart-rate-adjacent reading left
                // on screen after the phone stops sending it would be
                // actively misleading (docs/cardio/
                // 59-cardio-implementation-plan.md §11's "néma hiba" class).
                kind = kind ?: current.kind,
                cardioActivityType = cardioActivityType ?: current.cardioActivityType,
                cardioMetrics = cardioMetrics,
            )
        }
        // W-9 — the phone's court/bench state drives this watch's own switch,
        // so both screens show the same half of the match. After the copy
        // above, which is what `cardioFamily` is read off.
        cardioMetrics?.let { applyPhoneOnCourt(it.onCourt) }
    }

    /**
     * The exercise session actually started measuring, standalone
     * (docs/watch/44-watch-f6-standalone-plan.md §3.1) — the entry point for
     * the launcher's "Start workout" / picker's "Quick strength" **and**
     * synced-template rows, called by `ExerciseService.startStandaloneExercise`
     * once `startExerciseAsync` succeeds. [sessionClientId] is the watch's
     * own locally generated id; no `sendStartedOnWatch` here — there's no
     * phone-mastered session waiting on that signal.
     *
     * [template] defaults to `null` (Quick strength, F6a's original call
     * sites unaffected) — non-null is `ExerciseService`'s already-decoded
     * snapshot of whatever the picker row carried (docs/watch/
     * 49-watch-f6b-template-sync-plan.md §3.3, T6); this function never
     * itself touches `StandaloneSessionStore`. [activityType] (docs/cardio/
     * 55-cardio-watch-plan.md §5/§7 W-8, C5.7a) is the cardio counterpart —
     * mutually exclusive with [template] (a cardio standalone session has no
     * plan) — and is what makes `ActiveWorkoutScreen`'s `metadata.isCardio`
     * dispatch route this session to `CardioActiveScreen` like any other
     * cardio session.
     */
    fun onStandaloneStarted(
        sessionClientId: String,
        startedAtElapsedRealtimeMs: Long,
        template: StandaloneTemplate? = null,
        activityType: String? = null,
        title: String? = null,
    ) {
        _phase.value = SessionPhase.ACTIVE
        _metadata.update {
            SessionMetadata(
                sessionClientId = sessionClientId,
                isStandalone = true,
                standaloneTemplate = template,
                kind = if (activityType != null) "CARDIO" else "STRENGTH",
                cardioActivityType = activityType,
                // The picker row's own pre-localized name ("Walking"/"Séta"),
                // which is what `activeHeaderLabel` shows. Without it a
                // watch-started cardio session fell through to the generic
                // `active_header_label`, so a walk announced itself as
                // **STRENGTH** in its own header. This watch holds no
                // activity-type dictionary of its own by design (docs/cardio/
                // 55-cardio-watch-plan.md §3.2 — the phone pre-localizes
                // every title it syncs), so the name comes from the tapped
                // row rather than a lookup here.
                title = title,
                // Opens the first on-court stint for a standalone GAME
                // session's own playing-time accumulator (W-9) — set
                // directly, not through [applyOnCourt], which is a no-op
                // while the state already reads "on court". Unread by every
                // other family.
                localMovingAnchorElapsedRealtimeMs = startedAtElapsedRealtimeMs,
            )
        }
        _liveMetrics.update { it.copy(startedAtElapsedRealtimeMs = startedAtElapsedRealtimeMs) }
    }

    /**
     * Reattaches to a still-running standalone exercise after a process
     * death/reboot (docs/watch/44-watch-f6-standalone-plan.md §3.2, §11/6 —
     * mirrors iOS's `WorkoutManager.recoverStandaloneSessionIfNeeded()`).
     * Called by `ExerciseService.recoverStandaloneExercise()` once it has
     * confirmed (via Health Services' `getCurrentExerciseInfoAsync`) that
     * *this app's own* exercise is still tracked in progress and re-attached
     * its update callback — this only restores the state the fresh process
     * lost, it never touches the exercise session itself.
     *
     * Unlike [onStandaloneStarted], every field the running session had
     * accumulated is restored in one shot — [exerciseIndex] and [sets] don't
     * default to empty here, since a recovered session is never new. A
     * no-op outside [SessionPhase.IDLE]: if this process already has a live
     * view of a session (recovered or otherwise), a second recovery call
     * must not clobber it.
     */
    fun onStandaloneRecovered(
        sessionClientId: String,
        startedAtElapsedRealtimeMs: Long,
        template: StandaloneTemplate?,
        exerciseIndex: Int,
        sets: List<StandaloneSet>,
        sessionPlan: List<StandaloneTemplateExercise>? = null,
        // docs/cardio/55-cardio-watch-plan.md §5/§7 W-8, C5.7a — see
        // [onStandaloneStarted]'s identical parameters.
        activityType: String? = null,
        title: String? = null,
    ) {
        if (_phase.value != SessionPhase.IDLE) return
        _phase.value = SessionPhase.ACTIVE
        _metadata.update {
            SessionMetadata(
                sessionClientId = sessionClientId,
                isStandalone = true,
                standaloneTemplate = template,
                standaloneExerciseIndex = exerciseIndex,
                standaloneSets = sets,
                sessionPlanExercises = sessionPlan,
                kind = if (activityType != null) "CARDIO" else "STRENGTH",
                cardioActivityType = activityType,
                // …or a recovered walk would come back headed "STRENGTH" —
                // see [onStandaloneStarted].
                title = title,
                // A default open stint, immediately overwritten by
                // [restoreCourtState] when the snapshot had one — same
                // reasoning as [onStandaloneStarted]'s.
                localMovingAnchorElapsedRealtimeMs = startedAtElapsedRealtimeMs,
            )
        }
        _liveMetrics.update { it.copy(startedAtElapsedRealtimeMs = startedAtElapsedRealtimeMs) }
    }

    /**
     * Swaps in a new session plan, keeping the user on the *same exercise* —
     * by clientId, not by position (D-F6c.2): the phone can add, remove and
     * therefore renumber entries, so the index this watch holds means nothing
     * across the change. Already-logged sets need no such fix-up; they carry
     * their own [StandaloneSet.exerciseId].
     *
     * A no-op when the plan hasn't actually changed, so the ordinary state
     * sync (which carries it every time) costs nothing. Mirrors iOS's
     * `applySessionPlan`.
     */
    private fun applySessionPlan(plan: List<StandaloneTemplateExercise>?) {
        if (plan == null || plan == _metadata.value.sessionPlanExercises) return
        // Only the standalone path keeps a *position* of its own; a
        // phone-mastered session tracks its exercise by id
        // ([SessionMetadata.phoneCurrentExerciseId]), which a reordered list
        // can't invalidate.
        if (!_metadata.value.isStandalone) {
            _metadata.update { it.copy(sessionPlanExercises = plan) }
            return
        }
        _metadata.update { current ->
            val previousExerciseId = current.standaloneCurrentExerciseId
            val updated = current.copy(sessionPlanExercises = plan)
            val index = plan.indexOfFirst { it.exerciseId == previousExerciseId }
            if (previousExerciseId != null && index >= 0) {
                updated.copy(standaloneExerciseIndex = index)
            } else {
                // The exercise this watch was on is gone from the session
                // (deleted on the phone), or there was none yet: land on the
                // first one still unfinished, the same destination every other
                // advance picks — and drop the phone's prefill with it, since
                // it described the exercise we just left.
                updated.copy(
                    standaloneExerciseIndex = updated.firstUnfinishedStandaloneExerciseIndex,
                    standaloneExerciseManuallySelected = false,
                    nextSetReps = null,
                    nextSetWeight = null,
                )
            }
        }
    }

    /**
     * [SessionMetadata.advancedStandaloneExerciseIndex] applied — and, when it
     * actually moves the session on, the phone's pushed prefill dropped with
     * it: that value was computed for the exercise just left behind, so
     * keeping it would open the next exercise's first set on the finished
     * one's numbers. [SessionMetadata.standalonePrefill]'s local fallbacks
     * answer for the new exercise until the phone's fresh value lands (which
     * `ExerciseService` asks for by re-sending the adoption snapshot whenever
     * the index changes).
     */
    private fun SessionMetadata.withAdvancedExercise(): SessionMetadata {
        val advanced = advancedStandaloneExerciseIndex
        if (advanced == standaloneExerciseIndex) return this
        return copy(
            standaloneExerciseIndex = advanced,
            nextSetReps = null,
            nextSetWeight = null,
        )
    }

    /**
     * The gyakorlat-lista's tap handler (docs/watch/
     * 49-watch-f6b-template-sync-plan.md §3.5, D-F6b.8) — changes only which
     * exercise the *next* logged set counts against. Never closes a set,
     * starts/skips a rest, or touches a set already logged — those keep the
     * `exerciseIndex` they were logged with, permanently (§3.5). A no-op
     * outside a template session, for an index the snapshot doesn't have
     * (nothing to switch to, and the UI that calls this only ever offers
     * indices that exist), and for the exercise already selected.
     */
    /** The exercise list's tap handler in a **phone-mastered** session
     * (F6c §7) — records the pick locally and reports the exercise, so the
     * caller (`ActiveWorkoutScreen`) can send it to the phone, which owns the
     * decision and echoes it back on its next state push. Returns null when
     * there is nothing to send: an out-of-range index, or the exercise the
     * session is already on. */
    fun onPhoneExerciseSelected(index: Int): String? {
        val current = _metadata.value
        val exerciseId = current.activePlanExercises.getOrNull(index)?.exerciseId ?: return null
        if (exerciseId == current.currentExerciseId) return null
        _metadata.update {
            it.copy(
                phoneSelectedExerciseId = exerciseId,
                // The phone's prefill describes the exercise it still thinks
                // is current — dropping it stops the stepper from opening on
                // that one's numbers while the round trip completes.
                nextSetReps = null,
                nextSetWeight = null,
            )
        }
        return exerciseId
    }

    fun onStandaloneExerciseSelected(index: Int) {
        _metadata.update { current ->
            if (index in current.activePlanExercises.indices &&
                index != current.standaloneExerciseIndex &&
                !current.isStandaloneExerciseRemoved(index)
            ) {
                current.copy(
                    standaloneExerciseIndex = index,
                    standaloneExerciseManuallySelected = true,
                    // The phone's pushed prefill describes the exercise the
                    // *phone* thinks is current, which this tap just made
                    // stale — and [standalonePrefill] takes it ahead of
                    // everything else (priority 0). Dropping it here is what
                    // makes the "+1" tap and the adjust stepper follow the
                    // exercise the user just picked instead of opening on the
                    // previous one's numbers; the local fallbacks (this
                    // exercise's own synced `previousSets`, then its last
                    // logged set) cover the gap until the phone answers with a
                    // fresh value — and cover it entirely when the phone isn't
                    // reachable at all. `ExerciseService` is what tells the
                    // phone about the new index (it observes
                    // [standaloneExerciseIndex] and re-sends the adoption
                    // snapshot), so a fresh prefill is already on its way.
                    nextSetReps = null,
                    nextSetWeight = null,
                )
            } else {
                current
            }
        }
    }

    /**
     * The standalone local-mode branch of the "+1 set" tap (docs/watch/
     * 44-watch-f6-standalone-plan.md §2.1, §3.2) — no PENDING/ack
     * round-trip: this tap's set *is* the record (there's no phone to
     * confirm against), appended immediately, and a local rest starts right
     * away in the same field the phone-synced rest already uses
     * (`restDeadlineElapsedRealtimeMs`/`restTotalSeconds`), so
     * `ExerciseService`'s existing `scheduleRestVibration` collector works
     * unchanged. The rest length is the current exercise's synced,
     * already-resolved `restSeconds` (D-F6b.4, docs/watch/
     * 49-watch-f6b-template-sync-plan.md §3.3) when running from a template,
     * the fixed `STANDALONE_REST_SECONDS` default otherwise (44-doc §3.5).
     */
    fun onStandaloneSetLogged(reps: Int? = null, weight: Double? = null) {
        val nowElapsedRealtimeMs = SystemClock.elapsedRealtime()
        _metadata.update { current ->
            val restSeconds = current.standaloneCurrentExercise?.restSeconds ?: STANDALONE_REST_SECONDS
            // A plain tap takes whatever `standalonePrefill` resolved (last
            // workout's matching set, or this session's working weight)
            // instead of the bare STANDALONE_DEFAULT_REPS/no-weight it used
            // to log — that's what made every "+1" set land on the phone as
            // 0 kg.
            val prefill = current.standalonePrefill
            current.copy(
                standaloneSets = current.standaloneSets +
                    StandaloneSet(
                        loggedAtEpochMs = System.currentTimeMillis(),
                        reps = reps ?: prefill.reps,
                        weight = weight ?: prefill.weight,
                        // null outside a plan, matching F6a's original
                        // behavior exactly. The id is what the phone actually
                        // attributes by (F6c); the index rides along for a
                        // phone build that predates it.
                        exerciseIndex = current.activePlanExercises
                            .takeIf { it.isNotEmpty() }?.let { current.standaloneExerciseIndex },
                        exerciseId = current.standaloneCurrentExerciseId,
                    ),
                restDeadlineElapsedRealtimeMs = nowElapsedRealtimeMs + restSeconds * 1_000L,
                restTotalSeconds = restSeconds,
                // The hand-picked exercise has now been logged into, which is
                // all its stickiness was ever for — from here the normal
                // auto-advance below decides.
                standaloneExerciseManuallySelected = false,
            )
                // Read off the *updated* copy, so the set just appended counts
                // towards the target it may have completed.
                .withAdvancedExercise()
        }
        // Unlike the phone-mastered path there's no ack to wait for, but the
        // state still needs to move so ExerciseService's
        // scheduleLogSetTransition collector fires the confirm haptic/settle
        // it already does for a phone-acked tap (it reacts to any
        // LogSetState change, not just ones from the remote path).
        _logSetState.value = LogSetState.Confirmed
    }

    /**
     * The standalone counterpart of ending a session — called by
     * `ExerciseService.endStandaloneExercise` once the `HKWorkoutSession`-
     * equivalent Health Services exercise has closed and the finished
     * session is already queued in `StandaloneSessionStore`. Moves to
     * [SessionPhase.SUMMARY] with [summary] attached (see its doc comment)
     * and clears the running-session fields, same as [reset] otherwise
     * would for the phone-mastered path.
     */
    fun onStandaloneEnded(summary: StandaloneSummary) {
        _phase.value = SessionPhase.SUMMARY
        _standaloneSummary.value = summary
        _metadata.value = SessionMetadata()
        _liveMetrics.value = LiveMetrics()
    }

    fun onExerciseActive(startedAtElapsedRealtimeMs: Long) {
        _phase.value = SessionPhase.ACTIVE
        _liveMetrics.update { it.copy(startedAtElapsedRealtimeMs = startedAtElapsedRealtimeMs) }
    }

    fun onHeartRate(bpm: Double) {
        _liveMetrics.update { it.copy(heartRateBpm = bpm) }
    }

    fun onCalories(kcal: Double) {
        _liveMetrics.update { it.copy(activeCalories = kcal) }
    }

    /** The wrist's own pályán/padon tap (W-9) — moves this watch's state right
     * away; `ActiveWorkoutScreen` tells the phone, which runs its own
     * `_setOnCourt` and answers with the same value on its next push. GAME
     * only, so the toggle can't exist on a screen that has no bench.
     * Returns whether anything actually changed, so the caller only sends a
     * message for a real toggle. */
    fun setOnCourt(onCourt: Boolean): Boolean {
        val metadata = _metadata.value
        if (!metadata.isCardio || metadata.cardioFamily != CardioActivityFamily.GAME) return false
        if (metadata.isOnCourt == onCourt) return false
        applyOnCourt(onCourt)
        return true
    }

    /** The phone's own answer, from a state push. Ignored only while it
     * contradicts a still-unconfirmed local tap: pushes built *before* the
     * tap arrived still carry the old value, and applying one would visibly
     * flip the switch back for a second. The first agreeing push clears the
     * wait, and so does [PENDING_COURT_ECHO_MS] passing — so a tap the phone
     * legitimately refused (it guards on paused/finished) can't leave this
     * watch stuck on a state the session isn't in. */
    fun applyPhoneOnCourt(onCourt: Boolean) {
        val pending = pendingOnCourt
        if (pending != null) {
            val age = SystemClock.elapsedRealtime() - pendingOnCourtAtElapsedRealtimeMs
            val stillWaiting = pending != onCourt && age <= PENDING_COURT_ECHO_MS
            if (!stillWaiting) pendingOnCourt = null
            if (stillWaiting) return
        }
        applyOnCourt(onCourt, local = false)
    }

    /** Banks or reopens the local playing-time stint. Shared by both
     * directions so the accumulator can't drift from what the screen shows. */
    private fun applyOnCourt(onCourt: Boolean, local: Boolean = true) {
        if (local) {
            pendingOnCourt = onCourt
            pendingOnCourtAtElapsedRealtimeMs = SystemClock.elapsedRealtime()
        }
        _metadata.update { current ->
            if (current.isOnCourt == onCourt) return@update current
            val now = SystemClock.elapsedRealtime()
            if (onCourt) {
                current.copy(isOnCourt = true, localMovingAnchorElapsedRealtimeMs = now)
            } else {
                val banked = current.localMovingAnchorElapsedRealtimeMs
                    ?.let { ((now - it) / 1000L).toInt() } ?: 0
                current.copy(
                    isOnCourt = false,
                    localMovingSecondsBase = current.localMovingSecondsBase + banked,
                    localMovingAnchorElapsedRealtimeMs = null,
                )
            }
        }
    }

    /** This watch's own playing time so far — banked stints plus the open
     * one. Read by the standalone metrics page and by the closing payload. */
    fun localPlayingSeconds(): Int {
        val metadata = _metadata.value
        val anchor = metadata.localMovingAnchorElapsedRealtimeMs ?: return metadata.localMovingSecondsBase
        return metadata.localMovingSecondsBase +
            ((SystemClock.elapsedRealtime() - anchor) / 1000L).toInt()
    }

    /** Restores the accumulator after a process death — see
     * `ExerciseService.recoverStandaloneExercise`. An absent [sinceElapsedRealtimeMs]
     * *is* the benched state, exactly as it is on the phone. */
    fun restoreCourtState(movingSecondsBase: Int, sinceElapsedRealtimeMs: Long?) {
        _metadata.update {
            it.copy(
                isOnCourt = sinceElapsedRealtimeMs != null,
                localMovingSecondsBase = movingSecondsBase,
                localMovingAnchorElapsedRealtimeMs = sinceElapsedRealtimeMs,
            )
        }
    }

    /** Health Services' running distance total for this session — see
     * [LiveMetrics.distanceMeters]. */
    fun onDistanceMeasured(meters: Double) {
        _liveMetrics.update { it.copy(distanceMeters = meters) }
    }

    fun onPausedChanged(isPaused: Boolean) {
        _liveMetrics.update { it.copy(isPaused = isPaused) }
    }

    fun onHeartRatePermissionChecked(hasPermission: Boolean) {
        _liveMetrics.update { it.copy(hasHeartRatePermission = hasPermission) }
    }

    /**
     * `startExercise` was rejected — another app already owns the exercise
     * session (docs/40-watch-app-plan.md §12.1 B12). Drives `MainActivity`
     * to `ErrorScreen`; [reset] (its OK button) is what clears it.
     */
    fun onStartRejected() {
        _phase.value = SessionPhase.ERROR
    }

    /**
     * The log-lap UI (S13) calls this the instant it fires
     * `SummarySender.sendLogSet` — moves to [LogSetState.Pending] so
     * [ExerciseService] can schedule the ack timeout (docs/watch/
     * 43-watch-f5-set-logging-plan.md §3.2).
     */
    fun onLogSetRequested(eventId: String) {
        _logSetState.value = LogSetState.Pending(eventId)
    }

    /**
     * Called by [PhoneListenerService] on a `logSetAck` reply
     * (docs/watch/43-watch-f5-set-logging-plan.md §4.3). Only acts when
     * [eventId] matches the currently-pending tap — a late ack for a tap
     * that already timed out (and thus already settled back to
     * [LogSetState.Ready]) is a no-op, not a resurrection of stale state.
     */
    fun onLogSetAck(eventId: String, accepted: Boolean) {
        val pending = _logSetState.value as? LogSetState.Pending ?: return
        if (pending.eventId != eventId) return
        _logSetState.value = if (accepted) LogSetState.Confirmed else LogSetState.Failed
    }

    /**
     * Called by [ExerciseService]'s ack-timeout job (docs/watch/
     * 43-watch-f5-set-logging-plan.md §3.2, §7.1) once 5 s pass with no
     * [onLogSetAck] for [eventId]. Same match-or-no-op guard as
     * [onLogSetAck] — an ack that arrives in the same instant the timeout
     * fires simply wins the race, whichever call lands first.
     */
    fun onLogSetTimeout(eventId: String) {
        val pending = _logSetState.value as? LogSetState.Pending ?: return
        if (pending.eventId != eventId) return
        _logSetState.value = LogSetState.Failed
    }

    /** [ExerciseService] calls this once its confirm/fail settle delay
     * (1.2 s / 2.5 s) elapses — falls [LogSetState.Confirmed]/
     * [LogSetState.Failed] back to [LogSetState.Ready] on its own. */
    fun onLogSetSettled() {
        _logSetState.value = LogSetState.Ready
    }

    // ── Log-set adjust (docs/watch/48-watch-f5b-set-adjust-plan.md §3.1) ──

    /**
     * Opens the adjust stepper ([AdjustCircle]'s dedicated button, next to
     * the log control — D-F5b.1). Starts from the phone's prefill for the row a tap would
     * log into, falling back to a plain default when there's nothing to go
     * on (D-F5b.2) — standalone sessions have no phone prefill, so they
     * always take the default (`nextSetReps`/`nextSetWeight` are only ever
     * set by a phone-synced `state` message, which standalone never
     * receives). Same `Ready` gate the plain tap uses, so a still-pending
     * log can't be adjusted out from under itself.
     */
    /**
     * Whether a plain one-tap log has any idea what to record.
     *
     * For a phone-mastered session that's the prefill the phone publishes on
     * every state sync (the row's planned values, else this exercise's last
     * workout at that position, else its last logged set here); standalone
     * resolves the same chain locally. False means there is genuinely nothing
     * to go on for this exercise — a first-ever exercise with an empty plan —
     * and the tap would otherwise record a set with no weight and no reps.
     * `LogPage` sends the user to the adjust stepper instead, so they dial in
     * the first values rather than getting an empty row.
     */
    val hasLogSetPrefill: Boolean
        get() {
            val metadata = _metadata.value
            if (metadata.isStandalone) return metadata.standalonePrefill.weight != null
            return metadata.nextSetReps != null && metadata.nextSetWeight != null
        }

    fun onLogAdjustOpened() {
        val metadata = _metadata.value
        if (_phase.value != SessionPhase.ACTIVE) return
        if (_logSetState.value != LogSetState.Ready) return
        if (_logAdjustState.value != null) return
        // Standalone has no phone prefill to read (nextSetReps/nextSetWeight
        // only ever arrive via onStateSynced), so it resolves its own from
        // the synced template's history — see
        // [SessionMetadata.standalonePrefill]. Before this, the stepper
        // always opened on 10 reps / 0 kg in standalone.
        val prefill = if (metadata.isStandalone) metadata.standalonePrefill else null
        _logAdjustState.value = LogAdjustState(
            reps = prefill?.reps ?: metadata.nextSetReps ?: LOG_ADJUST_DEFAULT_REPS,
            weight = prefill?.weight ?: metadata.nextSetWeight ?: LOG_ADJUST_DEFAULT_WEIGHT,
            field = LogAdjustField.REPS,
        )
    }

    /**
     * One rotary detent = one step of the active field (D-F5b.5). [steps] is
     * signed. Values are clamped, never wrapped — running off the end should
     * feel like hitting a stop, not like jumping to the other end.
     *
     * The weight step is applied to whatever the prefill was, without
     * snapping to a 2.5 grid: a previously logged 61 kg steps to 63.5, not
     * 62.5. Predictable beats tidy — snapping would move the value by an
     * unrequested amount on the very first detent.
     */
    fun onLogAdjustStepped(steps: Int) {
        val current = _logAdjustState.value ?: return
        if (steps == 0) return
        _logAdjustState.value = when (current.field) {
            LogAdjustField.REPS -> current.copy(
                reps = (current.reps + steps * LOG_ADJUST_REPS_STEP)
                    .coerceIn(LOG_ADJUST_REPS_MIN, LOG_ADJUST_REPS_MAX),
                interactions = current.interactions + 1,
            )
            LogAdjustField.WEIGHT -> current.copy(
                weight = (current.weight + steps * LOG_ADJUST_WEIGHT_STEP)
                    .coerceIn(LOG_ADJUST_WEIGHT_MIN, LOG_ADJUST_WEIGHT_MAX),
                interactions = current.interactions + 1,
            )
        }
    }

    /** The Reps ⇄ Weight segment tap (0.2). */
    fun onLogAdjustFieldToggled() {
        val current = _logAdjustState.value ?: return
        _logAdjustState.value = current.copy(
            field = if (current.field == LogAdjustField.REPS) {
                LogAdjustField.WEIGHT
            } else {
                LogAdjustField.REPS
            },
            interactions = current.interactions + 1,
        )
    }

    /**
     * Closes the stepper **without logging** — the back gesture, the idle
     * timeout ([ExerciseService]) and the confirm button all land here
     * (D-F5b.7). Confirm reads the values first, then closes and sends
     * through the normal `onLogSetRequested` + `SummarySender.sendLogSet`
     * path, so there's no second state machine.
     */
    fun onLogAdjustCancelled() {
        _logAdjustState.value = null
    }

    /**
     * Called by [PhoneListenerService] on a `standaloneSessionAck`
     * (docs/watch/44-watch-f6-standalone-plan.md §4.2) — after
     * [StandaloneSessionStore.remove] already dropped the payload, this just
     * broadcasts the id for whichever summary screen is currently showing
     * it.
     */
    fun onStandaloneSessionAcked(standaloneSessionId: String) {
        _standaloneSessionAcked.tryEmit(standaloneSessionId)
    }

    /**
     * Called by [PhoneListenerService] on an `adoptionAck` (live bridging) —
     * the phone created (or already had) the live mirror row for
     * [standaloneSessionId]. Guarded against a stale ack for a
     * since-ended/since-replaced session, same shape as [onLogSetAck]'s
     * eventId check.
     */
    fun onAdoptionAcked(standaloneSessionId: String) {
        _metadata.update { current ->
            if (current.isStandalone && current.standaloneSessionId == standaloneSessionId) {
                current.copy(isAdopted = true)
            } else {
                current
            }
        }
    }

    /** Back to idle — both once a real exercise's notification is fully torn
     * down, and as [ErrorScreen]'s OK-button dismissal for [onStartRejected]. */
    fun reset() {
        _phase.value = SessionPhase.IDLE
        _metadata.value = SessionMetadata()
        pendingOnCourt = null
        _liveMetrics.value = LiveMetrics()
        _logSetState.value = LogSetState.Ready
        _logAdjustState.value = null
        _standaloneSummary.value = null
    }
}
