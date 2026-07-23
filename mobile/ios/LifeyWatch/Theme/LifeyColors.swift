import SwiftUI

extension Color {
  init(hex: UInt32) {
    self.init(
      red: Double((hex >> 16) & 0xFF) / 255,
      green: Double((hex >> 8) & 0xFF) / 255,
      blue: Double(hex & 0xFF) / 255)
  }
}

/// The Lifey brand's dark-only color palette (41-watch-design-prompt.md §2),
/// as flat constants — mirrors Android's `LifeyColors.kt` value-for-value
/// (docs/40-watch-app-plan.md §12.1 B6) so both watch platforms render the
/// same hex, not just the same token names.
///
/// `heart` deviates from the prompt's own §2.4 table (`#C46A6A`): every
/// single frame in the shipped design canvas (`docs/watch/design/Lifey Watch
/// Design.dc.html`) — Apple Watch, Wear OS, and the phone screens alike —
/// uses `#D97F7F` for the heart-rate icon/number instead. Same tie-break
/// rule the 42-doc's D0.1 applied to the elapsed-time color (canvas over
/// prompt, since the canvas is the later, visually-checked artifact): this
/// file follows the canvas, matching Android's own `LifeyColors.kt` note.
enum LifeyColors {
  // 2.1 Surfaces
  /// True AMOLED black — what the screen itself sits on, not a token from
  /// §2.1, but explicitly sanctioned by §2.1's own note ("on watch: may sit
  /// on #000000").
  static let trueBlack = Color(hex: 0x00_00_00)
  static let bg = Color(hex: 0x16_16_11)
  static let surface = Color(hex: 0x1C_1E_16)
  static let container = Color(hex: 0x22_24_1B)
  static let containerHigh = Color(hex: 0x2A_2C_20)
  static let containerHighest = Color(hex: 0x32_34_2A)
  static let outline = Color(hex: 0x3C_3E_32)

  // 2.2 Accents
  static let primary = Color(hex: 0x9D_AE_6B)
  static let secondary = Color(hex: 0xC4_9A_6C)
  static let tertiary = Color(hex: 0x6E_9A_6A)

  // 2.3 Text
  static let onSurface = Color(hex: 0xF1_F0_E4)
  static let onSurfaceVariant = Color(hex: 0xA8_A8_99)
  static let onPrimary = Color(hex: 0x16_16_11)

  // 2.4 Metric accents — see the enum doc for the `heart` canvas/prompt note
  static let heart = Color(hex: 0xD9_7F_7F)
  static let calories = Color(hex: 0xE0_91_5A)
  static let positive = Color(hex: 0x9D_AE_6B)
  static let negative = Color(hex: 0xE0_8A_52)
}
