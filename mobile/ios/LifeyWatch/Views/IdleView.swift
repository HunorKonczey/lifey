import SwiftUI

/// The badge behind the leaf mark, and the leaf itself within it, as
/// fractions of the shorter screen dimension — canvas AW 01's badge:leaf
/// ratio is roughly 76:44 (mirrors Android's `IdleScreen.kt` constants).
private let leafBadgeSizeFraction: CGFloat = 0.22
private let leafMarkSizeFraction: CGFloat = 0.13

/// No active session — docs/40-watch-app-plan.md §4.4 "IdleView" (mirrors
/// Android's `IdleScreen.kt`), carrying the calm brand-moment the design
/// canvas asks for (§12.1 B5 / 41-watch-design-prompt.md §3.1: "the only
/// screen where brand decoration is allowed to breathe; keep it calm, not
/// salesy") — a leaf badge + "Lifey" wordmark, matching canvas frame AW 01
/// pixel-for-pixel (§12.1 B6). Padding and type scale are dial-size-relative,
/// not fixed pt values (§12.1 B4 — see `DynamicSizing.swift`).
struct IdleView: View {
  var body: some View {
    GeometryReader { geometry in
      let isCompact = DynamicSizing.isCompact(width: geometry.size.width)
      let padding = geometry.size.width * DynamicSizing.screenPaddingFraction
      let shortSide = min(geometry.size.width, geometry.size.height)
      let badgeSize = shortSide * leafBadgeSizeFraction
      let leafSize = shortSide * leafMarkSizeFraction

      VStack(spacing: badgeSize * 0.35) {
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
        Text("idle_subtitle")
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
  IdleView()
}
