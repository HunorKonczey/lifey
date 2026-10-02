import SwiftUI

/// Circle button (frame 04/04): "+1 szett", "Módosítás", "Vége", "Szünet". Diameter from `WatchMetrics`;
/// the label sits **under** the circle (max two lines). Press = 100 ms scale to 0.96 and one tone step up;
/// a 300 ms double-tap guard stays.
struct CircleButton: View {
  enum Style {
    case primary  // fill primary, onPrimary content
    case raised  // fill raised, content text (icon may be clay)
    case control  // fill control, content text
    case errorTint  // error @ 16 %, error content
    case successTint  // success @ 16 %, success content (logged)
  }

  let style: Style
  /// SF Symbol; optional when the circle carries text ("+1") instead.
  var icon: String? = nil
  /// PJS text in the circle ("+1", "3/4"), alone or under the icon.
  var centerText: String? = nil
  let label: String
  var iconTint: Color? = nil
  var isGhosted = false
  /// Smaller than `metrics.circleButton` when a secondary EdgeButton / chip shares the page.
  var diameter: CGFloat? = nil
  let action: () -> Void

  @Environment(\.watchMetrics) private var metrics
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var guardTap = DoubleTapGuard()

  private var size: CGFloat { diameter ?? metrics.circleButton }

  var body: some View {
    VStack(spacing: LifeySpacing.xs) {
      Button {
        if guardTap.accept() { action() }
      } label: {
        VStack(spacing: LifeySpacing.xxs) {
          if let icon {
            Image(systemName: icon)
              .font(.system(size: size * (centerText == nil ? 0.36 : 0.34), weight: .bold))
          }
          if let centerText {
            Text(verbatim: centerText)
              .font(.custom(LifeyFont.extraBold, fixedSize: icon == nil ? size * 0.36 : size * 0.19))
              .monospacedDigit()
          }
        }
        .foregroundColor(isGhosted ? LifeyColors.ghost : (iconTint ?? content))
          .frame(width: size, height: size)
          .background(isGhosted ? LifeyColors.card : fill, in: Circle())
      }
      .buttonStyle(CirclePressStyle(reduceMotion: reduceMotion))
      .disabled(isGhosted)
      Text(verbatim: label)
        .lifeyLabel(metrics)
        .foregroundColor(isGhosted ? LifeyColors.ghost : LifeyColors.text2)
        .multilineTextAlignment(.center)
        .lineLimit(2)
        .frame(maxWidth: size + LifeySpacing.lg)
    }
  }

  private var fill: Color {
    switch style {
    case .primary: return LifeyColors.primary
    case .raised: return LifeyColors.raised
    case .control: return LifeyColors.control
    case .errorTint: return LifeyColors.tint(LifeyColors.error)
    case .successTint: return LifeyColors.tint(LifeyColors.success)
    }
  }

  private var content: Color {
    switch style {
    case .primary: return LifeyColors.onPrimary
    case .raised, .control: return LifeyColors.text
    case .errorTint: return LifeyColors.error
    case .successTint: return LifeyColors.success
    }
  }
}

/// 100 ms scale to 0.96 and one tone step up while pressed (frame 07).
private struct CirclePressStyle: ButtonStyle {
  let reduceMotion: Bool

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .scaleEffect(configuration.isPressed ? 0.96 : 1)
      .brightness(configuration.isPressed ? 0.08 : 0)
      .animation(
        LifeyMotion.animation(
          LifeyMotion.standard(LifeyMotion.Duration.tap), reduceMotion: reduceMotion),
        value: configuration.isPressed)
  }
}
