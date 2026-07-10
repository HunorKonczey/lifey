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
  }

  var sessionClientId: String
  var title: String
  var startedAtEpochMs: Int64
}
