import SwiftUI

/// "Workout saved" (docs/40-watch-app-plan.md §12.1 B9): shown once
/// `WorkoutManager.finishAndSendSummary()` closes the session, for
/// `summaryAutoDismissSeconds` before falling back to `IdleView` on its own
/// — the user never has to dismiss it manually. Styling (§12.1 B6) matches
/// canvas frame AW 06: `primary` checkmark, three `surface`-bg stat tiles
/// (time in `onSurface`, avg bpm in `heart`, kcal in `calories`), and the
/// `primary`-tinted "Saved to Health" pill. No Android reference for the
/// screen's *structure* (the Wear-side ENDING/SUMMARY pair isn't designed,
/// see the 42-doc D1.3/A5) — only the iOS canvas frame exists to match.
struct SummaryView: View {
  let data: WorkoutSummaryData

  var body: some View {
    GeometryReader { geometry in
      let isCompact = DynamicSizing.isCompact(width: geometry.size.width)
      let padding = geometry.size.width * DynamicSizing.screenPaddingFraction
      VStack(spacing: 8) {
        Image(systemName: "checkmark.circle.fill")
          .font(.system(size: isCompact ? 44 : 52))
          .foregroundColor(LifeyColors.primary)
        Text("summary_title")
          .font(isCompact ? .caption : .body)
          .fontWeight(.bold)
          .foregroundColor(LifeyColors.onSurface)
        HStack(spacing: 8) {
          StatTile(
            value: formatDuration(data.totalDuration), label: String(localized: "summary_time_label"),
            valueColor: LifeyColors.onSurface, isCompact: isCompact)
          if let averageHeartRate = data.averageHeartRate {
            StatTile(
              value: "\(Int(averageHeartRate.rounded()))", label: String(localized: "summary_avg_hr_label"),
              valueColor: LifeyColors.heart, isCompact: isCompact)
          }
          if let activeCalories = data.activeCalories {
            StatTile(
              value: "\(Int(activeCalories.rounded()))", label: String(localized: "active_calories_unit"),
              valueColor: LifeyColors.calories, isCompact: isCompact)
          }
        }
        if data.savedToHealth {
          HStack(spacing: 8) {
            Image(systemName: "heart.fill")
              .font(.system(size: isCompact ? 14 : 16))
              .foregroundColor(LifeyColors.primary)
            Text("summary_saved_to_health")
              .font(.caption2)
              .fontWeight(.semibold)
              .foregroundColor(LifeyColors.primary)
          }
          .padding(.horizontal, 14)
          .padding(.vertical, 6)
          .background(LifeyColors.primary.opacity(0.14))
          .clipShape(Capsule())
        }
      }
      .padding(.horizontal, padding)
      .frame(width: geometry.size.width, height: geometry.size.height)
      .background(LifeyColors.trueBlack)
    }
  }

  private func formatDuration(_ seconds: TimeInterval) -> String {
    let total = Int(seconds)
    return String(format: "%02d:%02d", total / 60, total % 60)
  }
}

/// One stat tile (canvas AW 06's three `surface`-bg cards: time / avg bpm /
/// kcal), each with its own accent color on the number and a muted label.
private struct StatTile: View {
  let value: String
  let label: String
  let valueColor: Color
  let isCompact: Bool

  var body: some View {
    VStack(spacing: 2) {
      Text(value)
        .font(isCompact ? .caption : .body)
        .fontWeight(.bold)
        .foregroundColor(valueColor)
        .monospacedDigit()
      Text(label)
        .font(.caption2)
        .foregroundColor(LifeyColors.onSurfaceVariant)
    }
    .padding(.horizontal, 8)
    .padding(.vertical, 10)
    .frame(maxWidth: .infinity)
    .background(LifeyColors.surface)
    .clipShape(RoundedRectangle(cornerRadius: LifeyShapes.card))
  }
}

#Preview {
  SummaryView(
    data: WorkoutSummaryData(
      totalDuration: 2734, averageHeartRate: 128, activeCalories: 312, savedToHealth: true))
}
