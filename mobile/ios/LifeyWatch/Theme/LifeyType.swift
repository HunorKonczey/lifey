import CoreText
import SwiftUI

/// Type styles of the watch design system (frame 02, D-X0.6 / D-X0.7).
///
/// Numbers are Plus Jakarta Sans (800 / 700, tabular) at sizes from `WatchMetrics`; every word stays in the
/// system font. Hero and metric grow with Dynamic Type to at most 115 % of their base size, body and label
/// to 135 % (`min(scaled, base × cap)`).
enum LifeyFont {
  static let extraBold = "PlusJakartaSans-ExtraBold"
  static let bold = "PlusJakartaSans-Bold"
  /// Weight 300 for Always-On numbers — the file is not bundled yet (Fonts/README.md); the lookup falls
  /// back to `bold`.
  static let light = "PlusJakartaSans-Light"

  static let numberCap: CGFloat = 1.15
  static let textCap: CGFloat = 1.35

  /// True if the named face is registered (also the DEBUG start-up assertion's check).
  static func isAvailable(_ postScriptName: String) -> Bool {
    let font = CTFontCreateWithName(postScriptName as CFString, 12, nil)
    return (CTFontCopyPostScriptName(font) as String) == postScriptName
  }

  static func assertBundled() {
    #if DEBUG
      assert(isAvailable(extraBold), "PlusJakartaSans-ExtraBold-numerals.ttf is not registered")
      assert(isAvailable(bold), "PlusJakartaSans-Bold-numerals.ttf is not registered")
    #endif
  }
}

/// Resolves a base point size against the current Dynamic Type size, capped at `cap` × base.
private struct CappedSize: ViewModifier {
  let name: String
  let base: CGFloat
  let style: Font.TextStyle
  let cap: CGFloat
  let tracking: CGFloat

  @ScaledMetric private var scaledSize: CGFloat

  init(name: String, base: CGFloat, style: Font.TextStyle, cap: CGFloat, tracking: CGFloat) {
    self.name = name
    self.base = base
    self.style = style
    self.cap = cap
    self.tracking = tracking
    _scaledSize = ScaledMetric(wrappedValue: base, relativeTo: style)
  }

  func body(content: Content) -> some View {
    let size = min(scaledSize, base * cap)
    let fontName = LifeyFont.isAvailable(name) ? name : LifeyFont.bold
    return content
      .font(.custom(fontName, fixedSize: size))
      .monospacedDigit()
      .tracking(tracking)
  }
}

extension View {
  /// `hero` — PJS 800, −2 %, the workout's unit (48 / 42 pt).
  func lifeyHero(_ metrics: WatchMetrics, dense: Bool = false) -> some View {
    let base = dense ? metrics.heroDense : metrics.hero
    return modifier(
      CappedSize(
        name: LifeyFont.extraBold, base: base, style: .largeTitle, cap: LifeyFont.numberCap,
        tracking: -base * 0.02))
  }

  /// `metric` — PJS 800 (28 / 25 pt), heart rate.
  func lifeyMetric(_ metrics: WatchMetrics) -> some View {
    modifier(
      CappedSize(
        name: LifeyFont.extraBold, base: metrics.metric, style: .title2, cap: LifeyFont.numberCap,
        tracking: 0))
  }

  /// `value` — PJS 700 (19 / 17 pt), kcal and tile numbers.
  func lifeyValue(_ metrics: WatchMetrics) -> some View {
    modifier(
      CappedSize(
        name: LifeyFont.bold, base: metrics.value, style: .headline, cap: LifeyFont.numberCap,
        tracking: 0))
  }

  /// `aod-hero` — PJS 300 in Always-On (falls back to 700 until the Light subset is bundled).
  func lifeyAodHero(_ metrics: WatchMetrics) -> some View {
    modifier(
      CappedSize(
        name: LifeyFont.light, base: metrics.hero, style: .largeTitle, cap: LifeyFont.numberCap,
        tracking: -metrics.hero * 0.02))
  }

  /// `title` — system 600, 17 / 16 pt.
  func lifeyTitle(_ metrics: WatchMetrics) -> some View {
    modifier(
      SystemStyle(base: metrics.isCompact ? 16 : 17, weight: .semibold, style: .headline, caps: false))
  }

  /// `body` — system 500, 15 / 14 pt.
  func lifeyBody(_ metrics: WatchMetrics) -> some View {
    modifier(
      SystemStyle(base: metrics.isCompact ? 14 : 15, weight: .medium, style: .body, caps: false))
  }

  /// `body` in the PJS-free bold used for set counts ("2/4"): system 700 at body size.
  func lifeyBodyBold(_ metrics: WatchMetrics) -> some View {
    modifier(
      SystemStyle(base: metrics.isCompact ? 14 : 15, weight: .bold, style: .body, caps: false))
  }

  /// `label` — system 700, 12 / 11 pt, +6 % tracking; CAPS only in the header chip and cardio field labels.
  func lifeyLabel(_ metrics: WatchMetrics, caps: Bool = false) -> some View {
    modifier(
      SystemStyle(base: metrics.isCompact ? 11 : 12, weight: .bold, style: .caption2, caps: caps))
  }
}

private struct SystemStyle: ViewModifier {
  let base: CGFloat
  let weight: Font.Weight
  let style: Font.TextStyle
  let caps: Bool

  @ScaledMetric private var scaledSize: CGFloat

  init(base: CGFloat, weight: Font.Weight, style: Font.TextStyle, caps: Bool) {
    self.base = base
    self.weight = weight
    self.style = style
    self.caps = caps
    _scaledSize = ScaledMetric(wrappedValue: base, relativeTo: style)
  }

  func body(content: Content) -> some View {
    let size = min(scaledSize, base * LifeyFont.textCap)
    return content
      .font(.system(size: size, weight: weight))
      .textCase(caps ? .uppercase : nil)
      .tracking(caps ? size * 0.06 : 0)
  }
}

/// A number in PJS followed by its unit in the system label style, `text2` (frame 02: units are never
/// PJS). The spoken form is supplied by the caller ("128 beats per minute").
struct LifeyNumber: View {
  enum Style { case hero, metric, value }

  let number: String
  var unit: String? = nil
  var style: Style = .value
  var color: Color = LifeyColors.text
  var accessibilityText: String? = nil

  @Environment(\.watchMetrics) private var metrics

  var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: LifeySpacing.xxs) {
      numberText
      if let unit {
        Text(unit)
          .lifeyLabel(metrics)
          .foregroundColor(LifeyColors.text2)
      }
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(accessibilityText ?? [number, unit].compactMap { $0 }.joined(separator: " "))
  }

  @ViewBuilder private var numberText: some View {
    switch style {
    case .hero: Text(number).lifeyHero(metrics).foregroundColor(color)
    case .metric: Text(number).lifeyMetric(metrics).foregroundColor(color)
    case .value: Text(number).lifeyValue(metrics).foregroundColor(color)
    }
  }
}

#Preview("Numerals 45 mm") {
  VStack(alignment: .leading, spacing: 6) {
    LifeyNumber(number: "12:34", style: .hero)
    LifeyNumber(number: "62,5", unit: "kg", style: .metric)
    LifeyNumber(number: "3.42", unit: "km", style: .value)
    LifeyNumber(number: "1:05:12", style: .value)
  }
  .environment(\.watchMetrics, WatchMetrics(width: 198))
  .background(LifeyColors.bg)
}

#Preview("Numerals 41 mm") {
  VStack(alignment: .leading, spacing: 6) {
    LifeyNumber(number: "12:34", style: .hero)
    LifeyNumber(number: "62,5", unit: "kg", style: .metric)
    LifeyNumber(number: "3.42", unit: "km", style: .value)
    LifeyNumber(number: "1:05:12", style: .value)
  }
  .environment(\.watchMetrics, WatchMetrics(width: 176))
  .background(LifeyColors.bg)
}
