import SwiftUI

private let rpeMin = 1
private let rpeMax = 10

/// Shown over `ActiveWorkoutView` right after the End button is tapped,
/// before anything is sent to the phone (docs/40-watch-app-plan.md §8.2
/// decision (b) — the round-trip that actually stops the sensors is
/// unchanged, only *where* the effort rating is collected moves here
/// instead of the phone's own post-workout feedback sheet). A big stepper
/// rather than the phone's 10-chip row: a row of 10 numbered chips doesn't
/// fit legibly on a round dial. Skip closes the workout with no rating at
/// all — the note is never collected here either way, it always stays
/// empty for a watch-closed session. The back button (top-leading, out of
/// the centered VStack's flow) dismisses this screen without ending the
/// workout at all — nothing is sent to the phone, `ActiveWorkoutView` just
/// resumes exactly as it was.
struct EffortSelectorView: View {
  @ObservedObject private var workoutManager = WorkoutManager.shared
  @State private var rpe = 5

  var body: some View {
    GeometryReader { geometry in
      let isCompact = DynamicSizing.isCompact(width: geometry.size.width)
      let padding = geometry.size.width * DynamicSizing.screenPaddingFraction
      ZStack(alignment: .topLeading) {
        VStack(spacing: 8) {
          Text("effort_selector_title")
            .font(isCompact ? .caption : .body)
            .fontWeight(.bold)
            .foregroundColor(LifeyColors.onSurface)
            .multilineTextAlignment(.center)
          HStack(spacing: 16) {
            StepButton(systemImage: "minus") { rpe = max(rpeMin, rpe - 1) }
            Text("\(rpe)")
              .font(.system(size: isCompact ? 34 : 42, weight: .bold))
              .foregroundColor(LifeyColors.primary)
              .frame(minWidth: isCompact ? 40 : 50)
            StepButton(systemImage: "plus") { rpe = min(rpeMax, rpe + 1) }
          }
          .padding(.vertical, 4)
          Button(action: { workoutManager.requestEnd(rpe: rpe) }) {
            Text("effort_selector_confirm")
              .font(isCompact ? .caption : .body)
              .fontWeight(.semibold)
              .foregroundColor(LifeyColors.onPrimary)
              .frame(maxWidth: .infinity)
              .padding(.vertical, 8)
          }
          .background(LifeyColors.primary)
          .clipShape(Capsule())
          .buttonStyle(.plain)
          Button(action: { workoutManager.requestEnd(rpe: nil) }) {
            Text("effort_selector_skip")
              .font(.caption2)
              .foregroundColor(LifeyColors.onSurfaceVariant)
          }
          .buttonStyle(.plain)
          .padding(.top, 2)
        }
        .padding(.horizontal, padding)
        .frame(width: geometry.size.width, height: geometry.size.height)

        Button(action: { workoutManager.cancelEffortSelection() }) {
          Image(systemName: "chevron.left")
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(LifeyColors.onSurfaceVariant)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("effort_selector_back"))
      }
      .background(LifeyColors.trueBlack)
    }
  }
}

private struct StepButton: View {
  let systemImage: String
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Image(systemName: systemImage)
        .font(.system(size: 16, weight: .semibold))
        .foregroundColor(LifeyColors.onSurface)
        .frame(width: 32, height: 32)
        .background(LifeyColors.container)
        .clipShape(Circle())
    }
    .buttonStyle(.plain)
  }
}

#Preview {
  EffortSelectorView()
}
