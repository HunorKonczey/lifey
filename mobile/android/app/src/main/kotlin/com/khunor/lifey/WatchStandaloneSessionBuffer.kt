package com.khunor.lifey

import android.content.Context
import org.json.JSONArray

/**
 * Buffers watch → phone standalone-session payloads in `SharedPreferences`
 * so they survive the Flutter engine not running when the message arrives
 * (docs/watch/44-watch-f6-standalone-plan.md §6/1) — mirrors
 * [WatchSummaryBuffer] under its own key (a separate class rather than a
 * shared/parameterized one, per the doc's own alternative), since a
 * standalone delivery landing while the phone is pocketed/backgrounded is
 * the *common* case here, not an edge case the way it is for the live-app
 * summary path. [PhoneWatchSummaryListenerService] writes here (manifest-
 * declared, matches its own `<data>` path); [WatchBridge] drains it
 * alongside [WatchSummaryBuffer] on `EventChannel.onListen`.
 */
object WatchStandaloneSessionBuffer {
    private const val PREFS_NAME = "lifey_watch_bridge"
    private const val KEY_PENDING = "pending_standalone_sessions"

    fun add(context: Context, standaloneSessionJson: String) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val array = JSONArray(prefs.getString(KEY_PENDING, "[]"))
        array.put(standaloneSessionJson)
        prefs.edit().putString(KEY_PENDING, array.toString()).apply()
    }

    /** Returns the buffered standalone-session payloads (raw JSON strings) and clears the buffer. */
    fun drain(context: Context): List<String> {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val raw = prefs.getString(KEY_PENDING, null) ?: return emptyList()
        prefs.edit().remove(KEY_PENDING).apply()
        val array = JSONArray(raw)
        return (0 until array.length()).map { array.getString(it) }
    }
}
