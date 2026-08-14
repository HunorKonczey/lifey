import ActivityKit
import Foundation

// Shared between Runner (starts/updates/ends activities via
// LiveActivityChannel.swift) and LifeyWidgets (renders them in
// WorkoutLiveActivity.swift). Add this file to BOTH targets' membership in
// Xcode — see docs/24-ios-widget-live-activity-plan.md, "Data Contracts".

@available(iOS 16.1, *)
struct WorkoutActivityAttributes: ActivityAttributes {
  struct ContentState: Codable, Hashable {
    var exerciseName: String
    var setsDone: Int
    var setsTotal: Int?
    var totalSetsDone: Int
    var lastSetAtEpochMs: Int64?
    // Rest-timer target end time (docs/39-rest-timer-plan.md, Prompt 5) —
    // nil when the rest timer is disabled, skipped, or already expired; the
    // Live Activity then falls back to the plain count-up from
    // lastSetAtEpochMs.
    var restEndsAtEpochMs: Int64?

    // Cardio (docs/cardio/59-cardio-implementation-plan.md C2.10b) — mirrors
    // `WorkoutSessionState.kind`/`activityType`/`cardio` (C2.9). `kind`
    // defaults to `"STRENGTH"` in `LiveActivityChannel`'s dict parsing, not
    // here: ActivityKit always round-trips a *complete* ContentState (it's
    // never partially decoded), so there's no "missing key" case for this
    // struct's own Codable synthesis to default — only the one-time JSON
    // dict handed across the MethodChannel can be missing a key, and that's
    // where the default belongs. A build that predates `kind` simply never
    // reads these three fields, which is exactly what keeps it on the
    // STRENGTH rendering path (see `exerciseName`'s doc comment on the Dart
    // side for why that degrades gracefully instead of crashing).
    var kind: String
    var activityType: String?
    var cardio: CardioLiveMetricsState?
  }

  var sessionClientId: String
  var title: String
  var startedAtEpochMs: Int64
}

/// Mirrors the Dart `CardioLiveMetrics` class
/// (`lib/core/workout_session_notifier/workout_session_notifier_service.dart`)
/// — three pre-formatted, pre-localized, unit-converted label/value pairs
/// plus the moving-time checkpoint that lets the Live Activity tick that one
/// quantity natively instead of the app pushing a JSON update every second
/// (docs/cardio/53-cardio-mobile-plan.md §5).
@available(iOS 16.1, *)
struct CardioLiveMetricsState: Codable, Hashable {
  var primaryLabel: String
  var primaryValue: String
  var secondaryLabel: String?
  var secondaryValue: String?
  var tertiaryLabel: String?
  var tertiaryValue: String?
  var paused: Bool
  var movingSecondsBase: Int?
  var movingSinceEpochMs: Int64?
}
