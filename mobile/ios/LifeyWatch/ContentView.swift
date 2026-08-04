import SwiftUI

/// Top-level watch screen — switches purely on `WorkoutManager.phase`
/// (docs/40-watch-app-plan.md §4.4, mirrors Android's `MainActivity`). All
/// the actual state syncing happens in `PhoneConnector`/`WorkoutManager`,
/// not here.
struct ContentView: View {
  @ObservedObject private var workoutManager = WorkoutManager.shared
  /// Whether `StandalonePickerView` is showing instead of the launcher,
  /// while `phase == .idle` (docs/watch/44-watch-f6-standalone-plan.md
  /// §3.1) — pure UI navigation, so it stays local here rather than on
  /// `WorkoutManager` (unlike `showEffortSelector` below, which the
  /// manager's own business logic needs to read and drive).
  @State private var showStandalonePicker = false

  var body: some View {
    switch workoutManager.phase {
    case .idle:
      if showStandalonePicker {
        StandalonePickerView(onBack: { showStandalonePicker = false })
      } else {
        IdleView(onStartTapped: { showStandalonePicker = true })
      }
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
