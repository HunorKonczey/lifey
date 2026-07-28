package com.khunor.lifey

import android.util.Log
import androidx.core.content.ContextCompat
import com.google.android.gms.wearable.DataEvent
import com.google.android.gms.wearable.DataEventBuffer
import com.google.android.gms.wearable.DataMapItem
import com.google.android.gms.wearable.MessageEvent
import com.google.android.gms.wearable.Node
import com.google.android.gms.wearable.WearableListenerService
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
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
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)

    override fun onMessageReceived(messageEvent: MessageEvent) {
        Log.d(TAG, "onMessageReceived: ${messageEvent.path}")
        if (!messageEvent.path.startsWith(MESSAGE_PATH_PREFIX)) return
        when (messageEvent.path) {
            "$MESSAGE_PATH_PREFIX/start" -> {
                // applyStateMessage's onStateSynced call already no-ops
                // during standalone (D-F6.2) — this just decides whether to
                // *also* start a second, phone-mastered exercise on top of
                // a running standalone one, and rejects if so (the reverse
                // of the existing "another app owns the sensors" conflict).
                val sessionClientId = applyStateMessage(messageEvent.data) ?: return
                if (SessionStateHolder.metadata.value.isStandalone) {
                    scope.launch { SummarySender.sendStartRejected(this@PhoneListenerService, sessionClientId) }
                    return
                }
                ContextCompat.startForegroundService(this, ExerciseService.startIntent(this, sessionClientId))
            }
            "$MESSAGE_PATH_PREFIX/state" -> {
                // No explicit standalone guard needed here — onStateSynced
                // itself already no-ops for a state sync during standalone
                // (D-F6.2), and unlike "start" a stray state sync doesn't
                // warrant a startRejected reply.
                applyStateMessage(messageEvent.data)
            }
            "$MESSAGE_PATH_PREFIX/end" -> {
                // A stray end for a phone-mastered session can't close a
                // running standalone one (D-F6.2) — the watch's own End
                // button drives ExerciseService.endStandaloneExercise
                // instead (S17), through a different intent action.
                if (SessionStateHolder.metadata.value.isStandalone) return
                ContextCompat.startForegroundService(this, ExerciseService.endIntent(this))
            }
            "$MESSAGE_PATH_PREFIX/logSetAck" -> {
                applyLogSetAck(messageEvent.data)
            }
            "$MESSAGE_PATH_PREFIX/standaloneSessionAck" -> {
                applyStandaloneSessionAck(messageEvent.data)
            }
        }
    }

    /**
     * The phone just reconnected — the closest Wear OS equivalent to iOS's
     * `sessionReachabilityDidChange` (docs/watch/44-watch-f6-standalone-plan.md
     * §4.1's retry trigger). Dispatched automatically by
     * `WearableListenerService` to any manifest-registered listener, no new
     * `CAPABILITY_CHANGED` filter/capability declaration needed — this app
     * has no phone-side capability to watch for reachability the way it
     * advertises `lifey_watch_workout` in the other direction.
     */
    override fun onPeerConnected(peer: Node) {
        scope.launch { SummarySender.flushPending(applicationContext) }
    }

    override fun onDestroy() {
        scope.cancel()
        super.onDestroy()
    }

    /**
     * Decodes `WatchBridge.kt`'s `ackSetLogged` JSON
     * (docs/watch/43-watch-f5-set-logging-plan.md §4.3) and applies it to
     * [SessionStateHolder]. `sessionClientId` isn't checked against the
     * watch's own current session here — [SessionStateHolder.onLogSetAck]
     * (S12) only acts when `eventId` matches its own pending tap, which
     * already rules out a stray ack for a stale/different session.
     */
    private fun applyLogSetAck(data: ByteArray) {
        try {
            val json = JSONObject(String(data))
            val eventId = json.optString("eventId").ifEmpty { null } ?: return
            val accepted = json.optBoolean("accepted")
            SessionStateHolder.onLogSetAck(eventId, accepted)
        } catch (e: Exception) {
            Log.w(TAG, "applyLogSetAck failed to parse payload", e)
        }
    }

    /**
     * Decodes `WatchBridge.kt`'s `ackStandaloneSession` JSON (docs/watch/
     * 44-watch-f6-standalone-plan.md §4.2) and applies it: removes the
     * payload from [StandaloneSessionStore] so it isn't retried, then
     * broadcasts the id via [SessionStateHolder.onStandaloneSessionAcked]
     * for whichever summary screen (S17) is currently showing it.
     */
    private fun applyStandaloneSessionAck(data: ByteArray) {
        try {
            val json = JSONObject(String(data))
            val standaloneSessionId = json.optString("standaloneSessionId").ifEmpty { null } ?: return
            StandaloneSessionStore.remove(this, standaloneSessionId)
            SessionStateHolder.onStandaloneSessionAcked(standaloneSessionId)
        } catch (e: Exception) {
            Log.w(TAG, "applyStandaloneSessionAck failed to parse payload", e)
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
                // The F5b adjust prefill (docs/watch/48-watch-f5b-set-adjust-plan.md
                // §4.2). The phone strips nulls before sending, so "key absent"
                // is how "no prefill" arrives — and the `has()` guard is what
                // keeps optInt/optDouble's 0-for-missing from looking like a
                // real 0 reps / 0 kg prefill.
                nextSetReps = state?.takeIf { it.has("nextSetReps") }?.optInt("nextSetReps"),
                nextSetWeight = state?.takeIf { it.has("nextSetWeight") }?.optDouble("nextSetWeight"),
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
                // Same F5b prefill as the message path above — this DataItem
                // route is the reconnect fallback, so it has to carry it too,
                // or a watch that only ever resyncs this way would show a
                // stale/absent stepper start value.
                nextSetReps = state?.takeIf { it.containsKey("nextSetReps") }?.getInt("nextSetReps"),
                nextSetWeight = state?.takeIf { it.containsKey("nextSetWeight") }
                    ?.getDouble("nextSetWeight"),
            )

            // The phone's `end` message may never have reached us while
            // unreachable — this DataItem resync, once we reconnect, is the
            // delivery guarantee's fallback (docs/40-watch-app-plan.md §3
            // "Kézbesítési garancia"). Same standalone guard as the "end"
            // message case above (D-F6.2) — this fallback is keyed only on
            // phase, not sessionClientId, so without it a stray
            // phone-mastered desiredPhase:"ended" could otherwise close a
            // running standalone session.
            if (map.getString("desiredPhase") == "ended" && SessionStateHolder.phase.value == SessionPhase.ACTIVE &&
                !SessionStateHolder.metadata.value.isStandalone
            ) {
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
