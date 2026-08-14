package com.khunor.lifey

import android.content.Context
import android.content.Intent
import android.content.pm.ShortcutInfo
import android.content.pm.ShortcutManager
import android.graphics.drawable.Icon
import android.net.Uri
import android.os.Build
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

private const val CHANNEL = "lifey/shortcuts"

/**
 * Android half of the dynamic app-shortcuts bridge
 * (docs/cardio/59-cardio-implementation-plan.md C2.11a, D-C2.2 in
 * docs/cardio/53-cardio-mobile-plan.md) — mirrors WatchBridge/
 * MediaSessionBridge's plain-MethodChannel-class pattern rather than
 * pulling in a Flutter plugin for what `ShortcutManager` already does in a
 * few lines.
 *
 * `ShortcutManager` (and dynamic shortcuts) needs API 25 (N_MR1); below
 * that [update] is a silent no-op — there is nothing to fall back to, since
 * the OS itself has no such concept pre-N_MR1.
 */
class ShortcutsBridge(context: Context, messenger: BinaryMessenger) {
    private val appContext = context.applicationContext
    private val channel = MethodChannel(messenger, CHANNEL)

    init {
        channel.setMethodCallHandler { call, result ->
            if (call.method == "update") {
                @Suppress("UNCHECKED_CAST")
                val shortcuts = call.argument<List<Map<String, Any>>>("shortcuts").orEmpty()
                update(shortcuts)
                result.success(null)
            } else {
                result.notImplemented()
            }
        }
    }

    private fun update(shortcuts: List<Map<String, Any>>) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N_MR1) return
        val manager = appContext.getSystemService(ShortcutManager::class.java) ?: return

        val infos = shortcuts
            .take(manager.maxShortcutCountPerActivity)
            .mapNotNull { spec -> toShortcutInfo(spec) }
        // A launcher (per Android's own contract) simply drops shortcuts it
        // can't build from, but never throws for a merely *empty* list here —
        // setDynamicShortcuts(emptyList()) is exactly how a cold-start user
        // with no ranking yet clears any stale shortcuts from a previous
        // install, so this must not be skipped when infos is empty.
        manager.dynamicShortcuts = infos
    }

    private fun toShortcutInfo(spec: Map<String, Any>): ShortcutInfo? {
        val id = spec["id"] as? String ?: return null
        val label = spec["shortLabel"] as? String ?: return null
        val uriString = spec["deepLinkUri"] as? String ?: return null
        val intent = Intent(
            Intent.ACTION_VIEW,
            Uri.parse(uriString),
            appContext,
            MainActivity::class.java,
        )
        return ShortcutInfo.Builder(appContext, id)
            .setShortLabel(label)
            .setIcon(Icon.createWithResource(appContext, R.mipmap.ic_launcher))
            .setIntent(intent)
            .build()
    }
}
