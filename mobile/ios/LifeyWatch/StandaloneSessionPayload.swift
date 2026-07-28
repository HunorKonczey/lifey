import Foundation

/// One set logged during a standalone (phone-less) session — part of the
/// batch a `StandaloneSessionPayload` carries at the end
/// (docs/watch/44-watch-f6-standalone-plan.md §4.1). `reps` is always
/// `standaloneDefaultReps` (10) in F6a — the watch has no reps input yet
/// (D-F6.8) — but carried per-set already so a future watch-side stepper
/// (F5b/F6b) won't need a protocol change. `exerciseIndex` is nil in F6a (no
/// plan); F6b resolves it against the synced template's exercise list.
struct StandaloneSet: Codable, Equatable {
  let loggedAtEpochMs: Int64
  let reps: Int
  let exerciseIndex: Int?
}

/// The wire/persisted shape of a finished standalone (phone-less) workout
/// (docs/watch/44-watch-f6-standalone-plan.md §4.1) — everything
/// `StandaloneSessionStore` queues locally and `PhoneConnector` eventually
/// sends via `transferUserInfo`. Doesn't include the envelope's `type` key
/// (`"standaloneSessionCompleted"`) — that's added at send time (S8), not
/// persisted, since every queued payload is the same type.
///
/// `standaloneSessionId` becomes the resulting session's `clientId` on the
/// phone — the idempotency key for a retried delivery (§4.2, D-F6.2).
struct StandaloneSessionPayload: Codable, Equatable {
  let standaloneSessionId: String
  let templateId: String?
  let startedAtEpochMs: Int64
  let endedAtEpochMs: Int64
  let rpe: Int?
  let sets: [StandaloneSet]
  let activeCalories: Double?
  let averageHeartRate: Double?
  let healthWorkoutId: String?
}

/// The in-progress standalone session's own metadata, kept up to date on
/// every set so a process death/reboot mid-session can recover into it
/// (docs/watch/44-watch-f6-standalone-plan.md §3.2, `WorkoutManager`'s
/// recovery path — S9) instead of losing the workout entirely. Same fields
/// `StandaloneSessionPayload` will eventually carry, minus `endedAtEpochMs`/
/// `rpe`/the health-enrichment fields, which only exist once the session
/// actually ends.
struct StandaloneActiveSessionMeta: Codable, Equatable {
  let standaloneSessionId: String
  let templateId: String?
  let startedAtEpochMs: Int64
  var sets: [StandaloneSet]
}
