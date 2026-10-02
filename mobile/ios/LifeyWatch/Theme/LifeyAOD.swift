import SwiftUI

/// Always-On primitives (frame 08, D-X0.15): only the active screens get an AOD variant (metrics, rest,
/// cardio, bench). Pure black, nothing filled, numbers PJS 300 in `text2`, metric colours at 60 %,
/// outlined symbols, minute resolution. The screens opt in during X2.11–X2.13.
enum LifeyAOD {
  /// "12 p" for under an hour, "1 ó 05 p" from an hour on (elapsed time without seconds).
  static func elapsed(_ seconds: Int) -> String {
    let minutes = max(seconds, 0) / 60
    if minutes < 60 {
      return String(format: String(localized: "aod_minutes"), minutes)
    }
    return String(format: String(localized: "aod_hours_minutes"), minutes / 60, minutes % 60)
  }

  /// Rest remaining rounded **up** to whole minutes: "~1 p".
  static func remaining(_ seconds: Int) -> String {
    let minutes = Int((Double(max(seconds, 0)) / 60).rounded(.up))
    return "~" + String(format: String(localized: "aod_minutes"), minutes)
  }

  /// "Mehet 9:42-kor" — the rest's end time in the device's time zone and 12/24 h convention.
  static func restUntil(endsAt: Date, timeZone: TimeZone = .current, locale: Locale = .current) -> String {
    var style = Date.FormatStyle(date: .omitted, time: .shortened, locale: locale, timeZone: timeZone)
    style.locale = locale
    return String(format: String(localized: "aod_rest_until"), endsAt.formatted(style))
  }

  /// The AOD symbol: outlined (non-`.fill`) variant of an SF Symbol name.
  static func symbol(_ name: String, filled: Bool = false) -> String {
    guard !filled, name.hasSuffix(".fill") else { return name }
    return String(name.dropLast(".fill".count))
  }

  /// Metric colours dim to 60 % in Always-On.
  static func metricTint(_ color: Color) -> Color { color.opacity(0.6) }

  /// AOD number colour.
  static let numberColor = LifeyColors.text2
}

extension View {
  /// `aod-hero` number in AOD: PJS 300 (Bold fallback until bundled), `text2`.
  func lifeyAodNumber(_ metrics: WatchMetrics) -> some View {
    lifeyAodHero(metrics).foregroundColor(LifeyAOD.numberColor)
  }
}

/// True under reduced luminance (Always-On), or when the DEBUG gallery's AOD toggle forces it.
struct AODReader<Content: View>: View {
  @Environment(\.isLuminanceReduced) private var luminanceReduced
  #if DEBUG
    @Environment(\.galleryAOD) private var galleryAOD
  #endif
  @ViewBuilder let content: (Bool) -> Content

  var body: some View {
    #if DEBUG
      content(luminanceReduced || galleryAOD)
    #else
      content(luminanceReduced)
    #endif
  }
}

/// A timeline that ticks once a second normally and once a minute under reduced luminance — AOD screens
/// must not redraw per second. `isAOD` is passed through for the content to pick its variant.
struct MinuteTimeline<Content: View>: View {
  @ViewBuilder let content: (Date, Bool) -> Content

  var body: some View {
    AODReader { isAOD in
      if isAOD {
        TimelineView(.everyMinute) { context in content(context.date, true) }
      } else {
        TimelineView(.periodic(from: .now, by: 1)) { context in content(context.date, false) }
      }
    }
  }
}
