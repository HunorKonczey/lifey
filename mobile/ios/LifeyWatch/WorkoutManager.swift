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
  /// The standalone session's own set log — the only record of it until
  /// `endStandalone(rpe:)` queues it (docs/watch/44-watch-f6-standalone-plan.md
  /// §3.1). Unused (`[]`) outside standalone mode; phone-mastered sessions
  /// track their set count via `setsDone`/`setsTotal` instead, which the
  /// phone itself owns.
  @Published private(set) var standaloneSets: [StandaloneSet] = []

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
  /// strength" tap (docs/watch/44-watch-f6-standalone-plan.md §3.1) — no
  /// `HKWorkoutConfiguration` from the phone this time, since there's no
  /// phone-mastered session to hang off: the watch builds its own
  /// configuration and generates its own session id. Reuses
  /// `startSession(configuration:)`'s HealthKit plumbing and
  /// `start(configuration:)`'s permission gate (§7: "ez az egyetlen
  /// kérési pont" — standalone has no prior phone onboarding to have
  /// already asked).
  func startStandalone() async {
    guard phase == .idle, HKHealthStore.isHealthDataAvailable() else { return }
    guard await ensureHealthAuthorized() else { return }

    let configuration = HKWorkoutConfiguration()
    configuration.activityType = .traditionalStrengthTraining
    configuration.locationType = .indoor

    isStandalone = true
    sessionClientId = UUID().uuidString
    standaloneSets = []

    do {
      try await startSession(configuration: configuration)
    } catch {
      // Another app owns the sensors — unlike `start(configuration:)`,
      // there's no phone waiting on a `sessionClientId` to reject against
      // here, so just fail back to idle silently (a dedicated error state
      // is out of scope for F6a).
      isStandalone = false
      sessionClientId = nil
      return
    }
    saveActiveSnapshot()
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
      // A phone-mastered session's state can't touch the watch's own
      // standalone session (docs/watch/44-watch-f6-standalone-plan.md
      // D-F6.2). During standalone, `self.sessionClientId` holds the
      // watch's own locally generated id, so any context/state arriving
      // here necessarily belongs to a *different* (phone) session — which
      // doubles as "a phone tried to start while standalone is active",
      // rejected the same way the existing "another app owns the sensors"
      // conflict is (§5.3).
      if sessionClientId != self.sessionClientId {
        PhoneConnector.shared.sendStartRejected(sessionClientId: sessionClientId)
      }
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
      // F5b's values are deliberately *not* threaded into the standalone
      // path: F6a logs a fixed `standaloneDefaultReps` (D-F6.8), and
      // rewiring that is F6b's job (D-F5b.8), not this step's. `beginLogAdjust()`
      // is gated on `!isStandalone` to match, so this branch never sees values.
      beginLocalLogSet()
    } else {
      beginRemoteLogSet(
        sessionClientId: sessionClientId, eventId: UUID().uuidString, reps: reps, weight: weight)
    }
  }

  /// The standalone local-mode branch (docs/watch/44-watch-f6-standalone-plan.md
  /// §2.1, §3.2) — no PENDING/ack round-trip: this tap's set *is* the record
  /// (there's no phone to confirm against), so it's appended and CONFIRMED
  /// immediately, and a fixed-length local rest starts right away.
  private func beginLocalLogSet() {
    let now = Date()
    standaloneSets.append(
      StandaloneSet(
        loggedAtEpochMs: Int64(now.timeIntervalSince1970 * 1000),
        reps: standaloneDefaultReps,
        exerciseIndex: nil))
    saveActiveSnapshot()

    logSetState = .confirmed
    WKInterfaceDevice.current().play(.success)
    scheduleLogSetSettle(after: logSetConfirmedSettleSeconds)

    restDeadlineUptime = ProcessInfo.processInfo.systemUptime + standaloneRestSeconds
    restTotalSeconds = Int(standaloneRestSeconds)
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

  /// Opens the adjust stepper (revealed by a long-press on the log control —
  /// D-F5b.1). Starts from the phone's prefill for the row a tap would log
  /// into, falling back to a plain default when there's nothing to go on
  /// (D-F5b.2). Same `logSetState == .ready` gate the plain tap uses, so a
  /// still-pending log can't be adjusted out from under itself.
  ///
  /// Not available in standalone: F6a logs a fixed reps count (D-F6.8) and
  /// binding the stepper there is F6b's job (D-F5b.8).
  func beginLogAdjust() {
    guard phase == .active, !isStandalone, logSetState == .ready, logAdjustState == nil else {
      return
    }
    logAdjustState = LogAdjustState(
      reps: nextSetReps ?? logAdjustDefaultReps,
      weight: nextSetWeight ?? logAdjustDefaultWeight,
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
      templateId: nil,
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
    standaloneSets = []
    logSetTimeoutTask?.cancel()
    logSetTimeoutTask = nil
    logSetSettleTask?.cancel()
    logSetSettleTask = nil
    logSetState = .ready
    logAdjustIdleTask?.cancel()
    logAdjustIdleTask = nil
    logAdjustState = nil
  }

  /// Overwrites the live standalone session's recovery snapshot — called on
  /// start and after every locally logged set (docs/watch/
  /// 44-watch-f6-standalone-plan.md §3.2).
  private func saveActiveSnapshot() {
    guard isStandalone, let sessionClientId, let startedAt else { return }
    StandaloneSessionStore.shared.saveActive(
      StandaloneActiveSessionMeta(
        standaloneSessionId: sessionClientId,
        templateId: nil,
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
