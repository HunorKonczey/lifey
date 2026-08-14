import Foundation

/// One set logged during a standalone (phone-less) session — part of the
/// batch a `StandaloneSessionPayload` carries at the end
/// (docs/watch/44-watch-f6-standalone-plan.md §4.1). `reps`/`weight` default
/// to `standaloneDefaultReps`/`nil` unless the F5b adjust stepper was used
/// (now wired up for standalone too — `WorkoutManager.beginLocalLogSet()`).
/// `exerciseIndex` is nil outside a template session; F6b resolves it
/// against the synced template's exercise list.
struct StandaloneSet: Codable, Equatable {
  let loggedAtEpochMs: Int64
  let reps: Int
  let weight: Double?
  let exerciseIndex: Int?
  /// The exercise's clientId, as the phone sent it in the session plan or the
  /// synced template (docs/watch/50-watch-f6c-session-plan-sync-plan.md) — the
  /// identity this set is attributed by, and what makes the exercise list free
  /// to change mid-session: a position means whatever the current list says, an
  /// id means the same exercise forever. Optional so a snapshot written by an
  /// older build still decodes; `exerciseIndex` stays alongside it as the
  /// fallback for exactly those sets and for an older phone build.
  var exerciseId: String?
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

/// The live-bridging counterpart of `StandaloneSessionPayload` — a snapshot
/// of a watch-started session that is still *running*, sent as soon as the
/// phone is (or becomes) reachable so it can mirror the workout live instead
/// of only importing it once it ends (`WorkoutManager
/// .sendAdoptionRequestIfNeeded()`). No `endedAtEpochMs`/`rpe`/
/// `healthWorkoutId` — the workout isn't over. `standaloneSessionId` is the
/// same id the eventual `StandaloneSessionPayload` will carry when it
/// finishes, which is what lets the phone's processor recognize "this
/// session already has a running row, finish it" instead of creating a
/// duplicate.
struct StandaloneAdoptionPayload: Codable, Equatable {
  let standaloneSessionId: String
  let templateId: String?
  let startedAtEpochMs: Int64
  let sets: [StandaloneSet]
  let activeCalories: Double?
  let averageHeartRate: Double?
  /// Which of the template's exercises the *next* set will count against —
  /// `standaloneExerciseIndex`, i.e. the same index space `StandaloneSet
  /// .exerciseIndex` uses. Unlike a set's index this describes the future,
  /// and the watch is the only one who knows it: it advances on its own once
  /// an exercise has all its planned sets (`advanceStandaloneExerciseIfComplete`),
  /// while the phone's own rule ("the exercise of the most recently logged
  /// set") still points at the finished one. Without it the phone computed
  /// its `nextSetReps`/`nextSetWeight` prefill — which the watch prefers over
  /// its own (`standalonePrefill`) — against the wrong exercise entirely.
  /// `nil` for a Quick strength session, where there's no plan to index into.
  let currentExerciseIndex: Int?
  /// The same answer by clientId (F6c) — preferred by the phone, since it
  /// survives a mid-session plan change and can name an exercise the template
  /// never had (one added to the session on the phone).
  let currentExerciseId: String?
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
  /// The **full snapshot**, not just an id (docs/watch/
  /// 49-watch-f6b-template-sync-plan.md §3.3, T6) — recovery has to restore
  /// the exact template the session started with, not re-resolve the id
  /// against whatever the cache holds by the time the app relaunches (which
  /// could differ if a `templateSync` landed while the process was dead).
  /// `nil` for a Quick strength session, same as before.
  let template: CachedTemplate?
  /// Which exercise new sets currently log against — meaningless (and
  /// unread) when `template` is nil. Not optional: always 0 for a
  /// Quick-strength session, just like the live `standaloneExerciseIndex`.
  var exerciseIndex: Int
  /// The phone's live session plan as it stood at the last save (F6c), when
  /// one had arrived — restored with the session so [exerciseIndex] still
  /// means a position in the *same* list after a process death. Without it a
  /// recovered session would read a plan position as a template position, and
  /// land on whatever exercise happened to sit there. Optional so a snapshot
  /// written before F6c (or by a phone-less session) still decodes.
  var sessionPlan: [CachedTemplateExercise]?
  let startedAtEpochMs: Int64
  var sets: [StandaloneSet]
}

/// One exercise of a synced template, exactly as the phone resolved it
/// (docs/watch/49-watch-f6b-template-sync-plan.md §4.1, D-F6b.4) —
/// `restSeconds` is never nil here, unlike `TemplateExercise` on the phone:
/// the watch knows neither the `Exercises` table nor `UserSettings`, so the
/// phone always sends a concrete number instead of a nullable override.
struct CachedTemplateExercise: Codable, Equatable {
  let exerciseId: String
  let name: String
  let restSeconds: Int
  let targetSets: Int?
  /// How many sets the **session** already has for this exercise, counting
  /// both devices' — only ever present when this entry came from the phone's
  /// live session plan (F6c); a synced template has no such thing. The watch
  /// takes the larger of this and its own count, exactly the reconciliation
  /// `setsDonePerExercise` did before.
  let setsDone: Int?
  /// What was logged for this exercise the last time it was trained,
  /// heaviest first, as the phone resolved it (`previousSetsFor` in
  /// `watch_template_sync.dart`) — a standalone session's stand-in for the
  /// `nextSetReps`/`nextSetWeight` prefill a phone-mastered session receives
  /// on every state sync (48-doc D-F5b.2). Without it the watch could only
  /// open its stepper on a hardcoded 10 reps / no weight. Optional rather
  /// than a defaulted array so a cache written by an older build (no such
  /// key) still decodes instead of throwing the whole template list away.
  let previousSets: [CachedPreviousSet]?
}

/// One set of [CachedTemplateExercise.previousSets].
struct CachedPreviousSet: Codable, Equatable {
  let weight: Double
  let reps: Int
}

/// The phone's live session plan (docs/watch/50-watch-f6c-session-plan-sync-plan.md)
/// — the session's *own* exercise list, which is what the watch shows and logs
/// against once it arrives, in place of the template snapshot the session
/// started from. Decoded from the `sessionPlan` JSON string in the state
/// payload; a string rather than a nested structure because the Wear side's
/// DataItem transport carries only flat values, and one shape for both
/// platforms is worth more than a marginally tidier iOS payload.
struct SessionPlan: Codable, Equatable {
  let exercises: [CachedTemplateExercise]
}

/// A template as cached on the watch for the standalone picker
/// (docs/watch/49-watch-f6b-template-sync-plan.md §3.1, T4.1) — the watch's
/// own copy of `WatchTemplatePayload` (mobile/lib/features/workouts/
/// application/watch_template_sync.dart), decoded once out of the
/// `applicationContext`'s `templates` array and persisted by
/// `StandaloneSessionStore`. `exercises`' array position is what a
/// standalone session's `exerciseIndex` refers back to (§4.1) — the watch
/// never sends `exerciseId` itself on the wire, only the index.
struct CachedTemplate: Codable, Equatable {
  let templateId: String
  let title: String
  let exercises: [CachedTemplateExercise]
}

/// One row of the unified, frequency-ranked quick-start list
/// (docs/cardio/55-cardio-watch-plan.md §3.2, C5.3/C5.4) — the watch's own
/// counterpart of Dart's `WatchQuickStartEntryPayload`
/// (mobile/lib/features/workouts/application/watch_template_sync.dart): a
/// synced template exactly as before (`CachedTemplate`, unchanged), or a
/// cardio activity type with no plan behind it. Order matters and is never
/// re-derived here — the phone already ranked the list
/// (`rankQuickStartEntries()`, D-C5.3's "nem másol logikát, és nem talál ki
/// saját rendezést"), so `StandaloneSessionStore`/`StandalonePickerView` both
/// preserve whatever order they're handed.
///
/// Manual `Codable`, not the synthesized enum-with-associated-values form:
/// the wire/persisted shape is a flat dict with a `type` discriminator
/// (`"TEMPLATE"`/`"CARDIO"`), matching the Dart `toJson()` shape exactly, not
/// Swift's own tagged-union JSON encoding.
enum WatchQuickStartEntry: Equatable {
  case template(CachedTemplate)
  /// [title] is pre-localized on the phone (55-doc §3.2) — the watch needs
  /// no activity-type dictionary of its own, same as a template's title
  /// already was.
  case cardio(activityType: String, title: String)
}

extension WatchQuickStartEntry: Codable {
  private enum CodingKeys: String, CodingKey {
    case type, templateId, title, exercises, activityType
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    switch try container.decode(String.self, forKey: .type) {
    case "TEMPLATE":
      let templateId = try container.decode(String.self, forKey: .templateId)
      let title = try container.decode(String.self, forKey: .title)
      // `exerciseCount` (a Dart-side convenience the watch never reads, since
      // `exercises.count` is right there) is simply absent from
      // [CodingKeys] — Codable ignores JSON keys it wasn't asked to decode.
      let exercises =
        try container.decodeIfPresent([CachedTemplateExercise].self, forKey: .exercises) ?? []
      self = .template(CachedTemplate(templateId: templateId, title: title, exercises: exercises))
    case "CARDIO":
      let activityType = try container.decode(String.self, forKey: .activityType)
      let title = try container.decode(String.self, forKey: .title)
      self = .cardio(activityType: activityType, title: title)
    default:
      // A future entry type this build doesn't know — costs this one row,
      // not the whole list (the caller decodes entries one at a time and
      // `compactMap`s away failures, `PhoneConnector.applyTemplateSync`'s
      // usual "a malformed entry costs that entry" rule).
      throw DecodingError.dataCorruptedError(
        forKey: .type, in: container, debugDescription: "Unknown quick-start entry type")
    }
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    switch self {
    case .template(let template):
      try container.encode("TEMPLATE", forKey: .type)
      try container.encode(template.templateId, forKey: .templateId)
      try container.encode(template.title, forKey: .title)
      try container.encode(template.exercises, forKey: .exercises)
    case .cardio(let activityType, let title):
      try container.encode("CARDIO", forKey: .type)
      try container.encode(activityType, forKey: .activityType)
      try container.encode(title, forKey: .title)
    }
  }
}
