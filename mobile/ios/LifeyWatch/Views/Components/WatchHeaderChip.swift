import SwiftUI

/// Header chip (frame 04/01): icon + CAPS label in `text2` (cardio: the activity accent). When paused the
/// whole chip turns clay and reads "SZÜNETELTETVE". An optional standalone mark sits at the trailing end —
/// a 26 pt `control` circle with a 44 pt hit area; its tapped state is `raised` with a sync glyph.
///
/// Named `Watch…` because the pre-redesign private `HeaderChip` still lives in `ActiveWorkoutView.swift`
/// until X1 switches the screens over.
struct WatchHeaderChip: View {
  let icon: String
  let label: String
  /// The accent for icon and label; `nil` = `text2`.
  var accent: Color? = nil
  var isPaused = false
  /// `nil` = not standalone (no mark). `.idle` / `.tapped`.
  var standaloneMark: StandaloneMarkState? = nil
  var onMarkTap: () -> Void = {}

  enum StandaloneMarkState { case idle, tapped }

  @Environment(\.watchMetrics) private var metrics

  private var contentColor: Color { isPaused ? LifeyColors.clay : (accent ?? LifeyColors.text2) }

  var body: some View {
    HStack(spacing: LifeySpacing.sm) {
      HStack(spacing: LifeySpacing.xs) {
        Image(systemName: isPaused ? "pause.fill" : icon)
          .font(.system(size: metrics.isCompact ? 12 : 13, weight: .semibold))
        Text(verbatim: label)
          .lifeyLabel(metrics, caps: true)
          .lineLimit(1)
      }
      .foregroundColor(contentColor)
      .padding(.horizontal, isPaused ? LifeySpacing.md : 0)
      .padding(.vertical, isPaused ? LifeySpacing.xs : 0)
      .background(isPaused ? LifeyColors.tint(LifeyColors.clay) : Color.clear)
      .clipShape(Capsule())

      if let standaloneMark {
        Button(action: onMarkTap) {
          ZStack {
            Circle()
              .fill(standaloneMark == .tapped ? LifeyColors.raised : LifeyColors.control)
              .frame(width: 26, height: 26)
            Image(systemName: standaloneMark == .tapped ? "arrow.triangle.2.circlepath" : "iphone.slash")
              .font(.system(size: 12))
              .foregroundColor(LifeyColors.text2)
          }
          .frame(width: metrics.minTouchTarget, height: metrics.minTouchTarget)
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.vertical, -9)  // the 44 pt hit area must not grow the header row
        .accessibilityLabel(Text("standalone_sync_retry_a11y"))
      }
    }
  }
}
