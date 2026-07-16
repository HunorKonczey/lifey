package com.khunor.lifey

import android.content.Context
import org.json.JSONArray

/**
 * Buffers watch → phone workout summaries in `SharedPreferences` so they
 * survive the Flutter engine not running when the message arrives
 * (docs/40-watch-app-plan.md §5.4). [PhoneWatchSummaryListenerService]
 * writes here; [WatchBridge] drains it the moment Dart starts listening
 * again (its `EventChannel.onListen`).
 */
object WatchSummaryBuffer {
    private const val PREFS_NAME = "lifey_watch_bridge"
    private const val KEY_PENDING = "pending_summaries"

    fun add(context: Context, summaryJson: String) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val array = JSONArray(prefs.getString(KEY_PENDING, "[]"))
        array.put(summaryJson)
        prefs.edit().putString(KEY_PENDING, array.toString()).apply()
    }

    /** Returns the buffered summaries (raw JSON strings) and clears the buffer. */
    fun drain(context: Context): List<String> {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val raw = prefs.getString(KEY_PENDING, null) ?: return emptyList()
        prefs.edit().remove(KEY_PENDING).apply()
        val array = JSONArray(raw)
        return (0 until array.length()).map { array.getString(it) }
    }
}
