import Flutter
import Foundation
import UIKit
import UserNotifications

// Handles the `lifey/push` MethodChannel — APNs device-token registration
// (docs/30-push-notifications-plan.md, M1). The Dart side calls `requestToken`;
// the actual APNs callbacks land on the UIApplicationDelegate (see AppDelegate),
// which forwards them here via `didRegister` / `didFail`.
//
// Registered from AppDelegate (kept as a stored property there, unlike
// LiveActivityChannel, because AppDelegate has to forward the async APNs
// callbacks back into this instance).
final class PushChannel: NSObject {
  static let channelName = "lifey/push"

  private let channel: FlutterMethodChannel

  // The in-flight `requestToken` result. APNs registration is asynchronous and
  // its outcome arrives on the AppDelegate, so the Flutter result is stashed
  // here and resolved when the token (or a failure) comes back. Only ever
  // touched on the main thread (see the dispatch in `requestToken` and the
  // fact that UIApplicationDelegate callbacks run on the main thread).
  private var pendingResult: FlutterResult?

  // Set from `didFinishLaunchingWithOptions`' launchOptions (app was fully
  // terminated and the user tapped a push to launch it) or from `didReceive`
  // firing before Dart has had a chance to register its own listener (M3) —
  // either way, `getLaunchNotification` hands it to Dart once, then clears it.
  private var pendingLaunchNotificationData: [String: Any]?

  init(messenger: FlutterBinaryMessenger, launchOptions: [UIApplication.LaunchOptionsKey: Any]?) {
    channel = FlutterMethodChannel(name: PushChannel.channelName, binaryMessenger: messenger)
    super.init()
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
    if let remoteNotification = launchOptions?[.remoteNotification] as? [AnyHashable: Any] {
      pendingLaunchNotificationData = Self.dataPayload(from: remoteNotification)
    }
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "requestToken":
      requestToken(result: result)
    case "getLaunchNotification":
      result(pendingLaunchNotificationData)
      pendingLaunchNotificationData = nil
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // Requests notification authorization, then registers for remote
  // notifications. Resolves with the hex-encoded APNs token, or nil if the
  // user denied permission (the plan: denial → skip registration silently,
  // re-attempted next cold start).
  private func requestToken(result: @escaping FlutterResult) {
    let center = UNUserNotificationCenter.current()
    center.requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, _ in
      guard let self else { return }
      guard granted else {
        result(nil)
        return
      }
      // registerForRemoteNotifications must be called on the main thread; the
      // authorization completion runs on an arbitrary one.
      DispatchQueue.main.async {
        // Replace any earlier pending result (a racing second call) — only the
        // most recent requestToken caller gets the next token callback.
        self.pendingResult = result
        UIApplication.shared.registerForRemoteNotifications()
      }
    }
  }

  // Forwarded from AppDelegate's
  // `application(_:didRegisterForRemoteNotificationsWithDeviceToken:)`.
  func didRegister(deviceToken: Data) {
    let token = deviceToken.map { String(format: "%02x", $0) }.joined()
    if let pending = pendingResult {
      pendingResult = nil
      pending(token)
    } else {
      // Token arrived with no in-flight request — iOS re-registered on its own
      // (e.g. token rotation). Push it to Dart so it can re-sync the backend
      // registration (M2).
      channel.invokeMethod("onToken", arguments: token)
    }
  }

  // Forwarded from AppDelegate's
  // `application(_:didFailToRegisterForRemoteNotificationsWithError:)`.
  func didFail(error: Error) {
    if let pending = pendingResult {
      pendingResult = nil
      pending(nil)
    }
  }

  // Forwarded from AppDelegate's `userNotificationCenter(_:willPresent:...)`
  // for one of our remote pushes (never a local one — see the `trigger is
  // UNPushNotificationTrigger` check there). Without this, iOS shows nothing
  // at all for a push that arrives while the app is in the foreground.
  func willPresent(completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
    completionHandler([.banner, .sound])
  }

  // Forwarded from AppDelegate's `userNotificationCenter(_:didReceive:...)`
  // — a tap on one of our remote pushes, whether the app was already running
  // (this invokes `onPushTapped` directly) or the tap just cold-launched it
  // (Dart isn't listening for the invoke yet in that case, so it's also
  // stashed for the `getLaunchNotification` pull once Dart starts up).
  func didReceive(_ response: UNNotificationResponse, completionHandler: @escaping () -> Void) {
    let userInfo = response.notification.request.content.userInfo
    if let data = Self.dataPayload(from: userInfo) {
      pendingLaunchNotificationData = data
      channel.invokeMethod("onPushTapped", arguments: data)
    }
    completionHandler()
  }

  // Only the custom top-level keys (see ApnsPushSender#send on the backend,
  // which adds PushMessage.data() as custom payload properties) — "aps" is
  // APNs' own alert/sound/badge machinery, not part of our deep-link contract.
  private static func dataPayload(from userInfo: [AnyHashable: Any]) -> [String: Any]? {
    var data: [String: Any] = [:]
    for (key, value) in userInfo {
      guard let key = key as? String, key != "aps" else { continue }
      data[key] = value
    }
    return data.isEmpty ? nil : data
  }
}
