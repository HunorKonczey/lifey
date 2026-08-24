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

  // 2.5 Error — added for the F5 log-set "failed" toast (docs/watch/
  // 43-watch-f5-set-logging-plan.md §3.2); mirrors Android's `LifeyColors.kt`,
  // which already has this section.
  static let error = Color(hex: 0xCF_66_79)
  static let onError = Color(hex: 0x1C_00_08)
  static let errorContainer = Color(hex: 0x8C_1D_2F)
  static let onErrorContainer = Color(hex: 0xFF_B3_BF)

  /// Dimmed content color for a ghosted/inert control — the log-set
  /// control's pending and phone-unreachable states (canvas AW 09/AW 11,
  /// docs/watch/43-watch-f5-set-logging-plan.md §3.2/§4.4). Not yet in
  /// Android's `LifeyColors.kt` since Wear's own log-lap ships later (S13)
  /// — add the identical hex there when it does.
  static let ghostedOnSurface = Color(hex: 0x46_46_3E)

  /// The standalone mode indicator's own muted tone — canvas AW 14/W 13
  /// explicitly calls for something quieter than `onSurfaceVariant`
  /// (docs/watch/44-watch-f6-standalone-plan.md §3.4: "mode, not alarm —
  /// muted `777264`"), since it's a passive glyph next to the header label,
  /// not informational text. Not yet in Android's `LifeyColors.kt` since
  /// Wear's own active-screen delta ships later (S17) — add the identical
  /// hex there when it does.
  static let standaloneIndicator = Color(hex: 0x77_72_64)

  // 2.6 Cardio activity-type accents (docs/cardio/55-cardio-watch-plan.md §2,
  // picker rows — C5.4) — the same hex the mobile app's `MetricColors` uses
  // for the matching activity (`activity_type.dart`'s `activityTypeColor`),
  // kept identical across platforms like every other token in this file.
  // `RUNNING` reuses `calories` (`0xE0915A` on both), `HIKING` reuses
  // `tertiary` (`0x6E9A6A`), and `CYCLING` (docs/cardio/62-cardio-cycling-
  // plan.md A6) reuses `secondary` (`0xC49A6C`) — the mobile app's
  // `colorScheme.secondary`, for the same "every AppMetricColors slot
  // already claimed" reason documented there — rather than duplicating any
  // of these three hexes under a second name. Only the four colors this
  // file didn't already have get their own constant.
  /// `WALKING` — mirrors mobile's `MetricColors.steps`.
  static let cardioWalking = Color(hex: 0xB0_8A_C8)
  /// `INDOOR_BIKE` — mirrors mobile's `MetricColors.carbs`.
  static let cardioIndoorBike = Color(hex: 0xD8_B3_5A)
  /// `BASKETBALL` — mirrors mobile's `MetricColors.fat`.
  static let cardioBasketball = Color(hex: 0x8E_8E_C4)
  /// `FOOTBALL` — mirrors mobile's `MetricColors.water`.
  static let cardioFootball = Color(hex: 0x6F_A8_C4)
}
