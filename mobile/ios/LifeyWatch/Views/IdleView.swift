import SwiftUI

/// No active session — docs/40-watch-app-plan.md §4.4 "IdleView" (mirrors
/// Android's `IdleScreen.kt`).
struct IdleView: View {
  var body: some View {
    VStack(spacing: 8) {
      Text("idle_title")
        .font(.headline)
      Text("idle_subtitle")
        .font(.caption)
        .multilineTextAlignment(.center)
    }
    .padding()
  }
}

#Preview {
  IdleView()
}
