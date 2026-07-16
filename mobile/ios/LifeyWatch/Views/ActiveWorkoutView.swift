import SwiftUI

/// Live workout screen — elapsed time, heart rate, calories, current
/// exercise/set counter, rest-timer countdown (docs/40-watch-app-plan.md
/// §4.4 "ActiveWorkoutView", mirrors Android's `ActiveWorkoutScreen.kt`).
/// The rest-end haptic is scheduled independently in `WorkoutManager`, not
/// here — it needs to fire even while this view isn't on screen. The End
/// button only *asks* the phone to close the session (§8.2 decision (b)) —
/// it never calls `WorkoutManager.finishAndSendSummary()` directly.
struct ActiveWorkoutView: View {
  @ObservedObject private var workoutManager = WorkoutManager.shared

  var body: some View {
    TimelineView(.periodic(from: .now, by: 1)) { context in
      VStack(spacing: 4) {
        Text(elapsedText(now: context.date))
          .font(.system(.title2, design: .rounded))
        Text(workoutManager.exerciseName ?? String(localized: "active_default_exercise"))
          .font(.body)
        if let setsDone = workoutManager.setsDone, let setsTotal = workoutManager.setsTotal {
          Text(
            String(
              format: String(localized: "active_sets_format"), setsDone, setsTotal)
          )
          .font(.caption)
        }
        if let restText = restText(now: context.date) {
          Text(restText)
            .font(.caption)
        }
        HStack(spacing: 8) {
          if let heartRate = workoutManager.heartRateBpm {
            Text("\(Int(heartRate.rounded())) \(String(localized: "active_heart_rate_unit"))")
              .font(.caption2)
          }
          if let calories = workoutManager.activeCalories {
            Text("\(Int(calories.rounded())) \(String(localized: "active_calories_unit"))")
              .font(.caption2)
          }
        }
        Button("active_end_button") {
          workoutManager.requestEnd()
        }
      }
      .padding()
    }
  }

  private func elapsedText(now: Date) -> String {
    guard let startedAt = workoutManager.startedAt else { return "00:00" }
    return format(seconds: max(0, now.timeIntervalSince(startedAt)))
  }

  private func restText(now: Date) -> String? {
    guard let restEndsAtEpochMs = workoutManager.restEndsAtEpochMs else { return nil }
    let remaining = Double(restEndsAtEpochMs) / 1000 - now.timeIntervalSince1970
    guard remaining > 0 else { return nil }
    return String(format: String(localized: "active_rest_format"), format(seconds: remaining))
  }

  private func format(seconds: TimeInterval) -> String {
    let total = Int(seconds)
    return String(format: "%02d:%02d", total / 60, total % 60)
  }
}

#Preview {
  ActiveWorkoutView()
}
