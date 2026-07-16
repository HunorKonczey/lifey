package com.khunor.lifey

import androidx.core.content.ContextCompat
import com.google.android.gms.wearable.DataEvent
import com.google.android.gms.wearable.DataEventBuffer
import com.google.android.gms.wearable.DataMapItem
import com.google.android.gms.wearable.MessageEvent
import com.google.android.gms.wearable.WearableListenerService

/**
 * Wakes even if the wear app isn't running, when the phone's `WatchBridge`
 * sends a command message (start/state/end) or pushes the "last known state"
 * DataItem (docs/40-watch-app-plan.md §5.1, §5.4, §D2). Commands trigger
 * [ExerciseService]; the DataItem sync is display-only except for the
 * "ended while unreachable" fallback below.
 */
class PhoneListenerService : WearableListenerService() {
    override fun onMessageReceived(messageEvent: MessageEvent) {
        if (!messageEvent.path.startsWith(MESSAGE_PATH_PREFIX)) return
        when (messageEvent.path) {
            "$MESSAGE_PATH_PREFIX/start" -> {
                val sessionClientId = String(messageEvent.data)
                ContextCompat.startForegroundService(this, ExerciseService.startIntent(this, sessionClientId))
            }
            "$MESSAGE_PATH_PREFIX/end" -> {
                ContextCompat.startForegroundService(this, ExerciseService.endIntent(this))
            }
            // "state" is display-only and already covered by the DataItem
            // sync below — the message is just the low-latency nudge.
        }
    }

    override fun onDataChanged(dataEvents: DataEventBuffer) {
        for (event in dataEvents) {
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
        const val MESSAGE_PATH_PREFIX = "/lifey/watch"
        const val STATE_PATH = "$MESSAGE_PATH_PREFIX/state"
    }
}
