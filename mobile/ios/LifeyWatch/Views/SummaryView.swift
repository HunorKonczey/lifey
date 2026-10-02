import SwiftUI

// MARK: - Summary (redesign X1.14 — AW1.22)

/// Plain data behind the summary.
struct SummaryModel {
  var totalSeconds: Double
  var averageHeartRate: Double?
  var calories: Double?
  /// Non-nil only for a standalone summary: a fourth "sets" tile and the sync row.
  var setsCount: Int?
  var savedToHealth: Bool
  /// Non-nil only for a standalone summary.
  var sync: (isSynced: Bool, pendingCount: Int)?
}

/// "Edzés mentve" (docs/40-watch-app-plan.md §12.1 B9): the check sits beside the title (saves a row), a
/// full-width time tile (28 pt number), the "átlag bpm" and kcal tiles side by side, the "Elmentve az Egészség
/// appba" row wrapping to two lines above the fold. Tiles count up over 600 ms (`SummaryTile`).
/// Standalone summaries add a sets tile and the sync row (refined in X2.6).
struct SummaryContent: View {
  let model: SummaryModel

  @Environment(\.watchMetrics) private var metrics

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: LifeySpacing.sm) {
        HStack(spacing: LifeySpacing.sm) {
          Image(systemName: "checkmark.circle.fill")
            .font(.system(size: 20))
            .foregroundColor(LifeyColors.success)
          Text("summary_title").lifeyTitle(metrics).foregroundColor(LifeyColors.text).lineLimit(2)
        }
        SummaryTile(
          number: model.totalSeconds, format: { SummaryContent.duration($0) },
          label: String(localized: "summary_time_label"))
        HStack(spacing: LifeySpacing.sm) {
          if let setsCount = model.setsCount {
            SummaryTile(
              number: Double(setsCount), format: { "\(Int($0.rounded()))" },
              label: String(localized: "summary_sets_label"))
          }
          if let bpm = model.averageHeartRate {
            SummaryTile(
              number: bpm, format: { "\(Int($0.rounded()))" },
              label: String(localized: "summary_avg_hr_label"), tint: LifeyColors.heart)
          }
          if let kcal = model.calories {
            SummaryTile(
              number: kcal, format: { "\(Int($0.rounded()))" },
              label: String(localized: "active_calories_unit"), tint: LifeyColors.calories)
          }
        }
        if model.savedToHealth {
          HStack(alignment: .top, spacing: LifeySpacing.sm) {
            Image(systemName: "heart.fill").font(.system(size: 13))
            Text("summary_saved_to_health").lifeyBody(metrics).lineLimit(2).multilineTextAlignment(.leading)
          }
          .foregroundColor(LifeyColors.success)
          .padding(.horizontal, LifeySpacing.lg)
          .padding(.vertical, LifeySpacing.md)
          .frame(maxWidth: .infinity, alignment: .leading)
          .background(LifeyColors.tint(LifeyColors.success), in: RoundedRectangle(cornerRadius: LifeyShapes.card))
        }
        if let sync = model.sync {
          SyncRow(
            isSynced: sync.isSynced,
            title: String(localized: sync.isSynced ? "sync_done" : "sync_pending"),
            subtitle: sync.pendingCount > 1
              ? String(format: String(localized: "sync_queue_count"), sync.pendingCount) : nil)
        }
      }
      .padding(.horizontal, metrics.sideMargin)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .background(LifeyColors.bg)
  }

  static func duration(_ seconds: Double) -> String {
    let total = Int(seconds)
    return String(format: "%02d:%02d", total / 60, total % 60)
  }
}

/// Shown once `WorkoutManager.finishAndSendSummary()` / `endStandalone(rpe:)` closes the session, for
/// `summaryAutoDismissSeconds` before falling back to `IdleView` on its own. A standalone summary flips its
/// sync row from `sync_pending` to `sync_done` live, once `PhoneConnector` posts `.standaloneSessionAcked`
/// for *this* session's id — not just "the queue emptied".
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
    SummaryContent(
      model: SummaryModel(
        totalSeconds: data.totalDuration, averageHeartRate: data.averageHeartRate,
        calories: data.activeCalories, setsCount: data.setsCount, savedToHealth: data.savedToHealth,
        sync: data.standaloneSessionId == nil ? nil : (isSynced, pendingCount))
    )
    .onReceive(NotificationCenter.default.publisher(for: .standaloneSessionAcked)) { notification in
      pendingCount = StandaloneSessionStore.shared.all().count
      guard let acked = notification.userInfo?["standaloneSessionId"] as? String,
        acked == data.standaloneSessionId
      else { return }
      isSynced = true
    }
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
