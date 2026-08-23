import Foundation
import HealthKit
import WatchKit

/// The closed-out workout's stats (docs/40-watch-app-plan.md §12.1 B9) —
/// carried by `WorkoutPhase.summary` rather than a separate published
/// property, since it only ever exists alongside that one phase and would
/// otherwise need to be manually kept in sync with it.
struct WorkoutSummaryData: Equatable {
  let totalDuration: TimeInterval
  let averageHeartRate: Double?
  let activeCalories: Double?
  /// Whether `finishWorkout()` returned a real `HKWorkout` (a
  /// `healthWorkoutId` was sent in the summary) — drives the "Saved to
  /// Health" line, not just whether the sensors *collected* HR/kcal data.
  let savedToHealth: Bool
  /// Non-nil only for a standalone summary (docs/watch/
  /// 44-watch-f6-standalone-plan.md D-F6.7) — phone-mastered sessions don't
  /// carry a set count on the watch at all (the phone owns that number).
  /// Drives `SummaryView`'s fourth "sets" tile.
  let setsCount: Int?
  /// Non-nil only for a standalone summary — the same id
  /// `StandaloneSessionPayload.standaloneSessionId` was queued under, so
  /// `SummaryView` can tell whether *this* session (not just "the queue")
  /// has been acked yet (§4.2) and render its own `sync_pending`/`sync_done`
  /// chip correctly even while other sessions remain queued.
  let standaloneSessionId: String?
}

/// How long the SUMMARY screen stays up before falling back to `.idle` on
/// its own (docs/40-watch-app-plan.md §12.1 B9: "~6 mp auto-dismiss").
private let summaryAutoDismissSeconds: TimeInterval = 6

/// What the active screen should show for "current exercise + set progress"
/// (docs/watch/49-watch-f6b-template-sync-plan.md §3.4) — one place
/// computing it (`WorkoutManager.activeExerciseDisplay`), shared by
/// `LogPage`, `MetricsPage` and `RestHeroView`'s caller instead of each
/// re-deriving the same three-way branch (template-with-`targetSets` /
/// template-without / phone-mastered vs. Quick strength).
struct ActiveExerciseDisplay {
  let name: String
  let setsDone: Int?
  let setsTotal: Int?
  /// Standalone's set-count line when there's no `targetSets` to compare
  /// against (44-doc §3.4, D-F6.3) — mutually exclusive with
  /// `setsDone`/`setsTotal` being non-nil.
  let freeFormatSets: (count: Int, totalReps: Int)?
}

/// DISTANCE/MACHINE/GAME grouping for a cardio `ActivityType` code — mirrors
/// Dart's `ActivityFamily`/`activityFamilyFor`
/// (mobile/lib/features/workouts/domain/activity_type.dart). The watch
/// derives this itself from `activityType` rather than the phone sending it,
/// the same "no activity-type dictionary of its own" choice `cardioActivityIcon`/
/// `cardioActivityTint` (`Views/ActiveWorkoutView.swift`) already make for
/// icons/tints — docs/cardio/55-cardio-watch-plan.md §2's table, minus the
/// `HKWorkoutActivityType`/`locationType` columns, which only `WatchBridge`
/// (a different target) and `startStandalone` need.
enum CardioActivityFamily {
  case distance
  case machine
  case game

  init(activityType: String) {
    switch activityType {
    case "INDOOR_BIKE": self = .machine
    case "BASKETBALL", "FOOTBALL", "OTHER_CARDIO": self = .game
    default: self = .distance  // RUNNING, WALKING, HIKING — and any future/unknown code
    }
  }
}

/// Maps a cardio `ActivityType` code to the `HKWorkoutConfiguration`
/// standalone (watch-started) cardio should record under (docs/cardio/
/// 55-cardio-watch-plan.md §5, W-8, C5.7b) — the watch-local counterpart of
/// `Runner/WatchBridge.swift`'s identical `cardioWorkoutActivityType`/
/// `cardioLocationType` pair, duplicated rather than shared for the same
/// reason `Views/ActiveWorkoutView.swift`'s icon/tint map already is: the
/// phone (`Runner`) and watch (`LifeyWatch`) are separate targets with no
/// shared source file, and this table is small (docs/cardio/
/// 59-cardio-implementation-plan.md's "tudatosan duplikálva" precedent).
/// No `venue` parameter, unlike the phone-side pair: a standalone session's
/// only cardio input is the picker's activity type
/// (`WatchQuickStartEntry.cardio`, `StandaloneSessionPayload.swift`) — there
/// is no venue to read here, so this always falls through to the
/// activity-type-only default branch the phone-side function also has.
private func cardioWorkoutActivityType(for activityType: String) -> HKWorkoutActivityType {
  switch activityType {
  case "INDOOR_BIKE": return .cycling
  case "RUNNING": return .running
  case "WALKING": return .walking
  case "HIKING": return .hiking
  case "BASKETBALL": return .basketball
  case "FOOTBALL": return .soccer
  case "OTHER_CARDIO": return .other
  default: return .traditionalStrengthTraining
  }
}

private func cardioLocationType(for activityType: String) -> HKWorkoutSessionLocationType {
  switch activityType {
  case "RUNNING", "WALKING", "HIKING": return .outdoor
  case "OTHER_CARDIO": return .unknown
  default: return .indoor
  }
}

/// One `WorkoutSessionState.cardio` push — `CardioLiveMetrics` in
/// `mobile/lib/core/workout_session_notifier/workout_session_notifier_service.dart`
/// — decoded into what the watch's own active screens need
/// (docs/cardio/55-cardio-watch-plan.md §4.2, C5.5). `primaryLabel`/`primaryValue`/
/// `secondaryLabel`/`secondaryValue`/`tertiaryLabel`/`tertiaryValue` are
/// pre-formatted, pre-localized strings — exactly like the STRENGTH fields
/// this class's siblings already carry, the watch needs no `CardioFormatter`
/// of its own — **except** for whichever slot holds the moving/game-time
/// duration (`ActiveWorkoutView`'s `CardioMetricsPage` decides which one by
/// family), which is stale between phone pushes by design (`movingSecondsBase`'s
/// own Dart doc: "hogy a natív felület magától ketyegjen, frissítés-kvóta
/// nélkül") and is re-rendered from [movingSecondsBase]/[movingAnchorUptime]
/// instead.
struct CardioActiveMetrics: Equatable {
  let primaryLabel: String
  let primaryValue: String
  let secondaryLabel: String?
  let secondaryValue: String?
  let tertiaryLabel: String?
  let tertiaryValue: String?

  /// The moving/game-time checkpoint the ticking slot counts up from — plain
  /// relative seconds, so (unlike the Dart source's `movingSinceEpochMs`,
  /// which this struct deliberately drops) it's safe to use regardless of
  /// whether the watch's and phone's wall clocks agree.
  let movingSecondsBase: Int

  /// This device's own `ProcessInfo.systemUptime` at the moment this
  /// snapshot was applied, or `nil` when paused — mirrors `restDeadlineUptime`'s
  /// pattern exactly: converts the phone's cross-device (and therefore
  /// clock-skew-prone) "ticking since epoch X" signal into a same-device
  /// monotonic anchor the instant it arrives, instead of ever comparing the
  /// phone's `movingSinceEpochMs` against this device's own wall clock (the
  /// same reasoning `applyStateUpdate`'s doc comment already gives for the
  /// rest timer).
  let movingAnchorUptime: TimeInterval?
}

enum WorkoutPhase: Equatable {
  case idle
  case active
  /// End was pressed on the watch (or the phone asked to end via
  /// `applyEndedIfNeeded`), waiting for the phone's real `end` command
  /// before `finishAndSendSummary()` actually closes the `HKWorkoutSession`
  /// (docs/40-watch-app-plan.md §12.1 B8, §8.2 decision (b)) — the sensors
  /// keep recording underneath.
  case ending
  /// The session just closed — showing the closing stats for
  /// `summaryAutoDismissSeconds` before `scheduleSummaryAutoDismiss()` falls
  /// back to `.idle` on its own (docs/40-watch-app-plan.md §12.1 B9).
  case summary(WorkoutSummaryData)
  /// HealthKit sharing is denied for the workout type — `start(configuration:)`
  /// checked before ever touching `HKWorkoutSession`, since a session that
  /// can't save a workout shouldn't silently run (docs/40-watch-app-plan.md
  /// §12.1 B10). `dismissError()` (the "Review access" button) is the only
  /// way out, back to `.idle`. No `startRejected`-style phase exists for the
  /// "another app owns the sensors" failure — that one keeps its original
  /// behavior (message to the phone, watch stays `.idle`), since §12.1 only
  /// lists a dedicated screen for the health-denied case on iOS.
  case healthDenied
}

/// The tap-to-ack lifecycle of the "+1 set" control (docs/watch/
/// 43-watch-f5-set-logging-plan.md §3.2). `.pending`'s associated `String`
/// is the tap's `eventId` — `applyLogSetAck` only acts on an ack matching
/// this exact id, so a stale ack for an already-settled/superseded tap is a
/// no-op. F6 (docs/watch/44-watch-f6-standalone-plan.md §2.1) will add a
/// local mode that skips straight to `.confirmed` — kept as a single branch
/// point in `logSet()` rather than scattered UI `if`s so that's a small
/// addition, not a restructure.
enum LogSetState: Equatable {
  case ready
  case pending(String)
  case confirmed
  case failed
}

/// How long `logSet()` waits for a `logSetAck` before giving up
/// (docs/watch/43-watch-f5-set-logging-plan.md §3.2, §10/4 — calibratable).
private let logSetAckTimeoutSeconds: TimeInterval = 5
/// How long `.confirmed`/`.failed` stays up before `logSetState` falls back
/// to `.ready` on its own (docs/watch/43-watch-f5-set-logging-plan.md §3.2).
private let logSetConfirmedSettleSeconds: TimeInterval = 1.2
private let logSetFailedSettleSeconds: TimeInterval = 2.5

/// D-F6.8 — the watch has no reps input yet in F6a, so every locally logged
/// standalone set uses this fixed value; the user corrects it on the phone
/// later. Carried per-set on the wire already so a future watch-side
/// stepper (F5b/F6b) won't need a protocol change.
private let standaloneDefaultReps = 10
/// §3.5 — standalone has no phone-driven rest timer, so the watch starts
/// its own fixed-length one on every logged set.
private let standaloneRestSeconds: TimeInterval = 90
/// How long the standalone badge shows its "syncing" glyph after a tap — see
/// `WorkoutManager.isRetryingAdoption` for why this is a fixed duration
/// rather than real progress.
private let adoptionRetryFeedbackSeconds: TimeInterval = 1.5

/// Which of the two values the adjust stepper is currently editing
/// (docs/watch/48-watch-f5b-set-adjust-plan.md 0.2) — one at a time, the
/// other stays visible in the caption line.
enum LogAdjustField: Equatable {
  case reps
  case weight
}

/// The live state of the "+1 set" adjust stepper (canvas AW 10). Non-nil
/// exactly while the stepper is on screen; `nil` means the plain log page.
/// Deliberately independent of `LogSetState`: the adjust lives entirely
/// *before* a tap is committed, and hands over to the existing
/// pending/ack lifecycle only on confirm — which is also what lets F6b
/// reuse it for the standalone path without rewriting it (D-F5b.8).
struct LogAdjustState: Equatable {
  var reps: Int
  /// Always kg, matching the phone's own workout UI (D-F5b.4).
  var weight: Double
  var field: LogAdjustField

  /// Whether a −/+ tap on the active field would still move the value —
  /// drives the disabled/ghosted look of the stepper's two buttons. The crown
  /// has no equivalent need (it just clamps silently against a stop), so these
  /// exist purely so a *button* can show it's at the end of its range instead
  /// of looking tappable and doing nothing. Kept next to `stepLogAdjust`'s own
  /// clamping so the bounds stay in one place.
  var canDecrement: Bool {
    switch field {
    case .reps: return reps > logAdjustRepsBounds.lowerBound
    case .weight: return weight > logAdjustWeightBounds.lowerBound
    }
  }

  var canIncrement: Bool {
    switch field {
    case .reps: return reps < logAdjustRepsBounds.upperBound
    case .weight: return weight < logAdjustWeightBounds.upperBound
    }
  }
}

/// Stepper steps and bounds (D-F5b.5). The reps floor of 1 matches the
/// phone's own validator (`> 0`); weight allows 0 for bodyweight work.
private let logAdjustRepsStep = 1
private let logAdjustWeightStep = 2.5
private let logAdjustRepsBounds = 1...99
private let logAdjustWeightBounds = 0.0...500.0
/// Used when the phone sent no prefill at all (D-F5b.2's 4th branch) — the
/// stepper has to start *somewhere*, and this is new data rather than an
/// adjustment of a known value.
private let logAdjustDefaultReps = 10
private let logAdjustDefaultWeight = 0.0
/// How long the stepper stays up without any interaction before dismissing
/// itself — **3 s, deliberately longer than the design's 2 s** (§11/3):
/// on a wrist a single glance away shouldn't cost the half-dialled value,
/// and the wait costs nothing since the view never logs on its own (0.5).
private let logAdjustIdleDismissSeconds: TimeInterval = 3

/// Mirrors Android's `SessionStateHolder` + `ExerciseService` combined
/// (docs/40-watch-app-plan.md §4.3, §5.1/§5.3) — the single in-process
/// source of truth `ContentView`/`ActiveWorkoutView` and `PhoneConnector`
/// all read from or write into. `.shared` because `AppDelegate.handle(_:)`
/// (a non-SwiftUI entry point) and `PhoneConnector` both need to reach it.
@MainActor
final class WorkoutManager: NSObject, ObservableObject {
  static let shared = WorkoutManager()

  @Published private(set) var phase: WorkoutPhase = .idle
  @Published private(set) var sessionClientId: String?
  @Published private(set) var title: String?
  @Published private(set) var exerciseName: String?
  @Published private(set) var setsDone: Int?
  @Published private(set) var setsTotal: Int?
  /// The rest timer's target end time, anchored to *this device's own*
  /// `ProcessInfo.systemUptime` (monotonic, not wall-clock) — nil when no
  /// rest is active. `applyStateUpdate` converts the phone's relative
  /// "seconds remaining" into this local deadline the instant a sync
  /// arrives, mirroring Android's `SessionStateHolder` fix
  /// (docs/40-watch-app-plan.md §12.1 bugfix): comparing an absolute epoch
  /// target against wall-clock time only works if the phone's and watch's
  /// clocks agree, which two paired devices aren't guaranteed to.
  @Published private(set) var restDeadlineUptime: TimeInterval? {
    didSet { scheduleRestHaptic() }
  }
  /// The rest timer's full configured duration in seconds — nil exactly
  /// when `restDeadlineUptime` is nil (docs/40-watch-app-plan.md §12.1 B1).
  /// Used alongside it to render the drain-down progress ring.
  @Published private(set) var restTotalSeconds: Int?
  /// Mirrors Android's `LiveMetrics.isPaused` (`ExerciseUpdate.exerciseStateInfo.state.isPaused`)
  /// — set from `HKWorkoutSessionDelegate`'s state-change callback, the
  /// authoritative signal for whether the *sensor* session is paused. Only
  /// `pause()`/`resume()` (docs/40-watch-app-plan.md §12.1 B3) touch this —
  /// the phone-session's own timing is untouched, matching §4.4/§5.3 ("csak
  /// a szenzor-sessiont pauzálja, a telefon-session időzítését nem").
  @Published private(set) var isPaused = false
  @Published private(set) var heartRateBpm: Double?
  @Published private(set) var activeCalories: Double?
  @Published private(set) var startedAt: Date?

  /// `'STRENGTH'` or `'CARDIO'` — mirrors `WorkoutSessionState.kind`
  /// (docs/cardio/55-cardio-watch-plan.md §4.1, C5.5). Only ever set by
  /// `applyStateUpdate`'s phone-mastered path **and** by
  /// `startStandalone(template:activityType:title:)` — a watch-started cardio
  /// session (C5.7b's W-8) sets it from the picker row's own activity type,
  /// which is what puts this watch on the cardio screens with no phone
  /// involved at all.
  @Published private(set) var sessionKind = "STRENGTH"
  /// One of `activity_type.dart`'s `kActivityTypes` — non-nil exactly when
  /// [sessionKind] is `'CARDIO'`, mirroring `WorkoutSessionState.activityType`.
  @Published private(set) var cardioActivityType: String?
  /// The session's live cardio metrics, or `nil` for a STRENGTH session (and,
  /// briefly, for a CARDIO one before its first state sync lands). See
  /// [CardioActiveMetrics].
  @Published private(set) var cardioMetrics: CardioActiveMetrics?

  var isCardio: Bool { sessionKind == "CARDIO" }
  var cardioFamily: CardioActivityFamily? { cardioActivityType.map(CardioActivityFamily.init(activityType:)) }

  /// The locally-ticking moving/game-time seconds for [cardioMetrics] — see
  /// [CardioActiveMetrics.movingAnchorUptime]'s doc. Falls back to the frozen
  /// base while paused (`movingAnchorUptime == nil`) or before any cardio
  /// metrics have arrived.
  func currentCardioMovingSeconds() -> Int {
    guard let metrics = activeCardioMetrics else { return 0 }
    guard let anchor = metrics.movingAnchorUptime else { return metrics.movingSecondsBase }
    return metrics.movingSecondsBase + Int((ProcessInfo.processInfo.systemUptime - anchor).rounded(.down))
  }

  /// What the cardio pages actually render: the phone's pushed metrics when
  /// there are any, this watch's **own** measurements otherwise.
  ///
  /// The fallback is the whole difference between a watch-started cardio
  /// session looking finished and looking real. `cardioMetrics` only ever
  /// arrives from a phone-mastered session's state sync, so a session started
  /// on the wrist (W-8) had nothing to show at all — no time, no distance,
  /// just the heart-rate row under a header that read "STRENGTH" (the generic
  /// `active_header_label`, since a standalone session has no phone-pushed
  /// title). Meanwhile HealthKit was handing this class every number the page
  /// needed.
  var activeCardioMetrics: CardioActiveMetrics? {
    if let cardioMetrics { return cardioMetrics }
    guard isCardio, let startedAt else { return nil }
    return localCardioMetrics(startedAt: startedAt)
  }

  /// This watch's own live cardio metrics, in the same slots and the same
  /// order the phone fills them (`CardioSessionScreen._cardioLiveMetrics`) —
  /// so the standalone screens are the *same* screens, not a second design:
  ///
  /// - `DISTANCE`: distance leads once there is one, moving time before that
  ///   (exactly the phone's `hasDistance` swap), with pace in the third slot;
  /// - `MACHINE`: moving time, and nothing else — the phone fills the other
  ///   two from cadence/power sensors this watch doesn't have, and a box
  ///   reading "—" for the whole session is worse than no box;
  /// - `GAME`: playing time alone, for the same reason (gross time only
  ///   differs from playing time once something actually pauses the
  ///   accounting, which standalone has no way to do — see
  ///   `CardioActiveContent`'s `onCourt` doc).
  ///
  /// Time is anchored, not stored: `movingSecondsBase: 0` plus an anchor
  /// derived from [startedAt] means the ticking slot counts real elapsed
  /// seconds even if this value is built once and held for a while. The
  /// anchor is never dropped for a paused session, matching what both
  /// platforms already do with a paused *phone-mastered* one — pausing stops
  /// the sensors, not the clock (docs/40-watch-app-plan.md §4.4/§5.3).
  private func localCardioMetrics(startedAt: Date) -> CardioActiveMetrics {
    let elapsed = max(0, Date().timeIntervalSince(startedAt))
    let anchor = ProcessInfo.processInfo.systemUptime - elapsed
    let movingTimeLabel = String(localized: "cardio_moving_time_label")
    let duration = formatCardioDuration(Int(elapsed))
    let units = StandaloneSessionStore.shared.unitSystem()

    switch cardioFamily {
    case .distance:
      let meters = lastDistanceMeters ?? 0
      let hasDistance = meters > 0
      let distanceLabel = String(localized: "cardio_distance_label")
      return CardioActiveMetrics(
        primaryLabel: hasDistance ? distanceLabel : movingTimeLabel,
        primaryValue: hasDistance ? formatDistance(meters, units: units) : duration,
        secondaryLabel: hasDistance ? movingTimeLabel : distanceLabel,
        secondaryValue: hasDistance ? duration : "—",
        tertiaryLabel: String(localized: "cardio_pace_label"),
        tertiaryValue: formatPace(meters: meters, seconds: Int(elapsed), units: units) ?? "—",
        movingSecondsBase: 0,
        movingAnchorUptime: anchor)
    case .machine:
      return CardioActiveMetrics(
        primaryLabel: movingTimeLabel,
        primaryValue: duration,
        secondaryLabel: nil,
        secondaryValue: nil,
        tertiaryLabel: nil,
        tertiaryValue: nil,
        movingSecondsBase: 0,
        movingAnchorUptime: anchor)
    case .game, .none:
      return CardioActiveMetrics(
        primaryLabel: String(localized: "cardio_playing_time_label"),
        primaryValue: duration,
        secondaryLabel: nil,
        secondaryValue: nil,
        tertiaryLabel: nil,
        tertiaryValue: nil,
        movingSecondsBase: 0,
        movingAnchorUptime: anchor)
    }
  }

  /// The closing-summary cardio block for whichever session is ending —
  /// `finishAndSendSummary()` (phone-mastered) and `endStandalone(rpe:)`
  /// (watch-started) both call this right before they close. `nil` for a
  /// STRENGTH session, and for a cardio one HealthKit never reported a
  /// distance sample for (docs/cardio/55-cardio-watch-plan.md §4.3: "csak
  /// akkor írja felül, ha az óra mért" — the phone's own merge already treats
  /// a missing field as a no-op, so there's nothing to fake here). `"DEVICE"`
  /// matches `source = DEVICE` — the phone's manual/measured value always
  /// wins (docs/cardio/51-cardio-overview-plan.md R8).
  ///
  /// The cadence pair rides along only for a RUNNING session that produced at
  /// least one full window ([collectsCadence], [cadenceWindowSeconds]) —
  /// everything else sends the block without those keys, exactly as before
  /// C6.5.
  private func cardioSummaryPayload() -> CardioSummaryPayload? {
    guard isCardio, let lastDistanceMeters else { return nil }
    return CardioSummaryPayload(
      distanceMeters: lastDistanceMeters, distanceSource: "DEVICE",
      avgCadence: averageCadenceSpm(), maxCadence: maxCadenceSpm)
  }

  /// Whether `EffortSelectorView` should be shown over `ActiveWorkoutView`
  /// right now — set by the End button, cleared once `requestEnd(rpe:)`
  /// actually sends the effort rating (or a skip) to the phone. A separate
  /// flag rather than a new `WorkoutPhase` case: `phase` stays `.active` the
  /// whole time the selector is up, since nothing about the session's
  /// lifecycle changes until Confirm/Skip is tapped.
  @Published private(set) var showEffortSelector = false

  /// The "+1 set" control's own lifecycle — see [LogSetState]. Independent
  /// of `phase`/`showEffortSelector`, since a set can be logged mid-rest or
  /// while paused (docs/watch/43-watch-f5-set-logging-plan.md §3.3).
  @Published private(set) var logSetState: LogSetState = .ready
  /// Drives the log-set control's ghosted "phone not reachable" state
  /// before a tap ever happens (docs/watch/43-watch-f5-set-logging-plan.md
  /// §4.4) — set from `PhoneConnector.applyReachabilityChanged(_:)`.
  /// Defaults `true` so the very first frame (before activation completes)
  /// doesn't flash ghosted on a normally-connected pair.
  @Published private(set) var isPhoneReachable = true

  /// What the F5b adjust stepper should start from — computed by the phone
  /// for the exact row a "+1 set" tap would log into, and re-sent on every
  /// state sync (docs/watch/48-watch-f5b-set-adjust-plan.md D-F5b.2, §4.2).
  /// Nil when the phone has nothing to go on; the stepper then starts from
  /// its own default. `nextSetWeight` is in kg (D-F5b.4).
  @Published private(set) var nextSetReps: Int?
  @Published private(set) var nextSetWeight: Double?

  /// The adjust stepper's live state — non-nil exactly while it's on screen
  /// (docs/watch/48-watch-f5b-set-adjust-plan.md §3.1). See [LogAdjustState].
  @Published private(set) var logAdjustState: LogAdjustState?

  /// Whether the running session is watch-only (docs/watch/
  /// 44-watch-f6-standalone-plan.md §1) rather than phone-mastered — `false`
  /// for every pre-F6 flow. Gates `logSet()`'s local-vs-remote branch,
  /// `applyStateUpdate`'s phone-state rejection (D-F6.2), and which of
  /// `finishAndSendSummary()`/`endStandalone(rpe:)` `requestEnd(rpe:)` calls.
  @Published private(set) var isStandalone = false
  /// Whether the phone has acknowledged a live-bridging adoption request for
  /// this standalone session (`sendAdoptionRequestIfNeeded()`/
  /// `applyAdoptionAck(standaloneSessionId:)`) — meaningless outside
  /// `isStandalone`. Deliberately does **not** flip `logSet()`'s local-vs-
  /// remote branch: set-logging stays watch-local/instant always for a
  /// standalone session, adopted or not (the whole reliability point of F6).
  /// It only relaxes the phone-originated `"end"` command's guard, so an
  /// adopted session can be ended from either side.
  @Published private(set) var isAdopted = false
  /// Whether `HeaderChip`'s "not connected" badge should show — a genuinely
  /// disconnected standalone session, not one the phone has already joined.
  /// Once adopted, the phone IS tracking the session live, so the icon
  /// implying otherwise would be actively misleading.
  var showsStandaloneBadge: Bool { isStandalone && !isAdopted }

  /// True for a moment after the standalone badge is tapped
  /// (`retryAdoption()`), so the glyph can acknowledge the tap. Purely
  /// cosmetic: `transferUserInfo` hands the payload to the OS immediately
  /// and answers nothing, so there is no real "sending" progress to show —
  /// what a successful sync actually looks like is `isAdopted` flipping and
  /// the badge disappearing altogether.
  @Published private(set) var isRetryingAdoption = false
  /// The metrics page's header label: the template/session name when one is
  /// available (`standaloneTemplate.title` for a template-backed standalone
  /// session, `title` for a phone-mastered one — never both at once, since
  /// `title` is never set for standalone, D-F6.2), the generic
  /// `active_header_label` ("STRENGTH"/"ERŐ") otherwise (Quick strength, or
  /// no name at all). `HeaderChip`'s own `.lineLimit(1)` already truncates a
  /// too-long name with a trailing "…" (SwiftUI's default truncation mode).
  var activeHeaderLabel: String {
    let name = standaloneTemplate?.title ?? title
    if let name, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      return name
    }
    return String(localized: "active_header_label")
  }
  /// The standalone session's own set log — the only record of it until
  /// `endStandalone(rpe:)` queues it (docs/watch/44-watch-f6-standalone-plan.md
  /// §3.1). Unused (`[]`) outside standalone mode; phone-mastered sessions
  /// track their set count via `setsDone`/`setsTotal` instead, which the
  /// phone itself owns.
  @Published private(set) var standaloneSets: [StandaloneSet] = []
  /// The template this standalone session is running against, or `nil` for
  /// the F6a "Quick strength" flow (docs/watch/49-watch-f6b-template-sync-plan.md
  /// §3.3, D-F6b.8). A **snapshot** taken at `startStandalone(template:)`,
  /// not a live reference to `StandaloneSessionStore`'s cache — a
  /// `templateSync` landing mid-session (D-F6b.2 guarantees it won't even
  /// try to touch the running session's own state) still must not be able
  /// to change what a *running* session's gyakorlatnév/restSeconds are,
  /// which a cache-lookup-by-id would risk.
  @Published private(set) var standaloneTemplate: CachedTemplate?
  /// The phone's live session plan (docs/watch/50-watch-f6c-session-plan-sync-plan.md),
  /// once it has pushed one — the session's *own* exercise list, which wins
  /// over `standaloneTemplate`'s snapshot from then on. That's the only list
  /// that can express an exercise added or removed on the phone mid-workout.
  ///
  /// `nil` until (and unless) one arrives: an older phone build, a phone out
  /// of range, or a session it isn't mirroring all leave the watch on its
  /// cached template, which is exactly the pre-F6c behaviour.
  @Published private(set) var sessionPlanExercises: [CachedTemplateExercise]?
  /// Which exercise the **phone** says is current, by clientId — the
  /// phone-mastered counterpart of `standaloneExerciseIndex` (docs/watch/
  /// 50-watch-f6c-session-plan-sync-plan.md §7). Pushed on every state sync.
  @Published private(set) var phoneCurrentExerciseId: String?
  /// The exercise the user picked from this watch's own list during a
  /// phone-mastered session, until the phone's next push confirms it — an
  /// optimistic local override so the list highlight and the next tap follow
  /// the finger immediately, without waiting for the round trip. Cleared the
  /// moment the phone agrees (or names something else the user has since
  /// picked on the phone itself).
  @Published private(set) var phoneSelectedExerciseId: String?

  /// The exercise list this session actually works against: the phone's live
  /// plan when there is one, the cached template otherwise. Every "which
  /// exercise" decision reads this rather than `standaloneTemplate` directly,
  /// so both sources behave identically everywhere downstream.
  var activePlanExercises: [CachedTemplateExercise] {
    sessionPlanExercises ?? standaloneTemplate?.exercises ?? []
  }

  /// The clientId of the exercise the next set counts against — what the watch
  /// now sends with every logged set and adoption snapshot instead of relying
  /// on its position (F6c).
  var standaloneCurrentExerciseId: String? { standaloneCurrentExercise?.exerciseId }

  /// The exercise the next set counts against, whoever is mastering the
  /// session: the wrist's own position in standalone mode, and in a
  /// phone-mastered one the user's local pick if there is one, else whatever
  /// the phone last named (F6c §7).
  var currentExerciseId: String? {
    isStandalone ? standaloneCurrentExerciseId : (phoneSelectedExerciseId ?? phoneCurrentExerciseId)
  }

  /// Where `currentExerciseId` sits in `activePlanExercises` — what the list
  /// highlights, and the index the standalone path already works in.
  var currentExercisePlanIndex: Int? {
    guard let currentExerciseId else { return nil }
    return activePlanExercises.firstIndex { $0.exerciseId == currentExerciseId }
  }

  /// Whether this watch may offer its exercise list: a plan-backed standalone
  /// session as before, and now a phone-mastered one too as soon as the phone
  /// has pushed the session's exercises (F6c §7). A single-exercise list is
  /// not worth a chip — there is nothing to switch to.
  var canChooseExercise: Bool {
    activePlanExercises.count > 1 || (isStandalone && standaloneTemplate != nil)
  }
  /// Which of `standaloneTemplate.exercises` new sets log against — always
  /// 0 and unused outside a template session. Changed only by
  /// `selectStandaloneExercise(_:)` (§3.5's gyakorlat-lista, wired in T7);
  /// never overwritten by anything synced from the phone.
  @Published private(set) var standaloneExerciseIndex = 0
  /// Set by `selectStandaloneExercise(_:)`, cleared by the next locally logged
  /// set — "the user picked this exercise by hand, don't move off it".
  ///
  /// Only `advanceStandaloneExerciseIfComplete()`'s *phone-count-driven* call
  /// site (`applyStateUpdate`) honours it, and it exists for one case: picking
  /// an exercise that already has all its planned sets, to add one more. That
  /// exercise is complete by definition, so the very next state sync would
  /// otherwise bounce the selection straight on to the first unfinished one —
  /// leaving the user unable to select it at all. A set logged into it clears
  /// the flag, so the normal auto-advance takes over again from there.
  private var standaloneExerciseManuallySelected = false

  /// What the phone reports for the exercise at `phoneSetsExerciseIndex`:
  /// how many sets its copy of this session has for it, and how many its plan
  /// holds. Both `nil` until a state sync names an exercise this watch agrees
  /// is the current one.
  ///
  /// A watch-started session is logged into from *both* sides — the phone's
  /// mirror screen stays editable — but only the phone's row holds both
  /// halves; `standaloneSets` is the watch's own half alone. Without this the
  /// counter on the wrist silently ignored every set logged on the phone, and
  /// the auto-advance below kept offering an exercise that was already
  /// finished there.
  @Published private(set) var phoneSetsDone: Int?
  @Published private(set) var phoneSetsTotal: Int?
  /// Which exercise `phoneSetsDone`/`phoneSetsTotal` are about, by clientId
  /// (F6c) — preferred over `phoneSetsExerciseIndex`, which is a position in
  /// the *template* and therefore meaningless once the phone's session plan is
  /// what this watch lists.
  @Published private(set) var phoneSetsExerciseId: String?
  /// The phone's set count for **every** exercise of the plan, in this
  /// watch's own index order (see `WorkoutSessionState.setsDonePerExercise`).
  ///
  /// `phoneSetsDone` above only describes the current exercise, which is
  /// enough to render its counter but not to decide when the session should
  /// move on: `advanceStandaloneExerciseIfComplete()` judges *every* exercise,
  /// and from this watch's own set list every exercise finished on the phone
  /// still looks unfinished. It kept jumping back into those, being told they
  /// were complete after all, then jumping on — visibly hopping between
  /// already-finished exercises.
  @Published private(set) var phoneSetsDonePerExercise: [Int]?
  /// Plan positions the user removed from this session on the phone (see
  /// `WorkoutSessionState.removedExerciseIndexes`) — hidden from the exercise
  /// list and never advanced into. Empty for every session the phone hasn't
  /// said otherwise about, including an older phone build's.
  ///
  /// The watch's cached template stays the index space, deliberately: every
  /// set already logged carries a position in it, so the list can only ever
  /// *hide* entries here, never renumber them. An exercise added to the
  /// session on the phone has no position at all and so can't appear — that
  /// needs the session's own plan as the index space (docs/watch/
  /// 50-watch-f6c-session-plan-sync-plan.md).
  @Published private(set) var removedExerciseIndexes: Set<Int> = []
  /// Which exercise the two values above are about — the phone echoes back
  /// the index this watch sent it (`currentExerciseIndex` in the adoption
  /// payload), so a value computed for a different exercise is never applied
  /// to the current one. `nil` whenever the phone had nothing matching to say.
  private var phoneSetsExerciseIndex: Int?

  private let store = HKHealthStore()
  private var session: HKWorkoutSession?
  private var builder: HKLiveWorkoutBuilder?
  private var restHapticTask: Task<Void, Never>?
  /// Cancelled/replaced on every `logSet()` tap and on `reset()` — see
  /// `logSet()`, `applyLogSetAck(eventId:accepted:)`.
  private var logSetTimeoutTask: Task<Void, Never>?
  /// Drives `.confirmed`/`.failed` falling back to `.ready` on their own —
  /// see `scheduleLogSetSettle(after:)`.
  private var logSetSettleTask: Task<Void, Never>?
  /// Restarted by every stepper interaction; dismisses the adjust view when
  /// it finally elapses — see `scheduleLogAdjustIdleDismiss()`.
  private var logAdjustIdleTask: Task<Void, Never>?
  /// Clears `isRetryingAdoption` — see `retryAdoption()`.
  private var adoptionRetryTask: Task<Void, Never>?
  /// The `sessionClientId` `sendStartedOnWatch` was already sent for, so a
  /// later `applyStateUpdate` (which fires on every state sync, many times
  /// per session) doesn't resend it — see `notifyStartedOnWatchIfNeeded()`.
  private var notifiedStartedOnWatchFor: String?
  /// The running cardio session's own distance measurement, meters —
  /// updated on every `HKLiveWorkoutBuilderDelegate` tick that carries one of
  /// `distanceWalkingRunningType`/`distanceCyclingType`, for both a
  /// phone-mastered and a standalone cardio session alike (the delegate
  /// callback is tied to `builder`, not to `isStandalone`). Read once, at
  /// close, by `cardioSummaryPayload()`. `nil` for a STRENGTH session and for
  /// a cardio one HealthKit hasn't reported a distance sample for yet (e.g.
  /// `GAME`, which has no matching quantity type at all — see
  /// `cardioSummaryPayload()`) — and, since standalone cardio renders its own
  /// numbers ([localCardioMetrics]), read live by the metrics page too, which
  /// is why it's `@Published` rather than the plain stored property it was
  /// while only the closing payload looked at it.
  @Published private(set) var lastDistanceMeters: Double?

  /// Whether this session collects running cadence at all (docs/cardio/
  /// 60-cardio-sport-specifics-plan.md C6.5) — true only for a `.running`
  /// `HKWorkoutConfiguration`, decided once in `startSession(configuration:)`
  /// and restored by `recoverStandaloneSessionIfNeeded()`. The same gate Wear
  /// OS applies by simply not requesting `DataType.STEPS_PER_MINUTE_STATS`
  /// (`ExerciseService.buildExerciseConfig`): a walker's or hiker's
  /// steps-per-minute is a number nobody trains on and the phone's summary
  /// has no place to show it, so it never goes on the wire.
  private var collectsCadence = false
  /// Steps counted inside completed cadence windows, and the seconds those
  /// windows spanned — the duration-weighted average's two halves (see
  /// `averageCadenceSpm()`). Accumulated in `workoutBuilder(_:didCollectDataOf:)`
  /// rather than derived at close from `builder.elapsedTime`, so a stretch
  /// where HealthKit reported no steps at all simply contributes nothing
  /// instead of dragging the average toward zero.
  private var cadenceSteps: Double = 0
  private var cadenceSeconds: TimeInterval = 0
  /// The fastest completed window, spm — C6.5's `maxCadence`. Nil until the
  /// first window closes.
  private var maxCadenceSpm: Double?
  /// The open window's start: the cumulative step total and the instant it was
  /// read at. Seeded from the session start (0 steps at `startedAt`) so the
  /// first window loses nothing, cleared on every pause/resume transition so a
  /// window can't straddle a pause and report the standing minutes as slow
  /// running.
  private var cadenceAnchorSteps: Double?
  private var cadenceAnchorAt: Date?
  /// The shortest stretch a cadence window may be scored over. HealthKit
  /// delivers step samples in small chunks, and over one or two seconds the
  /// step count quantizes brutally — 3 steps in 1 s reads as 180 spm, 4 as
  /// 240 — so a raw per-tick rate would put a number in `maxCadence` that the
  /// runner never actually ran. A window is only closed (and the anchor only
  /// advanced) once this much time has passed, which makes the window a
  /// sliding ≥10 s one rather than a per-tick sample.
  private static let cadenceWindowSeconds: TimeInterval = 10

  // docs/40-watch-app-plan.md §4.2 — the traditional `quantityType(forIdentifier:)`
  // form rather than the `HKQuantityType(.heartRate)` convenience init, which
  // needs a newer OS than this target's WATCHOS_DEPLOYMENT_TARGET (10.0).
  private static let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate)!
  private static let activeEnergyType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!
  /// Cardio closing-summary distance (docs/cardio/55-cardio-watch-plan.md §4.3,
  /// C5.7b) — the two quantity types `HKLiveWorkoutBuilder` actually
  /// accumulates for the activity types this watch can start
  /// ([cardioWorkoutActivityType]'s range). No elevation-gain counterpart:
  /// unlike Wear OS's Health Services (`DataType.ELEVATION_GAIN_TOTAL`,
  /// wired in C5.7a), HealthKit only derives elevation from GPS route data
  /// (`HKWorkoutRouteBuilder`), which this app doesn't collect yet
  /// (docs/cardio/55-cardio-watch-plan.md §6, "Watch-GPS" — its own,
  /// not-yet-started mini-plan) — so `cardioSummaryPayload()` sends distance
  /// only, exactly like Wear OS sends distance-without-elevation for any
  /// activity type its own sensor set can't back (C5.6's capability gate).
  private static let distanceWalkingRunningType = HKObjectType.quantityType(
    forIdentifier: .distanceWalkingRunning)!
  private static let distanceCyclingType = HKObjectType.quantityType(forIdentifier: .distanceCycling)!
  /// C6.5's cadence source. HealthKit has **no running-cadence quantity type**
  /// — the `cycling*` family got one (`.cyclingCadence`), the running family
  /// only ever got stride length, power, speed and the two form metrics — so
  /// unlike Wear OS's ready-made `DataType.STEPS_PER_MINUTE_STATS` the average
  /// and the max are derived here, out of the step count the live builder
  /// collects (`workoutBuilder(_:didCollectDataOf:)`). Not part of
  /// `HKLiveWorkoutDataSource`'s default set for a running configuration
  /// either, hence the explicit `enableCollection(for:predicate:)` in
  /// `startSession(configuration:)`.
  private static let stepCountType = HKObjectType.quantityType(forIdentifier: .stepCount)!

  private override init() {}

  /// `AppDelegate.handle(_:)`'s entry point (docs/40-watch-app-plan.md §4.3)
  /// — starts the real `HKWorkoutSession` off the configuration
  /// `HKHealthStore.startWatchApp(with:)` delivered. `sessionClientId`/
  /// `title` aren't known yet here — HealthKit only hands over the
  /// `HKWorkoutConfiguration`; `PhoneConnector`'s applicationContext fills
  /// those in separately, in whatever order the two arrive.
  func start(configuration: HKWorkoutConfiguration) async {
    guard phase == .idle, HKHealthStore.isHealthDataAvailable() else { return }
    guard await ensureHealthAuthorized() else { return }
    do {
      try await startSession(configuration: configuration)
    } catch {
      // Another app's HKWorkoutSession owns the sensors (docs/40-watch-app-plan.md
      // §5.3, §8.1's Wear-side equivalent). sessionClientId may still be nil
      // at this point if PhoneConnector's context hasn't arrived yet —
      // nothing to report in that case, the phone will simply see no watch
      // activity.
      if let sessionClientId {
        PhoneConnector.shared.sendStartRejected(sessionClientId: sessionClientId)
      }
    }
  }

  /// Entry point for the launcher's "Start workout" / picker's "Quick
  /// strength" **and** synced-template rows (docs/watch/
  /// 44-watch-f6-standalone-plan.md §3.1; docs/watch/
  /// 49-watch-f6b-template-sync-plan.md §3.3, T6) — no `HKWorkoutConfiguration`
  /// from the phone this time, since there's no phone-mastered session to
  /// hang off: the watch builds its own configuration and generates its own
  /// session id. Reuses `startSession(configuration:)`'s HealthKit plumbing
  /// and `start(configuration:)`'s permission gate (§7: "ez az egyetlen
  /// kérési pont" — standalone has no prior phone onboarding to have
  /// already asked).
  ///
  /// [template] defaults to `nil` (Quick strength, F6a's original single
  /// call site unaffected); non-nil is `StandalonePickerView`'s already-read
  /// picker snapshot handed straight through — this function never itself
  /// reads `StandaloneSessionStore.shared.quickStartEntries()`, so "which
  /// template" is decided exactly once, at the tap, not re-resolved here.
  ///
  /// [activityType] is `StandalonePickerView`'s `CardioRow` tap (docs/cardio/
  /// 55-cardio-watch-plan.md §5, W-8, C5.7b) — mutually exclusive with
  /// [template] (a cardio row has no plan behind it, `WatchQuickStartEntry
  /// .cardio` carries no `exercises`), so both default `nil` for the two
  /// pre-cardio call sites (Quick strength, a template row) and this
  /// function never receives both at once.
  func startStandalone(
    template: CachedTemplate? = nil, activityType: String? = nil, title: String? = nil
  ) async {
    guard phase == .idle, HKHealthStore.isHealthDataAvailable() else { return }
    guard await ensureHealthAuthorized() else { return }

    let configuration = HKWorkoutConfiguration()
    if let activityType {
      configuration.activityType = cardioWorkoutActivityType(for: activityType)
      configuration.locationType = cardioLocationType(for: activityType)
    } else {
      configuration.activityType = .traditionalStrengthTraining
      configuration.locationType = .indoor
    }

    isStandalone = true
    sessionClientId = UUID().uuidString
    standaloneSets = []
    standaloneTemplate = template
    standaloneExerciseIndex = 0
    standaloneExerciseManuallySelected = false
    removedExerciseIndexes = []
    sessionPlanExercises = nil
    // `reset()` clears these too — see this function's own nextSetReps/
    // nextSetWeight comment just below for why that isn't enough on its own.
    sessionKind = activityType != nil ? "CARDIO" : "STRENGTH"
    cardioActivityType = activityType
    // The picker row's own pre-localized name ("Walking"/"Séta") — what
    // `activeHeaderLabel` shows for this session. Without it a watch-started
    // cardio session fell through to the generic `active_header_label`, so a
    // walk announced itself as **STRENGTH** in its own header. Set here, from
    // the tap, rather than looked up: the watch deliberately holds no
    // activity-type dictionary of its own (docs/cardio/55-cardio-watch-plan.md
    // §3.2 — the phone pre-localizes every title it syncs), and this is the
    // same string the row the user tapped was already showing.
    self.title = title
    lastDistanceMeters = nil
    // A leftover prefill from an earlier session in this process would
    // otherwise win over this session's own resolution (see
    // `standalonePrefill`) until the phone adopts this one and pushes a
    // fresh value. `reset()` clears these too; this is the belt to its
    // braces, since `startStandalone` is reachable from `.idle` without a
    // reset having necessarily run in between.
    nextSetReps = nil
    nextSetWeight = nil
    phoneSetsExerciseIndex = nil
    phoneSetsExerciseId = nil
    phoneSetsDone = nil
    phoneSetsTotal = nil
    phoneSetsDonePerExercise = nil

    do {
      try await startSession(configuration: configuration)
    } catch {
      // Another app owns the sensors — unlike `start(configuration:)`,
      // there's no phone waiting on a `sessionClientId` to reject against
      // here, so just fail back to idle silently (a dedicated error state
      // is out of scope for F6a).
      isStandalone = false
      sessionClientId = nil
      standaloneTemplate = nil
      sessionKind = "STRENGTH"
      cardioActivityType = nil
      self.title = nil
      return
    }
    saveActiveSnapshot()
    // Live bridging (docs/watch's watch-phone live-bridging work): ask the
    // phone to join in, right now and **regardless of reachability** — unlike
    // the per-set resends below, which stay gated.
    //
    // `WCSession.isReachable` is false exactly when the phone app isn't
    // running, which is the most ordinary way to start a workout from the
    // wrist: phone in a pocket, app closed. `transferUserInfo` is a *queued*
    // delivery, though — it survives that and lands when the app next runs
    // (`Runner/WatchEventBuffer.swift` covers even a background launch), so
    // there was never a transport reason to hold this one back. Skipping it
    // meant the phone learned nothing about the session until either a
    // reachability change or a logged set happened to re-trigger it, and if
    // neither did, not until the user tapped the badge by hand.
    //
    // Exactly one snapshot is sent this way, at start: that's what makes the
    // session known, and the gated resends keep it fresh from there.
    sendAdoptionRequest()
  }

  /// Decodes the `sessionPlan` JSON string the phone pushes (F6c). A malformed
  /// or absent payload is `nil` — "keep using the cached template" — never a
  /// half-applied list.
  private func decodeSessionPlan(_ json: String?) -> [CachedTemplateExercise]? {
    guard let json, let data = json.data(using: .utf8),
      let plan = try? JSONDecoder().decode(SessionPlan.self, from: data),
      !plan.exercises.isEmpty
    else { return nil }
    return plan.exercises
  }

  /// Swaps in a new session plan, keeping the user on the *same exercise* —
  /// by clientId, not by position (D-F6c.2): the phone can add, remove and
  /// therefore renumber entries, so the index this watch holds means nothing
  /// across the change. Already-logged sets need no such fix-up; they carry
  /// their own `exerciseId`.
  ///
  /// A no-op when the plan hasn't actually changed, so the ordinary state sync
  /// (which carries it every time) costs nothing.
  private func applySessionPlan(_ plan: [CachedTemplateExercise]?) {
    guard plan != sessionPlanExercises else { return }
    let previousExerciseId = standaloneCurrentExerciseId
    sessionPlanExercises = plan
    // Only the standalone path keeps a *position* of its own; a phone-mastered
    // session tracks its exercise by id (`phoneCurrentExerciseId`), which a
    // reordered list can't invalidate.
    guard isStandalone else { return }
    let exercises = activePlanExercises
    guard !exercises.isEmpty else { return }
    if let previousExerciseId,
      let index = exercises.firstIndex(where: { $0.exerciseId == previousExerciseId })
    {
      guard index != standaloneExerciseIndex else { return }
      standaloneExerciseIndex = index
      saveActiveSnapshot()
      return
    }
    // The exercise this watch was on is gone from the session (deleted on the
    // phone), or there was none yet: land on the first one still unfinished,
    // the same destination every other advance picks.
    let next = exercises.indices.first { !standaloneExerciseIsComplete($0) } ?? 0
    guard next != standaloneExerciseIndex || previousExerciseId != nil else { return }
    standaloneExerciseIndex = next
    standaloneExerciseManuallySelected = false
    didAdvanceStandaloneExercise()
  }

  /// The gyakorlat-lista's tap handler (docs/watch/49-watch-f6b-template-sync-plan.md
  /// §3.5, D-F6b.8) — changes only which exercise the *next* logged set
  /// counts against. Never closes a set, starts/skips a rest, or touches a
  /// set already logged — those keep the `exerciseIndex` they were logged
  /// with, permanently (§3.5: "a már logolt szettek exerciseIndex-e
  /// véglegesen az marad"). A no-op outside a template session, for an index
  /// the snapshot doesn't have (nothing to switch to, and the UI that calls
  /// this only ever offers indices that exist), and for the exercise already
  /// selected.
  /// The exercise list's tap handler, whichever mode the session is in
  /// (F6c §7). Standalone keeps its existing path; a phone-mastered session
  /// records the pick locally and tells the phone, which owns the decision and
  /// echoes it back on its next state push.
  func selectExercise(at index: Int) {
    guard index >= 0, index < activePlanExercises.count else { return }
    guard !isStandalone else {
      selectStandaloneExercise(index)
      return
    }
    let exerciseId = activePlanExercises[index].exerciseId
    guard exerciseId != currentExerciseId, let sessionClientId else { return }
    phoneSelectedExerciseId = exerciseId
    // The phone's prefill describes the exercise it still thinks is current —
    // dropping it stops the stepper from opening on that one's numbers while
    // the round trip completes (the same rule the standalone pick follows).
    nextSetReps = nil
    nextSetWeight = nil
    PhoneConnector.shared.sendExerciseSelected(
      sessionClientId: sessionClientId, exerciseId: exerciseId)
  }

  func selectStandaloneExercise(_ index: Int) {
    guard index >= 0, index < activePlanExercises.count,
      index != standaloneExerciseIndex, !standaloneExerciseIsRemoved(index)
    else { return }
    standaloneExerciseIndex = index
    standaloneExerciseManuallySelected = true
    // The phone's pushed prefill describes the exercise the *phone* thinks is
    // current, which this tap just made stale — and `standalonePrefill` takes
    // it ahead of everything else (priority 0). Dropping it here is what makes
    // the "+1" tap and the adjust stepper follow the exercise the user just
    // picked instead of opening on the previous one's numbers; the local
    // fallbacks (the synced template's `previousSets` for *this* exercise,
    // then its last logged set) cover the gap until the phone answers with a
    // fresh one — and cover it entirely when the phone isn't reachable at all.
    nextSetReps = nil
    nextSetWeight = nil
    // A recovered process must come back on the exercise the user sees...
    saveActiveSnapshot()
    // ...and the phone must learn about the switch, or it would keep computing
    // its prefill (and its Live Activity's exercise name) for the exercise it
    // last knew about. The snapshot carries `currentExerciseIndex`, which is
    // exactly what `LogSessionScreen._watchCurrentBlock` resolves against.
    // Wear gets this for free — `ExerciseService` observes the index — but on
    // watchOS nothing but a logged set ever re-sent it.
    sendAdoptionRequestIfNeeded()
  }

  /// Whether the template exercise at [index] has had every set it planned
  /// for. A `targetSets` of nil counts as **one** set rather than "never
  /// complete" — that's what the phone effectively does with a plan-less
  /// exercise (`LogSessionScreen._rebuildBlocks` gives it a single row), and
  /// without it `advanceStandaloneExerciseIfComplete` would bounce back to a
  /// target-less exercise forever.
  private func standaloneExerciseIsComplete(_ index: Int) -> Bool {
    let exercises = activePlanExercises
    guard index >= 0, index < exercises.count else { return false }
    // Removed from the session on the phone — not somewhere to land, so it
    // counts as finished for every "where do we go next" decision.
    if standaloneExerciseIsRemoved(index) { return true }
    return standaloneSetsDone(at: index) >= (exercises[index].targetSets ?? 1)
  }

  /// Whether the phone has removed the plan's [index]-th exercise from this
  /// session — see `removedExerciseIndexes`.
  func standaloneExerciseIsRemoved(_ index: Int) -> Bool {
    // Meaningless once the phone's own plan is what we're listing: those
    // positions are the *template's*, and a plan that has an exercise at all
    // has it because the session still contains it.
    guard sessionPlanExercises == nil else { return false }
    return removedExerciseIndexes.contains(index)
  }

  /// The shared tail of an auto-advance: the prefill the phone pushed
  /// describes the exercise just left behind, the new position has to survive
  /// a process death, and the phone has to be told so its next push (and its
  /// Live Activity) describe the same exercise this watch moved to.
  private func didAdvanceStandaloneExercise() {
    nextSetReps = nil
    nextSetWeight = nil
    saveActiveSnapshot()
    sendAdoptionRequestIfNeeded()
  }

  /// How many sets this session has for the exercise at [index], counting the
  /// ones logged on the phone's mirror screen — see `phoneSetsDone`.
  ///
  /// The larger of the two counts, not the phone's: its copy is at best one
  /// sync behind, so right after a tap on the wrist the watch's own list is
  /// the higher (and correct) one, and taking the phone's would make the
  /// counter visibly jump backwards. The phone's is higher exactly when it
  /// knows about sets this watch never logged, which is the case this exists
  /// for.
  func standaloneSetsDone(at index: Int) -> Int {
    let exercises = activePlanExercises
    let exerciseId = index >= 0 && index < exercises.count ? exercises[index].exerciseId : nil
    // Id-first, position as the fallback: a set logged before the phone's plan
    // arrived (or by a pre-F6c build) carries only its position.
    var best = standaloneSets.filter {
      if let setId = $0.exerciseId, let exerciseId { return setId == exerciseId }
      return $0.exerciseIndex == index
    }.count
    // The phone's own count for this exercise. From its session plan it comes
    // keyed by id; the positional list is the template-space fallback and must
    // not be read once the plan is what we're listing.
    if index >= 0, index < exercises.count, let planSetsDone = exercises[index].setsDone {
      best = max(best, planSetsDone)
    }
    if sessionPlanExercises == nil, let phoneSetsDonePerExercise, index >= 0,
      index < phoneSetsDonePerExercise.count
    {
      best = max(best, phoneSetsDonePerExercise[index])
    }
    // The single-exercise value can be a sync fresher than the array (it is
    // recomputed for the exercise this watch named), so it still gets a look in.
    if let phoneSetsExerciseId, phoneSetsExerciseId == exerciseId, let phoneSetsDone {
      best = max(best, phoneSetsDone)
    } else if phoneSetsExerciseId == nil, index == phoneSetsExerciseIndex, let phoneSetsDone {
      best = max(best, phoneSetsDone)
    }
    return best
  }

  /// Moves `standaloneExerciseIndex` on once the current exercise has all the
  /// sets its plan asked for, so a tap after "Set 2 of 2" starts the *next*
  /// exercise instead of piling a third set onto the finished one — the
  /// watch-standalone counterpart of what the phone-mastered path has always
  /// done (`selectWatchSetLogTarget`'s rule (b): the first block with a
  /// not-done row). Same destination rule as that function, deliberately:
  /// the first incomplete exercise scanning from the top, not simply
  /// `index + 1`, so an exercise skipped or left half-finished earlier is
  /// picked back up rather than stranded.
  ///
  /// Only ever fires right after a set is logged, so a manual pick from the
  /// exercise list (`selectStandaloneExercise`) still holds for as long as
  /// that exercise has sets left. No-op outside a template session (nothing
  /// to advance through), when the current exercise has no `targetSets` (no
  /// way to know it's finished), and when every exercise is complete — that
  /// last case keeps logging into the current one, matching
  /// `selectWatchSetLogTarget`'s own rule (c).
  /// Returns whether it actually moved on, so a caller that isn't already
  /// persisting/publishing the session can do so — [beginLocalLogSet] does
  /// both right after this anyway, the phone-driven call site in
  /// `applyStateUpdate` doesn't.
  @discardableResult
  private func advanceStandaloneExerciseIfComplete() -> Bool {
    let exercises = activePlanExercises
    guard !exercises.isEmpty else { return false }
    // The `targetSets` requirement is what keeps a plan-less exercise from
    // being declared finished after one set — but a *removed* one has to be
    // left regardless, target or no target.
    guard standaloneExerciseIsRemoved(standaloneExerciseIndex)
      || (standaloneCurrentExercise?.targetSets != nil
        && standaloneExerciseIsComplete(standaloneExerciseIndex))
    else { return false }
    for index in exercises.indices where !standaloneExerciseIsComplete(index) {
      guard index != standaloneExerciseIndex else { return false }
      standaloneExerciseIndex = index
      return true
    }
    return false
  }

  /// The exercise the *next* logged set will count against, or `nil` for a
  /// Quick strength session (docs/watch/49-watch-f6b-template-sync-plan.md
  /// §3.3/§3.4) — the safe-indexed lookup every view that needs "what
  /// exercise is this" reads, instead of repeating the bounds check
  /// `selectStandaloneExercise(_:)` already guarantees can't go stale.
  var standaloneCurrentExercise: CachedTemplateExercise? {
    let exercises = activePlanExercises
    guard standaloneExerciseIndex >= 0, standaloneExerciseIndex < exercises.count else { return nil }
    return exercises[standaloneExerciseIndex]
  }

  /// What the *next* standalone set should default to for the current
  /// exercise — the standalone counterpart of the phone-pushed
  /// `nextSetReps`/`nextSetWeight` (docs/watch/48-watch-f5b-set-adjust-plan.md
  /// D-F5b.2), which a phone-less session never receives. Same priority order
  /// the phone uses for its own "+1" prefill
  /// (`LogSessionScreen._handleAddSet`, `StandaloneSessionProcessor
  /// ._resolveWeights`), so a set logged here and the row the phone would
  /// have produced agree:
  ///
  /// 0. what the phone last pushed for this session, once it has adopted it
  ///    (live bridging) — the *same* `watchSetPrefill` computation a
  ///    phone-started session receives, so both paths behave identically,
  ///    which is the whole point. It wins because the phone sees the real
  ///    history and the real row the set will land in; the watch only ever
  ///    approximates that from the cached template. Recomputed and repushed
  ///    after every set the watch logs, so it doesn't lag behind — but it
  ///    does freeze if the phone goes out of range, which is what the
  ///    watch-side fallbacks below are for;
  /// 1. the positional entry from the synced template's `previousSets` — the
  ///    last workout's *n*-th set of this exercise, for the *n*-th set about
  ///    to be logged now;
  /// 2. otherwise the last set already logged for this exercise in *this*
  ///    session (a run of taps stays at the working weight);
  /// 3. otherwise `standaloneDefaultReps` and no weight — a Quick strength
  ///    session with no history, i.e. exactly F6a's original behavior.
  var standalonePrefill: (reps: Int, weight: Double?) {
    if let nextSetReps {
      return (reps: nextSetReps, weight: nextSetWeight)
    }
    let sets = standaloneSetsForCurrentExercise
    if let previousSets = standaloneCurrentExercise?.previousSets, sets.count < previousSets.count {
      let hint = previousSets[sets.count]
      return (reps: hint.reps, weight: hint.weight)
    }
    if let last = sets.last {
      return (reps: last.reps, weight: last.weight)
    }
    return (reps: standaloneDefaultReps, weight: nil)
  }

  /// `standaloneSets` filtered to the *current* exercise only (docs/watch/
  /// 49-watch-f6b-template-sync-plan.md §3.4) — outside a template session
  /// (Quick strength) every set counts as one pool, matching F6a's original
  /// behavior exactly (§3.4's `standaloneTemplate == nil` short-circuit).
  var standaloneSetsForCurrentExercise: [StandaloneSet] {
    guard !activePlanExercises.isEmpty else { return standaloneSets }
    let currentExerciseId = standaloneCurrentExerciseId
    // Id-first, position as the fallback: a set logged before the phone's plan
    // arrived (or by a pre-F6c build) carries only its position.
    return standaloneSets.filter { set in
      if let setExerciseId = set.exerciseId, let currentExerciseId {
        return setExerciseId == currentExerciseId
      }
      return set.exerciseIndex == standaloneExerciseIndex
    }
  }

  /// See [ActiveExerciseDisplay]'s doc comment. Three branches, in priority
  /// order: (1) a template exercise with a `targetSets` falls back to the
  /// exact phone-mastered `setsDone`/`setsTotal` presentation (§3.4: "van
  /// cél-szettszám!"); (2) a template exercise with none uses the
  /// free-format count+reps line, scoped to that exercise's own sets; (3)
  /// Quick strength (no template at all) keeps F6a's original all-sets
  /// free-format behavior unchanged. Phone-mastered sessions fall through
  /// to the final `return`, which reproduces the pre-F6b code exactly —
  /// this getter is a superset, not a behavior change, for that path.
  var activeExerciseDisplay: ActiveExerciseDisplay {
    if let currentExercise = standaloneCurrentExercise {
      let sets = standaloneSetsForCurrentExercise
      // Both counts include what the phone logged into this same session; see
      // `standaloneSetsDone(at:)` and `phoneSetsTotal`.
      let setsDone = standaloneSetsDone(at: standaloneExerciseIndex)
      let phoneCountsThisExercise =
        phoneSetsExerciseId != nil
        ? phoneSetsExerciseId == currentExercise.exerciseId
        : standaloneExerciseIndex == phoneSetsExerciseIndex
      let targetSets = (phoneCountsThisExercise ? phoneSetsTotal : nil) ?? currentExercise.targetSets
      if let targetSets {
        return ActiveExerciseDisplay(
          name: currentExercise.name, setsDone: setsDone, setsTotal: targetSets,
          freeFormatSets: nil)
      }
      // No target to count towards: the set count still includes the phone's,
      // but the rep total can only sum the sets this watch itself logged — it
      // never receives the others' reps.
      return ActiveExerciseDisplay(
        name: currentExercise.name, setsDone: nil, setsTotal: nil,
        freeFormatSets: (setsDone, sets.reduce(0) { $0 + $1.reps }))
    }
    if isStandalone {
      return ActiveExerciseDisplay(
        name: String(localized: "standalone_quick_start"), setsDone: nil, setsTotal: nil,
        freeFormatSets: (standaloneSets.count, standaloneSets.reduce(0) { $0 + $1.reps }))
    }
    return ActiveExerciseDisplay(
      name: exerciseName ?? String(localized: "active_default_exercise"),
      setsDone: setsDone, setsTotal: setsTotal, freeFormatSets: nil)
  }

  /// Shared by `start(configuration:)` (phone-mastered) and
  /// `startStandalone()` — sets `phase = .healthDenied` and returns `false`
  /// if HealthKit sharing is denied or the authorization request itself
  /// fails (§12.1 B10).
  private func ensureHealthAuthorized() async -> Bool {
    do {
      try await requestAuthorizationIfNeeded()
    } catch {
      // The authorization *request* itself failed (rare) — treat the same
      // as an explicit denial (§12.1 B10).
      phase = .healthDenied
      return false
    }
    // Read-type denials are invisible by design (HealthKit's privacy model
    // never reveals whether READ was granted), but workoutType is a *share*
    // type, so its status is queryable — and a session that can't save a
    // workout shouldn't silently run one (§12.1 B10, replacing the earlier
    // "just falls back to Idle" behavior noted in the doc's §9 test matrix).
    guard store.authorizationStatus(for: HKObjectType.workoutType()) != .sharingDenied else {
      phase = .healthDenied
      return false
    }
    return true
  }

  /// The distance and step-count types are here for the same reason the heart
  /// rate and energy ones are: `HKLiveWorkoutBuilder.statistics(for:)` reads
  /// collected samples back, and HealthKit answers a never-requested read type
  /// with silence, not an error — so a type missing from this set doesn't fail
  /// loudly, it just makes the corresponding summary field permanently nil
  /// (docs/cardio/59-cardio-implementation-plan.md §11's "néma hiba" class).
  /// `stepCountType` is C6.5's addition; the two distance types back C5.7b's
  /// `cardioSummaryPayload()` distance, which this build had been collecting
  /// without ever asking to read.
  private func requestAuthorizationIfNeeded() async throws {
    let typesToShare: Set<HKSampleType> = [HKObjectType.workoutType()]
    let typesToRead: Set<HKObjectType> = [
      Self.heartRateType, Self.activeEnergyType, Self.distanceWalkingRunningType,
      Self.distanceCyclingType, Self.stepCountType,
    ]
    try await store.requestAuthorization(toShare: typesToShare, read: typesToRead)
  }

  /// The "Review access" button's dismissal (docs/40-watch-app-plan.md
  /// §12.1 B10) — watchOS has no public API to deep-link into the Health
  /// permission settings, so this is the "minimum: instruction + dismiss →
  /// IDLE" the 42-doc's D1.2/W5 settled on.
  func dismissError() {
    phase = .idle
  }

  private func startSession(configuration: HKWorkoutConfiguration) async throws {
    let session = try HKWorkoutSession(healthStore: store, configuration: configuration)
    let builder = session.associatedWorkoutBuilder()
    let dataSource = HKLiveWorkoutDataSource(
      healthStore: store, workoutConfiguration: configuration)
    // C6.5 — the one place both entry points (`start(configuration:)`'s
    // phone-mastered session and `startStandalone`'s watch-started one) pass
    // through, so the cadence decision and its accumulators are made exactly
    // once per session, off the configuration rather than off
    // `cardioActivityType` (which is still nil here for a phone-mastered
    // session — `PhoneConnector`'s context can arrive after this runs).
    if configuration.activityType == .running {
      dataSource.enableCollection(for: Self.stepCountType, predicate: nil)
    }
    builder.dataSource = dataSource
    session.delegate = self
    builder.delegate = self

    let now = Date()
    session.startActivity(with: now)
    try await builder.beginCollection(at: now)

    self.session = session
    self.builder = builder
    self.startedAt = now
    startCadenceCollection(enabled: configuration.activityType == .running, from: now, steps: 0)
    self.phase = .active
    notifyStartedOnWatchIfNeeded()
  }

  /// Tells the phone the watch's own session is actually measuring now
  /// (docs/40-watch-app-plan.md §12.4 B14) — the first time both `phase ==
  /// .active` and `sessionClientId` are known, since either can arrive first
  /// (`startSession()`'s HealthKit callback vs. `PhoneConnector`'s
  /// applicationContext race, see `start(configuration:)`'s doc comment).
  /// Guarded by `notifiedStartedOnWatchFor` so repeated state syncs don't
  /// resend it. Never fires for a standalone session — there's no
  /// phone-mastered session waiting on this signal (docs/watch/
  /// 44-watch-f6-standalone-plan.md §3.1).
  private func notifyStartedOnWatchIfNeeded() {
    guard !isStandalone, phase == .active, let sessionClientId,
      notifiedStartedOnWatchFor != sessionClientId
    else { return }
    notifiedStartedOnWatchFor = sessionClientId
    PhoneConnector.shared.sendStartedOnWatch(sessionClientId: sessionClientId)
  }

  /// Applied whenever a start/state message or applicationContext arrives
  /// from `PhoneConnector` (docs/40-watch-app-plan.md §D2, mirrors Android's
  /// `SessionStateHolder.onStateSynced`). Doesn't clear
  /// `title`/`exerciseName`/`setsDone`/`setsTotal` when the new payload
  /// didn't include them. `restDeadlineUptime`/`restTotalSeconds` are the
  /// exception — always overwritten (including to nil), since a null is
  /// indistinguishable on the wire from "key absent" once
  /// `WatchBridge.swift` strips nulls for property-list compatibility, and
  /// the rest timer toggles constantly within a single session.
  ///
  /// `restRemainingSeconds` is the phone's own "seconds left" at the moment
  /// it built the payload, converted here into `restDeadlineUptime` by
  /// adding it to this device's own `ProcessInfo.systemUptime` — see that
  /// property's doc comment for why this device's own clock is used instead
  /// of the phone's absolute `restEndsAtEpochMs` epoch target.
  func applyStateUpdate(
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
    setsDoneExerciseId: String?,
    setsDonePerExercise: [Int]?,
    removedExerciseIndexes: [Int]?,
    sessionPlan: String?,
    kind: String?,
    activityType: String?,
    cardio: CardioActiveMetrics?
  ) {
    guard !isStandalone else {
      // A *different* session's state can't touch the watch's own standalone
      // one (docs/watch/44-watch-f6-standalone-plan.md D-F6.2) — that's a
      // phone trying to start while standalone is active, rejected the same
      // way the existing "another app owns the sensors" conflict is (§5.3).
      if sessionClientId != self.sessionClientId {
        PhoneConnector.shared.sendStartRejected(sessionClientId: sessionClientId)
        return
      }
      // Which plan positions the phone's copy of this session no longer has
      // (§ the exercise list hides them, `standaloneExerciseIsComplete` never
      // lands on them). Applied before everything below, so the same payload's
      // advance decision already sees it.
      self.removedExerciseIndexes = Set(removedExerciseIndexes ?? [])
      // F6c: the phone's own exercise list for this session, which replaces
      // the cached template as what this watch lists and logs against. Applied
      // first, so everything below already judges against the new list.
      applySessionPlan(decodeSessionPlan(sessionPlan))
      // Matching id = the phone's live mirror of *this* session (live
      // bridging), pushing state for the workout the watch is running. Take
      // the prefill: those two fields are the phone answering "what should
      // the next set default to", which the watch cannot compute as well as
      // the phone can (it holds the full history) — and taking them here is
      // what finally makes a watch-started session prefill exactly like a
      // phone-started one.
      //
      // But only when it is answering about the exercise this watch is
      // actually on. `setsDoneExerciseIndex` is the phone echoing back the
      // index it computed everything in this payload for (nil in a
      // template-less Quick strength session, where there is no index to
      // disagree about) — a mismatch means the payload was built before the
      // phone learned about a hand-picked exercise, and applying it would open
      // the stepper on another exercise's numbers. Cleared rather than kept in
      // that case: a stale value is about the wrong exercise too, and
      // `standalonePrefill`'s local fallbacks answer for the right one.
      // Id-first (F6c): a position only means the same thing on both sides
      // while the list can't change, which is exactly what the session plan
      // undoes. Both sides carry the id whenever they can — a template's
      // `exerciseId` *is* the exercise's clientId — so this is the normal
      // route, and the index comparison is the pre-F6c fallback.
      let currentExerciseId = standaloneCurrentExerciseId
      let prefillDescribesCurrentExercise: Bool
      if let setsDoneExerciseId, let currentExerciseId {
        prefillDescribesCurrentExercise = setsDoneExerciseId == currentExerciseId
      } else {
        prefillDescribesCurrentExercise =
          setsDoneExerciseIndex == standaloneExerciseIndex
          || (setsDoneExerciseIndex == nil && standaloneTemplate == nil)
      }
      self.nextSetReps = prefillDescribesCurrentExercise ? nextSetReps : nil
      self.nextSetWeight = prefillDescribesCurrentExercise ? nextSetWeight : nil
      // And the set counts, but only when the phone says which exercise they
      // are about *and* it's the one this watch is logging into. The phone's
      // row is the only place both sides' sets meet (its mirror screen stays
      // editable), so this is the one thing it genuinely knows better —
      // unlike `exerciseName` and the rest timer, which describe the session
      // the watch itself drives and stay watch-owned. `standaloneSetsDone(at:)`
      // is what reconciles the phone's number with this watch's own.
      // Index-keyed, so unlike the pair below it needs no agreement about
      // which exercise is current — it describes all of them.
      phoneSetsDonePerExercise = setsDonePerExercise
      if prefillDescribesCurrentExercise {
        phoneSetsExerciseIndex = setsDoneExerciseIndex
        phoneSetsExerciseId = setsDoneExerciseId
        phoneSetsDone = setsDone
        phoneSetsTotal = setsTotal
        // A set logged on the phone can be the one that completes this
        // exercise, and until now only a tap on the wrist ever re-evaluated
        // that (`beginLocalLogSet`) — so the watch sat on a finished exercise
        // offering to add yet another set to it. Now that the count includes
        // the phone's sets, the same rule can run here — except right after a
        // hand-picked exercise (see `standaloneExerciseManuallySelected`),
        // which this would otherwise undo before the user got to log into it.
        if !standaloneExerciseManuallySelected, advanceStandaloneExerciseIfComplete() {
          didAdvanceStandaloneExercise()
        }
      } else {
        phoneSetsExerciseIndex = nil
        phoneSetsExerciseId = nil
        phoneSetsDone = nil
        phoneSetsTotal = nil
      }
      // The exercise this watch is standing on was removed from the session on
      // the phone: leave it whatever else this payload said. Deliberately
      // outside the branch above (the phone reports no `setsDoneExerciseIndex`
      // for an exercise its session no longer contains, so that branch never
      // runs for exactly this case) and deliberately ignoring
      // `standaloneExerciseManuallySelected` — a hand-picked exercise that has
      // since been deleted is not somewhere to keep the user.
      if standaloneExerciseIsRemoved(standaloneExerciseIndex),
        advanceStandaloneExerciseIfComplete()
      {
        didAdvanceStandaloneExercise()
      }
      return
    }
    // F6c §7: the phone's exercise list and its current exercise reach a
    // phone-mastered session too now — that's what its own picker lists, and
    // what tells this watch when the phone has moved on by itself.
    applySessionPlan(decodeSessionPlan(sessionPlan))
    self.phoneCurrentExerciseId = setsDoneExerciseId ?? self.phoneCurrentExerciseId
    // The local pick has served its purpose once the phone reports the same
    // exercise — or a different one the user has since chosen *there*, which
    // is the more recent instruction either way.
    if let setsDoneExerciseId, setsDoneExerciseId == phoneSelectedExerciseId {
      phoneSelectedExerciseId = nil
    }
    self.sessionClientId = sessionClientId
    self.title = title ?? self.title
    self.exerciseName = exerciseName ?? self.exerciseName
    self.setsDone = setsDone ?? self.setsDone
    self.setsTotal = setsTotal ?? self.setsTotal
    self.restDeadlineUptime = restRemainingSeconds.map { ProcessInfo.processInfo.systemUptime + Double($0) }
    self.restTotalSeconds = restTotalSeconds
    // Always overwritten, including to nil — like the rest fields above and
    // for the same reason: the phone recomputes the prefill on every sync,
    // and "no prefill any more" is a real state that must be able to clear
    // a stale one (docs/watch/48-watch-f5b-set-adjust-plan.md D-F5b.2).
    self.nextSetReps = nextSetReps
    self.nextSetWeight = nextSetWeight
    // Always overwritten, like the rest fields above — `kind` is never
    // actually absent on a real push (`WorkoutSessionState.toJson()` always
    // includes it, defaulted to `'STRENGTH'` Dart-side), so `?? self.sessionKind`
    // is purely defensive against a malformed/ancient payload, not something
    // that fires in practice. `cardioMetrics` in particular must be able to
    // go back to `nil` — a stale distance/heart-rate-adjacent reading left
    // on screen after the phone stops sending it would be actively
    // misleading (docs/cardio/59-cardio-implementation-plan.md §11's "néma
    // hiba" class).
    self.sessionKind = kind ?? self.sessionKind
    self.cardioActivityType = activityType ?? self.cardioActivityType
    self.cardioMetrics = cardio
    notifyStartedOnWatchIfNeeded()
  }

  // MARK: - Log-set (docs/watch/43-watch-f5-set-logging-plan.md §3.2)

  /// The "+1 set" control's entry point. Gated on `phase == .active` only —
  /// the log page doesn't exist outside `.active` at all (docs/watch/
  /// 43-watch-f5-set-logging-plan.md §3.3), but stays reachable and the
  /// button stays enabled through rest and pause, both of which leave
  /// `phase` at `.active` (pause only touches the sensor session, §3.3).
  /// [reps]/[weight] are the adjust stepper's values when the tap came
  /// through it (docs/watch/48-watch-f5b-set-adjust-plan.md §4.1); both nil
  /// for a plain one-tap log, which keeps F5a's behaviour bit for bit.
  func logSet(reps: Int? = nil, weight: Double? = nil) {
    guard phase == .active, let sessionClientId, logSetState == .ready else { return }
    // F6 (docs/watch/44-watch-f6-standalone-plan.md §2.1) local-mode branch:
    // confirms immediately instead of going through PhoneConnector — kept
    // as this single branch point rather than scattered UI `if`s.
    if isStandalone {
      beginLocalLogSet(reps: reps, weight: weight)
    } else {
      beginRemoteLogSet(
        sessionClientId: sessionClientId, eventId: UUID().uuidString, reps: reps, weight: weight,
        exerciseId: currentExerciseId)
    }
  }

  /// The standalone local-mode branch (docs/watch/44-watch-f6-standalone-plan.md
  /// §2.1, §3.2) — no PENDING/ack round-trip: this tap's set *is* the record
  /// (there's no phone to confirm against), so it's appended and CONFIRMED
  /// immediately, and a fixed-length local rest starts right away. [reps]/
  /// [weight] mirror `beginRemoteLogSet`'s own parameters — nil for a plain
  /// one-tap log (falls back to `standaloneDefaultReps`/no weight), set when
  /// the F5b adjust stepper was used instead.
  private func beginLocalLogSet(reps: Int? = nil, weight: Double? = nil) {
    let now = Date()
    // A plain tap takes whatever `standalonePrefill` resolved (last
    // workout's matching set, or this session's working weight) instead of
    // the bare `standaloneDefaultReps`/no-weight it used to log — that's
    // what made every "+1" set land on the phone as 0 kg.
    let prefill = standalonePrefill
    standaloneSets.append(
      StandaloneSet(
        loggedAtEpochMs: Int64(now.timeIntervalSince1970 * 1000),
        reps: reps ?? prefill.reps,
        weight: weight ?? prefill.weight,
        // nil outside a template session, matching F6a's original
        // behavior exactly; the current gyakorlat-lista selection
        // otherwise (docs/watch/49-watch-f6b-template-sync-plan.md §3.3).
        exerciseIndex: activePlanExercises.isEmpty ? nil : standaloneExerciseIndex,
        exerciseId: standaloneCurrentExerciseId))
    // The hand-picked exercise has now been logged into, which is all its
    // stickiness was ever for — from here the normal auto-advance decides.
    standaloneExerciseManuallySelected = false
    // Before the snapshot save below, so a session recovered after process
    // death comes back pointing at the same exercise the user would see now.
    if advanceStandaloneExerciseIfComplete() {
      // The phone's prefill was computed for the exercise this set finished —
      // the next tap is a different exercise's first set, so the local
      // fallbacks answer for it until the phone's fresh value lands (the
      // adoption re-send below is what asks for it).
      nextSetReps = nil
      nextSetWeight = nil
    }
    saveActiveSnapshot()
    // Live bridging: keeps an already-adopted phone mirror in sync with
    // every set as it's logged, not just at start/end — a no-op if the
    // phone isn't reachable right now, retried the next time it is (see
    // `sendAdoptionRequestIfNeeded`'s own doc comment).
    sendAdoptionRequestIfNeeded()

    logSetState = .confirmed
    WKInterfaceDevice.current().play(.success)
    scheduleLogSetSettle(after: logSetConfirmedSettleSeconds)

    let restSeconds = currentStandaloneRestSeconds
    restDeadlineUptime = ProcessInfo.processInfo.systemUptime + restSeconds
    restTotalSeconds = Int(restSeconds)
  }

  /// The rest length for whichever exercise `standaloneExerciseIndex`
  /// currently points at (docs/watch/49-watch-f6b-template-sync-plan.md
  /// §3.3) — the synced, already-resolved `restSeconds` (D-F6b.4) when
  /// running from a template, the fixed `standaloneRestSeconds` default
  /// otherwise (44-doc §3.5), or defensively if the index is somehow out of
  /// range (shouldn't happen — `selectStandaloneExercise` itself validates
  /// it before ever setting it).
  private var currentStandaloneRestSeconds: TimeInterval {
    guard let exercise = standaloneCurrentExercise else { return standaloneRestSeconds }
    return TimeInterval(exercise.restSeconds)
  }

  private func beginRemoteLogSet(
    sessionClientId: String, eventId: String, reps: Int? = nil, weight: Double? = nil,
    exerciseId: String? = nil
  ) {
    logSetState = .pending(eventId)
    let loggedAtEpochMs = Int64(Date().timeIntervalSince1970 * 1000)
    PhoneConnector.shared.sendLogSet(
      sessionClientId: sessionClientId, eventId: eventId, loggedAtEpochMs: loggedAtEpochMs,
      reps: reps, weight: weight, exerciseId: exerciseId)

    logSetTimeoutTask?.cancel()
    logSetTimeoutTask = Task {
      try? await Task.sleep(nanoseconds: UInt64(logSetAckTimeoutSeconds * 1_000_000_000))
      guard !Task.isCancelled, case .pending(let pendingEventId) = logSetState,
        pendingEventId == eventId
      else { return }
      failLogSet()
    }
  }

  /// Called by `PhoneConnector` on a `logSetAck` reply
  /// (docs/watch/43-watch-f5-set-logging-plan.md §4.3). Only acts when
  /// [eventId] matches the currently-pending tap — a late ack for a tap
  /// that already timed out (and thus already settled back to `.ready`) is
  /// a no-op, not a resurrection of stale state.
  func applyLogSetAck(eventId: String, accepted: Bool) {
    guard case .pending(let pendingEventId) = logSetState, pendingEventId == eventId else { return }
    logSetTimeoutTask?.cancel()
    logSetTimeoutTask = nil
    if accepted {
      logSetState = .confirmed
      WKInterfaceDevice.current().play(.success)
      scheduleLogSetSettle(after: logSetConfirmedSettleSeconds)
    } else {
      failLogSet()
    }
  }

  private func failLogSet() {
    logSetState = .failed
    WKInterfaceDevice.current().play(.failure)
    scheduleLogSetSettle(after: logSetFailedSettleSeconds)
  }

  /// Called by `PhoneConnector` on every `sessionReachabilityDidChange` (and
  /// once right after activation, for the initial value) — see
  /// `isPhoneReachable`.
  func applyReachabilityChanged(_ reachable: Bool) {
    isPhoneReachable = reachable
  }

  /// Falls `.confirmed`/`.failed` back to `.ready` on its own after
  /// [seconds] — mirrors `scheduleSummaryAutoDismiss()`'s cancellable-`Task`
  /// shape. A fresh `logSet()` tap can't race this: `logSet()` requires
  /// `logSetState == .ready`, which only becomes true once this fires.
  private func scheduleLogSetSettle(after seconds: TimeInterval) {
    logSetSettleTask?.cancel()
    logSetSettleTask = Task {
      try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
      guard !Task.isCancelled else { return }
      logSetState = .ready
    }
  }

  // MARK: - Log-set adjust (docs/watch/48-watch-f5b-set-adjust-plan.md §3.1)

  /// Opens the adjust stepper (`LogPage`'s dedicated adjust button, next to
  /// the log control — D-F5b.1). Starts from the phone's prefill for the row a tap would log
  /// into, falling back to a plain default when there's nothing to go on
  /// (D-F5b.2) — standalone sessions have no phone prefill, so they always
  /// take the default (`nextSetReps`/`nextSetWeight` are only ever set by
  /// `applyStateUpdate`, which standalone never receives). Same
  /// `logSetState == .ready` gate the plain tap uses, so a still-pending log
  /// can't be adjusted out from under itself.
  /// Whether a plain one-tap log has any idea what to record.
  ///
  /// For a phone-mastered session that's the prefill the phone publishes on
  /// every state sync (the row's planned values, else this exercise's last
  /// workout at that position, else its last logged set here); standalone
  /// resolves the same chain locally. False means there is genuinely nothing
  /// to go on for this exercise — a first-ever exercise with an empty plan —
  /// and the tap would otherwise record a set with no weight and no reps.
  /// `LogPage` sends the user to the adjust stepper instead, so they dial in
  /// the first values rather than getting an empty row.
  var hasLogSetPrefill: Bool {
    if isStandalone {
      let prefill = standalonePrefill
      return prefill.weight != nil
    }
    return nextSetReps != nil && nextSetWeight != nil
  }

  func beginLogAdjust() {
    guard phase == .active, logSetState == .ready, logAdjustState == nil else {
      return
    }
    // Standalone has no phone prefill to read (`nextSetReps`/`nextSetWeight`
    // are only ever set by `applyStateUpdate`), so it resolves its own from
    // the synced template's history — see `standalonePrefill`. Before this,
    // the stepper always opened on 10 reps / 0 kg in standalone, which is
    // the "nincs töltve az előző edzés számaival" report.
    let prefill = isStandalone ? standalonePrefill : nil
    logAdjustState = LogAdjustState(
      reps: prefill?.reps ?? nextSetReps ?? logAdjustDefaultReps,
      weight: prefill?.weight ?? nextSetWeight ?? logAdjustDefaultWeight,
      field: .reps)
    scheduleLogAdjustIdleDismiss()
  }

  /// One crown detent = one step of the active field (D-F5b.5). [steps] is
  /// signed; the platform's own crown acceleration decides how many arrive.
  /// Values are clamped, never wrapped — running off the end of the range
  /// should feel like hitting a stop, not like jumping to the other end.
  ///
  /// The weight step is applied to whatever the prefill was, without snapping
  /// to a 2.5 grid: a previously logged 61 kg steps to 63.5, not 62.5.
  /// Predictable beats tidy here — snapping would move the value by an
  /// unrequested amount on the very first detent.
  func stepLogAdjust(by steps: Int) {
    guard var state = logAdjustState, steps != 0 else { return }
    switch state.field {
    case .reps:
      let stepped = state.reps + steps * logAdjustRepsStep
      state.reps = min(max(stepped, logAdjustRepsBounds.lowerBound), logAdjustRepsBounds.upperBound)
    case .weight:
      let stepped = state.weight + Double(steps) * logAdjustWeightStep
      state.weight = min(
        max(stepped, logAdjustWeightBounds.lowerBound), logAdjustWeightBounds.upperBound)
    }
    logAdjustState = state
    scheduleLogAdjustIdleDismiss()
  }

  /// Resets the idle-dismiss timer without changing any value — called for a
  /// crown delta too small to round to a whole step, so actively turning the
  /// crown never lets the idle timeout fire out from under the user just
  /// because no individual delta happened to cross a rounding boundary
  /// (D-F5b.7). A no-op once the stepper is already closed.
  func noteLogAdjustActivity() {
    guard logAdjustState != nil else { return }
    scheduleLogAdjustIdleDismiss()
  }

  /// The Reps ⇄ Weight segment tap (0.2).
  func toggleLogAdjustField() {
    guard var state = logAdjustState else { return }
    state.field = state.field == .reps ? .weight : .reps
    logAdjustState = state
    scheduleLogAdjustIdleDismiss()
  }

  /// Closes the stepper **without logging** — the back gesture and the
  /// idle timeout both land here (D-F5b.7).
  func cancelLogAdjust() {
    logAdjustIdleTask?.cancel()
    logAdjustIdleTask = nil
    logAdjustState = nil
  }

  /// The "Log {n} reps" button (0.5): closes the stepper and hands the
  /// values to the normal `logSet()` path, so everything downstream — the
  /// pending/ack lifecycle, the timeout, the haptics — is the code F5a
  /// already ships. No second state machine.
  func confirmLogAdjust() {
    guard let state = logAdjustState else { return }
    cancelLogAdjust()
    logSet(reps: state.reps, weight: state.weight)
  }

  /// Restarted by every interaction, so the timeout measures *idle* time
  /// rather than time-since-open (D-F5b.7).
  private func scheduleLogAdjustIdleDismiss() {
    logAdjustIdleTask?.cancel()
    logAdjustIdleTask = Task {
      try? await Task.sleep(nanoseconds: UInt64(logAdjustIdleDismissSeconds * 1_000_000_000))
      guard !Task.isCancelled else { return }
      logAdjustState = nil
    }
  }

  /// Pause/Resume (docs/40-watch-app-plan.md §12.1 B3) go straight through
  /// the live `HKWorkoutSession` — unlike End (§8.2 decision (b)), this
  /// never involves the phone: only the sensor session pauses, nothing the
  /// phone needs to know about. `isPaused` isn't set here directly; it's
  /// derived from the delegate's state-change callback once HealthKit
  /// actually completes the transition.
  func pause() {
    session?.pause()
  }

  func resume() {
    session?.resume()
  }

  /// The watch's End button shows `EffortSelectorView` over `ActiveWorkoutView`
  /// instead of ending anything right away — `phase` stays `.active` until
  /// the user actually confirms or skips (see `requestEnd(rpe:)`).
  func beginEffortSelection() {
    guard phase == .active else { return }
    showEffortSelector = true
  }

  /// `EffortSelectorView`'s back button — dismisses it without ending the
  /// workout at all, nothing is sent to the phone, `ActiveWorkoutView` just
  /// resumes exactly as it was.
  func cancelEffortSelection() {
    showEffortSelector = false
  }

  /// The watch's End button never closes the session itself — it asks the
  /// phone to, so the phone's finish flow still runs, but only to persist
  /// (docs/40-watch-app-plan.md §8.2 decision (b), §11.1/5): the watch
  /// already collected [rpe] itself via `EffortSelectorView` (nil if
  /// skipped), so the phone no longer needs to show its own RPE sheet for
  /// this path. `phase` moves to `.ending` right away so `ContentView` shows
  /// the "waiting for phone" screen (§12.1 B8) — the session only actually
  /// ends once the real `end` command comes back, via `finishAndSendSummary()`.
  /// Standalone (docs/watch/44-watch-f6-standalone-plan.md §3.1) skips the
  /// phone round-trip entirely — no `.ending` phase (nothing to wait for),
  /// straight to `endStandalone(rpe:)`. The effort-selector UI itself is
  /// unchanged/shared between both modes (§11's decision to reuse it here).
  func requestEnd(rpe: Int?) {
    guard phase == .active, let sessionClientId else { return }
    showEffortSelector = false
    if isStandalone {
      Task { await endStandalone(rpe: rpe) }
    } else {
      phase = .ending
      PhoneConnector.shared.sendEndRequested(sessionClientId: sessionClientId, rpe: rpe)
    }
  }

  /// The standalone counterpart of `finishAndSendSummary()` (docs/watch/
  /// 44-watch-f6-standalone-plan.md §3.1, §4.1) — the watch closes its own
  /// `HKWorkoutSession` right away (no phone to wait for) and queues the
  /// finished session for delivery instead of sending a live `sendSummary`.
  func endStandalone(rpe: Int?) async {
    guard phase == .active, isStandalone, let session, let builder, let sessionClientId,
      let startedAt
    else { return }
    session.end()

    let averageHeartRate = builder.statistics(for: Self.heartRateType)?
      .averageQuantity()?.doubleValue(for: HKUnit(from: "count/min"))
    let activeCaloriesTotal = builder.statistics(for: Self.activeEnergyType)?
      .sumQuantity()?.doubleValue(for: .kilocalorie())
    let endedAt = Date()

    var healthWorkoutId: String?
    do {
      try await builder.endCollection(at: endedAt)
      let workout = try await builder.finishWorkout()
      healthWorkoutId = workout?.uuid.uuidString
    } catch {
      // Best-effort, same as finishAndSendSummary() — the payload still
      // queues with whatever metrics were collected.
    }

    let payload = StandaloneSessionPayload(
      standaloneSessionId: sessionClientId,
      templateId: standaloneTemplate?.templateId,
      startedAtEpochMs: Int64(startedAt.timeIntervalSince1970 * 1000),
      endedAtEpochMs: Int64(endedAt.timeIntervalSince1970 * 1000),
      rpe: rpe,
      sets: standaloneSets,
      activeCalories: activeCaloriesTotal,
      averageHeartRate: averageHeartRate,
      healthWorkoutId: healthWorkoutId,
      // `movingSeconds` deliberately omitted, mirroring C5.7a's Wear OS
      // choice — the phone recomputes it from `endedAtEpochMs -
      // startedAtEpochMs` on its own (docs/cardio/
      // 59-cardio-implementation-plan.md's C5.7a note).
      kind: isCardio ? "CARDIO" : nil,
      activityType: cardioActivityType,
      cardio: cardioSummaryPayload())
    StandaloneSessionStore.shared.append(payload)
    StandaloneSessionStore.shared.clearActive()
    PhoneConnector.shared.flushPendingStandaloneSessions()
    // A **cardio** session the phone has joined is running on both devices:
    // the phone opened its own `CardioSessionScreen` for it and is measuring
    // GPS. Ending on the wrist has to stop that too, or the phone keeps
    // tracking a workout that is over and eventually writes its own, later
    // finish over the row this watch just closed. The queued payload above
    // is the durable half; this is the live half, and the phone's screen
    // already handles it (`WatchEndRequested`) exactly as it does for a
    // phone-mastered session.
    //
    // Strength is deliberately left out: the phone's mirror screen isn't
    // measuring anything, and its row is finished by the payload itself
    // (`_finishAdoptedSession`) — asking it to finish *as well* would be a
    // second, racing writer for no gain.
    if isAdopted, isCardio {
      PhoneConnector.shared.sendEndRequested(sessionClientId: sessionClientId, rpe: rpe)
    }

    let setsCount = standaloneSets.count
    let totalDuration = endedAt.timeIntervalSince(startedAt)
    reset()
    phase = .summary(
      WorkoutSummaryData(
        totalDuration: totalDuration,
        averageHeartRate: averageHeartRate,
        activeCalories: activeCaloriesTotal,
        savedToHealth: healthWorkoutId != nil,
        setsCount: setsCount,
        standaloneSessionId: payload.standaloneSessionId))
    scheduleSummaryAutoDismiss()
  }

  // MARK: - Live bridging (watch-started session adopted by the phone)

  /// Sends a running-session snapshot so the phone can create (before
  /// `isAdopted`) or update (after) its live mirror row — called right after
  /// a standalone session starts, on every reachability-regain transition
  /// (`PhoneConnector.sessionReachabilityDidChange`), and after every locally
  /// logged set (`beginLocalLogSet`), so the phone's mirror never goes stale
  /// waiting for the workout to end. Deliberately **not** gated on
  /// `!isAdopted` — once adopted this is what keeps the phone's set list in
  /// sync as new sets land; the phone-side processor merges a resend into
  /// the existing running row rather than duplicating it. Never affects
  /// `logSet()`'s local-vs-remote branch — see `isAdopted`'s doc comment.
  func sendAdoptionRequestIfNeeded() {
    guard isPhoneReachable else { return }
    sendAdoptionRequest()
  }

  /// The user tapping the standalone badge (`HeaderChip`) — "the phone app
  /// wasn't running when I started this; it is now, please catch up".
  ///
  /// Deliberately **not** gated on `isPhoneReachable`, unlike
  /// `sendAdoptionRequestIfNeeded()`: `WCSession.isReachable` is false
  /// exactly when the phone app isn't running, which is the situation this
  /// button exists for. The underlying `transferUserInfo` is a *queued*
  /// delivery — it survives the counterpart app being closed and lands when
  /// it next launches (with `Runner/WatchBridge.swift`'s buffer covering the
  /// case where it arrives before Dart is listening) — so sending anyway is
  /// correct here, where the user has explicitly asked for it, rather than
  /// on every automatic trigger, which would pile up a queue of stale
  /// snapshots against a phone that may be switched off.
  ///
  /// One tap covers everything the phone needs: the same snapshot carries
  /// the session id, its start time and **every set logged so far**, so
  /// `StandaloneSessionProcessor.processAdoption` creates the running mirror
  /// and fills in the already-logged sets in one go.
  func retryAdoption() {
    guard isStandalone, !isRetryingAdoption else { return }
    isRetryingAdoption = true
    WKInterfaceDevice.current().play(.click)
    sendAdoptionRequest()
    adoptionRetryTask?.cancel()
    adoptionRetryTask = Task { [weak self] in
      try? await Task.sleep(nanoseconds: UInt64(adoptionRetryFeedbackSeconds * 1_000_000_000))
      guard !Task.isCancelled else { return }
      self?.isRetryingAdoption = false
    }
  }

  /// Builds and hands the snapshot to `PhoneConnector` — the shared body of
  /// `sendAdoptionRequestIfNeeded()` (automatic, reachability-gated) and
  /// `retryAdoption()` (manual, ungated).
  private func sendAdoptionRequest() {
    guard isStandalone, let sessionClientId, let startedAt else { return }
    let activeCaloriesTotal = builder?.statistics(for: Self.activeEnergyType)?
      .sumQuantity()?.doubleValue(for: .kilocalorie())
    let averageHeartRate = builder?.statistics(for: Self.heartRateType)?
      .averageQuantity()?.doubleValue(for: HKUnit(from: "count/min"))
    let payload = StandaloneAdoptionPayload(
      standaloneSessionId: sessionClientId,
      templateId: standaloneTemplate?.templateId,
      startedAtEpochMs: Int64(startedAt.timeIntervalSince1970 * 1000),
      sets: standaloneSets,
      activeCalories: activeCaloriesTotal,
      averageHeartRate: averageHeartRate,
      // Only meaningful within a plan — see the field's doc comment. The id
      // is what the phone actually resolves against (F6c); the index rides
      // along for a phone build that predates it.
      currentExerciseIndex: activePlanExercises.isEmpty ? nil : standaloneExerciseIndex,
      currentExerciseId: standaloneCurrentExerciseId,
      // What tells the phone which kind of session to join — see
      // `StandaloneAdoptionPayload.kind`. Without it a walk started here
      // became a "Quick strength" workout on the phone.
      kind: isCardio ? "CARDIO" : nil,
      activityType: cardioActivityType)
    PhoneConnector.shared.sendStandaloneAdoption(payload)
  }

  /// Called by `PhoneConnector` on an `adoptionAck` reply — the phone
  /// created (or already had) the live mirror row for [standaloneSessionId].
  /// Guarded against a stale ack for a since-ended/since-replaced session,
  /// same shape as `applyLogSetAck`'s eventId check.
  func applyAdoptionAck(standaloneSessionId: String) {
    guard isStandalone, sessionClientId == standaloneSessionId else { return }
    isAdopted = true
  }

  /// The real end, triggered by `PhoneConnector` once the phone's `end`
  /// command (or its `desiredPhase: "ended"` delivery-guarantee fallback,
  /// docs/40-watch-app-plan.md §3 "Kézbesítési garancia") arrives. Runs from
  /// either `.active` (the delivery-guarantee fallback can arrive before the
  /// watch ever requested an end, e.g. after being unreachable) or
  /// `.ending` (the normal watch-initiated path, §12.1 B8).
  func finishAndSendSummary() async {
    guard phase == .active || phase == .ending, !isStandalone, let session, let builder,
      let sessionClientId, let startedAt
    else { return }
    session.end()

    let averageHeartRate = builder.statistics(for: Self.heartRateType)?
      .averageQuantity()?.doubleValue(for: HKUnit(from: "count/min"))
    let activeCaloriesTotal = builder.statistics(for: Self.activeEnergyType)?
      .sumQuantity()?.doubleValue(for: .kilocalorie())
    let totalDuration = Date().timeIntervalSince(startedAt)

    var healthWorkoutId: String?
    do {
      try await builder.endCollection(at: Date())
      let workout = try await builder.finishWorkout()
      healthWorkoutId = workout?.uuid.uuidString
    } catch {
      // Best-effort — the summary still goes out with whatever metrics were
      // collected, just without a healthWorkoutId.
    }

    PhoneConnector.shared.sendSummary(
      sessionClientId: sessionClientId,
      activeCalories: activeCaloriesTotal,
      averageHeartRate: averageHeartRate,
      healthWorkoutId: healthWorkoutId,
      cardio: cardioSummaryPayload())

    reset()
    phase = .summary(
      WorkoutSummaryData(
        totalDuration: totalDuration,
        averageHeartRate: averageHeartRate,
        activeCalories: activeCaloriesTotal,
        savedToHealth: healthWorkoutId != nil,
        setsCount: nil,
        standaloneSessionId: nil))
    scheduleSummaryAutoDismiss()
  }

  /// Clears the running-session fields but leaves `phase` alone — the
  /// callers each set it themselves right after (`.summary` here,
  /// `endStandalone(rpe:)`, or `.idle` implicitly once
  /// `scheduleSummaryAutoDismiss()`'s timer fires).
  private func reset() {
    session = nil
    builder = nil
    sessionClientId = nil
    notifiedStartedOnWatchFor = nil
    title = nil
    exerciseName = nil
    setsDone = nil
    setsTotal = nil
    restDeadlineUptime = nil
    restTotalSeconds = nil
    nextSetReps = nil
    nextSetWeight = nil
    isPaused = false
    heartRateBpm = nil
    activeCalories = nil
    startedAt = nil
    sessionKind = "STRENGTH"
    cardioActivityType = nil
    cardioMetrics = nil
    lastDistanceMeters = nil
    clearCadenceCollection()
    isStandalone = false
    isAdopted = false
    standaloneSets = []
    standaloneTemplate = nil
    standaloneExerciseIndex = 0
    standaloneExerciseManuallySelected = false
    removedExerciseIndexes = []
    sessionPlanExercises = nil
    phoneCurrentExerciseId = nil
    phoneSelectedExerciseId = nil
    phoneSetsExerciseIndex = nil
    phoneSetsExerciseId = nil
    phoneSetsDone = nil
    phoneSetsTotal = nil
    phoneSetsDonePerExercise = nil
    logSetTimeoutTask?.cancel()
    logSetTimeoutTask = nil
    logSetSettleTask?.cancel()
    logSetSettleTask = nil
    logSetState = .ready
    logAdjustIdleTask?.cancel()
    logAdjustIdleTask = nil
    logAdjustState = nil
    adoptionRetryTask?.cancel()
    adoptionRetryTask = nil
    isRetryingAdoption = false
  }

  /// Overwrites the live standalone session's recovery snapshot — called on
  /// start and after every locally logged set (docs/watch/
  /// 44-watch-f6-standalone-plan.md §3.2).
  private func saveActiveSnapshot() {
    guard isStandalone, let sessionClientId, let startedAt else { return }
    StandaloneSessionStore.shared.saveActive(
      StandaloneActiveSessionMeta(
        standaloneSessionId: sessionClientId,
        template: standaloneTemplate,
        exerciseIndex: standaloneExerciseIndex,
        sessionPlan: sessionPlanExercises,
        startedAtEpochMs: Int64(startedAt.timeIntervalSince1970 * 1000),
        sets: standaloneSets,
        kind: isCardio ? "CARDIO" : nil,
        activityType: cardioActivityType,
        title: title))
  }

  /// Reattaches to a still-running standalone `HKWorkoutSession` after a
  /// process death/reboot (docs/watch/44-watch-f6-standalone-plan.md §3.2)
  /// — called once from `AppDelegate.applicationDidFinishLaunching()`. A
  /// no-op if there's no active session to recover (the normal case) or no
  /// saved meta to resume into.
  func recoverStandaloneSessionIfNeeded() async {
    guard phase == .idle, let recovered = await recoverActiveWorkoutSession(),
      let meta = StandaloneSessionStore.shared.loadActive()
    else { return }

    let recoveredBuilder = recovered.associatedWorkoutBuilder()
    recovered.delegate = self
    recoveredBuilder.delegate = self

    session = recovered
    builder = recoveredBuilder
    isStandalone = true
    sessionClientId = meta.standaloneSessionId
    standaloneTemplate = meta.template
    sessionPlanExercises = meta.sessionPlan
    standaloneExerciseIndex = meta.exerciseIndex
    standaloneSets = meta.sets
    startedAt = Date(timeIntervalSince1970: Double(meta.startedAtEpochMs) / 1000)
    // C5.7b: a recovered cardio session must come back on its own family's
    // screens, not the STRENGTH default `reset()` last left `sessionKind` at
    // — and its distance-so-far has to be re-seeded from the *recovered*
    // `HKLiveWorkoutBuilder`'s own statistics, since that builder already
    // accumulated it before this process died; without this the summary
    // would otherwise read only whatever distance accrues after the
    // recovery, silently understating the session (the same "néma hiba"
    // class docs/cardio/59-cardio-implementation-plan.md §11 keeps flagging).
    sessionKind = meta.kind ?? "STRENGTH"
    cardioActivityType = meta.activityType
    // …and with the name the picker row gave it, or the header would come
    // back reading "STRENGTH" for a recovered walk (see `startStandalone`).
    title = meta.title
    lastDistanceMeters = meta.activityType.flatMap { activityType in
      let family = CardioActivityFamily(activityType: activityType)
      let type: HKQuantityType?
      switch family {
      case .distance: type = Self.distanceWalkingRunningType
      case .machine: type = Self.distanceCyclingType
      case .game: type = nil
      }
      guard let type else { return nil }
      return recoveredBuilder.statistics(for: type)?.sumQuantity()?.doubleValue(for: .meter())
    }
    // C6.5's half of the same re-seeding, for the same reason: the recovered
    // builder kept counting steps while this process was dead, so starting the
    // accumulators at zero would report the cadence of whatever is left of the
    // run rather than of the run. The per-window history is gone with the
    // process, so only the average can be restored — from the cumulative step
    // total over `elapsedTime` (which excludes paused time) — and `maxCadence`
    // starts over from the windows that come after the recovery.
    let recoveredSteps =
      recoveredBuilder.statistics(for: Self.stepCountType)?.sumQuantity()?
      .doubleValue(for: .count()) ?? 0
    startCadenceCollection(
      enabled: meta.activityType == "RUNNING", from: Date(), steps: recoveredSteps,
      seconds: recoveredBuilder.elapsedTime)
    phase = .active
  }

  private func recoverActiveWorkoutSession() async -> HKWorkoutSession? {
    await withCheckedContinuation { continuation in
      store.recoverActiveWorkoutSession { session, _ in
        continuation.resume(returning: session)
      }
    }
  }

  // MARK: - SUMMARY auto-dismiss (docs/40-watch-app-plan.md §12.1 B9)

  private var summaryDismissTask: Task<Void, Never>?

  private func scheduleSummaryAutoDismiss() {
    summaryDismissTask?.cancel()
    summaryDismissTask = Task {
      try? await Task.sleep(nanoseconds: UInt64(summaryAutoDismissSeconds * 1_000_000_000))
      guard !Task.isCancelled else { return }
      phase = .idle
    }
  }

  // MARK: - Pihenő-visszaszámláló haptika (docs/40-watch-app-plan.md §5.4/F4 parity)

  /// Scheduled independently of whichever view is on screen, for as long as
  /// `WorkoutManager` itself lives (i.e. the whole session) — mirrors
  /// Android's `ExerciseService.scheduleRestVibration`, which runs on the
  /// always-alive foreground service rather than the Compose screen.
  private func scheduleRestHaptic() {
    restHapticTask?.cancel()
    guard let restDeadlineUptime else { return }
    let delaySeconds = restDeadlineUptime - ProcessInfo.processInfo.systemUptime
    guard delaySeconds > 0 else { return }
    restHapticTask = Task {
      try? await Task.sleep(nanoseconds: UInt64(delaySeconds * 1_000_000_000))
      guard !Task.isCancelled else { return }
      WKInterfaceDevice.current().play(.notification)
    }
  }
}

// MARK: - HKWorkoutSessionDelegate

extension WorkoutManager: HKWorkoutSessionDelegate {
  /// The authoritative source for `isPaused` (docs/40-watch-app-plan.md
  /// §12.1 B3) — `pause()`/`resume()` only *request* the transition;
  /// this callback fires once HealthKit actually completes it, mirroring
  /// Android's `ExerciseUpdateCallback` reporting `exerciseStateInfo.state.isPaused`
  /// from the system Health Services process rather than from the call site.
  nonisolated func workoutSession(
    _ workoutSession: HKWorkoutSession,
    didChangeTo toState: HKWorkoutSessionState,
    from fromState: HKWorkoutSessionState,
    date: Date
  ) {
    Task { @MainActor in
      self.isPaused = (toState == .paused)
      // C6.5: the open cadence window is measured in wall time, so one that
      // spans a pause would score the standing minutes as very slow running.
      // Dropping it costs at most the last sub-window of steps. Only the two
      // pause transitions themselves — the `.running` one this callback also
      // fires on at `startActivity` would otherwise race
      // `startSession(configuration:)`'s own anchor and throw it away.
      if toState == .paused || fromState == .paused {
        self.resetCadenceWindow()
      }
    }
  }

  nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error)
  {}
}

// MARK: - HKLiveWorkoutBuilderDelegate

extension WorkoutManager: HKLiveWorkoutBuilderDelegate {
  nonisolated func workoutBuilder(
    _ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>
  ) {
    Task { @MainActor in
      for type in collectedTypes {
        guard let quantityType = type as? HKQuantityType,
          let statistics = workoutBuilder.statistics(for: quantityType)
        else { continue }
        switch quantityType {
        case Self.heartRateType:
          heartRateBpm = statistics.mostRecentQuantity()?.doubleValue(for: HKUnit(from: "count/min"))
        case Self.activeEnergyType:
          activeCalories = statistics.sumQuantity()?.doubleValue(for: .kilocalorie())
        case Self.distanceWalkingRunningType, Self.distanceCyclingType:
          lastDistanceMeters = statistics.sumQuantity()?.doubleValue(for: .meter())
        case Self.stepCountType:
          recordCadenceProgress(
            totalSteps: statistics.sumQuantity()?.doubleValue(for: .count()),
            at: statistics.endDate)
        default:
          break
        }
      }
      sendLiveMetricsIfNeeded()
    }
  }

  /// Relays the just-updated `heartRateBpm`/`activeCalories` to the phone
  /// (docs/40-watch-app-plan.md — mirrors Android's `ExerciseService`
  /// forwarding every `ExerciseUpdateCallback` tick). No-ops without a
  /// `sessionClientId` — that only happens before `PhoneConnector`'s
  /// applicationContext has arrived, a narrow startup race also guarded
  /// against elsewhere in this class (see `notifyStartedOnWatchIfNeeded`).
  private func sendLiveMetricsIfNeeded() {
    guard let sessionClientId else { return }
    PhoneConnector.shared.sendLiveMetrics(
      sessionClientId: sessionClientId, heartRateBpm: heartRateBpm, activeCalories: activeCalories)
  }

  nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}
}

// MARK: - Running cadence (docs/cardio/60-cardio-sport-specifics-plan.md C6.5)

/// HealthKit exposes no running-cadence quantity type (see `stepCountType`'s
/// doc comment), so the two numbers Wear OS gets handed by
/// `DataType.STEPS_PER_MINUTE_STATS` are derived here from the workout's own
/// step count, over sliding windows of at least `cadenceWindowSeconds`:
///
/// - **max** is the fastest single window,
/// - **avg** is duration-weighted across every completed window — i.e. total
///   steps over total scored seconds, not the mean of the window rates, so a
///   short window can't count as much as a long one.
///
/// Both stay nil until the first window closes, which is what makes "the watch
/// measured no cadence" a missing key on the wire rather than a zero.
extension WorkoutManager {
  /// Called once per session from `startSession(configuration:)` — and again,
  /// with the recovered totals, from `recoverStandaloneSessionIfNeeded()`.
  /// [steps]/[seconds] seed the accumulators (both 0 for a fresh session),
  /// [from] opens the first window, so no steps fall outside a window at
  /// either end.
  private func startCadenceCollection(
    enabled: Bool, from: Date, steps: Double, seconds: TimeInterval = 0
  ) {
    collectsCadence = enabled
    cadenceSteps = steps
    cadenceSeconds = seconds
    maxCadenceSpm = nil
    guard enabled else {
      cadenceAnchorSteps = nil
      cadenceAnchorAt = nil
      return
    }
    cadenceAnchorSteps = steps
    cadenceAnchorAt = from
  }

  /// Clears everything C6.5 accumulated — `reset()`'s cadence half.
  private func clearCadenceCollection() {
    startCadenceCollection(enabled: false, from: Date(), steps: 0)
  }

  /// Abandons the open window without touching what's already been scored —
  /// the pause/resume handler's tool.
  private func resetCadenceWindow() {
    guard collectsCadence else { return }
    cadenceAnchorSteps = nil
    cadenceAnchorAt = nil
  }

  /// One `didCollectDataOf` tick's cumulative step total, as of [instant]
  /// (`HKStatistics.endDate` — the end of the newest sample, which is a truer
  /// clock for this than `Date()` and its collection latency).
  ///
  /// Closes the open window only once it is long enough to score; until then
  /// the anchor stays put and the window simply keeps growing, so a burst of
  /// ticks a second apart still produces ≥10 s windows rather than ten
  /// quantized ones.
  private func recordCadenceProgress(totalSteps: Double?, at instant: Date) {
    guard collectsCadence, let totalSteps else { return }
    guard let anchorSteps = cadenceAnchorSteps, let anchorAt = cadenceAnchorAt else {
      // First tick after a pause dropped the window (or after a recovery).
      cadenceAnchorSteps = totalSteps
      cadenceAnchorAt = instant
      return
    }
    let seconds = instant.timeIntervalSince(anchorAt)
    guard seconds >= Self.cadenceWindowSeconds else { return }
    // A cumulative total can only grow; a negative delta would mean HealthKit
    // restated the statistics under us, and re-anchoring is the honest answer.
    let steps = totalSteps - anchorSteps
    cadenceAnchorSteps = totalSteps
    cadenceAnchorAt = instant
    guard steps > 0 else { return }
    cadenceSteps += steps
    cadenceSeconds += seconds
    let spm = steps / seconds * 60
    maxCadenceSpm = max(maxCadenceSpm ?? spm, spm)
  }

  /// The session's average cadence, spm — nil when no window ever closed
  /// (a non-running session, or a run shorter than one window).
  private func averageCadenceSpm() -> Double? {
    guard collectsCadence, cadenceSeconds > 0, cadenceSteps > 0 else { return nil }
    return cadenceSteps / cadenceSeconds * 60
  }
}

// MARK: - Local cardio formatting (docs/cardio/55-cardio-watch-plan.md §5, W-8)

/// "5:12" under an hour, "1:05:12" from an hour up — a deliberate
/// transcription of the phone's `CardioFormatter.duration`
/// (`mobile/lib/core/format/cardio_formatter.dart`), so the same walk reads
/// the same on both screens. Separate from `ActiveWorkoutView`'s own
/// `formatSeconds`, which is the rest timer's mm:ss and must stay that way:
/// a 90-minute hike showing "90:00" is exactly the kind of thing this
/// function exists to avoid.
func formatCardioDuration(_ totalSeconds: Int) -> String {
  let hours = totalSeconds / 3600
  let minutes = (totalSeconds % 3600) / 60
  let seconds = totalSeconds % 60
  let ss = String(format: "%02d", seconds)
  if hours > 0 {
    return "\(hours):" + String(format: "%02d", minutes) + ":" + ss
  }
  return "\(minutes):" + ss
}

/// "5.23 km" / "3.25 mi" — `CardioFormatter.distance`, transcribed.
func formatDistance(_ meters: Double, units: WatchUnitSystem) -> String {
  let unitMeters = units == .imperial ? 1609.344 : 1000.0
  let suffix = units == .imperial ? "mi" : "km"
  return String(format: "%.2f %@", meters / unitMeters, suffix)
}

/// "5:12 /km" / "8:22 /mi", or nil with no distance to derive one from —
/// `CardioFormatter.pace`, transcribed (including its "never surface 0:00"
/// rule).
func formatPace(meters: Double, seconds: Int, units: WatchUnitSystem) -> String? {
  guard meters > 0, seconds > 0 else { return nil }
  let unitMeters = units == .imperial ? 1609.344 : 1000.0
  let secondsPerUnit = Double(seconds) / (meters / unitMeters)
  guard secondsPerUnit.isFinite else { return nil }
  let minutes = Int(secondsPerUnit) / 60
  let rest = Int((secondsPerUnit.truncatingRemainder(dividingBy: 60)).rounded())
  let suffix = units == .imperial ? "/mi" : "/km"
  return "\(minutes):" + String(format: "%02d", rest) + " " + suffix
}
