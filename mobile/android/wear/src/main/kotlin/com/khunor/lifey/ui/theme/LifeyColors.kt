package com.khunor.lifey.ui.theme

import androidx.compose.ui.graphics.Color

/**
 * The Lifey watch palette, Design System v2 (docs/redesign-watch/79-watch-redesign-plan.md D-X0.2).
 * Dark-only; mirrors the Apple Watch `LifeyColors.swift` name-for-name and hex-for-hex — a JVM test
 * (`TokenParityTest`) compares the two files. `bg` is true `#000` (D4), the only deliberate deviation
 * from the mobile `#12130E`.
 *
 * The v1 names stay at the bottom as deprecated aliases re-pointed at the nearest v2 token (D-X0.1)
 * and are deleted with the last Wear iteration (X4.16).
 */
object LifeyColors {
    // Surfaces — the tone ladder above true black
    val bg = Color(0xFF000000)
    val card = Color(0xFF1A1C15)
    val nested = Color(0xFF22251C)
    val control = Color(0xFF2C2F24)
    val raised = Color(0xFF36392D)
    /** Ambient only: outlined bars and rings. */
    val outline = Color(0xFF45483B)

    // Text — 19.4 / 10.3 / 6.3 : 1 on black; text3 is never below 13 sp
    val text = Color(0xFFF2F1E6)
    val text2 = Color(0xFFB6B5A5)
    val text3 = Color(0xFF8F8F80)
    /** Disabled content (D-X0.10): used with a `card` background, never as alpha. */
    val ghost = Color(0xFF5E5F55)

    // Control colour — controls only, never text, never a large fill
    val primary = Color(0xFFB5C47C)
    val onPrimary = Color(0xFF1A1F0A)

    // Metric and role colours
    val heart = Color(0xFFE07F76)
    /** kcal; also the warning role (rest's last 5 s, "already running"). */
    val calories = Color(0xFFEC9A66)
    val success = Color(0xFF93C98C)
    /** Same hex as [heart]; always shown with an icon so the shape separates it from HR. */
    val error = Color(0xFFE07F76)
    /** Side path: paused, bench, "Módosítás" icon, stepper header. */
    val clay = Color(0xFFC49A6C)

    // Cardio activity accents — icon and header-chip label only, never the hero.
    // Follow the mobile v2 `activityTypeColor`: run = calories, hike = mobile `tertiary`,
    // cycling = clay, other = text2.
    val cardioWalking = Color(0xFFC593CC)
    val cardioHiking = Color(0xFF6E9A6A)
    val cardioIndoorBike = Color(0xFFE2BE62)
    val cardioBasketball = Color(0xFFA3A1DB)
    val cardioFootball = Color(0xFF74B6D6)

    /** The tinted chip/pill background for a role colour: the role at 16 % (D-R0.4). */
    fun tint(role: Color): Color = role.copy(alpha = TINT_ALPHA)

    const val TINT_ALPHA = 0.16f
}
