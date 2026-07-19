import SwiftUI

/// Top-level watch screen — switches purely on `WorkoutManager.phase`
/// (docs/40-watch-app-plan.md §4.4, mirrors Android's `MainActivity`). All
/// the actual state syncing happens in `PhoneConnector`/`WorkoutManager`,
/// not here.
struct ContentView: View {
  @ObservedObject private var workoutManager = WorkoutManager.shared

  var body: some View {
    switch workoutManager.phase {
    case .idle:
      IdleView()
    case .active:
      if workoutManager.showEffortSelector {
        EffortSelectorView()
      } else {
        ActiveWorkoutView()
      }
    case .ending:
      EndingView()
    case .summary(let data):
      SummaryView(data: data)
    case .healthDenied:
      HealthDeniedView()
    }
  }
}

#Preview {
  ContentView()
}
