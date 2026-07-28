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
    case "ackSetLogged":
      ackSetLogged(call, result: result)
    case "ackStandaloneSession":
      ackStandaloneSession(call, result: result)
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
      let sanitizedState = (sanitizedForPropertyList(state) as? [String: Any]) ?? [:]
      WCSession.default.sendMessage(
        ["command": "state", "sessionClientId": sessionClientId, "state": sanitizedState],
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

  // Answers a watch `logSet` tap (docs/watch/43-watch-f5-set-logging-plan.md
  // §4.3, §5.1). Sent as a plain message, not queued via
  // updateApplicationContext like the state above — an ack has no value once
  // stale, so if the watch isn't reachable right now it simply times out
  // watch-side (§7.1) rather than being delivered late.
  private func ackSetLogged(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
      let sessionClientId = args["sessionClientId"] as? String,
      let eventId = args["eventId"] as? String,
      let accepted = args["accepted"] as? Bool
    else {
      result(nil)
      return
    }
    if WCSession.default.isReachable {
      WCSession.default.sendMessage(
        [
          "command": "logSetAck", "sessionClientId": sessionClientId, "eventId": eventId,
          "accepted": accepted,
        ], replyHandler: nil, errorHandler: nil)
    }
    result(nil)
  }

  // Answers a `standaloneSessionCompleted` delivery (docs/watch/
  // 44-watch-f6-standalone-plan.md §4.2). No `accepted` field — unlike
  // ackSetLogged there's no rejection case, the watch's pending-session
  // store just retries an un-acked delivery regardless of why it wasn't
  // acked. Also a plain message, not queued: a stale ack has no value, the
  // watch's own pending-session store (not this ack) is what survives it
  // being unreachable right now.
  private func ackStandaloneSession(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
      let standaloneSessionId = args["standaloneSessionId"] as? String
    else {
      result(nil)
      return
    }
    if WCSession.default.isReachable {
      WCSession.default.sendMessage(
        ["command": "standaloneSessionAck", "standaloneSessionId": standaloneSessionId],
        replyHandler: nil, errorHandler: nil)
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
    if let state, let sanitizedState = sanitizedForPropertyList(state) as? [String: Any] {
      context["state"] = sanitizedState
    }
    try? WCSession.default.updateApplicationContext(context)
  }
}

/// Strips `NSNull` (Flutter's encoding of Dart `null`, which the standard
/// method codec preserves as a real dictionary entry rather than omitting
/// the key) recursively. Both `updateApplicationContext` and `sendMessage`
/// require property-list-only values — `NSNull` isn't one, and an
/// un-sanitized payload fails `updateApplicationContext` silently (`try?`),
/// dropping the whole state update. This matters in practice because
/// `restEndsAtEpochMs` (docs/40-watch-app-plan.md §3 "Élő állapot") is
/// `null` on the wire whenever no rest is active — the common case.
private func sanitizedForPropertyList(_ value: Any) -> Any? {
  if value is NSNull { return nil }
  if let dict = value as? [String: Any] {
    var result: [String: Any] = [:]
    for (key, nested) in dict {
      if let sanitized = sanitizedForPropertyList(nested) {
        result[key] = sanitized
      }
    }
    return result
  }
  if let array = value as? [Any] {
    return array.compactMap { sanitizedForPropertyList($0) }
  }
  return value
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

  // Watch → phone `transferUserInfo` deliveries — workout summary
  // (docs/40-watch-app-plan.md §3 "Lezárás", §5.4) or a standalone session
  // (docs/watch/44-watch-f6-standalone-plan.md §4.1). Both are queued:
  // arrive even if this app wasn't running when the watch sent them, as
  // long as the delegate was set early — see AppDelegate. Distinguished by
  // a `type` key: the summary payload never carried one (an older watch
  // build's queued-but-undelivered summary would still be missing it), so
  // its *absence* means summary rather than a positive `"summary"` check.
  func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
    if userInfo["type"] as? String == "standaloneSessionCompleted" {
      eventSink?(["type": "standaloneSession", "payload": userInfo])
      return
    }
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

  // Watch → phone signals: "another app owns the exercise" and "user
  // pressed End on the watch" (docs/40-watch-app-plan.md §3, §8.2 decision
  // (b), §11.1/5). WatchEndRequested is handled Dart-side by
  // LogSessionScreen while mounted for this sessionClientId.
  func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
    guard let sessionClientId = message["sessionClientId"] as? String else { return }
    switch message["type"] as? String {
    case "startRejected":
      eventSink?(["type": "startRejected", "sessionClientId": sessionClientId])
    case "endRequested":
      // The watch already collected (or skipped) the effort rating itself
      // before sending this — rpe is nil when skipped.
      eventSink?(["type": "endRequested", "sessionClientId": sessionClientId, "rpe": message["rpe"]])
    case "startedOnWatch":
      eventSink?(["type": "startedOnWatch", "sessionClientId": sessionClientId])
    case "logSet":
      // The watch never says *which* exercise/row to log — LogSessionScreen
      // decides that from its own current position
      // (docs/watch/43-watch-f5-set-logging-plan.md §4.1). It may, however,
      // carry the values the user dialled in on its adjust stepper
      // (docs/watch/48-watch-f5b-set-adjust-plan.md §4.1): `reps`/`weight`
      // are absent for a plain F5a one-tap log, and the Dart side treats a
      // missing (or half-filled) pair as "no values" — D-F5b.6.
      eventSink?([
        "type": "setLogged",
        "sessionClientId": sessionClientId,
        "eventId": message["eventId"],
        "loggedAtEpochMs": message["loggedAtEpochMs"],
        "reps": message["reps"],
        "weight": message["weight"],
      ])
    case "liveMetrics":
      eventSink?([
        "type": "liveMetrics",
        "payload": [
          "sessionClientId": sessionClientId,
          "heartRateBpm": message["heartRateBpm"],
          "activeCalories": message["activeCalories"],
        ],
      ])
    default:
      break
    }
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
