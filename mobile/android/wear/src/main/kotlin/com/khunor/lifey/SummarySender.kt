package com.khunor.lifey

import android.content.Context
import android.util.Log
import com.google.android.gms.wearable.MessageClient
import com.google.android.gms.wearable.Wearable
import kotlinx.coroutines.tasks.await
import org.json.JSONObject

/**
 * Wear → phone messages for the summary round-trip and the "another app owns
 * the exercise" / "user pressed End on the watch" signals
 * (docs/40-watch-app-plan.md §3 "Lezárás", §5.3, §8.2). Mirrors the message
 * path convention the phone's WatchBridge.kt already uses for `startRejected`.
 */
object SummarySender {
    private const val TAG = "LifeySummarySender"
    private const val MESSAGE_PATH_PREFIX = "/lifey/watch"

    suspend fun sendSummary(
        context: Context,
        sessionClientId: String,
        activeCalories: Double?,
        averageHeartRate: Double?,
    ) {
        val payload = JSONObject().apply {
            put("sessionClientId", sessionClientId)
            putOpt("activeCalories", activeCalories)
            putOpt("averageHeartRate", averageHeartRate)
        }
        send(context, "$MESSAGE_PATH_PREFIX/summary", payload)
    }

    suspend fun sendStartRejected(context: Context, sessionClientId: String) {
        send(context, "$MESSAGE_PATH_PREFIX/startRejected", sessionClientId)
    }

    /**
     * [rpe] is whatever the watch's own effort-selector stepper produced
     * (docs/40-watch-app-plan.md §8.2 decision (b)) — null if the user
     * skipped it. JSON payload (like [sendSummary]), not just a raw id, so
     * it can carry rpe alongside the sessionClientId.
     */
    suspend fun sendEndRequested(context: Context, sessionClientId: String, rpe: Int?) {
        val payload = JSONObject().apply {
            put("sessionClientId", sessionClientId)
            putOpt("rpe", rpe)
        }
        send(context, "$MESSAGE_PATH_PREFIX/endRequested", payload)
    }

    /** The watch's own exercise session actually started measuring — drives
     * the phone's "Measuring" pill (docs/40-watch-app-plan.md §12.4 B14). */
    suspend fun sendStartedOnWatch(context: Context, sessionClientId: String) {
        send(context, "$MESSAGE_PATH_PREFIX/startedOnWatch", sessionClientId)
    }

    /**
     * The watch's "+1 set" tap (docs/watch/43-watch-f5-set-logging-plan.md
     * §4.1) — no exercise/reps/weight on the wire, the phone logs the next
     * row from its own current position (§2, §5.2). [eventId] is generated
     * by whoever calls this (`ActiveWorkoutScreen`'s log-lap, S13), used for
     * dedup (§4.2) and to correlate the eventual `logSetAck` back to this
     * specific tap.
     */
    /**
     * [reps]/[weight] are what the adjust stepper produced (docs/watch/
     * 48-watch-f5b-set-adjust-plan.md §4.1) — both null for a plain F5a
     * one-tap log, and `putOpt` then omits the keys entirely rather than
     * writing JSON nulls, so the phone's `has()` guard reads them as "no
     * values" (D-F5b.6).
     */
    suspend fun sendLogSet(
        context: Context,
        sessionClientId: String,
        eventId: String,
        loggedAtEpochMs: Long,
        reps: Int? = null,
        weight: Double? = null,
    ) {
        val payload = JSONObject().apply {
            put("sessionClientId", sessionClientId)
            put("eventId", eventId)
            put("loggedAtEpochMs", loggedAtEpochMs)
            putOpt("reps", reps)
            putOpt("weight", weight)
        }
        send(context, "$MESSAGE_PATH_PREFIX/logSet", payload)
    }

    /**
     * Live heart-rate/calorie readings, sent on every [ExerciseUpdateCallback]
     * tick — far more often than [sendSummary]'s one-shot totals. Best-effort
     * like the other sends here: a reading dropped while unreachable is
     * superseded moments later by the next one.
     */
    suspend fun sendLiveMetrics(
        context: Context,
        sessionClientId: String,
        heartRateBpm: Double?,
        activeCalories: Double?,
    ) {
        val payload = JSONObject().apply {
            put("sessionClientId", sessionClientId)
            putOpt("heartRateBpm", heartRateBpm)
            putOpt("activeCalories", activeCalories)
        }
        send(context, "$MESSAGE_PATH_PREFIX/liveMetrics", payload)
    }

    /**
     * Sends a just-closed standalone session (docs/watch/
     * 44-watch-f6-standalone-plan.md §4.1) — [payloadJson] already carries
     * `standaloneSessionId` etc. per §4.1's shape. Unlike the other sends
     * here, this one never removes anything from [StandaloneSessionStore]
     * itself — only the eventual `standaloneSessionAck` does that (§4.2), so
     * a delivery that doesn't land simply gets retried by [flushPending].
     */
    suspend fun sendStandaloneSession(context: Context, payloadJson: String) {
        send(context, "$MESSAGE_PATH_PREFIX/standaloneSessionCompleted", JSONObject(payloadJson))
    }

    /**
     * Re-sends every not-yet-acked standalone session from the local queue —
     * called on app start (`MainActivity.onCreate`) and on phone reconnect
     * (`PhoneListenerService.onPeerConnected`). [send]'s own best-effort
     * behavior already tolerates being called while unreachable, so this is
     * only about re-triggering delivery at moments it's newly likely to
     * land, not a correctness requirement on its own.
     */
    suspend fun flushPending(context: Context) {
        for (payload in StandaloneSessionStore.all(context)) {
            sendStandaloneSession(context, payload.toString())
        }
    }

    private suspend fun send(context: Context, path: String, payload: Any) {
        val messageClient = Wearable.getMessageClient(context)
        val nodeClient = Wearable.getNodeClient(context)
        val bytes = payload.toString().toByteArray()
        try {
            val nodes = nodeClient.connectedNodes.await()
            for (node in nodes) {
                sendToNode(messageClient, node.id, path, bytes)
            }
        } catch (e: Exception) {
            // Best-effort — no connected phone right now. The phone's own
            // DataItem/desiredPhase fallback (docs/40-watch-app-plan.md §D2)
            // is what a lost summary would otherwise need; a lost
            // startRejected/endRequested simply means the user retries.
            Log.w(TAG, "Failed to send $path", e)
        }
    }

    private suspend fun sendToNode(
        messageClient: MessageClient,
        nodeId: String,
        path: String,
        bytes: ByteArray,
    ) {
        try {
            messageClient.sendMessage(nodeId, path, bytes).await()
        } catch (e: Exception) {
            Log.w(TAG, "Failed to send $path to $nodeId", e)
        }
    }
}
