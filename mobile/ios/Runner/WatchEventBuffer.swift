import Foundation

/// Buffers watch → phone `transferUserInfo` deliveries that arrived before
/// Flutter attached the `lifey/watch/events` `EventChannel` — see
/// `WatchBridge.bufferOrEmit(_:)` for why that happens at all. `WatchBridge`
/// drains this on `onListen`.
///
/// The iOS counterpart of Android's `WatchSummaryBuffer` /
/// `WatchStandaloneSessionBuffer` / `WatchAdoptionBuffer` — one store rather
/// than three, since the buffered dictionaries already carry their own
/// `type` key and are re-emitted verbatim, so nothing here needs to know
/// which is which.
///
/// `UserDefaults`, not an in-memory array: `WCSession` can deliver during a
/// background launch that the OS then terminates without Dart ever running,
/// and an in-memory buffer would lose the payload exactly the way the
/// unbuffered code did. Property-list types only, which every payload here
/// already is (that's `PhoneConnector`'s `propertyListDictionary` guarantee
/// on the watch side).
enum WatchEventBuffer {
  private static let key = "lifey_watch_pending_events"

  /// Beyond this many queued events the oldest are dropped. Only reachable
  /// if the phone app hasn't run for a very long time, and the payloads are
  /// snapshots rather than increments — the newest of each kind supersedes
  /// its predecessors — so dropping the oldest loses nothing that the
  /// remaining ones don't already say.
  private static let maxBufferedEvents = 32

  static func add(_ event: [String: Any]) {
    var pending = (UserDefaults.standard.array(forKey: key) as? [[String: Any]]) ?? []
    pending.append(event)
    if pending.count > maxBufferedEvents {
      pending.removeFirst(pending.count - maxBufferedEvents)
    }
    UserDefaults.standard.set(pending, forKey: key)
  }

  /// Returns the buffered events in arrival order and clears the buffer.
  static func drain() -> [[String: Any]] {
    let pending = (UserDefaults.standard.array(forKey: key) as? [[String: Any]]) ?? []
    if !pending.isEmpty {
      UserDefaults.standard.removeObject(forKey: key)
    }
    return pending
  }
}
