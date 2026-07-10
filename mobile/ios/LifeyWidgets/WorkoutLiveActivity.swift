import ActivityKit
import SwiftUI
import WidgetKit

// Lock screen + Dynamic Island UI for a running workout. See
// docs/24-ios-widget-live-activity-plan.md, "Live Activity UI". Reuses
// `Palette` from TodaySummaryWidget.swift for the app's light/dark colors.

@available(iOS 16.1, *)
struct WorkoutLiveActivity: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: WorkoutActivityAttributes.self) { context in
      LockScreenView(attributes: context.attributes, state: context.state)
        .padding(16)
        .activityBackgroundTint(Color(red: 0x16 / 255, green: 0x16 / 255, blue: 0x11 / 255))
        .activitySystemActionForegroundColor(.white)
    } dynamicIsland: { context in
      DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          ElapsedTimerView(startedAtEpochMs: context.attributes.startedAtEpochMs)
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(.white)
        }
        DynamicIslandExpandedRegion(.trailing) {
          RestTimerView(lastSetAtEpochMs: context.state.lastSetAtEpochMs)
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(.white)
        }
        DynamicIslandExpandedRegion(.bottom) {
          ExerciseProgressView(state: context.state)
            .foregroundColor(.white)
        }
      } compactLeading: {
        Image(systemName: "dumbbell.fill")
      } compactTrailing: {
        RestTimerView(lastSetAtEpochMs: context.state.lastSetAtEpochMs)
          .font(.system(size: 13, weight: .semibold))
      } minimal: {
        Image(systemName: "dumbbell.fill")
      }
      .widgetURL(URL(string: "lifey://today"))
    }
  }
}

// MARK: - Timers
// Per the plan's Key Design Decision #4: SwiftUI renders these natively —
// no push/update needed while backgrounded. Both count *up* (open-ended
// range to .distantFuture, countsDown: false) since there's no fixed rest
// duration in the current data model.

@available(iOS 16.1, *)
private struct ElapsedTimerView: View {
  let startedAtEpochMs: Int64

  var body: some View {
    let start = Date(timeIntervalSince1970: Double(startedAtEpochMs) / 1000)
    Text(timerInterval: start...Date.distantFuture, countsDown: false, showsHours: true)
      .monospacedDigit()
  }
}

@available(iOS 16.1, *)
private struct RestTimerView: View {
  let lastSetAtEpochMs: Int64?

  var body: some View {
    if let lastSetAtEpochMs {
      let start = Date(timeIntervalSince1970: Double(lastSetAtEpochMs) / 1000)
      HStack(spacing: 4) {
        Image(systemName: "hourglass")
        Text(timerInterval: start...Date.distantFuture, countsDown: false, showsHours: false)
          .monospacedDigit()
      }
    }
    // Hidden before the first set — no lastSetAtEpochMs yet.
  }
}

// MARK: - Exercise + set progress

@available(iOS 16.1, *)
private struct ExerciseProgressView: View {
  let state: WorkoutActivityAttributes.ContentState

  private var setsLabel: String {
    if let total = state.setsTotal {
      return "\(state.setsDone)/\(total)"
    }
    return "\(state.setsDone)"
  }

  var body: some View {
    HStack {
      Text(state.exerciseName)
        .font(.system(size: 13, weight: .semibold))
        .lineLimit(1)
      Spacer()
      Text(setsLabel)
        .font(.system(size: 13, weight: .medium))
        .opacity(0.75)
    }
  }
}

// MARK: - Lock screen

@available(iOS 16.1, *)
private struct LockScreenView: View {
  let attributes: WorkoutActivityAttributes
  let state: WorkoutActivityAttributes.ContentState

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Text(attributes.title)
          .font(.system(size: 15, weight: .bold))
          .foregroundColor(.white)
        Spacer()
        ElapsedTimerView(startedAtEpochMs: attributes.startedAtEpochMs)
          .font(.system(size: 15, weight: .bold))
          .foregroundColor(.white)
      }
      ExerciseProgressView(state: state)
        .foregroundColor(.white.opacity(0.9))
      if state.lastSetAtEpochMs != nil {
        RestTimerView(lastSetAtEpochMs: state.lastSetAtEpochMs)
          .font(.system(size: 13, weight: .medium))
          .foregroundColor(.white.opacity(0.7))
      }
    }
  }
}
