package com.khunor.lifey.ui.active

import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import com.khunor.lifey.SummarySender
import com.khunor.lifey.ui.components.HeaderChip
import com.khunor.lifey.ui.components.StandaloneMark
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/**
 * The header chip of every active page with the standalone mark wired to the existing adoption request:
 * a tap sends the whole snapshot to the phone (`SummarySender.sendAdoptionRequestIfNeeded`) and shows the
 * sync glyph for [ADOPTION_RETRY_FEEDBACK_MS] — the real success is the mark disappearing once the phone's
 * `adoptionAck` flips `isAdopted`. Behaviour is unchanged from the Material 2 header; only the look is v2
 * (24 dp mark inside a 48 dp target, W2.5).
 */
@Composable
internal fun ActiveHeader(
    icon: ImageVector,
    label: String,
    modifier: Modifier = Modifier,
    isPaused: Boolean = false,
    showsStandaloneMark: Boolean = false,
    accent: Color? = null,
) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var tapped by remember { mutableStateOf(false) }
    HeaderChip(
        icon = icon,
        label = label,
        modifier = modifier,
        accent = accent,
        isPaused = isPaused,
        standaloneMark = if (showsStandaloneMark) (if (tapped) StandaloneMark.Tapped else StandaloneMark.Idle) else null,
        onMarkTap = {
            if (!tapped) {
                scope.launch {
                    tapped = true
                    SummarySender.sendAdoptionRequestIfNeeded(context)
                    delay(ADOPTION_RETRY_FEEDBACK_MS)
                    tapped = false
                }
            }
        },
    )
}
