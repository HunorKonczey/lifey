import SwiftUI

/// Compact chip (frame 04/10): "Gyakorlatok" — 36 pt visible, 44 pt touch target (today 32).
struct CompactChip: View {
  let title: String
  var icon: String? = nil
  var isGhosted = false
  let action: () -> Void

  @Environment(\.watchMetrics) private var metrics

  var body: some View {
    Button(action: action) {
      HStack(spacing: LifeySpacing.xs) {
        if let icon { Image(systemName: icon).font(.system(size: 13, weight: .semibold)) }
        Text(verbatim: title).lifeyBody(metrics).lineLimit(1)
      }
      .foregroundColor(isGhosted ? LifeyColors.ghost : LifeyColors.text)
      .padding(.horizontal, LifeySpacing.lg)
      .frame(height: 36)
      .background(isGhosted ? LifeyColors.card : LifeyColors.control, in: Capsule())
      .frame(minHeight: metrics.minTouchTarget)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .disabled(isGhosted)
  }
}
