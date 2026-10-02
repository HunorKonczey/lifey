import SwiftUI

/// Cardio field (frame 04/15, Apple): one row — the value left (PJS `value`), the phone-supplied label
/// right (CAPS `label`, wraps to two lines, never below 80 % scale). Labels are variable-length text.
struct CardioField: View {
  let value: String
  let label: String

  @Environment(\.watchMetrics) private var metrics

  var body: some View {
    HStack(alignment: .center, spacing: LifeySpacing.md) {
      Text(verbatim: value)
        .lifeyValue(metrics)
        .foregroundColor(LifeyColors.text)
        .lineLimit(1)
        .layoutPriority(1)
      Spacer(minLength: 0)
      Text(verbatim: label)
        .lifeyLabel(metrics, caps: true)
        .foregroundColor(LifeyColors.text2)
        .lineLimit(2)
        .minimumScaleFactor(0.8)
        .multilineTextAlignment(.trailing)
    }
    .padding(.horizontal, LifeySpacing.lg)
    .frame(minHeight: 40)
    .background(LifeyColors.card, in: RoundedRectangle(cornerRadius: LifeyShapes.control))
  }
}
