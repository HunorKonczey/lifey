import ActivityKit
import Flutter
import Foundation

// Handles the `lifey/live_activity` MethodChannel — see
// docs/24-ios-widget-live-activity-plan.md, "Hand-rolled MethodChannel for
// the Live Activity". Registered in AppDelegate.
//
// Gated at iOS 16.2 rather than the plan's headline "16.1" — ActivityKit
// itself shipped in 16.1, but `ActivityContent` (needed for `staleDate`,
// which every start/update here sets) only landed in 16.2. The plan doc
// notes the same nuance under Constraints ("Live Activities need sim iOS
// 16.2+"). All calls below no-op (return nil) on 16.1 devices rather than
// crashing.
final class LiveActivityChannel: NSObject {
  static let channelName = "lifey/live_activity"

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: registrar.messenger())
    let instance = LiveActivityChannel()
    channel.setMethodCallHandler { call, result in
      instance.handle(call, result: result)
    }
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard #available(iOS 16.2, *) else {
      result(nil)
      return
    }

    switch call.method {
    case "start":
      start(call, result: result)
    case "update":
      update(call, result: result)
    case "end":
      endAllActivities(result: result)
    case "endAll":
      endAllActivities(result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  @available(iOS 16.2, *)
  private func contentState(from dict: [String: Any]) -> WorkoutActivityAttributes.ContentState? {
    guard let exerciseName = dict["exerciseName"] as? String,
      let setsDone = dict["setsDone"] as? Int,
      let totalSetsDone = dict["totalSetsDone"] as? Int
    else { return nil }
    let setsTotal = dict["setsTotal"] as? Int
    let lastSetAtEpochMs = (dict["lastSetAtEpochMs"] as? NSNumber)?.int64Value
    let restEndsAtEpochMs = (dict["restEndsAtEpochMs"] as? NSNumber)?.int64Value
    // Same default as the Dart `WorkoutSessionState.kind` field: absent
    // (older payload shape) means STRENGTH.
    let kind = (dict["kind"] as? String) ?? "STRENGTH"
    let activityType = dict["activityType"] as? String
    let cardio = cardioLiveMetrics(from: dict["cardio"] as? [String: Any])
    return WorkoutActivityAttributes.ContentState(
      exerciseName: exerciseName,
      setsDone: setsDone,
      setsTotal: setsTotal,
      totalSetsDone: totalSetsDone,
      lastSetAtEpochMs: lastSetAtEpochMs,
      restEndsAtEpochMs: restEndsAtEpochMs,
      kind: kind,
      activityType: activityType,
      cardio: cardio
    )
  }

  /// Mirrors the Dart `CardioLiveMetrics.toJson()` shape. Returns `nil` for
  /// a STRENGTH update (no `"cardio"` key at all) as well as for a
  /// malformed block — either way the ContentState just carries no cardio
  /// data, which is what routes rendering to the STRENGTH branch.
  @available(iOS 16.2, *)
  private func cardioLiveMetrics(from dict: [String: Any]?) -> CardioLiveMetricsState? {
    guard let dict,
      let primaryLabel = dict["primaryLabel"] as? String,
      let primaryValue = dict["primaryValue"] as? String,
      let paused = dict["paused"] as? Bool
    else { return nil }
    return CardioLiveMetricsState(
      primaryLabel: primaryLabel,
      primaryValue: primaryValue,
      secondaryLabel: dict["secondaryLabel"] as? String,
      secondaryValue: dict["secondaryValue"] as? String,
      tertiaryLabel: dict["tertiaryLabel"] as? String,
      tertiaryValue: dict["tertiaryValue"] as? String,
      paused: paused,
      movingSecondsBase: dict["movingSecondsBase"] as? Int,
      movingSinceEpochMs: (dict["movingSinceEpochMs"] as? NSNumber)?.int64Value
    )
  }

  @available(iOS 16.2, *)
  private func activityContent(_ state: WorkoutActivityAttributes.ContentState)
    -> ActivityContent<WorkoutActivityAttributes.ContentState>
  {
    // 4h stale window: an abandoned activity visibly greys out and iOS may
    // remove it, per the plan's orphan-handling section.
    ActivityContent(state: state, staleDate: Date().addingTimeInterval(4 * 3600))
  }

  /// Reports failures to Dart instead of swallowing them as `nil`, so
  /// `WorkoutSessionNotifierService` can tell "ask again in a moment" apart
  /// from "never going to work". The one that matters is `start_failed`:
  /// ActivityKit refuses to *start* an activity while the app is in the
  /// background (`ActivityAuthorizationError.visibility`), which is exactly
  /// what happens when a set logged on the watch creates the session while
  /// the phone sits in a pocket. That used to be indistinguishable from
  /// success, so the workout ran to the end with no Live Activity and the
  /// phone never tried again.
  @available(iOS 16.2, *)
  private func start(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard ActivityAuthorizationInfo().areActivitiesEnabled else {
      result(
        FlutterError(
          code: "activities_disabled",
          message: "Live Activities are turned off for this app", details: nil))
      return
    }
    guard let args = call.arguments as? [String: Any],
      let sessionClientId = args["sessionClientId"] as? String,
      let title = args["title"] as? String,
      let startedAtEpochMs = (args["startedAtEpochMs"] as? NSNumber)?.int64Value,
      let stateDict = args["state"] as? [String: Any],
      let state = contentState(from: stateDict)
    else {
      result(
        FlutterError(code: "invalid_args", message: "Malformed start arguments", details: nil))
      return
    }

    // Re-attach rather than duplicate: LogSessionScreen calls start() both
    // for a brand-new session and to re-attach after the OS killed the app
    // mid-workout (see docs/24-ios-widget-live-activity-plan.md, orphan
    // handling). If one already exists for this session, just update it.
    if let existing = Activity<WorkoutActivityAttributes>.activities.first(where: {
      $0.attributes.sessionClientId == sessionClientId
    }) {
      Task {
        await existing.update(activityContent(state))
      }
      result(existing.id)
      return
    }

    let attributes = WorkoutActivityAttributes(
      sessionClientId: sessionClientId, title: title, startedAtEpochMs: startedAtEpochMs)

    do {
      let activity = try Activity<WorkoutActivityAttributes>.request(
        attributes: attributes, content: activityContent(state))
      result(activity.id)
    } catch {
      // Retryable by contract with the Dart side — see this function's doc
      // comment. The message is carried through for logging only; Dart keys
      // off the code.
      result(
        FlutterError(code: "start_failed", message: "\(error)", details: nil))
    }
  }

  @available(iOS 16.2, *)
  private func update(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
      let sessionClientId = args["sessionClientId"] as? String,
      let stateDict = args["state"] as? [String: Any],
      let state = contentState(from: stateDict)
    else {
      result(nil)
      return
    }

    // No-op (not an error) if the activity is already gone — the app may be
    // racing a stale-date expiry or a concurrent end().
    guard
      let activity = Activity<WorkoutActivityAttributes>.activities.first(where: {
        $0.attributes.sessionClientId == sessionClientId
      })
    else {
      result(nil)
      return
    }

    Task {
      await activity.update(activityContent(state))
      result(nil)
    }
  }

  // `end()` and `endAll()` share one implementation: at most one workout
  // runs at a time in this app, so "end the current one" and "sweep every
  // orphan" both reduce to "end everything currently tracked."
  @available(iOS 16.2, *)
  private func endAllActivities(result: @escaping FlutterResult) {
    Task {
      for activity in Activity<WorkoutActivityAttributes>.activities {
        await activity.end(activity.content, dismissalPolicy: .immediate)
      }
      result(nil)
    }
  }
}
