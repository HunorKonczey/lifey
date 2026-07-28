import Foundation

/// Local persistence for standalone (phone-less) watch sessions
/// (docs/watch/44-watch-f6-standalone-plan.md §3.2) — two concerns:
/// - the **pending queue**: closed sessions not yet acked by the phone,
///   retried until `remove(id:)` is called on ack (§4.2);
/// - the **active session meta**: the currently-running standalone
///   session's own state, kept up to date on every set so a process
///   death/reboot can recover into it (`WorkoutManager`'s recovery path,
///   S9) instead of losing the in-progress workout.
///
/// Backed by two JSON files in `Application Support` (mirrors the phone
/// side's `SharedPreferences`-based `WatchSummaryBuffer` on Wear). All
/// access funnels through a private serial queue so a background-thread ack
/// (arriving on `WCSessionDelegate`'s callback queue) can't race a
/// foreground write from `WorkoutManager`.
final class StandaloneSessionStore {
  static let shared = StandaloneSessionStore()

  private let queue = DispatchQueue(label: "com.khunor.lifey.standaloneSessionStore")
  private let pendingURL: URL
  private let activeURL: URL

  private init() {
    let directory = FileManager.default.urls(
      for: .applicationSupportDirectory, in: .userDomainMask
    ).first!
    try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    pendingURL = directory.appendingPathComponent("standalone_sessions_pending.json")
    activeURL = directory.appendingPathComponent("standalone_session_active.json")
  }

  // MARK: - Pending queue (docs/watch/44-watch-f6-standalone-plan.md §3.2, §4.1)

  /// Queues a just-closed standalone session for delivery — `PhoneConnector`
  /// (S8) sends it and calls `remove(id:)` once the phone acks.
  func append(_ payload: StandaloneSessionPayload) {
    queue.sync {
      var pending = readPending()
      pending.append(payload)
      writePending(pending)
    }
  }

  /// Every not-yet-acked session, oldest first — `PhoneConnector` sends them
  /// in this order (§4.1: "a szinkron sorban küldi őket").
  func all() -> [StandaloneSessionPayload] {
    queue.sync { readPending() }
  }

  /// Removes the payload with this `standaloneSessionId` — called once the
  /// phone's `standaloneSessionAck` arrives for it (§4.2). A no-op if
  /// already removed (a duplicate ack, or one for an id never queued here).
  func remove(id: String) {
    queue.sync {
      var pending = readPending()
      pending.removeAll { $0.standaloneSessionId == id }
      writePending(pending)
    }
  }

  private func readPending() -> [StandaloneSessionPayload] {
    guard let data = try? Data(contentsOf: pendingURL) else { return [] }
    return (try? JSONDecoder().decode([StandaloneSessionPayload].self, from: data)) ?? []
  }

  private func writePending(_ pending: [StandaloneSessionPayload]) {
    guard let data = try? JSONEncoder().encode(pending) else { return }
    try? data.write(to: pendingURL, options: .atomic)
  }

  // MARK: - Active session meta (recovery — S9)

  /// Overwrites the live standalone session's recovery snapshot — called on
  /// start and after every locally logged set.
  func saveActive(_ meta: StandaloneActiveSessionMeta) {
    queue.sync {
      guard let data = try? JSONEncoder().encode(meta) else { return }
      try? data.write(to: activeURL, options: .atomic)
    }
  }

  /// The live standalone session's last-saved snapshot, or nil if none is
  /// running (or it already ended and `clearActive()` ran).
  func loadActive() -> StandaloneActiveSessionMeta? {
    queue.sync {
      guard let data = try? Data(contentsOf: activeURL) else { return nil }
      return try? JSONDecoder().decode(StandaloneActiveSessionMeta.self, from: data)
    }
  }

  /// Called once the session ends (successfully or via `reset()`) — an
  /// active-session file left behind would otherwise make the next launch
  /// think a session is still running.
  func clearActive() {
    queue.sync {
      try? FileManager.default.removeItem(at: activeURL)
    }
  }
}
