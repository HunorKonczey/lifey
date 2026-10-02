import Combine
import Foundation

/// Watch **app** target only (not the extension): turns `WorkoutManager`'s published state into
/// `WatchWidgetSnapshot`s for the widgets. Observation only — `WorkoutManager` itself is not edited; the
/// single hook is `WatchWidgetPublisher.shared.start(observing:)` (README, step 5).
///
/// WidgetKit reloads are budgeted, so a write happens only when something the widgets *show structurally*
/// changed (phase, names, set counts, rest window, pause), when the heart rate moved by 5 bpm or more, or
/// when a minute has passed since the last write. Live timers need no writes at all.
@MainActor
final class WatchWidgetPublisher {
  static let shared = WatchWidgetPublisher()

  private var cancellable: AnyCancellable?
  private var last: WatchWidgetSnapshot?

  func start(observing manager: WorkoutManager) {
    cancellable = manager.objectWillChange
      // `objectWillChange` fires before the change lands; the debounce lets the values settle.
      .debounce(for: .milliseconds(400), scheduler: RunLoop.main)
      .sink { [weak self, weak manager] _ in
        guard let self, let manager else { return }
        self.publish(Self.snapshot(from: manager))
      }
    publish(Self.snapshot(from: manager))
  }

  static func snapshot(from manager: WorkoutManager) -> WatchWidgetSnapshot {
    let now = Date()
    var restStartedAt: Date?
    var restEndsAt: Date?
    // `restDeadlineUptime` is anchored to `systemUptime`, never wall-clock — convert it for the extension.
    if let deadline = manager.restDeadlineUptime {
      let remaining = deadline - ProcessInfo.processInfo.systemUptime
      if remaining > 0 {
        let ends = now.addingTimeInterval(remaining)
        restEndsAt = ends
        restStartedAt = manager.restTotalSeconds.map { ends.addingTimeInterval(-Double($0)) } ?? now
      }
    }
    let isActive: Bool
    if case .active = manager.phase { isActive = true } else { isActive = false }
    guard isActive else { return .idle }
    return WatchWidgetSnapshot(
      phase: restEndsAt == nil ? .active : .resting,
      title: manager.title,
      exerciseName: manager.exerciseName,
      setsDone: manager.setsDone,
      setsTotal: manager.setsTotal,
      startedAt: manager.startedAt,
      heartRateBpm: manager.heartRateBpm.map { Int($0.rounded()) },
      restStartedAt: restStartedAt,
      restEndsAt: restEndsAt,
      isPaused: manager.isPaused,
      updatedAt: now)
  }

  private func publish(_ snapshot: WatchWidgetSnapshot) {
    if let last, !Self.shouldWrite(old: last, new: snapshot) { return }
    last = snapshot
    WatchWidgetStore.write(snapshot)
  }

  static func shouldWrite(old: WatchWidgetSnapshot, new: WatchWidgetSnapshot) -> Bool {
    var a = old
    var b = new
    // Compare everything except the volatile fields…
    let heartMoved = abs((a.heartRateBpm ?? 0) - (b.heartRateBpm ?? 0)) >= 5
    let minutePassed = b.updatedAt.timeIntervalSince(a.updatedAt) >= 60
    a.heartRateBpm = nil
    b.heartRateBpm = nil
    a.updatedAt = b.updatedAt
    return a != b || heartMoved || minutePassed
  }
}
