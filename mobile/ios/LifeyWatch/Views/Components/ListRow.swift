import SwiftUI

/// List row (frame 04/09): a 22-radius card row. Highlighted (selected / the quick-strength entry) =
/// `nested` + a 36 pt icon holder. The title wraps to two lines. Optional trailing chevron (templates); the
/// cardio variant carries a tinted icon circle (accent @ 16 %).
struct ListRow: View {
  enum Leading {
    case none
    case holder(icon: String)  // 36 pt `control` holder with a `primary` glyph
    case tintedCircle(icon: String, accent: Color)  // cardio types
    case controlCircle(icon: String)  // "Minden edzéstípus": `control` circle, `text` glyph
  }

  let title: String
  let action: () -> Void
  var subtitle: String? = nil
  var leading: Leading = .none
  var isHighlighted = false
  var showsChevron = false
  var showsCheck = false
  var isDisabled = false

  init(
    title: String, onClick action: @escaping () -> Void, subtitle: String? = nil, leading: Leading = .none,
    isHighlighted: Bool = false, showsChevron: Bool = false, showsCheck: Bool = false, isDisabled: Bool = false
  ) {
    self.title = title
    self.action = action
    self.subtitle = subtitle
    self.leading = leading
    self.isHighlighted = isHighlighted
    self.showsChevron = showsChevron
    self.showsCheck = showsCheck
    self.isDisabled = isDisabled
  }

  @Environment(\.watchMetrics) private var metrics

  var body: some View {
    Button(action: action) {
      HStack(spacing: LifeySpacing.md) {
        leadingView
        VStack(alignment: .leading, spacing: LifeySpacing.xxs) {
          Text(verbatim: title)
            .lifeyTitle(metrics)
            .foregroundColor(LifeyColors.text)
            .lineLimit(2)
            .multilineTextAlignment(.leading)
          if let subtitle {
            Text(verbatim: subtitle).lifeyLabel(metrics).foregroundColor(LifeyColors.text2).lineLimit(1)
          }
        }
        Spacer(minLength: 0)
        if showsCheck {
          Image(systemName: "checkmark").font(.system(size: 14, weight: .bold)).foregroundColor(LifeyColors.text)
        } else if showsChevron {
          Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundColor(LifeyColors.text3)
        }
      }
      .padding(.horizontal, LifeySpacing.lg)
      .frame(minHeight: metrics.buttonHeight)
      .background(isHighlighted ? LifeyColors.nested : LifeyColors.card, in: RoundedRectangle(cornerRadius: LifeyShapes.card))
      .contentShape(RoundedRectangle(cornerRadius: LifeyShapes.card))
    }
    .buttonStyle(.plain)
    .disabled(isDisabled)
  }

  @ViewBuilder private var leadingView: some View {
    switch leading {
    case .none:
      EmptyView()
    case .holder(let icon):
      Image(systemName: icon)
        .font(.system(size: 16, weight: .semibold))
        .foregroundColor(LifeyColors.primary)
        .frame(width: 36, height: 36)
        .background(LifeyColors.control, in: Circle())
    case .controlCircle(let icon):
      Image(systemName: icon)
        .font(.system(size: 16, weight: .semibold))
        .foregroundColor(LifeyColors.text)
        .frame(width: 36, height: 36)
        .background(LifeyColors.control, in: Circle())
    case .tintedCircle(let icon, let accent):
      Image(systemName: icon)
        .font(.system(size: 16, weight: .semibold))
        .foregroundColor(accent)
        .frame(width: 36, height: 36)
        .background(LifeyColors.tint(accent), in: Circle())
    }
  }
}
