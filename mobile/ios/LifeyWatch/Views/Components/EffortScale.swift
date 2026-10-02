import SwiftUI

/// Effort scale (frame 04/11): a `ValueStepper` 1–10 plus a 10-segment bar. The number is white — effort
/// has no metric colour. The "Kihagyás" skip button and the confirm button belong to the screen (X1.12).
struct EffortScale: View {
  @Binding var value: Int

  @Environment(\.watchMetrics) private var metrics

  var body: some View {
    VStack(spacing: LifeySpacing.md) {
      ValueStepper(
        value: Binding(get: { Double(value) }, set: { value = Int($0.rounded()) }),
        range: 1...10, step: 1, format: { "\(Int($0))" })
      HStack(spacing: LifeySpacing.xxs) {
        ForEach(1...10, id: \.self) { index in
          Capsule()
            .fill(index <= value ? LifeyColors.text : LifeyColors.raised)
            .frame(height: 6)
        }
      }
      .accessibilityHidden(true)
    }
  }
}
