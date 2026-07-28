package com.khunor.lifey

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

/**
 * Local persistence for standalone (phone-less) watch sessions
 * (docs/watch/44-watch-f6-standalone-plan.md §3.2) — mirrors iOS's
 * `StandaloneSessionStore` (S7), two concerns:
 * - the **pending queue**: closed sessions not yet acked by the phone,
 *   retried until [remove] is called on ack (§4.2);
 * - the **active session meta**: the currently-running standalone
 *   session's own state, kept up to date on every set so a process
 *   death/reboot can recover into it.
 *
 * Payloads are raw JSON, not a typed data class — matches this codebase's
 * existing convention for every other Wear↔phone message
 * (`SummarySender`/`PhoneListenerService` never use a typed model either).
 * `SharedPreferences`-backed, like the phone-side `WatchSummaryBuffer` this
 * mirrors (S13).
 */
object StandaloneSessionStore {
    private const val PREFS_NAME = "lifey_standalone_sessions"
    private const val KEY_PENDING = "pending"
    private const val KEY_ACTIVE = "active"

    /** Queues a just-closed standalone session for delivery — `ExerciseService`
     * (S15) sends it and calls [remove] once the phone acks. */
    fun add(context: Context, standaloneSessionJson: String) {
        val prefs = prefs(context)
        val array = JSONArray(prefs.getString(KEY_PENDING, "[]"))
        array.put(JSONObject(standaloneSessionJson))
        prefs.edit().putString(KEY_PENDING, array.toString()).apply()
    }

    /** Every not-yet-acked session, oldest first — sent in this order (§4.1:
     * "a szinkron sorban küldi őket"). */
    fun all(context: Context): List<JSONObject> {
        val array = JSONArray(prefs(context).getString(KEY_PENDING, "[]"))
        return (0 until array.length()).map { array.getJSONObject(it) }
    }

    /** Removes the payload with this `standaloneSessionId` — called once the
     * phone's `standaloneSessionAck` arrives for it (§4.2). A no-op if
     * already removed. */
    fun remove(context: Context, standaloneSessionId: String) {
        val array = JSONArray(prefs(context).getString(KEY_PENDING, "[]"))
        val remaining = JSONArray()
        for (i in 0 until array.length()) {
            val item = array.getJSONObject(i)
            if (item.optString("standaloneSessionId") != standaloneSessionId) {
                remaining.put(item)
            }
        }
        prefs(context).edit().putString(KEY_PENDING, remaining.toString()).apply()
    }

    /** Overwrites the live standalone session's recovery snapshot — called on
     * start and after every locally logged set. */
    fun saveActive(context: Context, activeJson: String) {
        prefs(context).edit().putString(KEY_ACTIVE, activeJson).apply()
    }

    /** The live standalone session's last-saved snapshot, or null if none is
     * running (or it already ended and [clearActive] ran). */
    fun loadActive(context: Context): JSONObject? {
        val raw = prefs(context).getString(KEY_ACTIVE, null) ?: return null
        return try {
            JSONObject(raw)
        } catch (e: Exception) {
            null
        }
    }

    /** Called once the session ends (successfully or via reset) — a
     * leftover active-session entry would otherwise make the next launch
     * think a session is still running. */
    fun clearActive(context: Context) {
        prefs(context).edit().remove(KEY_ACTIVE).apply()
    }

    private fun prefs(context: Context) =
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
}
