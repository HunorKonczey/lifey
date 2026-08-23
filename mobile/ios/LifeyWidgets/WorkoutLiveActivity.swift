import ActivityKit
import SwiftUI
import WidgetKit

// Lock screen + Dynamic Island UI for a running workout. See
// docs/24-ios-widget-live-activity-plan.md, "Live Activity UI". Reuses
// `Palette` from TodaySummaryWidget.swift for the app's light/dark colors.

@available(iOS 16.1, *)
struct WorkoutLiveActivity: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: WorkoutActivityAttributes.self) { context in
      Group {
        if context.state.kind == "CARDIO", let cardio = context.state.cardio {
          CardioLockScreenView(attributes: context.attributes, state: context.state, cardio: cardio)
        } else {
          LockScreenView(attributes: context.attributes, state: context.state)
        }
      }
      .padding(16)
      .activityBackgroundTint(Color(red: 0x16 / 255, green: 0x16 / 255, blue: 0x11 / 255))
      .activitySystemActionForegroundColor(.white)
      // Own widgetURL for the lock screen presentation — it does NOT
      // inherit the one set below on the Dynamic Island. Distinct from
      // TodaySummaryWidget's `lifey://today` since tapping a running
      // workout should reopen that workout, not the dashboard (see
      // app_router.dart's onException handling of the `workout` host).
      .widgetURL(URL(string: "lifey://workout"))
    } dynamicIsland: { context in
      // One DynamicIsland value, not two branches returning different
      // instances — its generic Content types are fixed once per widget, so
      // the STRENGTH/CARDIO choice has to live *inside* each @ViewBuilder
      // region/compact closure (same trick as the Group above), not at the
      // level of picking between two whole DynamicIsland literals.
      let cardio = context.state.kind == "CARDIO" ? context.state.cardio : nil
      return DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          if let cardio {
            CardioIslandLeading(activityType: context.state.activityType, cardio: cardio)
          } else {
            ElapsedTimerView(startedAtEpochMs: context.attributes.startedAtEpochMs)
              .font(.system(size: 14, weight: .semibold))
              .foregroundColor(.white)
          }
        }
        DynamicIslandExpandedRegion(.trailing) {
          if let cardio {
            CardioIslandTrailing(cardio: cardio)
          } else {
            RestTimerView(
              lastSetAtEpochMs: context.state.lastSetAtEpochMs,
              restEndsAtEpochMs: context.state.restEndsAtEpochMs
            )
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(.white)
          }
        }
        DynamicIslandExpandedRegion(.bottom) {
          if let cardio {
            CardioIslandBottom(cardio: cardio)
          } else {
            ExerciseProgressView(state: context.state)
              .foregroundColor(.white)
          }
        }
      } compactLeading: {
        Image(systemName: cardio != nil ? cardioActivitySymbol(context.state.activityType) : "dumbbell.fill")
      } compactTrailing: {
        if let cardio {
          Text(cardio.primaryValue)
            .font(.system(size: 13, weight: .semibold))
            .monospacedDigit()
            .lineLimit(1)
            .opacity(cardio.paused ? 0.6 : 1)
        } else {
          RestTimerView(
            lastSetAtEpochMs: context.state.lastSetAtEpochMs,
            restEndsAtEpochMs: context.state.restEndsAtEpochMs
          )
          .font(.system(size: 13, weight: .semibold))
        }
      } minimal: {
        Image(systemName: cardio != nil ? cardioActivitySymbol(context.state.activityType) : "dumbbell.fill")
      }
      .widgetURL(URL(string: "lifey://workout"))
    }
  }
}

// MARK: - Timers
// Per the plan's Key Design Decision #4: SwiftUI renders these natively —
// no push/update needed while backgrounded. ElapsedTimerView always counts
// *up* (open-ended range to .distantFuture, countsDown: false). RestTimerView
// counts down to a known rest-timer target when one exists, otherwise up from
// the last set — see its own doc comment below.

@available(iOS 16.1, *)
private struct ElapsedTimerView: View {
  let startedAtEpochMs: Int64

  var body: some View {
    let start = Date(timeIntervalSince1970: Double(startedAtEpochMs) / 1000)
    Text(timerInterval: start...Date.distantFuture, countsDown: false, showsHours: true)
      .monospacedDigit()
  }
}

// Countdown when a rest-timer target is known and still in the future
// (docs/39-rest-timer-plan.md, Prompt 5); otherwise the original plain
// count-up since the last set — structural extension of the "no rest target
// in the data model" note in Key Design Decision #4, now that one exists.
@available(iOS 16.1, *)
private struct RestTimerView: View {
  let lastSetAtEpochMs: Int64?
  let restEndsAtEpochMs: Int64?

  var body: some View {
    let nowMs = Int64(Date().timeIntervalSince1970 * 1000)
    if let restEndsAtEpochMs, restEndsAtEpochMs > nowMs {
      let end = Date(timeIntervalSince1970: Double(restEndsAtEpochMs) / 1000)
      HStack(spacing: 4) {
        Image(systemName: "hourglass")
        Text(timerInterval: Date()...end, countsDown: true, showsHours: false)
          .monospacedDigit()
      }
    } else if let lastSetAtEpochMs {
      let start = Date(timeIntervalSince1970: Double(lastSetAtEpochMs) / 1000)
      HStack(spacing: 4) {
        Image(systemName: "hourglass")
        Text(timerInterval: start...Date.distantFuture, countsDown: false, showsHours: false)
          .monospacedDigit()
      }
    }
    // Hidden before the first set — no lastSetAtEpochMs yet.
  }
}

// MARK: - Exercise + set progress

@available(iOS 16.1, *)
private struct ExerciseProgressView: View {
  let state: WorkoutActivityAttributes.ContentState

  private var setsLabel: String {
    if let total = state.setsTotal {
      return "\(state.setsDone)/\(total)"
    }
    return "\(state.setsDone)"
  }

  var body: some View {
    HStack {
      Text(state.exerciseName)
        .font(.system(size: 13, weight: .semibold))
        .lineLimit(1)
      Spacer()
      Text(setsLabel)
        .font(.system(size: 13, weight: .medium))
        .opacity(0.75)
    }
  }
}

// MARK: - Lock screen

@available(iOS 16.1, *)
private struct LockScreenView: View {
  let attributes: WorkoutActivityAttributes
  let state: WorkoutActivityAttributes.ContentState

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Text(attributes.title)
          .font(.system(size: 15, weight: .bold))
          .foregroundColor(.white)
        Spacer()
        ElapsedTimerView(startedAtEpochMs: attributes.startedAtEpochMs)
          .font(.system(size: 15, weight: .bold))
          .foregroundColor(.white)
      }
      ExerciseProgressView(state: state)
        .foregroundColor(.white.opacity(0.9))
      if state.lastSetAtEpochMs != nil {
        RestTimerView(
          lastSetAtEpochMs: state.lastSetAtEpochMs,
          restEndsAtEpochMs: state.restEndsAtEpochMs
        )
        .font(.system(size: 13, weight: .medium))
        .foregroundColor(.white.opacity(0.7))
      }
    }
  }
}

// MARK: - Cardio (docs/cardio/59-cardio-implementation-plan.md C2.10b)
//
// M23/M24 mockups (design/Lifey Cardio Design.dc.html): a header row (icon +
// activity name + the moving-time checkpoint, ticking natively) above a
// metrics row (the family's primary metric large, up to two supporting
// stats). Same three label/value pairs feed both the lock screen and the
// Dynamic Island's expanded regions — only the arrangement differs.

/// SF Symbol per `activity_type.dart`'s `kActivityTypes` code — icon-only
/// mapping (never translated text, per the plan's decision #6), so a raw
/// code switch here doesn't duplicate any localization.
private func cardioActivitySymbol(_ activityType: String?) -> String {
  switch activityType {
  case "RUNNING": return "figure.run"
  case "WALKING": return "figure.walk"
  case "HIKING": return "figure.hiking"
  // Outdoor cycling (docs/cardio/62-cardio-cycling-plan.md A6) — distinct
  // from INDOOR_BIKE's "bicycle" below, mirroring the same symbol choice
  // `LifeyWatch/Views/ActiveWorkoutView.swift`'s `cardioActivityIcon` makes.
  case "CYCLING": return "figure.outdoor.cycle"
  case "INDOOR_BIKE": return "bicycle"
  case "BASKETBALL": return "basketball.fill"
  case "FOOTBALL": return "soccerball"
  default: return "bolt.fill"  // OTHER_CARDIO, or an activityType this build doesn't know yet
  }
}

/// The epoch a `Text(timerInterval:)` should count up from to show the
/// *moving*-time checkpoint live — shifting the anchor back by the
/// already-accrued base, the same "when = since − base" trick
/// `WorkoutSessionNotifierService._renderAndroidNotification` uses for
/// Android's chronometer (C2.10a). `nil` while paused (mirrors
/// `CardioLiveMetrics.movingSinceEpochMs`'s own nil-while-paused contract).
private func cardioMovingStartDate(_ cardio: CardioLiveMetricsState) -> Date? {
  guard let since = cardio.movingSinceEpochMs else { return nil }
  let baseMs = Int64(cardio.movingSecondsBase ?? 0) * 1000
  return Date(timeIntervalSince1970: Double(since - baseMs) / 1000)
}

/// Swift port of `CardioFormatter.duration` — only needed for the paused,
/// static render (the running case ticks natively and never calls this).
private func cardioDurationText(_ totalSeconds: Int) -> String {
  let hours = totalSeconds / 3600
  let minutes = (totalSeconds % 3600) / 60
  let seconds = totalSeconds % 60
  let ss = String(format: "%02d", seconds)
  if hours > 0 {
    return "\(hours):\(String(format: "%02d", minutes)):\(ss)"
  }
  return "\(minutes):\(ss)"
}

/// Ticks live while moving; freezes on the pre-formatted base the instant
/// [CardioLiveMetrics.paused] is true — never keeps counting through a
/// pause, which is exactly the bug `usesChronometer: false` exists to avoid
/// on the Android side (C2.10a).
@available(iOS 16.1, *)
private struct CardioMovingTimeView: View {
  let cardio: CardioLiveMetricsState

  var body: some View {
    if !cardio.paused, let start = cardioMovingStartDate(cardio) {
      Text(timerInterval: start...Date.distantFuture, countsDown: false, showsHours: true)
        .monospacedDigit()
    } else {
      Text(cardioDurationText(cardio.movingSecondsBase ?? 0))
        .monospacedDigit()
    }
  }
}

@available(iOS 16.1, *)
private struct CardioStatPair: View {
  let label: String
  let value: String

  var body: some View {
    VStack(spacing: 2) {
      Text(value)
        .font(.system(size: 17, weight: .bold))
        .foregroundColor(.white)
        .monospacedDigit()
      Text(label)
        .font(.system(size: 9, weight: .semibold))
        .foregroundColor(.white.opacity(0.6))
    }
  }
}

/// Drops a slot whose value is the unmeasured-placeholder `"—"` (e.g.
/// GAME's heart rate today, per `CardioSessionScreen._cardioLiveMetrics`) —
/// same "missing beats ugly" call as the Android body-string filter in
/// `WorkoutSessionNotifierService._renderAndroidNotification`.
private func cardioStatVisible(_ value: String?) -> Bool {
  guard let value else { return false }
  return value != "—"
}

@available(iOS 16.1, *)
private struct CardioHeaderView: View {
  let title: String
  let activityType: String?
  let cardio: CardioLiveMetricsState

  var body: some View {
    HStack {
      HStack(spacing: 8) {
        Image(systemName: cardioActivitySymbol(activityType))
          .font(.system(size: 14))
        Text(title)
          .font(.system(size: 15, weight: .bold))
      }
      .foregroundColor(.white)
      Spacer()
      HStack(spacing: 4) {
        if cardio.paused {
          Image(systemName: "pause.circle.fill")
        }
        CardioMovingTimeView(cardio: cardio)
      }
      .font(.system(size: 15, weight: .bold))
      .foregroundColor(.white.opacity(cardio.paused ? 0.6 : 1))
    }
  }
}

@available(iOS 16.1, *)
private struct CardioMetricsRow: View {
  let cardio: CardioLiveMetricsState

  var body: some View {
    HStack(alignment: .lastTextBaseline) {
      VStack(alignment: .leading, spacing: 2) {
        Text(cardio.primaryLabel.uppercased())
          .font(.system(size: 10, weight: .bold))
          .foregroundColor(.white.opacity(0.6))
        Text(cardio.primaryValue)
          .font(.system(size: 34, weight: .bold))
          .foregroundColor(.white.opacity(cardio.paused ? 0.55 : 1))
          .monospacedDigit()
      }
      Spacer()
      HStack(spacing: 16) {
        if cardioStatVisible(cardio.secondaryValue) {
          CardioStatPair(label: cardio.secondaryLabel ?? "", value: cardio.secondaryValue!)
        }
        if cardioStatVisible(cardio.tertiaryValue) {
          CardioStatPair(label: cardio.tertiaryLabel ?? "", value: cardio.tertiaryValue!)
        }
      }
    }
  }
}

@available(iOS 16.1, *)
private struct CardioLockScreenView: View {
  let attributes: WorkoutActivityAttributes
  let state: WorkoutActivityAttributes.ContentState
  let cardio: CardioLiveMetricsState

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      CardioHeaderView(title: attributes.title, activityType: state.activityType, cardio: cardio)
      CardioMetricsRow(cardio: cardio)
    }
  }
}

// MARK: - Cardio Dynamic Island regions

@available(iOS 16.1, *)
private struct CardioIslandLeading: View {
  let activityType: String?
  let cardio: CardioLiveMetricsState

  var body: some View {
    HStack(spacing: 6) {
      Image(systemName: cardioActivitySymbol(activityType))
      CardioMovingTimeView(cardio: cardio)
    }
    .font(.system(size: 13, weight: .semibold))
    .foregroundColor(.white)
  }
}

@available(iOS 16.1, *)
private struct CardioIslandTrailing: View {
  let cardio: CardioLiveMetricsState

  var body: some View {
    VStack(alignment: .trailing, spacing: 1) {
      Text(cardio.primaryValue)
        .font(.system(size: 15, weight: .bold))
        .monospacedDigit()
      if cardioStatVisible(cardio.secondaryValue) {
        Text(cardio.secondaryValue!)
          .font(.system(size: 11, weight: .semibold))
          .opacity(0.7)
      }
    }
    .foregroundColor(.white)
    .opacity(cardio.paused ? 0.6 : 1)
  }
}

@available(iOS 16.1, *)
private struct CardioIslandBottom: View {
  let cardio: CardioLiveMetricsState

  var body: some View {
    if cardioStatVisible(cardio.tertiaryValue) {
      HStack {
        Text(cardio.tertiaryLabel ?? "")
          .font(.system(size: 11, weight: .semibold))
          .opacity(0.6)
        Spacer()
        Text(cardio.tertiaryValue!)
          .font(.system(size: 12, weight: .semibold))
          .monospacedDigit()
      }
      .foregroundColor(.white)
    }
    // Hidden when the tertiary metric is unmeasured — mirrors RestTimerView
    // above, which the same STRENGTH region renders instead.
  }
}
