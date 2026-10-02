package com.khunor.lifey

import androidx.compose.ui.graphics.toArgb
import androidx.concurrent.futures.ResolvableFuture
import androidx.wear.protolayout.ActionBuilders
import androidx.wear.protolayout.ColorBuilders.argb
import androidx.wear.protolayout.DimensionBuilders.dp
import androidx.wear.protolayout.DimensionBuilders.sp
import androidx.wear.protolayout.LayoutElementBuilders
import androidx.wear.protolayout.ModifiersBuilders
import androidx.wear.protolayout.ResourceBuilders
import androidx.wear.protolayout.TimelineBuilders
import androidx.wear.tiles.RequestBuilders
import androidx.wear.tiles.TileBuilders
import androidx.wear.tiles.TileService
import com.google.common.util.concurrent.ListenableFuture
import com.khunor.lifey.ui.theme.LifeyColors

/**
 * Launcher Tile (redesign X4.o1, frame W2.20): one tap from the tile carousel into the start picker. Shows
 * "Gyors erőedzés" and, under it, the first ranked template from the already-synced local cache
 * ([StandaloneSessionStore] — no phone contact, like the picker itself). Tapping opens [MainActivity] with
 * [EXTRA_OPEN_PICKER], which lands on the picker (the sensor permission re-check and the actual start stay
 * where they are: in the picker's own callbacks).
 */
class LauncherTileService : TileService() {

    override fun onTileRequest(requestParams: RequestBuilders.TileRequest): ListenableFuture<TileBuilders.Tile> {
        val firstTemplate = StandaloneSessionStore.entries(this)
            .firstOrNull { it.optString("type") != "CARDIO" }
            ?.optString("title")
            ?.takeIf { it.isNotBlank() }
        val tile = TileBuilders.Tile.Builder()
            .setResourcesVersion(RESOURCES_VERSION)
            .setTileTimeline(TimelineBuilders.Timeline.fromLayoutElement(layout(firstTemplate)))
            .build()
        return ResolvableFuture.create<TileBuilders.Tile>().apply { set(tile) }
    }

    override fun onTileResourcesRequest(requestParams: RequestBuilders.ResourcesRequest): ListenableFuture<ResourceBuilders.Resources> =
        ResolvableFuture.create<ResourceBuilders.Resources>().apply {
            set(ResourceBuilders.Resources.Builder().setVersion(RESOURCES_VERSION).build())
        }

    private fun layout(firstTemplate: String?): LayoutElementBuilders.LayoutElement {
        val openPicker = ModifiersBuilders.Clickable.Builder()
            .setId("open_picker")
            .setOnClick(
                ActionBuilders.LaunchAction.Builder()
                    .setAndroidActivity(
                        ActionBuilders.AndroidActivity.Builder()
                            .setPackageName(packageName)
                            .setClassName(MainActivity::class.java.name)
                            .addKeyToExtraMapping(EXTRA_OPEN_PICKER, ActionBuilders.booleanExtra(true))
                            .build(),
                    )
                    .build(),
            )
            .build()
        val column = LayoutElementBuilders.Column.Builder()
            .setHorizontalAlignment(LayoutElementBuilders.HORIZONTAL_ALIGN_CENTER)
            .addContent(text(getString(R.string.standalone_quick_start), 18f, LifeyColors.onPrimary.toArgb(), bold = true))
        if (firstTemplate != null) {
            column.addContent(text(firstTemplate, 13f, LifeyColors.onPrimary.toArgb(), bold = false))
        }
        return LayoutElementBuilders.Box.Builder()
            .setModifiers(
                ModifiersBuilders.Modifiers.Builder()
                    .setClickable(openPicker)
                    .setBackground(
                        ModifiersBuilders.Background.Builder()
                            .setColor(argb(LifeyColors.primary.toArgb()))
                            .setCorner(ModifiersBuilders.Corner.Builder().setRadius(dp(26f)).build())
                            .build(),
                    )
                    .setPadding(ModifiersBuilders.Padding.Builder().setAll(dp(14f)).build())
                    .build(),
            )
            .addContent(column.build())
            .build()
    }

    private fun text(value: String, size: Float, color: Int, bold: Boolean): LayoutElementBuilders.LayoutElement =
        LayoutElementBuilders.Text.Builder()
            .setText(value)
            .setMaxLines(2)
            .setFontStyle(
                LayoutElementBuilders.FontStyle.Builder()
                    .setSize(sp(size))
                    .setColor(argb(color))
                    .setWeight(if (bold) LayoutElementBuilders.FONT_WEIGHT_BOLD else LayoutElementBuilders.FONT_WEIGHT_MEDIUM)
                    .build(),
            )
            .build()

    private companion object {
        const val RESOURCES_VERSION = "1"
    }
}

/** Intent extra that sends [MainActivity] straight to the start picker (the Tile's tap). */
const val EXTRA_OPEN_PICKER = "open_picker"
