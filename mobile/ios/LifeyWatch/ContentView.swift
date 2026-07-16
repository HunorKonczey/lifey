import SwiftUI

/// F0 spike placeholder — F2 replaces this with `ActiveWorkoutView`/
/// `IdleView` (docs/40-watch-app-plan.md §4.4).
struct ContentView: View {
    @ObservedObject private var lastLaunch = LastLaunchConfiguration.shared

    var body: some View {
        VStack(spacing: 8) {
            Text("Lifey")
                .font(.headline)
            if let raw = lastLaunch.activityTypeRawValue {
                Text("Workout config received (type \(raw))")
                    .font(.caption)
                    .multilineTextAlignment(.center)
            } else {
                Text("Indíts edzést a telefonon")
                    .font(.caption)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
