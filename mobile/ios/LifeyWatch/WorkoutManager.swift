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
  /// Which of `standaloneTemplate.exercises` new sets log against — always
  /// 0 and unused outside a template session. Changed only by
  /// `selectStandaloneExercise(_:)` (§3.5's gyakorlat-lista, wired in T7);
  /// never overwritten by anything synced from the phone.
  @Published private(set) var standaloneExerciseIndex = 0

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

  // docs/40-watch-app-plan.md §4.2 — the traditional `quantityType(forIdentifier:)`
  // form rather than the `HKQuantityType(.heartRate)` convenience init, which
  // needs a newer OS than this target's WATCHOS_DEPLOYMENT_TARGET (10.0).
  private static let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate)!
  private static let activeEnergyType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!

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
  /// reads `StandaloneSessionStore.shared.templates()`, so "which template"
  /// is decided exactly once, at the tap, not re-resolved here.
  func startStandalone(template: CachedTemplate? = nil) async {
    guard phase == .idle, HKHealthStore.isHealthDataAvailable() else { return }
    guard await ensureHealthAuthorized() else { return }

    let configuration = HKWorkoutConfiguration()
    configuration.activityType = .traditionalStrengthTraining
    configuration.locationType = .indoor

    isStandalone = true
    sessionClientId = UUID().uuidString
    standaloneSets = []
    standaloneTemplate = template
    standaloneExerciseIndex = 0
    // A leftover prefill from an earlier session in this process would
    // otherwise win over this session's own resolution (see
    // `standalonePrefill`) until the phone adopts this one and pushes a
    // fresh value. `reset()` clears these too; this is the belt to its
    // braces, since `startStandalone` is reachable from `.idle` without a
    // reset having necessarily run in between.
    nextSetReps = nil
    nextSetWeight = nil

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
      return
    }
    saveActiveSnapshot()
    // Live bridging (docs/watch's watch-phone live-bridging work): if the
    // phone is already reachable at the exact moment the session starts,
    // ask it to join in right away. If not, `sessionReachabilityDidChange`
    // retries this the moment the phone reconnects, so a workout started
    // out of range still gets adopted as soon as the phone comes back.
    sendAdoptionRequestIfNeeded()
  }

  /// The gyakorlat-lista's tap handler (docs/watch/49-watch-f6b-template-sync-plan.md
  /// §3.5, D-F6b.8) — changes only which exercise the *next* logged set
  /// counts against. Never closes a set, starts/skips a rest, or touches a
  /// set already logged — those keep the `exerciseIndex` they were logged
  /// with, permanently (§3.5: "a már logolt szettek exerciseIndex-e
  /// véglegesen az marad"). A no-op outside a template session or for an
  /// index the snapshot doesn't have — nothing to switch to, and the UI
  /// that calls this (T7) only ever offers indices that exist.
  func selectStandaloneExercise(_ index: Int) {
    guard let standaloneTemplate, index >= 0, index < standaloneTemplate.exercises.count else { return }
    standaloneExerciseIndex = index
  }

  /// Whether the template exercise at [index] has had every set it planned
  /// for. A `targetSets` of nil counts as **one** set rather than "never
  /// complete" — that's what the phone effectively does with a plan-less
  /// exercise (`LogSessionScreen._rebuildBlocks` gives it a single row), and
  /// without it `advanceStandaloneExerciseIfComplete` would bounce back to a
  /// target-less exercise forever.
  private func standaloneExerciseIsComplete(_ index: Int) -> Bool {
    guard let standaloneTemplate, index < standaloneTemplate.exercises.count else { return false }
    let logged = standaloneSets.filter { $0.exerciseIndex == index }.count
    return logged >= (standaloneTemplate.exercises[index].targetSets ?? 1)
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
  private func advanceStandaloneExerciseIfComplete() {
    guard let standaloneTemplate, standaloneCurrentExercise?.targetSets != nil,
      standaloneExerciseIsComplete(standaloneExerciseIndex)
    else { return }
    for index in standaloneTemplate.exercises.indices where !standaloneExerciseIsComplete(index) {
      standaloneExerciseIndex = index
      return
    }
  }

  /// The exercise the *next* logged set will count against, or `nil` for a
  /// Quick strength session (docs/watch/49-watch-f6b-template-sync-plan.md
  /// §3.3/§3.4) — the safe-indexed lookup every view that needs "what
  /// exercise is this" reads, instead of repeating the bounds check
  /// `selectStandaloneExercise(_:)` already guarantees can't go stale.
  var standaloneCurrentExercise: CachedTemplateExercise? {
    guard let standaloneTemplate, standaloneExerciseIndex < standaloneTemplate.exercises.count else {
      return nil
    }
    return standaloneTemplate.exercises[standaloneExerciseIndex]
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
    guard standaloneTemplate != nil else { return standaloneSets }
    return standaloneSets.filter { $0.exerciseIndex == standaloneExerciseIndex }
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
      if let targetSets = currentExercise.targetSets {
        return ActiveExerciseDisplay(
          name: currentExercise.name, setsDone: sets.count, setsTotal: targetSets, freeFormatSets: nil)
      }
      return ActiveExerciseDisplay(
        name: currentExercise.name, setsDone: nil, setsTotal: nil,
        freeFormatSets: (sets.count, sets.reduce(0) { $0 + $1.reps }))
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

  private func requestAuthorizationIfNeeded() async throws {
    let typesToShare: Set<HKSampleType> = [HKObjectType.workoutType()]
    let typesToRead: Set<HKObjectType> = [Self.heartRateType, Self.activeEnergyType]
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
    builder.dataSource = HKLiveWorkoutDataSource(
      healthStore: store, workoutConfiguration: configuration)
    session.delegate = self
    builder.delegate = self

    let now = Date()
    session.startActivity(with: now)
    try await builder.beginCollection(at: now)

    self.session = session
    self.builder = builder
    self.startedAt = now
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
    nextSetWeight: Double?
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
      // Matching id = the phone's live mirror of *this* session (live
      // bridging), pushing state for the workout the watch is running. Take
      // the prefill and nothing else: those two fields are the phone
      // answering "what should the next set default to", which the watch
      // cannot compute as well as the phone can (it holds the full history)
      // — and taking them here is what finally makes a watch-started session
      // prefill exactly like a phone-started one. Everything else stays
      // watch-owned: `exerciseName`/`setsDone`/`setsTotal` and the rest
      // timer all describe the session the watch itself is driving, and the
      // phone's copy of them is at best a sync behind.
      self.nextSetReps = nextSetReps
      self.nextSetWeight = nextSetWeight
      return
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
        sessionClientId: sessionClientId, eventId: UUID().uuidString, reps: reps, weight: weight)
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
        exerciseIndex: standaloneTemplate != nil ? standaloneExerciseIndex : nil))
    // Before the snapshot save below, so a session recovered after process
    // death comes back pointing at the same exercise the user would see now.
    advanceStandaloneExerciseIfComplete()
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
    guard let standaloneTemplate, standaloneExerciseIndex < standaloneTemplate.exercises.count else {
      return standaloneRestSeconds
    }
    return TimeInterval(standaloneTemplate.exercises[standaloneExerciseIndex].restSeconds)
  }

  private func beginRemoteLogSet(
    sessionClientId: String, eventId: String, reps: Int? = nil, weight: Double? = nil
  ) {
    logSetState = .pending(eventId)
    let loggedAtEpochMs = Int64(Date().timeIntervalSince1970 * 1000)
    PhoneConnector.shared.sendLogSet(
      sessionClientId: sessionClientId, eventId: eventId, loggedAtEpochMs: loggedAtEpochMs,
      reps: reps, weight: weight)

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
      healthWorkoutId: healthWorkoutId)
    StandaloneSessionStore.shared.append(payload)
    StandaloneSessionStore.shared.clearActive()
    PhoneConnector.shared.flushPendingStandaloneSessions()

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
      averageHeartRate: averageHeartRate)
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
      healthWorkoutId: healthWorkoutId)

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
    isStandalone = false
    isAdopted = false
    standaloneSets = []
    standaloneTemplate = nil
    standaloneExerciseIndex = 0
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
        startedAtEpochMs: Int64(startedAt.timeIntervalSince1970 * 1000),
        sets: standaloneSets))
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
    standaloneExerciseIndex = meta.exerciseIndex
    standaloneSets = meta.sets
    startedAt = Date(timeIntervalSince1970: Double(meta.startedAtEpochMs) / 1000)
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
