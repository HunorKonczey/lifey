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
