package com.khunor.lifey.ui.theme

import androidx.compose.ui.graphics.Color

/**
 * The Lifey brand's dark-only color palette (41-watch-design-prompt.md §2),
 * as flat constants — this is the single place the raw hex values live so
 * every screen references the same tokens instead of re-declaring private
 * per-file `Color(0x...)` vals (docs/40-watch-app-plan.md §12.1 B6).
 *
 * `heart` deviates from the prompt's own §2.4 table (`#C46A6A`): every single
 * frame in the shipped design canvas (`docs/watch/design/Lifey Watch
 * Design.dc.html`) — Apple Watch, Wear OS, and the phone screens alike —
 * uses `#D97F7F` for the heart-rate icon/number instead. Same tie-break rule
 * the 42-doc's D0.1 applied to the elapsed-time color (canvas over prompt,
 * since the canvas is the later, visually-checked artifact): this file
 * follows the canvas. Flagged here in case that was an unintentional drift
 * rather than a deliberate re-pick.
 */
object LifeyColors {
    // 2.1 Surfaces
    /** True AMOLED black — what the screen itself sits on, not a token from
     * §2.1, but explicitly sanctioned by §2.1's own note ("on watch: may sit
     * on #000000"). */
    val trueBlack = Color(0xFF000000)
    val bg = Color(0xFF161611)
    val surface = Color(0xFF1C1E16)
    val container = Color(0xFF22241B)
    val containerHigh = Color(0xFF2A2C20)
    val containerHighest = Color(0xFF32342A)
    val outline = Color(0xFF3C3E32)

    // 2.2 Accents
    val primary = Color(0xFF9DAE6B)
    val secondary = Color(0xFFC49A6C)
    val tertiary = Color(0xFF6E9A6A)
    val primaryContainer = Color(0xFF22241B)
    val secondaryContainer = Color(0xFF2A2018)
    val tertiaryContainer = Color(0xFF1A2E1A)

    // 2.3 Text
    val onSurface = Color(0xFFF1F0E4)
    val onSurfaceVariant = Color(0xFFA8A899)
    val onPrimary = Color(0xFF161611)

    // 2.4 Metric accents — see class doc for the `heart` canvas/prompt note
    val heart = Color(0xFFD97F7F)
    val calories = Color(0xFFE0915A)
    val positive = Color(0xFF9DAE6B)
    val negative = Color(0xFFE08A52)

    // 2.5 Error
    val error = Color(0xFFCF6679)
    val onError = Color(0xFF1C0008)
    val errorContainer = Color(0xFF8C1D2F)
    val onErrorContainer = Color(0xFFFFB3BF)

    /** Dimmed content color for a ghosted/inert control — the log-set
     * control's pending and phone-unreachable states (canvas W 08/W 10,
     * docs/watch/43-watch-f5-set-logging-plan.md §3.2/§4.4). Mirrors iOS's
     * `LifeyColors.ghostedOnSurface`, added there first (S8) with a note to
     * add the identical hex here once Wear's own log-lap (S13) needed it. */
    val ghostedOnSurface = Color(0xFF46463E)

    /** The `phonelink_off` header glyph's quiet tint (docs/watch/
     * 44-watch-f6-standalone-plan.md §3.4, canvas W 13's "mode, not alarm" —
     * no chip/background of its own). Mirrors iOS's `LifeyColors
     * .standaloneIndicator`, added there first (S11). */
    val standaloneIndicator = Color(0xFF777264)

    // 2.6 Cardio activity-type accents (docs/cardio/55-cardio-watch-plan.md §2,
    // picker rows + active screens — C5.6) — the same hex the mobile app's
    // `MetricColors` uses for the matching activity, mirrors iOS's identical
    // "Cardio activity-type accents" LifeyColors section. `RUNNING` reuses
    // `calories` (`0xE0915A` on both), `HIKING` reuses `tertiary`
    // (`0x6E9A6A`), and `CYCLING` (docs/cardio/62-cardio-cycling-plan.md A5)
    // reuses `secondary` (`0xC49A6C`) — the mobile app's `colorScheme
    // .secondary`, for the same "every AppMetricColors slot already claimed"
    // reason documented there — rather than duplicating any of these three
    // hexes under a second name. Only the four colors this object didn't
    // already have get their own constant.
    /** `WALKING` — mirrors mobile's `MetricColors.steps`. */
    val cardioWalking = Color(0xFFB08AC8)
    /** `INDOOR_BIKE` — mirrors mobile's `MetricColors.carbs`. */
    val cardioIndoorBike = Color(0xFFD8B35A)
    /** `BASKETBALL` — mirrors mobile's `MetricColors.fat`. */
    val cardioBasketball = Color(0xFF8E8EC4)
    /** `FOOTBALL` — mirrors mobile's `MetricColors.water`. */
    val cardioFootball = Color(0xFF6FA8C4)
}
