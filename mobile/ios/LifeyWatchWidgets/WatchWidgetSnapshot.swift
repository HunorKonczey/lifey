import Foundation

#if canImport(WidgetKit)
  import WidgetKit
#endif

/// What the watch app tells its widgets (redesign plan 79, X2.o1 / X2.o2). Only the watch's own state — no
/// phone contact — written to the shared App Group by `WatchWidgetPublisher` (watch app target) and read by
/// the timeline providers (widget extension target). **Add this file to both targets.**
///
/// Times are wall-clock `Date`s so the extension can render *live* timers (`Text(date, style: .timer)`,
/// `ProgressView(timerInterval:)`) without being woken every second.
struct WatchWidgetSnapshot: Codable, Equatable {
  enum Phase: String, Codable {
    case idle
    case active
    case resting
  }

  var phase: Phase
  /// Template / session name ("Push nap"); nil → the localized "Strength".
  var title: String?
  var exerciseName: String?
  var setsDone: Int?
  var setsTotal: Int?
  /// Wall-clock start of the workout (live elapsed time).
  var startedAt: Date?
  var heartRateBpm: Int?
  /// The rest window, while `phase == .resting`.
  var restStartedAt: Date?
  var restEndsAt: Date?
  var isPaused: Bool
  var updatedAt: Date

  static let idle = WatchWidgetSnapshot(
    phase: .idle, title: nil, exerciseName: nil, setsDone: nil, setsTotal: nil, startedAt: nil,
    heartRateBpm: nil, restStartedAt: nil, restEndsAt: nil, isPaused: false, updatedAt: Date())

  /// The fixture of the Xcode widget gallery / previews (AW2.24 / AW2.25).
  static var sample: WatchWidgetSnapshot {
    let now = Date()
    return WatchWidgetSnapshot(
      phase: .active, title: "Push nap", exerciseName: "Fekvenyomás", setsDone: 2, setsTotal: 4,
      startedAt: now.addingTimeInterval(-(12 * 60 + 34)), heartRateBpm: 128, restStartedAt: nil,
      restEndsAt: nil, isPaused: false, updatedAt: now)
  }

  /// The same snapshot once the rest window has passed: the active layout again, without waiting for the app.
  func endingRest() -> WatchWidgetSnapshot {
    var copy = self
    copy.phase = .active
    copy.restStartedAt = nil
    copy.restEndsAt = nil
    return copy
  }

  /// A snapshot nobody refreshed for this long (the app was killed mid-workout) is treated as idle.
  static let staleAfter: TimeInterval = 12 * 60 * 60
}

/// The App Group `UserDefaults` both targets share. The group is **new** (`group.com.khunor.lifey.watch`):
/// the phone's `group.com.khunor.lifey` is not available to a watchOS app, so register this one in the Apple
/// Developer portal and add it to the watch app's and the extension's entitlements (README, step 3).
enum WatchWidgetStore {
  static let suiteName = "group.com.khunor.lifey.watch"
  private static let key = "watch.widget.snapshot.v1"

  static func read(now: Date = Date()) -> WatchWidgetSnapshot {
    guard
      let defaults = UserDefaults(suiteName: suiteName),
      let data = defaults.data(forKey: key),
      let snapshot = try? JSONDecoder().decode(WatchWidgetSnapshot.self, from: data),
      now.timeIntervalSince(snapshot.updatedAt) < WatchWidgetSnapshot.staleAfter
    else { return .idle }
    return snapshot
  }

  /// Writes the snapshot and asks WidgetKit to reload (callers throttle — reloads are budgeted).
  static func write(_ snapshot: WatchWidgetSnapshot) {
    guard
      let defaults = UserDefaults(suiteName: suiteName),
      let data = try? JSONEncoder().encode(snapshot)
    else { return }
    defaults.set(data, forKey: key)
    #if canImport(WidgetKit)
      WidgetCenter.shared.reloadAllTimelines()
    #endif
  }
}
