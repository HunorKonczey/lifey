import SwiftUI
import WidgetKit

/// Smart Stack widget (frame AW2.24, redesign X2.o1), `accessoryRectangular`: during a workout the name, the
/// live elapsed time, the heart rate and the current set — all from the watch's own state; during a rest the
/// countdown replaces the elapsed time; outside a workout a quiet "Gyors erőedzés" launcher.
struct WorkoutSmartStackWidget: Widget {
  static let kind = "LifeyWorkoutSmartStack"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: Self.kind, provider: WorkoutProvider()) { entry in
      WorkoutSmartStackView(snapshot: entry.snapshot)
        .containerBackground(for: .widget) { Color.clear }
    }
    .configurationDisplayName(String(localized: "widget_display_name"))
    .description(String(localized: "widget_description"))
    .supportedFamilies([.accessoryRectangular])
  }
}

struct WorkoutSmartStackView: View {
  let snapshot: WatchWidgetSnapshot

  var body: some View {
    switch snapshot.phase {
    case .idle: launcher
    case .active, .resting: workout
    }
  }

  /// Not in a workout: one tap to the start picker (`lifey-watch://quick-strength`, README step 5).
  private var launcher: some View {
    HStack(spacing: 8) {
      Image(systemName: "leaf.fill").widgetAccentable()
      VStack(alignment: .leading, spacing: 2) {
        Text(String(localized: "widget_quick_strength")).font(.system(size: 15, weight: .semibold))
        Text(String(localized: "widget_open_picker"))
          .font(.system(size: 12, weight: .medium))
          .foregroundStyle(LifeyColors.text2)
      }
    }
    .widgetURL(URL(string: "lifey-watch://quick-strength"))
  }

  private var workout: some View {
    VStack(alignment: .leading, spacing: 2) {
      HStack(spacing: 4) {
        Image(systemName: "leaf.fill").font(.system(size: 11)).widgetAccentable()
        Text(headerText)
          .font(.system(size: 12, weight: .bold))
          .textCase(.uppercase)
          .foregroundStyle(LifeyColors.text2)
          .lineLimit(1)
      }
      HStack(alignment: .firstTextBaseline, spacing: 8) {
        clock
        if let bpm = snapshot.heartRateBpm {
          HStack(spacing: 2) {
            Image(systemName: "heart.fill").font(.system(size: 11))
            Text("\(bpm)").font(LifeyWidgetFont.number(15))
          }
          .foregroundStyle(LifeyColors.heart)
        }
      }
      Text(exerciseLine)
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(LifeyColors.text2)
        .lineLimit(2)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .widgetURL(URL(string: "lifey-watch://workout"))
  }

  private var headerText: String {
    if snapshot.phase == .resting { return String(localized: "widget_rest") }
    return snapshot.title ?? String(localized: "widget_workout_default")
  }

  /// A system-rendered live timer: the elapsed time, or the rest countdown while resting. No wake-ups.
  @ViewBuilder private var clock: some View {
    if snapshot.phase == .resting, let start = snapshot.restStartedAt, let end = snapshot.restEndsAt {
      Text(timerInterval: start...end, countsDown: true, showsHours: false)
        .font(LifeyWidgetFont.number(26)).monospacedDigit().foregroundStyle(LifeyColors.text)
    } else if let startedAt = snapshot.startedAt {
      Text(startedAt, style: .timer)
        .font(LifeyWidgetFont.number(26)).monospacedDigit().foregroundStyle(LifeyColors.text)
    } else {
      Text("—").font(LifeyWidgetFont.number(26)).foregroundStyle(LifeyColors.ghost)
    }
  }

  private var exerciseLine: String {
    guard let name = snapshot.exerciseName else { return "" }
    if let done = snapshot.setsDone, let total = snapshot.setsTotal {
      return String(format: String(localized: "widget_exercise_sets"), name, done, total)
    }
    return name
  }
}

/// Plus Jakarta Sans numerals when the extension bundles them (README step 4), the system font otherwise —
/// `Font.custom` falls back silently, so a missing font never breaks the widget.
enum LifeyWidgetFont {
  static func number(_ size: CGFloat) -> Font {
    .custom("PlusJakartaSans-ExtraBold", size: size)
  }
}
