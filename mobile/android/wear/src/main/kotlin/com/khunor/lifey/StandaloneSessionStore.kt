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
    private const val KEY_TEMPLATES = "templates"
    private const val KEY_ALL_CARDIO = "allCardio"
    private const val KEY_UNIT_SYSTEM = "unitSystem"

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

    // Quick-start cache (docs/watch/49-watch-f6b-template-sync-plan.md §3.1, T4.3;
    // docs/cardio/55-cardio-watch-plan.md §3.2, C5.3/C5.6 — templates + cardio
    // types, unified)

    /** Overwrites the whole cache with the phone's latest sync — never
     * merged, since every `templateSync` already carries the complete,
     * current list (T1.3's "empty list still goes out" decision means an
     * empty array here correctly clears a stale cache too, not just skips
     * the write). [entriesJson] is the raw `entries` JSON array as sent on
     * the wire (`{type: "TEMPLATE", ...}` / `{type: "CARDIO", ...}` rows,
     * docs/cardio/55-cardio-watch-plan.md §3.2) — stored as-is under the same
     * key `saveTemplates`/`templates` used pre-C5.3, not re-parsed into a
     * typed model, matching this store's existing convention (unlike iOS's
     * `WatchQuickStartEntry`, Android never introduced a typed model for
     * watch↔phone messages). A stale pre-C5.3 `templates`-shaped cache file
     * simply isn't read from this key any more — [entries] starts fresh from
     * whatever the next sync writes. */
    fun saveEntries(context: Context, entriesJson: String) {
        prefs(context).edit().putString(KEY_TEMPLATES, entriesJson).apply()
    }

    /** The picker's data source — empty if nothing was ever synced, or the
     * cached JSON failed to parse (a corrupt write, or a future app
     * version's incompatible shape). Never throws: the picker's F6a
     * fallback (just the "Quick strength" card) already handles "nothing to
     * show" correctly. Each row is read with `opt*` for its `"type"`
     * discriminator (`"TEMPLATE"`/`"CARDIO"`) at the call site
     * (`StandalonePickerScreen`), same as every other JSON row this app
     * hands around. */
    fun entries(context: Context): List<JSONObject> = readRows(context, KEY_TEMPLATES)

    /** Overwrites the "all activity types" cache — the complete, unranked
     * activity-type list behind the picker's second screen, pushed in the
     * same message as [saveEntries]'s ranked one but kept under its own key:
     * the two feed different screens and change for different reasons (usage
     * vs. the account's language), and a corrupt write to either then can't
     * take the other down with it. [allCardioJson] is the raw JSON array as
     * sent on the wire — same "stored as-is, read with `opt*` at the call
     * site" convention as [saveEntries]. */
    fun saveAllCardio(context: Context, allCardioJson: String) {
        prefs(context).edit().putString(KEY_ALL_CARDIO, allCardioJson).apply()
    }

    /** Every activity type the phone last offered, in display order — empty
     * until a phone build that sends the list has synced once, which is
     * exactly when the picker hides the row that opens the screen rather
     * than opening an empty one. */
    fun allCardio(context: Context): List<JSONObject> = readRows(context, KEY_ALL_CARDIO)

    /** Which units the phone's owner reads distances in (`UserSettings
     * .unitSystem` there), pushed with the quick-start sync so this watch can
     * format its **own** measurements the way the phone would — a
     * watch-started cardio session has no phone pushing pre-formatted
     * strings into it. `"METRIC"`/`"IMPERIAL"`; anything else is ignored
     * rather than collapsed to metric, so a newer phone build's new unit
     * system can't silently reformat a watch that already knows a good one. */
    fun saveUnitSystem(context: Context, raw: String) {
        if (raw != "METRIC" && raw != "IMPERIAL") return
        prefs(context).edit().putString(KEY_UNIT_SYSTEM, raw).apply()
    }

    /** Metric unless the phone has said otherwise — the same default a fresh
     * account gets, and the safe answer for a watch that has never synced. */
    fun isImperial(context: Context): Boolean =
        prefs(context).getString(KEY_UNIT_SYSTEM, null) == "IMPERIAL"

    private fun readRows(context: Context, key: String): List<JSONObject> {
        val raw = prefs(context).getString(key, null) ?: return emptyList()
        return try {
            val array = JSONArray(raw)
            (0 until array.length()).map { array.getJSONObject(it) }
        } catch (e: Exception) {
            emptyList()
        }
    }

    private fun prefs(context: Context) =
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
}
