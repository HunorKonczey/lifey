import Flutter
import UIKit

// iOS half of the dynamic app-shortcuts bridge
// (docs/cardio/59-cardio-implementation-plan.md C2.11b). Android's
// ShortcutsBridge.kt is the C2.11a counterpart — same `lifey/shortcuts`
// MethodChannel, same JSON shape ({id, shortLabel, deepLinkUri} per entry),
// same "no new plugin, a few native lines" call (D-C2.2, 53-cardio-mobile-plan.md).

private let channelName = "lifey/shortcuts"

final class ShortcutsChannel: NSObject {
  static func register(with registrar: FlutterPluginRegistrar) -> ShortcutsChannel {
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: registrar.messenger())
    let instance = ShortcutsChannel()
    channel.setMethodCallHandler { call, result in
      instance.handle(call, result: result)
    }
    return instance
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "update" else {
      result(FlutterMethodNotImplemented)
      return
    }
    let shortcuts = (call.arguments as? [String: Any])?["shortcuts"] as? [[String: Any]] ?? []
    update(shortcuts)
    result(nil)
  }

  /// Replaces `UIApplication.shared.shortcutItems` wholesale — same "an
  /// empty list clears rather than being skipped" contract the Dart test
  /// suite already pins for the Android side, and for the same reason: a
  /// cold-start user with no ranking yet must not keep whatever a previous
  /// install left behind.
  private func update(_ shortcuts: [[String: Any]]) {
    // Apple caps visible dynamic shortcuts at 4; WidgetSnapshotController
    // only ever sends the top 3 (53-cardio-mobile-plan.md §3.2), so this is
    // a defensive trim, not a path anything currently exercises.
    UIApplication.shared.shortcutItems = shortcuts.prefix(4).compactMap(toShortcutItem)
  }

  /// No per-type icon — `UIApplicationShortcutIcon.IconType` only offers a
  /// fixed set of generic system glyphs (compose, play, add, …), none of
  /// which fits a specific `kActivityTypes` entry any better than showing
  /// none at all, so `icon: nil` (title-only). Mirrors ShortcutsBridge.kt's
  /// own call for the same reason: this is a secondary entry point, not
  /// worth shipping and maintaining a vector icon per activity type for.
  private func toShortcutItem(_ spec: [String: Any]) -> UIApplicationShortcutItem? {
    guard let id = spec["id"] as? String,
      let label = spec["shortLabel"] as? String,
      let deepLinkUri = spec["deepLinkUri"] as? String
    else { return nil }
    return UIApplicationShortcutItem(
      type: id,
      localizedTitle: label,
      localizedSubtitle: nil,
      icon: nil,
      userInfo: ["deepLinkUri": deepLinkUri as NSSecureCoding]
    )
  }
}
