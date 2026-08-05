package com.khunor.lifey

import android.util.Log
import androidx.core.content.ContextCompat
import com.google.android.gms.wearable.DataEvent
import com.google.android.gms.wearable.DataEventBuffer
import com.google.android.gms.wearable.DataItem
import com.google.android.gms.wearable.DataMapItem
import com.google.android.gms.wearable.MessageEvent
import com.google.android.gms.wearable.Node
import com.google.android.gms.wearable.WearableListenerService
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import org.json.JSONArray
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
                //
                // A start naming the standalone session's *own* id isn't
                // that conflict: it's the phone re-announcing the session it
                // adopted from this watch (live bridging — its mirror screen
                // starts its notifier on open). Ignore it silently rather
                // than rejecting, or the phone shows the user a "the watch
                // didn't mirror your workout" warning about the very workout
                // the watch is running. Mirrors the same `sessionClientId !=
                // self.sessionClientId` condition watchOS's
                // `WorkoutManager.applyStateUpdate` already used.
                val sessionClientId = applyStateMessage(messageEvent.data) ?: return
                val metadata = SessionStateHolder.metadata.value
                if (metadata.isStandalone) {
                    if (sessionClientId != metadata.sessionClientId) {
                        scope.launch {
                            SummarySender.sendStartRejected(this@PhoneListenerService, sessionClientId)
                        }
                    }
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
                // A stray end for a not-yet-adopted standalone session can't
                // close it (D-F6.2) — the watch's own End button drives
                // ExerciseService.endStandaloneExercise instead (S17),
                // through a different intent action. Once adopted (live
                // bridging), the phone genuinely does know about the session
                // and ending from either side should work — routed to the
                // same endStandaloneIntent the watch's own End button uses,
                // not the phone-mastered endIntent.
                val metadata = SessionStateHolder.metadata.value
                if (metadata.isStandalone) {
                    if (metadata.isAdopted) {
                        ContextCompat.startForegroundService(
                            this,
                            ExerciseService.endStandaloneIntent(this, rpe = null),
                        )
                    }
                    return
                }
                ContextCompat.startForegroundService(this, ExerciseService.endIntent(this))
            }
            "$MESSAGE_PATH_PREFIX/logSetAck" -> {
                applyLogSetAck(messageEvent.data)
            }
            "$MESSAGE_PATH_PREFIX/standaloneSessionAck" -> {
                applyStandaloneSessionAck(messageEvent.data)
            }
            "$MESSAGE_PATH_PREFIX/adoptionAck" -> {
                applyAdoptionAck(messageEvent.data)
            }
            "$MESSAGE_PATH_PREFIX/templateSync" -> {
                applyTemplateSyncMessage(messageEvent.data)
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
        // Live bridging: reachability regained is exactly when a not-yet-
        // adopted standalone session should (re-)send its adoption snapshot
        // — sendAdoptionRequestIfNeeded is a no-op once already adopted or
        // if this isn't a standalone session.
        scope.launch { SummarySender.sendAdoptionRequestIfNeeded(applicationContext) }
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
     * Decodes `WatchBridge.kt`'s `ackAdoption` JSON (live bridging) and
     * applies it — the phone confirmed it created (or already had) the live
     * mirror row for this standalone session.
     */
    private fun applyAdoptionAck(data: ByteArray) {
        try {
            val json = JSONObject(String(data))
            val standaloneSessionId = json.optString("standaloneSessionId").ifEmpty { null } ?: return
            SessionStateHolder.onAdoptionAcked(standaloneSessionId)
        } catch (e: Exception) {
            Log.w(TAG, "applyAdoptionAck failed to parse payload", e)
        }
    }

    /**
     * Decodes `WatchBridge.kt`'s `templateSyncMessagePayload()`
     * (docs/watch/49-watch-f6b-template-sync-plan.md §4.1, T3.3) and
     * overwrites the picker's cache. No guard-ordering hazard here unlike
     * iOS's `applyContext` (T4.1's fix, D-F6b.2) — this is its own message
     * path, entirely independent of the state-sync branches above (D-F6b.3).
     */
    private fun applyTemplateSyncMessage(data: ByteArray) {
        try {
            val json = JSONObject(String(data))
            val templates = json.optJSONArray("templates") ?: JSONArray()
            StandaloneSessionStore.saveTemplates(this, templates.toString())
        } catch (e: Exception) {
            Log.w(TAG, "applyTemplateSyncMessage failed to parse payload", e)
        }
    }

    /**
     * The reconnect-fallback counterpart of [applyTemplateSyncMessage] —
     * decodes `WatchBridge.kt`'s [pushTemplates] `DataItem` ([TEMPLATES_PATH],
     * D-F6b.3). `templatesJson` already arrives as a JSON array string (the
     * `DataMap` has no native array-of-maps type — see `WatchBridge.kt`'s own
     * doc comment on this), so it's stored as-is, same as the message path.
     */
    private fun applyTemplateSyncDataItem(dataItem: DataItem) {
        val map = DataMapItem.fromDataItem(dataItem).dataMap
        val templatesJson = map.getString("templatesJson") ?: return
        StandaloneSessionStore.saveTemplates(this, templatesJson)
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
                // Which exercise setsDone/setsTotal are about, for a
                // watch-started session the phone has adopted — see
                // SessionMetadata.phoneSetsDone.
                setsDoneExerciseIndex = state?.takeIf { it.has("setsDoneExerciseIndex") }
                    ?.optInt("setsDoneExerciseIndex"),
                setsDonePerExercise = state?.optJSONArray("setsDonePerExercise")
                    ?.let { array -> List(array.length()) { array.optInt(it) } },
                // Which plan positions the session no longer has — absent
                // (older phone build, or nothing removed) means "nothing
                // removed", i.e. the pre-existing behaviour.
                removedExerciseIndexes = state?.optJSONArray("removedExerciseIndexes")
                    ?.let { array -> List(array.length()) { array.optInt(it) } },
                // …and the same answer by clientId, which is what F6c compares
                // against: a position stops meaning the same thing on both
                // sides the moment the session's exercise list changes.
                setsDoneExerciseId = state?.optString("setsDoneExerciseId")?.ifEmpty { null },
                // The session's own exercise list, JSON-encoded (F6c) — a
                // string, so it crosses every transport unchanged.
                sessionPlan = StandalonePlanJson.parseSessionPlan(
                    state?.optString("sessionPlan")?.ifEmpty { null },
                ),
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

            // TEMPLATES_PATH is its own independent DataItem (D-F6b.3, T3.3)
            // — handled and skipped here before the STATE_PATH-only guard
            // below, which the rest of this loop body still assumes.
            if (event.dataItem.uri.path == TEMPLATES_PATH) {
                applyTemplateSyncDataItem(event.dataItem)
                continue
            }
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
                setsDoneExerciseIndex = state?.takeIf { it.containsKey("setsDoneExerciseIndex") }
                    ?.getInt("setsDoneExerciseIndex"),
                setsDonePerExercise = state?.getIntegerArrayList("setsDonePerExercise")?.toList(),
                removedExerciseIndexes =
                    state?.getIntegerArrayList("removedExerciseIndexes")?.toList(),
                setsDoneExerciseId = state?.getString("setsDoneExerciseId"),
                sessionPlan = StandalonePlanJson.parseSessionPlan(state?.getString("sessionPlan")),
            )

            // The phone's `end` message may never have reached us while
            // unreachable — this DataItem resync, once we reconnect, is the
            // delivery guarantee's fallback (docs/40-watch-app-plan.md §3
            // "Kézbesítési garancia"). Same standalone/adopted guard as the
            // "end" message case above (D-F6.2, widened for live bridging)
            // — this fallback is keyed only on phase, not sessionClientId,
            // so without it a stray phone-mastered desiredPhase:"ended"
            // could otherwise close a running, not-yet-adopted standalone
            // session.
            if (map.getString("desiredPhase") == "ended" && SessionStateHolder.phase.value == SessionPhase.ACTIVE) {
                val metadata = SessionStateHolder.metadata.value
                if (metadata.isStandalone) {
                    if (metadata.isAdopted) {
                        ContextCompat.startForegroundService(
                            this,
                            ExerciseService.endStandaloneIntent(this, rpe = null),
                        )
                    }
                } else {
                    ContextCompat.startForegroundService(this, ExerciseService.endIntent(this))
                }
            }
        }
    }

    companion object {
        private const val TAG = "LifeyPhoneListener"
        const val MESSAGE_PATH_PREFIX = "/lifey/watch"
        const val STATE_PATH = "$MESSAGE_PATH_PREFIX/state"
        // Kept manually in sync with WatchBridge.kt's identically-named
        // constant in the :app module (docs/watch/49-watch-f6b-template-sync-plan.md
        // T4.3) — same pattern STATE_PATH above already follows across the
        // two modules.
        const val TEMPLATES_PATH = "$MESSAGE_PATH_PREFIX/templates"
    }
}
