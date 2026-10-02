import SwiftUI
import WidgetKit

/// Complication (frame AW2.25, redesign X2.o2), `accessoryCircular`: during a rest the remaining time inside a
/// white ring that drains; otherwise the elapsed time; outside a workout a leaf that opens the start picker.
/// Tinted faces colour it through the system (`widgetAccentable`), so no colour is forced on the ring or glyph.
struct LifeyCircularComplication: Widget {
  static let kind = "LifeyWorkoutComplication"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: Self.kind, provider: WorkoutProvider()) { entry in
      LifeyCircularComplicationView(snapshot: entry.snapshot)
        .containerBackground(for: .widget) { Color.clear }
    }
    .configurationDisplayName(String(localized: "complication_display_name"))
    .description(String(localized: "complication_description"))
    .supportedFamilies([.accessoryCircular])
  }
}

struct LifeyCircularComplicationView: View {
  let snapshot: WatchWidgetSnapshot

  var body: some View {
    switch snapshot.phase {
    case .idle:
      ZStack {
        AccessoryWidgetBackground()
        Image(systemName: "leaf.fill").font(.system(size: 20)).widgetAccentable()
      }
      .widgetURL(URL(string: "lifey-watch://quick-strength"))
    case .resting:
      if let start = snapshot.restStartedAt, let end = snapshot.restEndsAt {
        ProgressView(timerInterval: start...end, countsDown: true) {
          EmptyView()
        } currentValueLabel: {
          Text(timerInterval: start...end, countsDown: true, showsHours: false)
            .font(LifeyWidgetFont.number(14)).monospacedDigit()
        }
        .progressViewStyle(.circular)
        .tint(LifeyColors.text)
        .widgetAccentable()
        .widgetURL(URL(string: "lifey-watch://workout"))
      } else {
        elapsed
      }
    case .active:
      elapsed
    }
  }

  private var elapsed: some View {
    ZStack {
      AccessoryWidgetBackground()
      if let startedAt = snapshot.startedAt {
        Text(startedAt, style: .timer)
          .font(LifeyWidgetFont.number(15)).monospacedDigit()
          .multilineTextAlignment(.center).minimumScaleFactor(0.6)
          .padding(4)
      } else {
        Image(systemName: "leaf.fill").widgetAccentable()
      }
    }
    .widgetURL(URL(string: "lifey-watch://workout"))
  }
}
