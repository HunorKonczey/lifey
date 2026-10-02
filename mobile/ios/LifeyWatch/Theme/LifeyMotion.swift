import SwiftUI

/// Motion of the watch design system (frame 07, D-X0.14): the v2 durations and curves on the wrist.
/// Ticking numbers never animate — they swap; only summary tiles count up.
enum LifeyMotion {
  /// Durations in seconds.
  enum Duration {
    static let tap = 0.100  // circle scales to 0.96, one tone step up
    static let setLogged = 0.250  // circle primary → success tint
    static let countUp = 0.600  // summary tiles only
    static let crossFade = 0.300  // stepper / rest with the metric page
    static let tintSwitch = 0.250  // sync row pending → synced, last-5 s colour
    static let goIn = 0.150  // "Mehet!" rim: in
    static let goHold = 0.250  //          hold
    static let goOut = 0.700  //          out
    static let stagger = 0.060  // "Edzés mentve" tiles
  }

  /// `cubic(0.2, 0, 0, 1)`
  static func standard(_ duration: Double) -> Animation {
    .timingCurve(0.2, 0, 0, 1, duration: duration)
  }
  /// `cubic(0.05, 0.7, 0.1, 1)`
  static func enter(_ duration: Double) -> Animation {
    .timingCurve(0.05, 0.7, 0.1, 1, duration: duration)
  }
  /// `cubic(0.3, 0, 0.8, 0.15)`
  static func exit(_ duration: Double) -> Animation {
    .timingCurve(0.3, 0, 0.8, 0.15, duration: duration)
  }

  /// The animation to use for `base`, or `nil` (no animation, 0 ms) under Reduce Motion.
  static func animation(_ base: Animation, reduceMotion: Bool) -> Animation? {
    reduceMotion ? nil : base
  }

  /// "Mehet!" with Reduce Motion: the rim is shown statically for 1.1 s (150 + 250 + 700 ms).
  static let goStaticSeconds = Duration.goIn + Duration.goHold + Duration.goOut
}

/// `withAnimation` that respects Reduce Motion (0 ms).
func withLifeyAnimation<Result>(
  _ animation: Animation, reduceMotion: Bool, _ body: () throws -> Result
) rethrows -> Result {
  try withAnimation(LifeyMotion.animation(animation, reduceMotion: reduceMotion), body)
}
