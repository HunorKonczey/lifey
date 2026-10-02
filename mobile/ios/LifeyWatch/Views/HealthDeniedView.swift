import SwiftUI

// MARK: - Health access denied (redesign X2.10 — AW2.17, AW2.18)

/// "Allow Health access" (docs/40-watch-app-plan.md §12.1 B10): shown when the workout session could not
/// start because Health access is missing. The left-aligned `StatusScreen`: a bare 26 pt `waveform.path.ecg`,
/// a title of at most two lines, the subtitle, and the "Engedélyek áttekintése" **control** button above the
/// fold — it only steps back (there is no Settings API on watchOS). In a longer locale or at a larger text
/// size the page scrolls and the button is at the end.
struct HealthDeniedContent: View {
  var onDismiss: () -> Void = {}

  var body: some View {
    ScrollView {
      StatusScreen(
        icon: "waveform.path.ecg", title: String(localized: "health_denied_title"),
        subtitle: String(localized: "health_denied_subtitle"),
        buttonTitle: String(localized: "health_denied_button"), onButton: onDismiss)
    }
    .background(LifeyColors.bg)
  }
}

struct HealthDeniedView: View {
  @ObservedObject private var workoutManager = WorkoutManager.shared

  var body: some View {
    HealthDeniedContent(onDismiss: { workoutManager.dismissError() })
  }
}

#Preview {
  HealthDeniedView()
}
