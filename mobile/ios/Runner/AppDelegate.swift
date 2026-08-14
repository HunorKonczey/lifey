import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {
  // Stored (unlike LiveActivityChannel) so the APNs registration callbacks
  // below can forward into it — see PushChannel / docs/30-push-notifications-plan.md.
  private var pushChannel: PushChannel?
  // Stored so the WCSessionDelegate it sets on WCSession.default stays alive
  // for the app's lifetime — see docs/40-watch-app-plan.md §4.5.
  private var watchBridge: WatchBridge?
  // Stored so its MPMusicPlayerController notification observers stay alive
  // for the app's lifetime — see docs/music/46-workout-music-controls-plan.md §2.2.
  private var appleMusicBridge: AppleMusicBridge?
  // Stored purely so ARC doesn't deallocate it — ShortcutsChannel has no
  // callbacks that need to reach back into AppDelegate later (unlike
  // watchBridge/appleMusicBridge above), see docs/cardio/59-cardio-implementation-plan.md C2.11b.
  private var shortcutsChannel: ShortcutsChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    if let registrar = self.registrar(forPlugin: "LiveActivityChannel") {
      LiveActivityChannel.register(with: registrar)
    }
    if let registrar = self.registrar(forPlugin: "PushChannel") {
      pushChannel = PushChannel(messenger: registrar.messenger(), launchOptions: launchOptions)
    }
    // Set the WCSessionDelegate as early as possible so a queued
    // transferUserInfo summary isn't missed (docs/40-watch-app-plan.md §4.5).
    if let registrar = self.registrar(forPlugin: "WatchBridge") {
      watchBridge = WatchBridge.register(with: registrar)
    }
    if let registrar = self.registrar(forPlugin: "AppleMusicBridge") {
      appleMusicBridge = AppleMusicBridge.register(with: registrar)
    }
    if let registrar = self.registrar(forPlugin: "ShortcutsChannel") {
      shortcutsChannel = ShortcutsChannel.register(with: registrar)
    }
    // Makes this AppDelegate the app's single UNUserNotificationCenterDelegate
    // (FlutterAppDelegate formally conforms via FlutterAppLifeCycleProvider,
    // which inherits from UNUserNotificationCenterDelegate — see
    // FlutterPlugin.h). Required for both our own remote-push handling below
    // and flutter_local_notifications' foreground display / tap handling
    // (which otherwise silently never fires — see its iOS setup docs).
    UNUserNotificationCenter.current().delegate = self
    let launched = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    // Cold launch from a home-screen dynamic shortcut (app icon long-press)
    // — iOS hands this through launchOptions rather than
    // application(_:performActionFor:completionHandler:) below, which Apple
    // only calls for an app that's already running. Must run after
    // super.application(...) above: that's what stands up the Flutter
    // engine/binary messenger that openDeepLink(_:) forwards into.
    if let shortcutItem = launchOptions?[.shortcutItem] as? UIApplicationShortcutItem {
      openDeepLink(from: shortcutItem)
    }
    return launched
  }

  // Warm launch (app already running, in foreground or background) from a
  // home-screen dynamic shortcut — the counterpart to the launchOptions
  // branch above.
  override func application(
    _ application: UIApplication,
    performActionFor shortcutItem: UIApplicationShortcutItem,
    completionHandler: @escaping (Bool) -> Void
  ) {
    openDeepLink(from: shortcutItem)
    completionHandler(true)
  }

  /// Routes a shortcut's `lifey://workout/start?...` URI through the exact
  /// same `application(_:open:options:)` path `FlutterAppDelegate` already
  /// uses for a plain `lifey://` tap (Live Activity, Safari-typed URL) — so
  /// go_router's existing `onException` deep-link handling
  /// (docs/cardio/59-cardio-implementation-plan.md C2.11a) needs no
  /// iOS-specific branch to also handle shortcuts.
  private func openDeepLink(from shortcutItem: UIApplicationShortcutItem) {
    guard let uriString = shortcutItem.userInfo?["deepLinkUri"] as? String,
      let url = URL(string: uriString)
    else { return }
    _ = self.application(UIApplication.shared, open: url, options: [:])
  }

  // APNs delivers the device token (or a failure) here after
  // PushChannel triggers registerForRemoteNotifications(). Not calling super:
  // no plugin in this app consumes remote-notification registration, and
  // PushChannel owns the result. (firebase_messaging, if ever added, would
  // need these forwarded to it instead.)
  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    pushChannel?.didRegister(deviceToken: deviceToken)
  }

  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    pushChannel?.didFail(error: error)
  }

  // Foreground presentation. Only a genuine remote push (delivered via a
  // UNPushNotificationTrigger) goes to PushChannel — everything else (the
  // step-goal / workout-session local notifications) falls through to
  // flutter_local_notifications via `super` (docs/30-push-notifications-plan.md, M3).
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    if notification.request.trigger is UNPushNotificationTrigger {
      pushChannel?.willPresent(completionHandler: completionHandler)
    } else {
      super.userNotificationCenter(
        center, willPresent: notification, withCompletionHandler: completionHandler)
    }
  }

  // Tap handling — same remote/local split as above.
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    if response.notification.request.trigger is UNPushNotificationTrigger {
      pushChannel?.didReceive(response, completionHandler: completionHandler)
    } else {
      super.userNotificationCenter(
        center, didReceive: response, withCompletionHandler: completionHandler)
    }
  }
}
