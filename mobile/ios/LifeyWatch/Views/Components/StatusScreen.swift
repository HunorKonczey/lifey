import SwiftUI

/// Status screen (left-aligned pattern, AW1.21 / AW2.17): an icon (in a holder or bare), a title of at most
/// two lines, a subtitle, and an optional button — all above the fold. Replaces the centred stack that
/// squeezed Hungarian strings.
struct StatusScreen<Accessory: View>: View {
  let icon: String
  var iconTint: Color = LifeyColors.text2
  let title: String
  var subtitle: String? = nil
  var buttonTitle: String? = nil
  var onButton: () -> Void = {}
  @ViewBuilder var accessory: () -> Accessory

  @Environment(\.watchMetrics) private var metrics

  var body: some View {
    VStack(alignment: .leading, spacing: LifeySpacing.md) {
      Image(systemName: icon)
        .font(.system(size: 26))
        .foregroundColor(iconTint)
      Text(verbatim: title)
        .lifeyTitle(metrics)
        .foregroundColor(LifeyColors.text)
        .lineLimit(2)
        .multilineTextAlignment(.leading)
      if let subtitle {
        Text(verbatim: subtitle)
          .lifeyBody(metrics)
          .foregroundColor(LifeyColors.text2)
          .multilineTextAlignment(.leading)
      }
      accessory()
      if let buttonTitle {
        Button(action: onButton) {
          Text(verbatim: buttonTitle)
            .lifeyBody(metrics)
            .foregroundColor(LifeyColors.text)
            .frame(maxWidth: .infinity, minHeight: metrics.buttonHeight)
            .background(LifeyColors.control, in: RoundedRectangle(cornerRadius: LifeyShapes.control))
        }
        .buttonStyle(.plain)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.horizontal, metrics.sideMargin)
  }
}

extension StatusScreen where Accessory == EmptyView {
  init(
    icon: String, iconTint: Color = LifeyColors.text2, title: String, subtitle: String? = nil,
    buttonTitle: String? = nil, onButton: @escaping () -> Void = {}
  ) {
    self.init(
      icon: icon, iconTint: iconTint, title: title, subtitle: subtitle, buttonTitle: buttonTitle,
      onButton: onButton, accessory: { EmptyView() })
  }
}
