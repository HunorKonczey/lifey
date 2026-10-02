import SwiftUI

// MARK: - Finish on the iPhone (redesign X1.13 — AW1.21)

/// Shown between the effort screen's Confirm/Skip and the phone's real `end` command coming back
/// (docs/40-watch-app-plan.md §12.1 B8, §8.2 decision (b)): the sensors keep recording underneath, this
/// screen just says the phone is finishing, not stuck. A left-aligned `StatusScreen` — `iphone` in `text`
/// (not green), a two-line title, the subtitle, and an indeterminate `ProgressView` that keeps moving
/// (also under Reduce Motion — it is the only sign of life) instead of three static dots.
struct EndingContent: View {
  @Environment(\.watchMetrics) private var metrics

  var body: some View {
    ScrollView {
      StatusScreen(
        icon: "iphone", iconTint: LifeyColors.text, title: String(localized: "ending_title"),
        subtitle: String(localized: "ending_subtitle")
      ) {
        ProgressView()
          .progressViewStyle(.linear)
          .tint(LifeyColors.text)
      }
    }
    .background(LifeyColors.bg)
  }
}

struct EndingView: View {
  var body: some View { EndingContent() }
}

#Preview {
  EndingView()
}
