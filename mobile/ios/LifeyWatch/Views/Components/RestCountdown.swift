import SwiftUI

/// Rest countdown, Apple variant (frame 04/06): the hero number above an 8 pt white linear bar (radius 4)
/// with "/ 1:30" in `text2`. The last 5 s turn number and fill `calories` and the number pulses 100 → 92 %
/// at 1 Hz (off with Reduce Motion). The bar drains linearly once per second.
struct RestCountdown: View {
  let remainingSeconds: Int
  let totalSeconds: Int

  @Environment(\.watchMetrics) private var metrics
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  /// The last five seconds are the warning window (the warning role is `calories`).
  static let warningSeconds = 5

  private var isWarning: Bool { remainingSeconds <= Self.warningSeconds && remainingSeconds > 0 }
  private var accent: Color { isWarning ? LifeyColors.calories : LifeyColors.text }
  private var fraction: Double {
    guard totalSeconds > 0 else { return 0 }
    return min(max(Double(remainingSeconds) / Double(totalSeconds), 0), 1)
  }

  static func format(_ seconds: Int) -> String {
    String(format: "%d:%02d", max(seconds, 0) / 60, max(seconds, 0) % 60)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: LifeySpacing.sm) {
      HStack(alignment: .firstTextBaseline, spacing: LifeySpacing.sm) {
        Text(verbatim: Self.format(remainingSeconds))
          .lifeyHero(metrics)
          .foregroundColor(accent)
          .scaleEffect(pulseScale, anchor: .leading)
          .animation(
            reduceMotion ? nil : .easeInOut(duration: 0.5), value: remainingSeconds)
        Text(verbatim: "/ \(Self.format(totalSeconds))")
          .lifeyBody(metrics)
          .foregroundColor(LifeyColors.text2)
      }
      GeometryReader { proxy in
        ZStack(alignment: .leading) {
          Capsule().fill(LifeyColors.control)
          Capsule()
            .fill(isWarning ? LifeyColors.calories : LifeyColors.text)
            .frame(width: proxy.size.width * fraction)
        }
      }
      .frame(height: 8)
      .animation(reduceMotion ? nil : .linear(duration: 1), value: remainingSeconds)
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(Text(verbatim: Self.format(remainingSeconds)))
  }

  /// 100 % ↔ 92 % on alternating seconds inside the warning window.
  private var pulseScale: CGFloat {
    guard isWarning, !reduceMotion else { return 1 }
    return remainingSeconds % 2 == 0 ? 0.92 : 1
  }
}
