import SwiftUI

extension Color {
  init(hex: UInt32) {
    self.init(
      red: Double((hex >> 16) & 0xFF) / 255,
      green: Double((hex >> 8) & 0xFF) / 255,
      blue: Double(hex & 0xFF) / 255)
  }

  /// The tinted chip/pill background of the v2 system (D-X0.2): the role colour at 16 %.
  /// The one place that opacity is written — screens call `LifeyColors.tint(_:)`.
  var lifeyTint: Color { opacity(0.16) }
}

/// The Lifey watch palette, Design System v2 (docs/redesign-watch/79-watch-redesign-plan.md D-X0.2).
/// Dark-only; mirrors Android's `LifeyColors.kt` name-for-name and hex-for-hex (a Wear JVM test
/// compares the two files). `bg` is true `#000` (D4) — the only deliberate deviation from the
/// mobile `#12130E`.
enum LifeyColors {
  // Surfaces — the tone ladder above true black
  static let bg = Color(hex: 0x00_00_00)
  static let card = Color(hex: 0x1A_1C_15)
  static let nested = Color(hex: 0x22_25_1C)
  static let control = Color(hex: 0x2C_2F_24)
  static let raised = Color(hex: 0x36_39_2D)
  /// AOD only: outlined bars and rings.
  static let outline = Color(hex: 0x45_48_3B)

  // Text — 19.4 / 10.3 / 6.3 : 1 on black; text3 is never below 13 pt
  static let text = Color(hex: 0xF2_F1_E6)
  static let text2 = Color(hex: 0xB6_B5_A5)
  static let text3 = Color(hex: 0x8F_8F_80)
  /// Disabled content (D-X0.10): used with a `card` background, never as opacity.
  static let ghost = Color(hex: 0x5E_5F_55)

  // Control colour — controls only, never text, never a large fill
  static let primary = Color(hex: 0xB5_C4_7C)
  static let onPrimary = Color(hex: 0x1A_1F_0A)

  // Metric and role colours
  static let heart = Color(hex: 0xE0_7F_76)
  /// kcal; also the warning role (rest's last 5 s, "already running").
  static let calories = Color(hex: 0xEC_9A_66)
  static let success = Color(hex: 0x93_C9_8C)
  /// Same hex as `heart`; always shown with an icon so the shape separates it from HR.
  static let error = Color(hex: 0xE0_7F_76)
  /// Side path: paused, bench, "Módosítás" icon, stepper header.
  static let clay = Color(hex: 0xC4_9A_6C)

  // Cardio activity accents — icon and header-chip label only, never the hero.
  // Follow the mobile v2 `activityTypeColor`: run = calories, hike = mobile `tertiary`, cycling = clay,
  // other = text2.
  static let cardioWalking = Color(hex: 0xC5_93_CC)
  static let cardioHiking = Color(hex: 0x6E_9A_6A)
  static let cardioIndoorBike = Color(hex: 0xE2_BE_62)
  static let cardioBasketball = Color(hex: 0xA3_A1_DB)
  static let cardioFootball = Color(hex: 0x74_B6_D6)

  /// The tinted chip/pill background for a role colour (16 %).
  static func tint(_ role: Color) -> Color { role.lifeyTint }
}
