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

  /// The application-context dict actually sent to the watch, kept between
  /// calls (docs/watch/49-watch-f6b-template-sync-plan.md D-F6b.2) —
  /// `WCSession.applicationContext` is a single global value that
  /// `updateApplicationContext` **replaces wholesale**, never merges. Every
  /// writer (session-state pushes here, `templates` once syncTemplates
  /// lands) must therefore mutate this same dict and resend all of it, or
  /// one writer's push would silently erase the other's last update.
  private var lastContext: [String: Any] = [:]

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
    case "ackAdoption":
      ackAdoption(call, result: result)
    case "syncTemplates":
      syncTemplates(call, result: result)
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

  /// [activityType]/[venue] are `CardioSessionScreen`'s C5.2 additions to
  /// `WatchWorkoutService.startWorkout()` — both nil for every pre-cardio
  /// (STRENGTH) call site, which is exactly what falls through to the
  /// original hardcoded `.traditionalStrengthTraining`/`.indoor` pair below.
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

    let activityType = args["activityType"] as? String
    let venue = args["venue"] as? String
    let configuration = HKWorkoutConfiguration()
    configuration.activityType = cardioWorkoutActivityType(for: activityType)
    configuration.locationType = cardioLocationType(for: activityType, venue: venue)
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

  // Answers a `standaloneSessionAdopted` delivery (live bridging — the
  // watch-started session is still running, this just confirms the phone
  // created its live mirror row). Same "always ack, even on a dedup
  // no-op" contract as ackStandaloneSession, for the same reason: the
  // watch retries an un-acked adoption snapshot on reconnect/cold start
  // regardless of why it wasn't acked.
  private func ackAdoption(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
      let standaloneSessionId = args["standaloneSessionId"] as? String
    else {
      result(nil)
      return
    }
    if WCSession.default.isReachable {
      WCSession.default.sendMessage(
        ["command": "adoptionAck", "standaloneSessionId": standaloneSessionId],
        replyHandler: nil, errorHandler: nil)
    }
    result(nil)
  }

  /// Answers `syncTemplates` (docs/watch/49-watch-f6b-template-sync-plan.md
  /// §4.1, T3.2; wire shape bumped to the unified `entries` list by
  /// docs/cardio/55-cardio-watch-plan.md §3.2/C5.3) — folds
  /// `version`/`entries`/`syncedAtEpochMs` into [lastContext] (D-F6b.2)
  /// alongside whatever session-state keys already live there, then resends
  /// the whole thing. No `sendMessage` counterpart, unlike the session-state
  /// pushes above: template sync has no latency-sensitive live half, so the
  /// queued `updateApplicationContext` delivery — arriving whenever the
  /// watch next connects — is enough on its own (§4.3).
  ///
  /// `entries` replaces the old `templates` key entirely (C5.3's Dart side
  /// already made this switch — `WatchWorkoutService.syncTemplates()` has
  /// sent `{version: 2, entries: [...]}` since then, never `templates`) — an
  /// empty array still writes and sends (never skipped), the same "watch
  /// whose last plan just got deleted is told to clear its cache" contract
  /// `templates` had (T1.3's phone-side decision).
  ///
  /// `allCardio` is the complete activity-type list behind the picker's "all
  /// activity types" screen — every `kActivityTypes` code, pre-localized,
  /// unranked. Carried in the *same* context write rather than a channel of
  /// its own: it's ~7 short rows, the phone rebuilds it on the same triggers
  /// as `entries`, and one write keeps `lastContext`'s single-value merge
  /// contract (D-F6b.2) as simple as it is. Defaulted to `[]` rather than
  /// guarded on, so a Dart build that predates it still syncs its `entries`.
  private func syncTemplates(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
      let entries = args["entries"] as? [[String: Any]],
      let version = (args["version"] as? NSNumber)?.intValue,
      let syncedAtEpochMs = (args["syncedAtEpochMs"] as? NSNumber)?.int64Value
    else {
      result(nil)
      return
    }
    guard WCSession.isSupported() else {
      result(nil)
      return
    }
    let allCardio = args["allCardio"] as? [[String: Any]] ?? []
    lastContext["version"] = version
    lastContext["entries"] = (sanitizedForPropertyList(entries) as? [Any]) ?? []
    lastContext["allCardio"] = (sanitizedForPropertyList(allCardio) as? [Any]) ?? []
    lastContext["syncedAtEpochMs"] = syncedAtEpochMs
    try? WCSession.default.updateApplicationContext(lastContext)
    result(nil)
  }

  /// The "last known desired state" snapshot (docs/40-watch-app-plan.md §3,
  /// §D2) — survives the watch being unreachable; delivered whenever it next
  /// connects, unlike `sendMessage`.
  ///
  /// Mutates [lastContext] rather than building a fresh dict per call
  /// (docs/watch/49-watch-f6b-template-sync-plan.md D-F6b.2/T3.1) — any key
  /// this function doesn't touch (`templates`/`syncedAtEpochMs`, written by
  /// [syncTemplates]) carries over untouched into the resend. Matches the
  /// pre-refactor behavior exactly for the keys it does own:
  /// `title`/`startedAtEpochMs` are only ever *added*, never removed, when
  /// the caller passes nil — the original code had no path that deleted
  /// them either (`endWorkout` passing `state: nil` never cleared a
  /// previously-set `state` key, and still doesn't).
  private func pushContext(
    sessionClientId: String, title: String?, startedAtEpochMs: Int64?, state: [String: Any]?,
    desiredPhase: String
  ) {
    guard WCSession.isSupported() else { return }
    lastContext["sessionClientId"] = sessionClientId
    lastContext["desiredPhase"] = desiredPhase
    if let title { lastContext["title"] = title }
    if let startedAtEpochMs { lastContext["startedAtEpochMs"] = startedAtEpochMs }
    if let state, let sanitizedState = sanitizedForPropertyList(state) as? [String: Any] {
      lastContext["state"] = sanitizedState
    }
    try? WCSession.default.updateApplicationContext(lastContext)
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

/// Maps a cardio `ActivityType` code (docs/cardio/55-cardio-watch-plan.md §2's
/// table; `mobile/lib/features/workouts/domain/activity_type.dart`'s
/// `kActivityTypes`) to the `HKWorkoutConfiguration.activityType` the watch's
/// own `HKWorkoutSession` should record under. `nil` — every pre-cardio
/// (STRENGTH) call — keeps the original hardcoded behavior; an activity type
/// this build doesn't recognize (a future phone build talking to an
/// unrebuilt watch companion) falls back the same way, rather than crashing
/// on a force-unwrap.
///
/// Duplicated in `LifeyWatch/Views/StandalonePickerView.swift`'s icon/tint
/// map rather than shared — the two targets don't share a source file today,
/// and this table is small enough that C5.3's "tudatosan duplikálva"
/// precedent (docs/cardio/59-cardio-implementation-plan.md) applies here too.
private func cardioWorkoutActivityType(for activityType: String?) -> HKWorkoutActivityType {
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

/// The `HKWorkoutSessionLocationType` paired with [cardioWorkoutActivityType]
/// — D-C5.1 (docs/cardio/55-cardio-watch-plan.md §2): an explicit [venue]
/// ("INDOOR"/"OUTDOOR", the `GAME` family's own field) always wins; absent
/// that, `DISTANCE`-family types (running/walking/hiking) default `.outdoor`
/// and everything else (the stationary `INDOOR_BIKE`, a venue-less `GAME`,
/// `OTHER_CARDIO`, and STRENGTH) defaults `.indoor` — `OTHER_CARDIO` uses
/// `.unknown` instead, matching §2's table exactly, since neither indoor nor
/// outdoor is a safe guess for it.
private func cardioLocationType(for activityType: String?, venue: String?) -> HKWorkoutSessionLocationType
{
  switch venue {
  case "INDOOR": return .indoor
  case "OUTDOOR": return .outdoor
  default: break
  }
  switch activityType {
  case "RUNNING", "WALKING", "HIKING": return .outdoor
  case "OTHER_CARDIO": return .unknown
  default: return .indoor
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

  // Watch → phone `transferUserInfo` deliveries — workout summary
  // (docs/40-watch-app-plan.md §3 "Lezárás", §5.4), a finished standalone
  // session (docs/watch/44-watch-f6-standalone-plan.md §4.1), or a still-
  // running standalone session being adopted live. All queued: arrive even
  // if this app wasn't running when the watch sent them, as long as the
  // delegate was set early — see AppDelegate. Distinguished by a `type`
  // key: the summary payload never carried one (an older watch build's
  // queued-but-undelivered summary would still be missing it), so its
  // *absence* means summary rather than a positive `"summary"` check.
  func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
    if userInfo["type"] as? String == "standaloneSessionCompleted" {
      bufferOrEmit(["type": "standaloneSession", "payload": userInfo])
      return
    }
    if userInfo["type"] as? String == "standaloneSessionAdopted" {
      bufferOrEmit(["type": "standaloneSessionAdopted", "payload": userInfo])
      return
    }
    guard let sessionClientId = userInfo["sessionClientId"] as? String else { return }
    bufferOrEmit([
      "type": "summary",
      "payload": [
        "sessionClientId": sessionClientId,
        "activeCalories": userInfo["activeCalories"],
        "averageHeartRate": userInfo["averageHeartRate"],
        "healthWorkoutId": userInfo["healthWorkoutId"],
        // `PhoneConnector.sendSummary`'s cardio addition (docs/cardio/
        // 55-cardio-watch-plan.md §4.3, C5.7b) — nil for every STRENGTH
        // summary and every pre-cardio watch build, decoded Dart-side by
        // `WatchWorkoutSummary.fromJson`'s existing `cardio` handling
        // (already in place since C5.7a).
        "cardio": userInfo["cardio"],
      ],
    ])
  }

  /// `transferUserInfo` is a *queued* delivery: it survives this app being
  /// closed and lands whenever it next runs — including a background launch
  /// where `WCSession` wakes us up before Flutter has attached the
  /// `EventChannel`. Emitting into a nil `eventSink` at that moment silently
  /// dropped the payload, which is precisely the "I started the workout on
  /// my watch while the phone app was closed, and it never showed up" case.
  /// Persist instead, and let `onListen` drain it — the same treatment
  /// Android has always given these three payloads via its own
  /// `SharedPreferences` buffers (`WatchSummaryBuffer` and friends), so this
  /// closes a platform gap rather than inventing a mechanism.
  private func bufferOrEmit(_ event: [String: Any]) {
    guard let eventSink else {
      WatchEventBuffer.add(event)
      return
    }
    eventSink(event)
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
      // The watch names *which* exercise only when its own picker was used
      // (`exerciseId`, docs/watch/50-watch-f6c-session-plan-sync-plan.md §7);
      // for a plain tap it still says nothing and LogSessionScreen decides
      // from its own current position
      // (docs/watch/43-watch-f5-set-logging-plan.md §4.1). It may also
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
        "exerciseId": message["exerciseId"],
      ])
    case "exerciseSelected":
      // The wrist's exercise picker in a phone-mastered session — no set, just
      // "this is the exercise I'm on now" (F6c §7).
      eventSink?([
        "type": "exerciseSelected",
        "sessionClientId": sessionClientId,
        "exerciseId": message["exerciseId"],
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
    // The moment Dart starts listening is also the sweep point for
    // `transferUserInfo` deliveries that landed while it wasn't — see
    // `bufferOrEmit`. Mirrors `WatchBridge.kt`'s own `onListen` drain of its
    // three `SharedPreferences` buffers.
    for buffered in WatchEventBuffer.drain() {
      events(buffered)
    }
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil
    return nil
  }
}
