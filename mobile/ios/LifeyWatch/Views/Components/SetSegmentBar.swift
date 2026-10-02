import SwiftUI

/// Set segment bar (frame 04/03): segments instead of dots, readable up to 8 sets, card width.
/// Done = `text`, just logged = `success` (for 1.2 s, driven by the caller), remaining = `raised`. The
/// "2/4" text sits beside it. A session without a plan (quick strength) shows no bar, only the text
/// "3. szett · 24 ism." that the caller supplies as `freeFormText`.
struct SetSegmentBar: View {
  let done: Int
  let total: Int
  /// The segment that was just logged (0-based) turns `success`; `nil` when none.
  var justLoggedIndex: Int? = nil
  /// Quick strength has no plan: only this text is shown.
  var freeFormText: String? = nil

  @Environment(\.watchMetrics) private var metrics

  var body: some View {
    if let freeFormText {
      Text(verbatim: freeFormText)
        .lifeyBody(metrics)
        .foregroundColor(LifeyColors.text2)
        .lineLimit(2)
    } else {
      HStack(spacing: LifeySpacing.sm) {
        HStack(spacing: LifeySpacing.xxs) {
          ForEach(0..<max(total, 0), id: \.self) { index in
            Capsule()
              .fill(color(for: index))
              .frame(height: 6)
          }
        }
        Text(verbatim: "\(done)/\(total)")
          .lifeyBody(metrics)
          .foregroundColor(LifeyColors.text2)
          .monospacedDigit()
          .fixedSize()
      }
      .accessibilityElement(children: .ignore)
      .accessibilityLabel(Text(verbatim: "\(done)/\(total)"))
    }
  }

  private func color(for index: Int) -> Color {
    if index == justLoggedIndex { return LifeyColors.success }
    return index < done ? LifeyColors.text : LifeyColors.raised
  }
}

#Preview("Header + reading + bar") {
  VStack(alignment: .leading, spacing: 8) {
    WatchHeaderChip(icon: "dumbbell", label: "Erőedzés")
    WatchHeaderChip(icon: "dumbbell", label: "Erőedzés", isPaused: true)
    WatchMetricReading(icon: "heart.fill", iconTint: LifeyColors.heart, number: "128", unit: "bpm", level: .metric)
    WatchMetricReading(icon: "flame.fill", iconTint: LifeyColors.calories, number: "212")
    SetSegmentBar(done: 2, total: 4)
    SetSegmentBar(done: 3, total: 4, justLoggedIndex: 2)
  }
  .environment(\.watchMetrics, WatchMetrics(width: 198))
  .background(LifeyColors.bg)
}
