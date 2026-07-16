import Flutter
import Foundation
import HealthKit
import WatchConnectivity

/// Handles the `lifey/watch` MethodChannel + `lifey/watch/events` EventChannel
/// that `WatchWorkoutService` (mobile/lib/core/watch/watch_workout_service.dart)
/// calls into — docs/40-watch-app-plan.md §3, §4.5, §6.1. Registered in
/// AppDelegate, mirroring LiveActivityChannel/PushChannel.
final class WatchBridge: NSObject {
  static let channelName = "lifey/watch"
  static let eventChannelName = "lifey/watch/events"

  private let healthStore = HKHealthStore()
  private var eventSink: FlutterEventSink?

  @discardableResult
  static func register(with registrar: FlutterPluginRegistrar) -> WatchBridge {
    let instance = WatchBridge()
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: registrar.messenger())
    channel.setMethodCallHandler { call, result in
      instance.handle(call, result: result)
    }
    let eventChannel = FlutterEventChannel(
      name: eventChannelName, binaryMessenger: registrar.messenger())
    eventChannel.setStreamHandler(instance)

    if WCSession.isSupported() {
      WCSession.default.delegate = instance
      WCSession.default.activate()
    }
    return instance
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "isWatchAppAvailable":
      result(isWatchAppAvailable)
    case "startWorkout":
      startWorkout(call, result: result)
    case "updateState":
      updateState(call, result: result)
    case "endWorkout":
      endWorkout(call, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private var isWatchAppAvailable: Bool {
    guard WCSession.isSupported() else { return false }
    let session = WCSession.default
    return session.isPaired && session.isWatchAppInstalled
  }

  // MARK: - Commands (docs/40-watch-app-plan.md §4.5)

  private func startWorkout(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
      let sessionClientId = args["sessionClientId"] as? String,
      let title = args["title"] as? String,
      let startedAtEpochMs = (args["startedAtEpochMs"] as? NSNumber)?.int64Value,
      let state = args["state"] as? [String: Any]
    else {
      result(nil)
      return
    }
    guard isWatchAppAvailable, HKHealthStore.isHealthDataAvailable() else {
      result(nil)
      return
    }

    pushContext(
      sessionClientId: sessionClientId, title: title, startedAtEpochMs: startedAtEpochMs,
      state: state, desiredPhase: "running")

    let configuration = HKWorkoutConfiguration()
    configuration.activityType = .traditionalStrengthTraining
    configuration.locationType = .indoor
    // Best-effort — docs/40-watch-app-plan.md §8.1: startWatchApp can be flaky
    // if the watch is asleep/charging. The applicationContext pushed above is
    // the fallback: the watch starts from it once woken regardless.
    healthStore.startWatchApp(with: configuration) { _, _ in }
    result(nil)
  }

  private func updateState(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
      let sessionClientId = args["sessionClientId"] as? String,
      let state = args["state"] as? [String: Any]
    else {
      result(nil)
      return
    }
    pushContext(
      sessionClientId: sessionClientId, title: nil, startedAtEpochMs: nil, state: state,
      desiredPhase: "running")
    if WCSession.default.isReachable {
      WCSession.default.sendMessage(
        ["command": "state", "sessionClientId": sessionClientId, "state": state],
        replyHandler: nil, errorHandler: nil)
    }
    result(nil)
  }

  private func endWorkout(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
      let sessionClientId = args["sessionClientId"] as? String
    else {
      result(nil)
      return
    }
    pushContext(
      sessionClientId: sessionClientId, title: nil, startedAtEpochMs: nil, state: nil,
      desiredPhase: "ended")
    if WCSession.default.isReachable {
      WCSession.default.sendMessage(
        ["command": "end", "sessionClientId": sessionClientId], replyHandler: nil,
        errorHandler: nil)
    }
    result(nil)
  }

  /// The "last known desired state" snapshot (docs/40-watch-app-plan.md §3,
  /// §D2) — survives the watch being unreachable; delivered whenever it next
  /// connects, unlike `sendMessage`.
  private func pushContext(
    sessionClientId: String, title: String?, startedAtEpochMs: Int64?, state: [String: Any]?,
    desiredPhase: String
  ) {
    guard WCSession.isSupported() else { return }
    var context: [String: Any] = ["sessionClientId": sessionClientId, "desiredPhase": desiredPhase]
    if let title { context["title"] = title }
    if let startedAtEpochMs { context["startedAtEpochMs"] = startedAtEpochMs }
    if let state { context["state"] = state }
    try? WCSession.default.updateApplicationContext(context)
  }
}

// MARK: - WCSessionDelegate

extension WatchBridge: WCSessionDelegate {
  func session(
    _ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState,
    error: Error?
  ) {}

  func sessionDidBecomeInactive(_ session: WCSession) {}

  func sessionDidDeactivate(_ session: WCSession) {
    // Required for multi-watch support (Apple docs) — re-activate so a newly
    // paired watch gets a session too.
    session.activate()
  }

  func sessionReachabilityDidChange(_ session: WCSession) {
    eventSink?(["type": "reachabilityChanged", "reachable": session.isReachable])
  }

  // Watch → phone workout summary (docs/40-watch-app-plan.md §3 "Lezárás",
  // §5.4). Queued delivery: arrives even if this app wasn't running when the
  // watch sent it, as long as the delegate was set early — see AppDelegate.
  func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
    guard let sessionClientId = userInfo["sessionClientId"] as? String else { return }
    eventSink?([
      "type": "summary",
      "payload": [
        "sessionClientId": sessionClientId,
        "activeCalories": userInfo["activeCalories"],
        "averageHeartRate": userInfo["averageHeartRate"],
        "healthWorkoutId": userInfo["healthWorkoutId"],
      ],
    ])
  }

  func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
    guard message["type"] as? String == "startRejected",
      let sessionClientId = message["sessionClientId"] as? String
    else { return }
    eventSink?(["type": "startRejected", "sessionClientId": sessionClientId])
  }
}

// MARK: - FlutterStreamHandler

extension WatchBridge: FlutterStreamHandler {
  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink)
    -> FlutterError?
  {
    eventSink = events
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil
    return nil
  }
}
