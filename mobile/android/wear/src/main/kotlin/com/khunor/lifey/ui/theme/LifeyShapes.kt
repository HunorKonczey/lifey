package com.khunor.lifey.ui.theme

import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.ui.unit.dp

/**
 * Corner-radius scale (41-watch-design-prompt.md §1 "Shape & motion"):
 * 8 for chips/tags, 16 for buttons, 20 for cards, 24 for large cards, plus
 * a stadium/pill shape for progress chips and small buttons
 * (docs/40-watch-app-plan.md §12.1 B6).
 */
object LifeyShapes {
    val chip = RoundedCornerShape(8.dp)
    val button = RoundedCornerShape(16.dp)
    val card = RoundedCornerShape(20.dp)
    val cardLarge = RoundedCornerShape(24.dp)
    val pill = CircleShape
}
