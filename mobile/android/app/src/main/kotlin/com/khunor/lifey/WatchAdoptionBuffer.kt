package com.khunor.lifey

import android.content.Context
import org.json.JSONArray

/**
 * Buffers watch → phone standalone-session-adoption payloads in
 * `SharedPreferences` so they survive the Flutter engine not running when
 * the message arrives — mirrors [WatchStandaloneSessionBuffer] under its own
 * key (a still-running watch session being adopted while the phone is
 * pocketed/killed is exactly the scenario live bridging exists for, not an
 * edge case). [PhoneWatchSummaryListenerService] writes here (manifest-
 * declared, matches its own `<data>` path); [WatchBridge] drains it
 * alongside the other two buffers on `EventChannel.onListen`.
 */
object WatchAdoptionBuffer {
    private const val PREFS_NAME = "lifey_watch_bridge"
    private const val KEY_PENDING = "pending_standalone_adoptions"

    fun add(context: Context, adoptionJson: String) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val array = JSONArray(prefs.getString(KEY_PENDING, "[]"))
        array.put(adoptionJson)
        prefs.edit().putString(KEY_PENDING, array.toString()).apply()
    }

    /** Returns the buffered adoption payloads (raw JSON strings) and clears the buffer. */
    fun drain(context: Context): List<String> {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val raw = prefs.getString(KEY_PENDING, null) ?: return emptyList()
        prefs.edit().remove(KEY_PENDING).apply()
        val array = JSONArray(raw)
        return (0 until array.length()).map { array.getString(it) }
    }
}
