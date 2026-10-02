import SwiftUI

/// Summary tile (frame 04/12): a PJS `metric` number with a one-line `text2` label ("átlag bpm"). The
/// number counts up over 600 ms when it appears (summary tiles only — ticking numbers never animate).
struct SummaryTile: View {
  let number: Double
  let format: (Double) -> String
  let label: String
  var tint: Color = LifeyColors.text

  @Environment(\.watchMetrics) private var metrics
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var shown = 0.0

  var body: some View {
    VStack(alignment: .leading, spacing: LifeySpacing.xxs) {
      CountUpText(value: shown, format: format)
        .lifeyMetric(metrics)
        .foregroundColor(tint)
        .lineLimit(1)
        .minimumScaleFactor(0.85)
      Text(verbatim: label).lifeyLabel(metrics).foregroundColor(LifeyColors.text2).lineLimit(1)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(LifeySpacing.md)
    .background(LifeyColors.nested, in: RoundedRectangle(cornerRadius: LifeyShapes.card))
    .onAppear {
      if reduceMotion { shown = number; return }
      withAnimation(LifeyMotion.standard(LifeyMotion.Duration.countUp)) { shown = number }
    }
  }
}

/// A number that interpolates through SwiftUI's animation, so the count-up actually counts.
private struct CountUpText: View, Animatable {
  var value: Double
  let format: (Double) -> String

  var animatableData: Double {
    get { value }
    set { value = newValue }
  }

  var body: some View { Text(verbatim: format(value)) }
}

/// Sync row (frame 04/12) under the standalone summary's title: pending (`nested`, sync glyph, title and
/// a "n edzés vár szinkronizálásra" second line) or synced (success tint). The tint switches in 250 ms.
struct SyncRow: View {
  let isSynced: Bool
  let title: String
  var subtitle: String? = nil

  @Environment(\.watchMetrics) private var metrics
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    HStack(spacing: LifeySpacing.md) {
      Image(systemName: isSynced ? "checkmark.icloud" : "icloud.and.arrow.up")
        .font(.system(size: 16, weight: .semibold))
      VStack(alignment: .leading, spacing: LifeySpacing.xxs) {
        Text(verbatim: title).lifeyBody(metrics).lineLimit(2).multilineTextAlignment(.leading)
        if let subtitle, !isSynced {
          Text(verbatim: subtitle).lifeyLabel(metrics).foregroundColor(LifeyColors.text2).lineLimit(2)
        }
      }
      Spacer(minLength: 0)
    }
    .foregroundColor(isSynced ? LifeyColors.success : LifeyColors.text)
    .padding(.horizontal, LifeySpacing.lg)
    .padding(.vertical, LifeySpacing.md)
    .background(
      isSynced ? LifeyColors.tint(LifeyColors.success) : LifeyColors.nested,
      in: RoundedRectangle(cornerRadius: LifeyShapes.card)
    )
    .animation(
      LifeyMotion.animation(LifeyMotion.standard(LifeyMotion.Duration.tintSwitch), reduceMotion: reduceMotion),
      value: isSynced)
  }
}
