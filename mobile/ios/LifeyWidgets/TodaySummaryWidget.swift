import WidgetKit
import SwiftUI

// Renders the "Widget snapshot" data contract from
// docs/24-ios-widget-live-activity-plan.md. The `home_widget` package
// writes the raw JSON string directly into App Group UserDefaults under
// `today_snapshot` (see HomeWidgetPlugin.swift's saveWidgetData) — this
// file only ever reads it back, it never talks to Flutter.

private let appGroupId = "group.com.khunor.lifey"
private let snapshotKey = "today_snapshot"

// MARK: - Data contract

struct WidgetLabels: Codable {
  let calories: String
  let steps: String
  let noData: String
}

/// One home screen quick-start button (docs/cardio/59-cardio-implementation-plan.md
/// C2.11b, M29) — mirrors the Android `widget_quickstart_1/2` slots and the
/// `{label, deepLinkUri}` shape `WidgetSnapshotWriter.write` already sends
/// (added for C2.11a; this file just hadn't read it back yet).
struct QuickStartWidgetEntry: Codable {
  let label: String
  let deepLinkUri: String
}

struct TodaySnapshot: Codable {
  let date: String
  let updatedAtEpochMs: Int64
  let calories: Int
  let calorieGoal: Int?
  let steps: Int?
  let stepGoal: Int?
  let locale: String
  let labels: WidgetLabels
  // Optional, not because the writer ever omits the key (it always sends an
  // array, possibly empty), but because a snapshot written by a pre-C2.11a
  // app version — still sitting in App Group storage until the next write —
  // has no such key at all, and JSONDecoder would otherwise fail the whole
  // decode over one missing field.
  let quickStart: [QuickStartWidgetEntry]?
}

private func loadSnapshot() -> TodaySnapshot? {
  guard let defaults = UserDefaults(suiteName: appGroupId),
    let json = defaults.string(forKey: snapshotKey),
    let data = json.data(using: .utf8)
  else { return nil }
  return try? JSONDecoder().decode(TodaySnapshot.self, from: data)
}

private func dayString(_ date: Date) -> String {
  let calendar = Calendar.current
  let c = calendar.dateComponents([.year, .month, .day], from: date)
  return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
}

private func nextMidnight(after date: Date) -> Date {
  let calendar = Calendar.current
  let startOfToday = calendar.startOfDay(for: date)
  return calendar.date(byAdding: .day, value: 1, to: startOfToday) ?? date.addingTimeInterval(86400)
}

// MARK: - Timeline

struct TodaySummaryEntry: TimelineEntry {
  let date: Date
  let snapshot: TodaySnapshot?
  // True once the local day has rolled past `snapshot.date` — calories
  // render as 0/goal (nothing logged today is a true statement), steps as
  // unknown, per the plan's day-rollover rule.
  let isRolledOver: Bool
}

struct TodaySummaryProvider: TimelineProvider {
  func placeholder(in context: Context) -> TodaySummaryEntry {
    TodaySummaryEntry(date: Date(), snapshot: nil, isRolledOver: false)
  }

  func getSnapshot(in context: Context, completion: @escaping (TodaySummaryEntry) -> Void) {
    completion(currentEntry())
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<TodaySummaryEntry>) -> Void) {
    let snapshot = loadSnapshot()
    let now = Date()
    let current = TodaySummaryEntry(
      date: now, snapshot: snapshot, isRolledOver: isRolledOver(snapshot, comparedTo: now))
    // Always schedule one extra entry at the next local midnight so the
    // day-rollover switch happens on time without any app involvement.
    let midnight = TodaySummaryEntry(date: nextMidnight(after: now), snapshot: snapshot, isRolledOver: true)
    completion(Timeline(entries: [current, midnight], policy: .atEnd))
  }

  private func currentEntry() -> TodaySummaryEntry {
    let snapshot = loadSnapshot()
    let now = Date()
    return TodaySummaryEntry(date: now, snapshot: snapshot, isRolledOver: isRolledOver(snapshot, comparedTo: now))
  }

  private func isRolledOver(_ snapshot: TodaySnapshot?, comparedTo now: Date) -> Bool {
    guard let snapshot else { return false }
    return snapshot.date != dayString(now)
  }
}

// MARK: - Palette (transcribed from lib/core/theme/app_tokens.dart + app_theme.dart)
// Internal (not `private`) so WorkoutLiveActivity.swift can reuse it too.

struct Palette {
  let bg: Color
  let container: Color
  let onSurface: Color
  let onSurfaceVariant: Color
  let calories: Color
  let steps: Color

  static let light = Palette(
    bg: Color(red: 0xF3 / 255, green: 0xF2 / 255, blue: 0xE8 / 255),
    container: Color(red: 0xEC / 255, green: 0xEB / 255, blue: 0xDE / 255),
    onSurface: Color(red: 0x1E / 255, green: 0x1F / 255, blue: 0x18 / 255),
    onSurfaceVariant: Color(red: 0x5C / 255, green: 0x5C / 255, blue: 0x50 / 255),
    calories: Color(red: 0xD2 / 255, green: 0x7A / 255, blue: 0x3E / 255),
    steps: Color(red: 0x8A / 255, green: 0x6A / 255, blue: 0xB0 / 255)
  )

  static let dark = Palette(
    bg: Color(red: 0x16 / 255, green: 0x16 / 255, blue: 0x11 / 255),
    container: Color(red: 0x22 / 255, green: 0x24 / 255, blue: 0x1B / 255),
    onSurface: Color(red: 0xF1 / 255, green: 0xF0 / 255, blue: 0xE4 / 255),
    onSurfaceVariant: Color(red: 0xA8 / 255, green: 0xA8 / 255, blue: 0x99 / 255),
    calories: Color(red: 0xE0 / 255, green: 0x91 / 255, blue: 0x5A / 255),
    steps: Color(red: 0xB0 / 255, green: 0x8A / 255, blue: 0xC8 / 255)
  )
}

// MARK: - Views

struct TodaySummaryWidgetView: View {
  @Environment(\.colorScheme) private var colorScheme
  @Environment(\.widgetFamily) private var family
  var entry: TodaySummaryProvider.Entry

  private var palette: Palette { colorScheme == .dark ? .dark : .light }

  var body: some View {
    Group {
      if let snapshot = entry.snapshot {
        if family == .systemMedium {
          MediumSummaryView(snapshot: snapshot, isRolledOver: entry.isRolledOver, palette: palette)
        } else {
          SmallSummaryView(snapshot: snapshot, isRolledOver: entry.isRolledOver, palette: palette)
        }
      } else {
        NoDataView(palette: palette)
      }
    }
    .background(palette.bg)
    .widgetURL(URL(string: "lifey://today"))
  }
}

private struct SmallSummaryView: View {
  let snapshot: TodaySnapshot
  let isRolledOver: Bool
  let palette: Palette

  private var calories: Int { isRolledOver ? 0 : snapshot.calories }
  private var steps: Int? { isRolledOver ? nil : snapshot.steps }
  private var caloriesProgress: Double? {
    guard let goal = snapshot.calorieGoal, goal > 0 else { return nil }
    return min(Double(calories) / Double(goal), 1.0)
  }

  var body: some View {
    VStack(spacing: 6) {
      ZStack {
        Circle().stroke(palette.container, lineWidth: 8)
        if let progress = caloriesProgress {
          Circle()
            .trim(from: 0, to: progress)
            .stroke(palette.calories, style: StrokeStyle(lineWidth: 8, lineCap: .round))
            .rotationEffect(.degrees(-90))
        }
        VStack(spacing: 0) {
          Text("\(calories)")
            .font(.system(size: 18, weight: .bold))
            .foregroundColor(palette.onSurface)
            .minimumScaleFactor(0.6)
            .lineLimit(1)
          Text(snapshot.labels.calories)
            .font(.system(size: 9))
            .foregroundColor(palette.onSurfaceVariant)
        }
        .padding(.horizontal, 4)
      }
      .frame(width: 64, height: 64)

      Text(steps.map { "\(snapshot.labels.steps): \($0)" } ?? "\(snapshot.labels.steps): —")
        .font(.system(size: 11, weight: .medium))
        .foregroundColor(palette.onSurfaceVariant)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }
    .padding()
  }
}

private struct MediumSummaryView: View {
  let snapshot: TodaySnapshot
  let isRolledOver: Bool
  let palette: Palette

  private var calories: Int { isRolledOver ? 0 : snapshot.calories }
  private var steps: Int? { isRolledOver ? nil : snapshot.steps }

  var body: some View {
    VStack(spacing: 10) {
      HStack(spacing: 12) {
        StatTile(
          label: snapshot.labels.calories,
          value: "\(calories)",
          goal: snapshot.calorieGoal.map { "/ \($0)" },
          accent: palette.calories,
          palette: palette
        )
        StatTile(
          label: snapshot.labels.steps,
          value: steps.map { "\($0)" } ?? "—",
          goal: snapshot.stepGoal.map { "/ \($0)" },
          accent: palette.steps,
          palette: palette
        )
      }
      // Medium only — Small's 155pt square is already full with the
      // calorie ring + steps line, and 53-cardio-mobile-plan.md §3.3 only
      // ever asked for "a quick-start row with the top 2", not a variant
      // for every widget size (same simplification C2.11a already made on
      // Android, which also shipped this as one fixed layout, not per-size).
      QuickStartRow(entries: snapshot.quickStart ?? [], palette: palette)
    }
    .padding()
  }
}

/// Up to two deep-link buttons (docs/cardio/59-cardio-implementation-plan.md
/// C2.11b, M29) — plain `Link`s, not an interactive widget (out of scope per
/// docs/24-ios-widget-live-activity-plan.md's Scope section; iOS 17+ only).
/// Each `Link`'s own URL overrides the whole-widget `.widgetURL(lifey://today)`
/// set in `TodaySummaryWidgetView` for exactly its own tap region — the
/// standard pre-iOS-17 multi-target widget pattern, no extra capability
/// needed. Renders nothing when the ranking hasn't produced any entries yet
/// (fresh install, before the first `WidgetSnapshotController` refresh).
private struct QuickStartRow: View {
  let entries: [QuickStartWidgetEntry]
  let palette: Palette

  var body: some View {
    if !entries.isEmpty {
      HStack(spacing: 8) {
        ForEach(entries.prefix(2), id: \.deepLinkUri) { entry in
          if let url = URL(string: entry.deepLinkUri) {
            Link(destination: url) {
              Text(entry.label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(palette.onSurface)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(palette.container)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
          }
        }
      }
    }
  }
}

private struct StatTile: View {
  let label: String
  let value: String
  let goal: String?
  let accent: Color
  let palette: Palette

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(label)
        .font(.system(size: 12, weight: .medium))
        .foregroundColor(palette.onSurfaceVariant)
      HStack(alignment: .firstTextBaseline, spacing: 3) {
        Text(value)
          .font(.system(size: 22, weight: .bold))
          .foregroundColor(accent)
          .minimumScaleFactor(0.7)
          .lineLimit(1)
        if let goal {
          Text(goal)
            .font(.system(size: 12))
            .foregroundColor(palette.onSurfaceVariant)
        }
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(12)
    .background(palette.container)
    .clipShape(RoundedRectangle(cornerRadius: 16))
  }
}

private struct NoDataView: View {
  let palette: Palette

  var body: some View {
    Text("Open Lifey")
      .font(.system(size: 13, weight: .medium))
      .foregroundColor(palette.onSurfaceVariant)
      .multilineTextAlignment(.center)
      .padding()
  }
}

// MARK: - Widget

struct TodaySummaryWidget: Widget {
  let kind: String = "TodaySummaryWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: TodaySummaryProvider()) { entry in
      TodaySummaryWidgetView(entry: entry)
    }
    .configurationDisplayName("Ma")
    .description("Mai kalória és lépésszám.")
    .supportedFamilies([.systemSmall, .systemMedium])
  }
}
