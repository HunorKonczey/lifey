import SwiftUI

// MARK: - Effort (redesign X1.12 — AW1.20)

/// Rating content as plain data/callbacks so the gallery can render it. "Milyen nehéz volt?", the white
/// number with 10 segments (`EffortScale`), a primary "Edzés lezárása" pill, a real "Kihagyás" button (38 pt
/// visible, 44 pt target). Back is the navigation bar's button. The crown steps 1–10; no note is collected.
struct EffortContent: View {
  @Binding var rpe: Int
  var onConfirm: () -> Void = {}
  var onSkip: () -> Void = {}
  var onBack: () -> Void = {}

  @Environment(\.watchMetrics) private var metrics

  var body: some View {
    NavigationStack {
      // Scrollable only as a safety net: title + scale + confirm + skip should fit both faces, but a title
      // that wraps to two lines in a longer locale must never push "Kihagyás" out of reach.
      GeometryReader { geometry in
        ScrollView {
          VStack(spacing: LifeySpacing.md) {
            Text("effort_selector_title")
              .lifeyBodyBold(metrics)
              .foregroundColor(LifeyColors.text)
              .multilineTextAlignment(.center)
            EffortScale(value: $rpe)
            Button(action: onConfirm) {
              Text("effort_selector_confirm")
                .lifeyBodyBold(metrics)
                .foregroundColor(LifeyColors.onPrimary)
                .frame(maxWidth: .infinity, minHeight: metrics.minTouchTarget)
                .background(LifeyColors.primary, in: Capsule())
            }
            .buttonStyle(.plain)
            Button(action: onSkip) {
              Text("effort_selector_skip")
                .lifeyBody(metrics)
                .foregroundColor(LifeyColors.text)
                .frame(maxWidth: .infinity, minHeight: 38)
                .background(LifeyColors.control, in: Capsule())
                .frame(minHeight: metrics.minTouchTarget)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
          }
          .padding(.horizontal, metrics.sideMargin)
          .frame(maxWidth: .infinity, minHeight: geometry.size.height)
        }
      }
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button(action: onBack) { Image(systemName: "chevron.left") }
            .accessibilityLabel(Text("effort_selector_back"))
        }
      }
    }
  }
}

/// Shown over `ActiveWorkoutView` right after End is tapped, before anything is sent to the phone
/// (docs/40-watch-app-plan.md §8.2 decision (b)). Skip closes the workout with no rating; back dismisses this
/// screen without ending anything — `ActiveWorkoutView` resumes exactly as it was.
struct EffortSelectorView: View {
  @ObservedObject private var workoutManager = WorkoutManager.shared
  @State private var rpe = 5

  var body: some View {
    EffortContent(
      rpe: $rpe,
      onConfirm: { workoutManager.requestEnd(rpe: rpe) },
      onSkip: { workoutManager.requestEnd(rpe: nil) },
      onBack: { workoutManager.cancelEffortSelection() })
  }
}

#Preview {
  EffortSelectorView()
}
