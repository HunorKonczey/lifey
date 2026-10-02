import SwiftUI

/// Stepper (frame 04/08): 44 pt ± circles inside the side margin, the value in PJS between them with a
/// unit line under it. The crown steps one value per detent; a reached bound ghosts its button. A 4-character
/// value ("102,5") may shrink to 85 % but is never truncated (AW1.11).
struct ValueStepper: View {
  @Binding var value: Double
  let range: ClosedRange<Double>
  let step: Double
  /// "8", "62,5" — the caller's locale-aware formatter.
  let format: (Double) -> String
  var unit: String? = nil
  /// Clay for the adjust header / icon accents; nil = `text`.
  var accent: Color? = nil

  @Environment(\.watchMetrics) private var metrics
  @State private var crown = 0.0

  private var atMin: Bool { value <= range.lowerBound }
  private var atMax: Bool { value >= range.upperBound }

  var body: some View {
    HStack(spacing: LifeySpacing.md) {
      stepButton(icon: "minus", delta: -step, ghosted: atMin)
      VStack(spacing: LifeySpacing.xxs) {
        Text(verbatim: format(value))
          .lifeyMetric(metrics)
          .foregroundColor(accent ?? LifeyColors.text)
          .lineLimit(1)
          .minimumScaleFactor(0.85)
        if let unit {
          Text(verbatim: unit).lifeyLabel(metrics).foregroundColor(LifeyColors.text2)
        }
      }
      .frame(maxWidth: .infinity)
      stepButton(icon: "plus", delta: step, ghosted: atMax)
    }
    .focusable()
    .digitalCrownRotation(
      $crown, from: range.lowerBound / step, through: range.upperBound / step, by: 1,
      sensitivity: .high, isContinuous: false, isHapticFeedbackEnabled: true
    )
    .onChange(of: crown) { _, newValue in
      let stepped = (newValue.rounded()) * step
      if abs(stepped - value) >= step / 2 { value = min(max(stepped, range.lowerBound), range.upperBound) }
    }
    .onAppear { crown = value / step }
  }

  private func stepButton(icon: String, delta: Double, ghosted: Bool) -> some View {
    Button {
      value = min(max(value + delta, range.lowerBound), range.upperBound)
      crown = value / step
      LifeyHaptics.stepperTick()
    } label: {
      Image(systemName: icon)
        .font(.system(size: 16, weight: .bold))
        .foregroundColor(ghosted ? LifeyColors.ghost : LifeyColors.text)
        .frame(width: metrics.minTouchTarget, height: metrics.minTouchTarget)
        .background(ghosted ? LifeyColors.card : LifeyColors.control, in: Circle())
    }
    .buttonStyle(.plain)
    .disabled(ghosted)
  }
}
