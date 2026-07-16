import Foundation
import HealthKit
import WatchKit

enum WorkoutPhase {
  case idle
  case active
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
  @Published private(set) var restEndsAtEpochMs: Int64? {
    didSet { scheduleRestHaptic() }
  }
  @Published private(set) var heartRateBpm: Double?
  @Published private(set) var activeCalories: Double?
  @Published private(set) var startedAt: Date?

  private let store = HKHealthStore()
  private var session: HKWorkoutSession?
  private var builder: HKLiveWorkoutBuilder?
  private var restHapticTask: Task<Void, Never>?

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
      try await startSession(configuration: configuration)
    } catch {
      // Another app's HKWorkoutSession owns the sensors, authorization was
      // denied, etc. (docs/40-watch-app-plan.md §5.3, §8.1's Wear-side
      // equivalent). sessionClientId may still be nil at this point if
      // PhoneConnector's context hasn't arrived yet — nothing to report in
      // that case, the phone will simply see no watch activity.
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
  }

  /// Applied whenever a start/state message or applicationContext arrives
  /// from `PhoneConnector` (docs/40-watch-app-plan.md §D2, mirrors Android's
  /// `SessionStateHolder.onStateSynced`). Doesn't clear
  /// `title`/`exerciseName`/`setsDone`/`setsTotal` when the new payload
  /// didn't include them. `restEndsAtEpochMs` is the one exception — always
  /// overwritten (including to nil), since a null is indistinguishable on
  /// the wire from "key absent" once `WatchBridge.swift` strips nulls for
  /// property-list compatibility, and the rest timer toggles constantly
  /// within a single session.
  func applyStateUpdate(
    sessionClientId: String,
    title: String?,
    exerciseName: String?,
    setsDone: Int?,
    setsTotal: Int?,
    restEndsAtEpochMs: Int64?
  ) {
    self.sessionClientId = sessionClientId
    self.title = title ?? self.title
    self.exerciseName = exerciseName ?? self.exerciseName
    self.setsDone = setsDone ?? self.setsDone
    self.setsTotal = setsTotal ?? self.setsTotal
    self.restEndsAtEpochMs = restEndsAtEpochMs
  }

  /// The watch's End button never closes the session itself — it asks the
  /// phone to, so the phone's finish flow (RPE sheet) still runs
  /// (docs/40-watch-app-plan.md §8.2 decision (b), §11.1/5). The session
  /// only actually ends once the real `end` command comes back, via
  /// `finishAndSendSummary()`.
  func requestEnd() {
    guard let sessionClientId else { return }
    PhoneConnector.shared.sendEndRequested(sessionClientId: sessionClientId)
  }

  /// The real end, triggered by `PhoneConnector` once the phone's `end`
  /// command (or its `desiredPhase: "ended"` delivery-guarantee fallback,
  /// docs/40-watch-app-plan.md §3 "Kézbesítési garancia") arrives.
  func finishAndSendSummary() async {
    guard phase == .active, let session, let builder, let sessionClientId else { return }
    session.end()

    let averageHeartRate = builder.statistics(for: Self.heartRateType)?
      .averageQuantity()?.doubleValue(for: HKUnit(from: "count/min"))
    let activeCaloriesTotal = builder.statistics(for: Self.activeEnergyType)?
      .sumQuantity()?.doubleValue(for: .kilocalorie())

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
  }

  private func reset() {
    session = nil
    builder = nil
    phase = .idle
    sessionClientId = nil
    title = nil
    exerciseName = nil
    setsDone = nil
    setsTotal = nil
    restEndsAtEpochMs = nil
    heartRateBpm = nil
    activeCalories = nil
    startedAt = nil
  }

  // MARK: - Pihenő-visszaszámláló haptika (docs/40-watch-app-plan.md §5.4/F4 parity)

  /// Scheduled independently of whichever view is on screen, for as long as
  /// `WorkoutManager` itself lives (i.e. the whole session) — mirrors
  /// Android's `ExerciseService.scheduleRestVibration`, which runs on the
  /// always-alive foreground service rather than the Compose screen.
  private func scheduleRestHaptic() {
    restHapticTask?.cancel()
    guard let restEndsAtEpochMs else { return }
    let delaySeconds = Double(restEndsAtEpochMs) / 1000 - Date().timeIntervalSince1970
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
  nonisolated func workoutSession(
    _ workoutSession: HKWorkoutSession,
    didChangeTo toState: HKWorkoutSessionState,
    from fromState: HKWorkoutSessionState,
    date: Date
  ) {}

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
    }
  }

  nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}
}
