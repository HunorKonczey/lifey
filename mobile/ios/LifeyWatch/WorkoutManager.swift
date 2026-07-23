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

  private let store = HKHealthStore()
  private var session: HKWorkoutSession?
  private var builder: HKLiveWorkoutBuilder?
  private var restHapticTask: Task<Void, Never>?
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
    do {
      try await requestAuthorizationIfNeeded()
    } catch {
      // The authorization *request* itself failed (rare) — treat the same
      // as an explicit denial (§12.1 B10).
      phase = .healthDenied
      return
    }
    // Read-type denials are invisible by design (HealthKit's privacy model
    // never reveals whether READ was granted), but workoutType is a *share*
    // type, so its status is queryable — and a session that can't save a
    // workout shouldn't silently run one (§12.1 B10, replacing the earlier
    // "just falls back to Idle" behavior noted in the doc's §9 test matrix).
    guard store.authorizationStatus(for: HKObjectType.workoutType()) != .sharingDenied else {
      phase = .healthDenied
      return
    }
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
  /// resend it.
  private func notifyStartedOnWatchIfNeeded() {
    guard phase == .active, let sessionClientId, notifiedStartedOnWatchFor != sessionClientId
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
    restTotalSeconds: Int?
  ) {
    self.sessionClientId = sessionClientId
    self.title = title ?? self.title
    self.exerciseName = exerciseName ?? self.exerciseName
    self.setsDone = setsDone ?? self.setsDone
    self.setsTotal = setsTotal ?? self.setsTotal
    self.restDeadlineUptime = restRemainingSeconds.map { ProcessInfo.processInfo.systemUptime + Double($0) }
    self.restTotalSeconds = restTotalSeconds
    notifyStartedOnWatchIfNeeded()
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
  func requestEnd(rpe: Int?) {
    guard phase == .active, let sessionClientId else { return }
    showEffortSelector = false
    phase = .ending
    PhoneConnector.shared.sendEndRequested(sessionClientId: sessionClientId, rpe: rpe)
  }

  /// The real end, triggered by `PhoneConnector` once the phone's `end`
  /// command (or its `desiredPhase: "ended"` delivery-guarantee fallback,
  /// docs/40-watch-app-plan.md §3 "Kézbesítési garancia") arrives. Runs from
  /// either `.active` (the delivery-guarantee fallback can arrive before the
  /// watch ever requested an end, e.g. after being unreachable) or
  /// `.ending` (the normal watch-initiated path, §12.1 B8).
  func finishAndSendSummary() async {
    guard phase == .active || phase == .ending, let session, let builder, let sessionClientId,
      let startedAt
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
        savedToHealth: healthWorkoutId != nil))
    scheduleSummaryAutoDismiss()
  }

  /// Clears the running-session fields but leaves `phase` alone — the two
  /// callers each set it themselves right after (`.summary` here, `.idle`
  /// implicitly once `scheduleSummaryAutoDismiss()`'s timer fires).
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
    isPaused = false
    heartRateBpm = nil
    activeCalories = nil
    startedAt = nil
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
