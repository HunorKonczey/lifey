import WatchKit

/// The haptic map of the watch design system (frame 07, D-X0.14): one function per event, each wrapping
/// the existing `WKHapticType`. Events and timing are unchanged by the redesign; the map only records
/// which visual each one accompanies. Call sites keep calling from the place they always did — the rest
/// vibration in particular stays timed from `WorkoutManager`'s own clock, independent of what is on
/// screen.
enum LifeyHaptics {
  /// Set logged ↔ the "+1" circle turns success.
  static func setLogged() { play(.success) }
  /// Logging failed ↔ the error pill (≈ 2.5 s).
  static func logFailed() { play(.failure) }
  /// Rest over ↔ the "Mehet!" rim.
  static func restOver() { play(.notification) }
  /// Stepper ± ↔ the number swaps. The crown's own detents are the system's.
  static func stepperTick() { play(.click) }
  /// Tapping the standalone mark / "sync now" ↔ the raised mark.
  static func syncTap() { play(.click) }

  private static func play(_ type: WKHapticType) {
    WKInterfaceDevice.current().play(type)
  }
}
