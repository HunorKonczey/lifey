import SwiftUI

/// "Workout saved" (docs/40-watch-app-plan.md §12.1 B9): shown once
/// `WorkoutManager.finishAndSendSummary()`/`endStandalone(rpe:)` closes the
/// session, for `summaryAutoDismissSeconds` before falling back to
/// `IdleView` on its own — the user never has to dismiss it manually.
/// Styling (§12.1 B6) matches canvas frame AW 06: `primary` checkmark,
/// `surface`-bg stat tiles (time in `onSurface`, avg bpm in `heart`, kcal in
/// `calories`), and the `primary`-tinted "Saved to Health" pill. No Android
/// reference for the screen's *structure* (the Wear-side ENDING/SUMMARY pair
/// isn't designed, see the 42-doc D1.3/A5) — only the iOS canvas frame
/// exists to match.
///
/// Standalone summaries (`data.setsCount`/`data.standaloneSessionId`
/// non-nil, docs/watch/44-watch-f6-standalone-plan.md §3.6, canvas AW 15)
/// add a fourth "sets" tile and a sync-status chip that flips from
/// `sync_pending` to `sync_done` live, once `PhoneConnector` posts
/// `.standaloneSessionAcked` for *this* session's id — not just "the queue
/// emptied", since other queued sessions may ack independently.
struct SummaryView: View {
  let data: WorkoutSummaryData

  @State private var isSynced: Bool
  @State private var pendingCount: Int

  init(data: WorkoutSummaryData) {
    self.data = data
    let pending = StandaloneSessionStore.shared.all()
    _pendingCount = State(initialValue: pending.count)
    _isSynced = State(
      initialValue: data.standaloneSessionId.map { id in
        !pending.contains { $0.standaloneSessionId == id }
      } ?? true)
  }

  var body: some View {
    GeometryReader { geometry in
      let isCompact = DynamicSizing.isCompact(width: geometry.size.width)
      let padding = geometry.size.width * DynamicSizing.screenPaddingFraction
      // Scrollable: the standalone variant stacks a checkmark, title, a 2×2
      // tile grid, the "saved to Health" pill, the sync chip and (with more
      // than one queued session) a count line — taller than a 41 mm face,
      // and without a ScrollView the bottom rows are simply unreachable.
      ScrollView {
      VStack(spacing: 8) {
        Image(systemName: "checkmark.circle.fill")
          .font(.system(size: isCompact ? 44 : 52))
          .foregroundColor(LifeyColors.primary)
        Text("summary_title")
          .font(isCompact ? .caption : .body)
          .fontWeight(.bold)
          .foregroundColor(LifeyColors.onSurface)
        if data.setsCount != nil {
          // Standalone: 4 tiles (time, sets, avg bpm, kcal) don't fit an
          // HStack legibly on a round dial — canvas AW 15/W 14 use a 2×2
          // grid instead of AW 06's row.
          LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
            statTiles(isCompact: isCompact)
          }
        } else {
          HStack(spacing: 8) {
            statTiles(isCompact: isCompact)
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
        if data.standaloneSessionId != nil {
          HStack(spacing: 6) {
            Image(systemName: isSynced ? "checkmark.circle.fill" : "icloud.and.arrow.up")
              .font(.system(size: isCompact ? 14 : 16))
              .foregroundColor(isSynced ? LifeyColors.tertiary : LifeyColors.onSurfaceVariant)
            Text(isSynced ? "sync_done" : "sync_pending")
              .font(.caption2)
              .fontWeight(.semibold)
              .foregroundColor(isSynced ? LifeyColors.tertiary : LifeyColors.onSurfaceVariant)
          }
          .padding(.horizontal, 14)
          .padding(.vertical, 6)
          .background(isSynced ? LifeyColors.tertiary.opacity(0.14) : LifeyColors.container)
          .clipShape(Capsule())
          if pendingCount > 1 {
            Text(String(format: String(localized: "sync_queue_count"), pendingCount))
              .font(.caption2)
              .foregroundColor(LifeyColors.onSurfaceVariant)
          }
        }
      }
      .padding(.horizontal, padding)
      .frame(maxWidth: .infinity)
      // Keeps the content vertically centred when it fits (see HealthDeniedView).
      .frame(minHeight: geometry.size.height)
      }
      .frame(width: geometry.size.width, height: geometry.size.height)
      .background(LifeyColors.trueBlack)
    }
    .onReceive(NotificationCenter.default.publisher(for: .standaloneSessionAcked)) { notification in
      pendingCount = StandaloneSessionStore.shared.all().count
      guard let acked = notification.userInfo?["standaloneSessionId"] as? String,
        acked == data.standaloneSessionId
      else { return }
      isSynced = true
    }
  }

  /// The tiles shared by both layouts — the sets tile only appears when
  /// `data.setsCount` is set (standalone). Building them once and just
  /// swapping the container (`LazyVGrid` vs `HStack`) keeps the two layouts
  /// from drifting out of sync with each other.
  @ViewBuilder
  private func statTiles(isCompact: Bool) -> some View {
    StatTile(
      value: formatDuration(data.totalDuration), label: String(localized: "summary_time_label"),
      valueColor: LifeyColors.onSurface, isCompact: isCompact)
    if let setsCount = data.setsCount {
      StatTile(
        value: "\(setsCount)", label: String(localized: "summary_sets_label"),
        valueColor: LifeyColors.onSurface, isCompact: isCompact)
    }
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
      totalDuration: 2734, averageHeartRate: 128, activeCalories: 312, savedToHealth: true,
      setsCount: nil, standaloneSessionId: nil))
}

#Preview("Standalone, pending") {
  SummaryView(
    data: WorkoutSummaryData(
      totalDuration: 2292, averageHeartRate: 126, activeCalories: 214, savedToHealth: true,
      setsCount: 9, standaloneSessionId: "preview-standalone-session"))
}
