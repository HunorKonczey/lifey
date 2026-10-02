import SwiftUI

/// Set segment bar (frame 04/03): the exercise name left and "2/4" right (PJS 700, "/4" in `text3`) over
/// full-width segments instead of dots — readable up to 8 sets, the width of the card. Done = `text`, just
/// logged = `success` (for 1.2 s, driven by the caller), remaining = `raised`. A session without a plan
/// (quick strength) shows the name and no bar, only the text "3. szett · 24 ism." the caller supplies.
struct SetSegmentBar: View {
  var title: String? = nil
  let done: Int
  let total: Int
  /// The segment that was just logged (0-based) turns `success`; `nil` when none.
  var justLoggedIndex: Int? = nil
  /// Quick strength has no plan: only this text is shown.
  var freeFormText: String? = nil

  @Environment(\.watchMetrics) private var metrics

  var body: some View {
    if let freeFormText {
      VStack(alignment: .leading, spacing: LifeySpacing.xs) {
        if let title {
          Text(verbatim: title).lifeyTitle(metrics).foregroundColor(LifeyColors.text).lineLimit(2)
        }
        Text(verbatim: freeFormText).lifeyBody(metrics).foregroundColor(LifeyColors.text2).lineLimit(2)
      }
    } else if total <= 0 {
      if let title {
        Text(verbatim: title).lifeyTitle(metrics).foregroundColor(LifeyColors.text).lineLimit(2)
      }
    } else {
      VStack(spacing: LifeySpacing.sm) {
        HStack(alignment: .firstTextBaseline, spacing: LifeySpacing.md) {
          if let title {
            Text(verbatim: title)
              .lifeyTitle(metrics)
              .foregroundColor(LifeyColors.text)
              .lineLimit(2)
              .multilineTextAlignment(.leading)
          }
          Spacer(minLength: 0)
          Text(verbatim: "\(done)").foregroundColor(LifeyColors.text)
            + Text(verbatim: "/\(total)").foregroundColor(LifeyColors.text3)
        }
        .lifeyBodyBold(metrics)
        HStack(spacing: LifeySpacing.xs) {
          ForEach(0..<max(total, 0), id: \.self) { index in
            Capsule().fill(color(for: index)).frame(height: 6)
          }
        }
      }
      .accessibilityElement(children: .ignore)
      .accessibilityLabel(Text(verbatim: "\(title ?? "") \(done)/\(total)"))
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
    SetSegmentBar(title: "Fekvenyomás", done: 2, total: 4)
    SetSegmentBar(title: "Fekvenyomás", done: 3, total: 4, justLoggedIndex: 2)
  }
  .environment(\.watchMetrics, WatchMetrics(width: 198))
  .background(LifeyColors.bg)
}
