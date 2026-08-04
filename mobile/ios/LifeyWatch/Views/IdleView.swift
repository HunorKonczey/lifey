import SwiftUI

/// The badge behind the leaf mark, and the leaf itself within it, as
/// fractions of the shorter screen dimension — slightly smaller than the
/// original idle screen's (canvas AW 01: 0.22/0.13) to make room for the
/// launcher's "Start workout" pill below (canvas AW 12: "brand moment
/// kept... slightly compacted").
private let leafBadgeSizeFraction: CGFloat = 0.19
private let leafMarkSizeFraction: CGFloat = 0.11

/// No active session — now a **launcher**, not just a status screen
/// (docs/watch/44-watch-f6-standalone-plan.md §3.1, design canvas AW 12).
/// The calm brand-moment the design canvas asks for (§12.1 B5 /
/// 41-watch-design-prompt.md §3.1) is kept — leaf badge + "Lifey" wordmark
/// — but compacted, since the `primary`-fill "Start workout" pill is now
/// the screen's only saturated element, opening `StandalonePickerView`. The
/// old `idle_subtitle` demotes to a quiet second line under the pill
/// (`standalone_start_caption`) — the key itself stays in the string
/// catalogs (harmless, unreferenced) rather than being deleted, since
/// nothing else in this pass touches it. Padding and type scale are
/// dial-size-relative, not fixed pt values (§12.1 B4 — see
/// `DynamicSizing.swift`).
struct IdleView: View {
  let onStartTapped: () -> Void

  var body: some View {
    GeometryReader { geometry in
      let isCompact = DynamicSizing.isCompact(width: geometry.size.width)
      let padding = geometry.size.width * DynamicSizing.screenPaddingFraction
      let shortSide = min(geometry.size.width, geometry.size.height)
      let badgeSize = shortSide * leafBadgeSizeFraction
      let leafSize = shortSide * leafMarkSizeFraction

      VStack(spacing: badgeSize * 0.3) {
        ZStack {
          RoundedRectangle(cornerRadius: badgeSize * 0.3)
            .fill(LifeyColors.surface)
            .frame(width: badgeSize, height: badgeSize)
          Image(systemName: "leaf.fill")
            .font(.system(size: leafSize))
            .foregroundColor(LifeyColors.primary)
        }
        Text("idle_title")
          .font(isCompact ? .title3 : .title2)
          .foregroundColor(LifeyColors.onSurface)
        Button(action: onStartTapped) {
          Text("standalone_start_button")
            .font(isCompact ? .caption : .body)
            .fontWeight(.bold)
            .foregroundColor(LifeyColors.onPrimary)
            .padding(.horizontal, isCompact ? 18 : 24)
            .padding(.vertical, isCompact ? 8 : 10)
        }
        .buttonStyle(.plain)
        .background(LifeyColors.primary)
        .clipShape(Capsule())
        .accessibilityLabel(Text("standalone_start_button_a11y"))
        .padding(.top, 2)
        Text("standalone_start_caption")
          .font(isCompact ? .caption2 : .caption)
          .foregroundColor(LifeyColors.onSurfaceVariant)
          .multilineTextAlignment(.center)
      }
      .padding(.horizontal, padding)
      .frame(width: geometry.size.width, height: geometry.size.height)
      .background(LifeyColors.trueBlack)
    }
  }
}

#Preview {
  IdleView(onStartTapped: {})
}
