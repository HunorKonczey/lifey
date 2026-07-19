import Foundation
import WatchConnectivity

/// Watch-side `WCSessionDelegate` — mirrors Android's `PhoneListenerService`
/// + `SummarySender` combined (docs/40-watch-app-plan.md §4.3, §4.5, §3).
/// Applies phone-pushed context/messages to `WorkoutManager` and sends the
/// summary/startRejected/endRequested messages back. The phone-side
/// counterpart (`Runner/WatchBridge.swift`) already implements its half of
/// every path used here.
final class PhoneConnector: NSObject {
  static let shared = PhoneConnector()

  private override init() {
    super.init()
  }

  /// Called from `AppDelegate.applicationDidFinishLaunching()` — as early as
  /// possible, so a `transferUserInfo`/applicationContext already queued by
  /// the phone isn't missed (mirrors the phone-side WatchBridge.swift's own
  /// comment on this).
  func activate() {
    guard WCSession.isSupported() else { return }
    WCSession.default.delegate = self
    WCSession.default.activate()
  }

  // MARK: - Watch → phone (docs/40-watch-app-plan.md §3 "Lezárás", §5.3, §8.2)

  /// Queued delivery via `transferUserInfo` — arrives even if the phone app
  /// isn't running right now, unlike `sendMessage` (docs/40-watch-app-plan.md
  /// §3 "Lezárás").
  func sendSummary(
    sessionClientId: String, activeCalories: Double?, averageHeartRate: Double?,
    healthWorkoutId: String?
  ) {
    guard WCSession.isSupported() else { return }
    var userInfo: [String: Any] = ["sessionClientId": sessionClientId]
    if let activeCalories { userInfo["activeCalories"] = activeCalories }
    if let averageHeartRate { userInfo["averageHeartRate"] = averageHeartRate }
    if let healthWorkoutId { userInfo["healthWorkoutId"] = healthWorkoutId }
    WCSession.default.transferUserInfo(userInfo)
  }

  func sendStartRejected(sessionClientId: String) {
    sendMessage(["type": "startRejected", "sessionClientId": sessionClientId])
  }

  /// [rpe] is whatever `EffortSelectorView`'s stepper produced (nil if the
  /// user skipped it) — the key is omitted entirely when nil, never sent as
  /// `NSNull`, which `sendMessage`'s property-list encoding rejects (the
  /// same pitfall already hit `restEndsAtEpochMs`, docs/40-watch-app-plan.md
  /// §11.2).
  func sendEndRequested(sessionClientId: String, rpe: Int?) {
    var message: [String: Any] = ["type": "endRequested", "sessionClientId": sessionClientId]
    if let rpe { message["rpe"] = rpe }
    sendMessage(message)
  }

  /// The watch's own `HKWorkoutSession` actually started running — drives the
  /// phone's "Measuring" pill (docs/40-watch-app-plan.md §12.4 B14). Sent
  /// once per watch session by `WorkoutManager`, not on every state sync.
  func sendStartedOnWatch(sessionClientId: String) {
    sendMessage(["type": "startedOnWatch", "sessionClientId": sessionClientId])
  }

  /// Live heart-rate/calorie readings, pushed every time
  /// `HKLiveWorkoutBuilderDelegate` reports fresh data — far more often than
  /// `sendSummary`'s one-shot totals. Best-effort like the other `sendMessage`
  /// calls here: a reading dropped while unreachable is superseded moments
  /// later by the next one, so there's no `transferUserInfo`-style delivery
  /// guarantee to bother with.
  func sendLiveMetrics(sessionClientId: String, heartRateBpm: Double?, activeCalories: Double?) {
    var message: [String: Any] = ["type": "liveMetrics", "sessionClientId": sessionClientId]
    if let heartRateBpm { message["heartRateBpm"] = heartRateBpm }
    if let activeCalories { message["activeCalories"] = activeCalories }
    sendMessage(message)
  }

  private func sendMessage(_ message: [String: Any]) {
    // Best-effort, like the phone side's own sendMessage calls — a lost
    // startRejected/endRequested simply means the user retries
    // (docs/40-watch-app-plan.md §8.1).
    guard WCSession.isSupported(), WCSession.default.isReachable else { return }
    WCSession.default.sendMessage(message, replyHandler: nil, errorHandler: nil)
  }
}

// MARK: - WCSessionDelegate

extension PhoneConnector: WCSessionDelegate {
  func session(
    _ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState,
    error: Error?
  ) {
    // Picks up a context pushed before this delegate was set (e.g. the
    // phone's `startWorkout` call raced `handle(_:)`'s app launch).
    applyContext(session.receivedApplicationContext)
  }

  func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any])
  {
    applyContext(applicationContext)
  }

  func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
    guard let sessionClientId = message["sessionClientId"] as? String else { return }
    switch message["command"] as? String {
    case "state":
      applyState(
        sessionClientId: sessionClientId, title: nil, state: message["state"] as? [String: Any])
    case "end":
      Task { @MainActor in await WorkoutManager.shared.finishAndSendSummary() }
    default:
      break
    }
  }

  /// `desiredPhase: "ended"` is the delivery-guarantee fallback
  /// (docs/40-watch-app-plan.md §3 "Kézbesítési garancia") — mirrors
  /// Android's `onDataChanged` check: the phone's `end` message may never
  /// have reached us while unreachable.
  private func applyContext(_ context: [String: Any]) {
    guard !context.isEmpty, let sessionClientId = context["sessionClientId"] as? String else {
      return
    }
    applyState(
      sessionClientId: sessionClientId, title: context["title"] as? String,
      state: context["state"] as? [String: Any])
    if context["desiredPhase"] as? String == "ended" {
      Task { @MainActor in
        let phase = WorkoutManager.shared.phase
        if phase == .active || phase == .ending {
          await WorkoutManager.shared.finishAndSendSummary()
        }
      }
    }
  }

  private func applyState(sessionClientId: String, title: String?, state: [String: Any]?) {
    Task { @MainActor in
      WorkoutManager.shared.applyStateUpdate(
        sessionClientId: sessionClientId,
        title: title,
        exerciseName: state?["exerciseName"] as? String,
        setsDone: (state?["setsDone"] as? NSNumber)?.intValue,
        setsTotal: (state?["setsTotal"] as? NSNumber)?.intValue,
        restRemainingSeconds: (state?["restRemainingSeconds"] as? NSNumber)?.intValue,
        restTotalSeconds: (state?["restTotalSeconds"] as? NSNumber)?.intValue)
    }
  }
}
