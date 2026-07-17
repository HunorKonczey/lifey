import SwiftUI

/// "Allow Health access" (docs/40-watch-app-plan.md §12.1 B10): shown when
/// `WorkoutManager.start(configuration:)` finds HealthKit sharing denied for
/// the workout type, instead of silently falling back to `IdleView` (the
/// earlier behavior the doc's §9 test matrix documented). The "Review
/// access" button doesn't deep-link to Settings — watchOS has no public API
/// for that — it just dismisses back to `IdleView`
/// (`WorkoutManager.dismissError()`), the "minimum: instruction + dismiss →
/// IDLE" the 42-doc's D1.2/W5 settled on. Styling (§12.1 B6) matches canvas
/// frame AW 07: the ECG glyph is `onSurfaceVariant` (muted, informational),
/// not `negative` — this is a permission prompt, not an alarm.
struct HealthDeniedView: View {
  @ObservedObject private var workoutManager = WorkoutManager.shared

  var body: some View {
    GeometryReader { geometry in
      let isCompact = DynamicSizing.isCompact(width: geometry.size.width)
      let padding = geometry.size.width * DynamicSizing.screenPaddingFraction
      VStack(spacing: 10) {
        Image(systemName: "waveform.path.ecg")
          .font(.system(size: isCompact ? 38 : 44))
          .foregroundColor(LifeyColors.onSurfaceVariant)
        Text("health_denied_title")
          .font(isCompact ? .caption : .body)
          .fontWeight(.bold)
          .foregroundColor(LifeyColors.onSurface)
          .multilineTextAlignment(.center)
        Text("health_denied_subtitle")
          .font(isCompact ? .caption2 : .caption)
          .foregroundColor(LifeyColors.onSurfaceVariant)
          .multilineTextAlignment(.center)
        Button("health_denied_button") {
          workoutManager.dismissError()
        }
        .font(isCompact ? .caption : .body)
        .fontWeight(.bold)
        .foregroundColor(LifeyColors.onSurface)
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(LifeyColors.containerHighest)
        .clipShape(Capsule())
      }
      .padding(.horizontal, padding)
      .frame(width: geometry.size.width, height: geometry.size.height)
      .background(LifeyColors.trueBlack)
    }
  }
}

#Preview {
  HealthDeniedView()
}
