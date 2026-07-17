import SwiftUI

/// Shown between the watch's End button and the phone's real `end` command
/// coming back (docs/40-watch-app-plan.md §12.1 B8, §8.2 decision (b)): the
/// sensors keep recording underneath (`WorkoutManager` stays in `.ending`,
/// the `HKWorkoutSession` is untouched) — this screen just tells the user
/// the finish flow (RPE rating) is happening on the phone, not stuck.
/// Styling (§12.1 B6) matches canvas frame AW 05: `primary`-tinted phone
/// glyph, bold title, muted subtitle, and the 3-dot progress row (first dot
/// `primary`, the other two `outline`) the canvas shows under the copy.
/// Padding and type scale are dial-size-relative (§12.1 B4 — see
/// `DynamicSizing.swift`).
struct EndingView: View {
  var body: some View {
    GeometryReader { geometry in
      let isCompact = DynamicSizing.isCompact(width: geometry.size.width)
      let padding = geometry.size.width * DynamicSizing.screenPaddingFraction
      VStack(spacing: 8) {
        Image(systemName: "iphone")
          .font(.system(size: isCompact ? 40 : 48))
          .foregroundColor(LifeyColors.primary)
        Text("ending_title")
          .font(isCompact ? .caption : .body)
          .fontWeight(.bold)
          .foregroundColor(LifeyColors.onSurface)
          .multilineTextAlignment(.center)
        Text("ending_subtitle")
          .font(isCompact ? .caption2 : .caption)
          .foregroundColor(LifeyColors.onSurfaceVariant)
          .multilineTextAlignment(.center)
        HStack(spacing: 8) {
          Circle().fill(LifeyColors.primary).frame(width: 6, height: 6)
          Circle().fill(LifeyColors.outline).frame(width: 6, height: 6)
          Circle().fill(LifeyColors.outline).frame(width: 6, height: 6)
        }
        .padding(.top, 4)
      }
      .padding(.horizontal, padding)
      .frame(width: geometry.size.width, height: geometry.size.height)
      .background(LifeyColors.trueBlack)
    }
  }
}

#Preview {
  EndingView()
}
