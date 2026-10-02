import SwiftUI

/// Heart-rate slot (frame 04/02 + DS 06, D-X0.4): level two of every active screen, in a fixed place and
/// size. Live = heart icon + PJS number + "bpm". Missing = ghost heart + ghost "—" + `text3` "nincs
/// pulzus" + ⓘ — the slot keeps its frame, never an error tone. Tap (missing) opens the explanation as a
/// sheet, so the text takes no space on the page (AW2.19). The *cause* of a missing reading is existing
/// state; the slot only reads `bpm`.
struct HeartRateSlot: View {
  /// `nil` = no reading.
  let bpm: Int?
  @State private var showsExplanation = false

  @Environment(\.watchMetrics) private var metrics

  /// The slot's height is the `metric` line in both states, so the layout never jumps.
  private var slotHeight: CGFloat { metrics.metric * 1.25 }

  var body: some View {
    Group {
      if let bpm {
        WatchMetricReading(
          icon: "heart.fill", iconTint: LifeyColors.heart, number: "\(bpm)",
          unit: String(localized: "active_heart_rate_unit"), level: .metric)
      } else {
        Button { showsExplanation = true } label: {
          HStack(spacing: LifeySpacing.xs) {
            Image(systemName: "heart.fill")
              .font(.system(size: metrics.metric * 0.7))
              .foregroundColor(LifeyColors.ghost)
            Text(verbatim: "—")
              .lifeyMetric(metrics)
              .foregroundColor(LifeyColors.ghost)
            Text("cardio_no_heart_rate_label")
              .lifeyBody(metrics)
              .foregroundColor(LifeyColors.text3)
              .lineLimit(1)
            Image(systemName: "info.circle")
              .font(.system(size: metrics.value * 0.8))
              .foregroundColor(LifeyColors.text3)
          }
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showsExplanation) { HeartRateExplanationSheet() }
      }
    }
    .frame(minHeight: slotHeight, alignment: .leading)
  }
}

/// AW2.19 — the explanation behind the ⓘ. Closes with the system X or the crown.
struct HeartRateExplanationSheet: View {
  @Environment(\.watchMetrics) private var metrics

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: LifeySpacing.md) {
        Image(systemName: "heart.slash")
          .font(.system(size: 26))
          .foregroundColor(LifeyColors.ghost)
        Text("cardio_no_heart_rate_label")
          .lifeyTitle(metrics)
          .foregroundColor(LifeyColors.text)
        Text("cardio_no_heart_rate_hint")
          .lifeyBody(metrics)
          .foregroundColor(LifeyColors.text2)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .background(LifeyColors.bg)
  }
}

#Preview("Heart-rate slot") {
  VStack(alignment: .leading, spacing: 12) {
    HeartRateSlot(bpm: 128)
    HeartRateSlot(bpm: nil)
  }
  .environment(\.watchMetrics, WatchMetrics(width: 198))
  .background(LifeyColors.bg)
}
