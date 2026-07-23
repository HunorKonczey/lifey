package com.khunor.lifey

import android.util.Log
import androidx.core.content.ContextCompat
import com.google.android.gms.wearable.DataEvent
import com.google.android.gms.wearable.DataEventBuffer
import com.google.android.gms.wearable.DataMapItem
import com.google.android.gms.wearable.MessageEvent
import com.google.android.gms.wearable.WearableListenerService
import org.json.JSONObject

/**
 * Wakes even if the wear app isn't running, when the phone's `WatchBridge`
 * sends a command message (start/state/end) or pushes the "last known state"
 * DataItem (docs/40-watch-app-plan.md §5.1, §5.4, §D2). Commands trigger
 * [ExerciseService]. The start/state messages are the *primary* state-sync
 * path — see [applyStateMessage]'s doc comment; the DataItem in
 * [onDataChanged] is now only a best-effort backup for a reconnect.
 */
class PhoneListenerService : WearableListenerService() {
    override fun onMessageReceived(messageEvent: MessageEvent) {
        Log.d(TAG, "onMessageReceived: ${messageEvent.path}")
        if (!messageEvent.path.startsWith(MESSAGE_PATH_PREFIX)) return
        when (messageEvent.path) {
            "$MESSAGE_PATH_PREFIX/start" -> {
                val sessionClientId = applyStateMessage(messageEvent.data) ?: return
                ContextCompat.startForegroundService(this, ExerciseService.startIntent(this, sessionClientId))
            }
            "$MESSAGE_PATH_PREFIX/state" -> {
                applyStateMessage(messageEvent.data)
            }
            "$MESSAGE_PATH_PREFIX/end" -> {
                ContextCompat.startForegroundService(this, ExerciseService.endIntent(this))
            }
        }
    }

    /**
     * Decodes the JSON `WatchBridge.kt`'s `stateMessagePayload()` builds and
     * applies it to [SessionStateHolder] — the primary state-sync path, not
     * [onDataChanged]'s DataItem: that sync between two paired devices' Play
     * services instances has been observed to be unreliable in practice
     * (never arriving despite a successful local `putDataItem`, tracked back
     * to internal `Mismatched certificate` warnings in `com.google.android.gms`
     * — the Wearable Data Layer message path doesn't have this problem).
     * Returns the session's clientId on success, null if the payload
     * couldn't be parsed (or had no clientId).
     */
    private fun applyStateMessage(data: ByteArray): String? {
        return try {
            val json = JSONObject(String(data))
            val sessionClientId = json.optString("sessionClientId").ifEmpty { null } ?: return null
            val state = json.optJSONObject("state")
            SessionStateHolder.onStateSynced(
                sessionClientId = sessionClientId,
                title = json.optString("title").ifEmpty { null },
                exerciseName = state?.optString("exerciseName")?.ifEmpty { null },
                setsDone = state?.takeIf { it.has("setsDone") }?.optInt("setsDone"),
                setsTotal = state?.takeIf { it.has("setsTotal") }?.optInt("setsTotal"),
                restRemainingSeconds = state?.takeIf { it.has("restRemainingSeconds") }
                    ?.optInt("restRemainingSeconds"),
                restTotalSeconds = state?.takeIf { it.has("restTotalSeconds") }?.optInt("restTotalSeconds"),
            )
            sessionClientId
        } catch (e: Exception) {
            Log.w(TAG, "applyStateMessage failed to parse payload", e)
            null
        }
    }

    override fun onDataChanged(dataEvents: DataEventBuffer) {
        Log.d(TAG, "onDataChanged: ${dataEvents.count} event(s)")
        for (event in dataEvents) {
            Log.d(TAG, "  event type=${event.type} path=${event.dataItem.uri.path}")
            if (event.type != DataEvent.TYPE_CHANGED) continue
            if (event.dataItem.uri.path != STATE_PATH) continue

            val map = DataMapItem.fromDataItem(event.dataItem).dataMap
            val sessionClientId = map.getString("sessionClientId") ?: continue
            val state = map.getDataMap("state")
            SessionStateHolder.onStateSynced(
                sessionClientId = sessionClientId,
                title = map.getString("title"),
                exerciseName = state?.getString("exerciseName"),
                setsDone = state?.takeIf { it.containsKey("setsDone") }?.getInt("setsDone"),
                setsTotal = state?.takeIf { it.containsKey("setsTotal") }?.getInt("setsTotal"),
                restRemainingSeconds = state?.takeIf { it.containsKey("restRemainingSeconds") }
                    ?.getInt("restRemainingSeconds"),
                restTotalSeconds = state?.takeIf { it.containsKey("restTotalSeconds") }?.getInt("restTotalSeconds"),
            )

            // The phone's `end` message may never have reached us while
            // unreachable — this DataItem resync, once we reconnect, is the
            // delivery guarantee's fallback (docs/40-watch-app-plan.md §3
            // "Kézbesítési garancia").
            if (map.getString("desiredPhase") == "ended" && SessionStateHolder.phase.value == SessionPhase.ACTIVE) {
                ContextCompat.startForegroundService(this, ExerciseService.endIntent(this))
            }
        }
    }

    companion object {
        private const val TAG = "LifeyPhoneListener"
        const val MESSAGE_PATH_PREFIX = "/lifey/watch"
        const val STATE_PATH = "$MESSAGE_PATH_PREFIX/state"
    }
}
