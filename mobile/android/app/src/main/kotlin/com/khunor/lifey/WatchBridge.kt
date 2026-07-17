package com.khunor.lifey

import android.content.Context
import android.util.Log
import com.google.android.gms.tasks.Tasks
import com.google.android.gms.wearable.CapabilityClient
import com.google.android.gms.wearable.DataClient
import com.google.android.gms.wearable.DataMap
import com.google.android.gms.wearable.MessageClient
import com.google.android.gms.wearable.MessageEvent
import com.google.android.gms.wearable.PutDataMapRequest
import com.google.android.gms.wearable.Wearable
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors
import org.json.JSONObject

/**
 * Handles the `lifey/watch` MethodChannel + `lifey/watch/events` EventChannel
 * that `WatchWorkoutService` (mobile/lib/core/watch/watch_workout_service.dart)
 * calls into — docs/40-watch-app-plan.md §3, §5.1, §6.1. Registered from
 * MainActivity.configureFlutterEngine.
 *
 * Every Wearable Data Layer call runs on a background executor: they block on
 * `Tasks.await`, which must not run on the main thread.
 */
class WatchBridge(context: Context, messenger: BinaryMessenger) :
    MethodChannel.MethodCallHandler,
    EventChannel.StreamHandler,
    MessageClient.OnMessageReceivedListener {

    private val appContext = context.applicationContext
    private val messageClient = Wearable.getMessageClient(appContext)
    private val dataClient = Wearable.getDataClient(appContext)
    private val capabilityClient = Wearable.getCapabilityClient(appContext)
    private val executor = Executors.newSingleThreadExecutor()
    private var eventSink: EventChannel.EventSink? = null

    init {
        MethodChannel(messenger, CHANNEL_NAME).setMethodCallHandler(this)
        EventChannel(messenger, EVENT_CHANNEL_NAME).setStreamHandler(this)
        messageClient.addListener(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isWatchAppAvailable" -> isWatchAppAvailable(result)
            "startWorkout" -> startWorkout(call, result)
            "updateState" -> updateState(call, result)
            "endWorkout" -> endWorkout(call, result)
            else -> result.notImplemented()
        }
    }

    private fun isWatchAppAvailable(result: MethodChannel.Result) {
        executor.execute {
            val available =
                try {
                    targetNodes().isNotEmpty()
                } catch (_: Exception) {
                    false
                }
            result.success(available)
        }
    }

    // MARK: - Commands (docs/40-watch-app-plan.md §5.1)

    private fun startWorkout(call: MethodCall, result: MethodChannel.Result) {
        val args = call.arguments as? Map<*, *> ?: return result.success(null)
        val sessionClientId = args["sessionClientId"] as? String ?: return result.success(null)
        val title = args["title"] as? String
        val startedAtEpochMs = (args["startedAtEpochMs"] as? Number)?.toLong()
        @Suppress("UNCHECKED_CAST") val state = args["state"] as? Map<String, Any?>

        pushState(sessionClientId, title, startedAtEpochMs, state, desiredPhase = "running")
        sendMessage(COMMAND_START, stateMessagePayload(sessionClientId, title, state))
        result.success(null)
    }

    private fun updateState(call: MethodCall, result: MethodChannel.Result) {
        val args = call.arguments as? Map<*, *> ?: return result.success(null)
        val sessionClientId = args["sessionClientId"] as? String ?: return result.success(null)
        @Suppress("UNCHECKED_CAST") val state = args["state"] as? Map<String, Any?>

        pushState(sessionClientId, title = null, startedAtEpochMs = null, state = state, desiredPhase = "running")
        sendMessage(COMMAND_STATE, stateMessagePayload(sessionClientId, title = null, state = state))
        result.success(null)
    }

    private fun endWorkout(call: MethodCall, result: MethodChannel.Result) {
        val args = call.arguments as? Map<*, *> ?: return result.success(null)
        val sessionClientId = args["sessionClientId"] as? String ?: return result.success(null)

        pushState(sessionClientId, title = null, startedAtEpochMs = null, state = null, desiredPhase = "ended")
        sendMessage(COMMAND_END, sessionClientId.toByteArray())
        result.success(null)
    }

    /**
     * The message payload for start/state (docs/40-watch-app-plan.md §3,
     * §D2 adjusted): carries the full state JSON directly, rather than only
     * `sessionClientId` with the watch expected to pick up the rest from the
     * [pushState] DataItem. `DataItem` sync between two paired devices' Play
     * services instances has been observed to be unreliable in practice (see
     * [targetNodes]'s doc comment) — this message is now the primary,
     * reliable path; `pushState`'s DataItem remains a best-effort backup for
     * the watch reconnecting later while genuinely unreachable.
     */
    private fun stateMessagePayload(sessionClientId: String, title: String?, state: Map<String, Any?>?): ByteArray {
        val json = JSONObject().apply {
            put("sessionClientId", sessionClientId)
            title?.let { put("title", it) }
            state?.let { s ->
                val stateJson = JSONObject()
                s.forEach { (key, value) -> if (value != null) stateJson.put(key, value) }
                put("state", stateJson)
            }
        }
        return json.toString().toByteArray()
    }

    /**
     * The Data Layer's "last known desired state" (docs/40-watch-app-plan.md
     * §D2) — the `updateApplicationContext` analogue: survives the watch
     * being unreachable and syncs once it reconnects, unlike [sendMessage].
     */
    private fun pushState(
        sessionClientId: String,
        title: String?,
        startedAtEpochMs: Long?,
        state: Map<String, Any?>?,
        desiredPhase: String,
    ) {
        executor.execute {
            val putDataMapRequest =
                PutDataMapRequest.create(STATE_PATH).apply {
                    dataMap.putString("sessionClientId", sessionClientId)
                    dataMap.putString("desiredPhase", desiredPhase)
                    title?.let { dataMap.putString("title", it) }
                    startedAtEpochMs?.let { dataMap.putLong("startedAtEpochMs", it) }
                    state?.let { dataMap.putDataMap("state", it.toDataMap()) }
                }
            val putDataRequest = putDataMapRequest.asPutDataRequest().setUrgent()
            try {
                Tasks.await(dataClient.putDataItem(putDataRequest))
                Log.d(TAG, "pushState OK (desiredPhase=$desiredPhase, sessionClientId=$sessionClientId)")
            } catch (e: Exception) {
                Log.w(TAG, "pushState FAILED (desiredPhase=$desiredPhase)", e)
            }
        }
    }

    private fun sendMessage(command: String, payload: ByteArray) {
        executor.execute {
            try {
                val nodeIds = targetNodes()
                Log.d(TAG, "sendMessage($command): ${nodeIds.size} target node(s)")
                nodeIds.forEach { nodeId ->
                    Tasks.await(messageClient.sendMessage(nodeId, "$MESSAGE_PATH_PREFIX/$command", payload))
                }
            } catch (e: Exception) {
                // Best-effort — no reachable watch right now; pushState's
                // DataItem is the fallback (docs/40-watch-app-plan.md §D2).
                Log.w(TAG, "sendMessage($command) FAILED", e)
            }
        }
    }

    /**
     * [CapabilityClient]'s `lifey_watch_workout` node lookup is the precise
     * way to find "a connected node actually running our watch app" — but
     * its sync between two paired devices' Play services instances has been
     * observed to be unreliable in practice: empty even with a genuinely
     * connected, correctly-installed watch (internal `Mismatched
     * certificate` warnings from `com.google.android.gms` in logcat). Since
     * this app only ever has one companion watch app to talk to (same
     * `applicationId` — docs/40-watch-app-plan.md §5.1), falling back to
     * every connected node is safe: a node without our wear app installed
     * just silently drops a message with no listener for our path.
     */
    private fun targetNodes(): List<String> {
        val capabilityNodeIds =
            Tasks.await(capabilityClient.getCapability(WATCH_CAPABILITY, CapabilityClient.FILTER_REACHABLE))
                .nodes.map { it.id }
        if (capabilityNodeIds.isNotEmpty()) return capabilityNodeIds
        return Tasks.await(Wearable.getNodeClient(appContext).connectedNodes).map { it.id }
    }

    override fun onMessageReceived(messageEvent: MessageEvent) {
        when (messageEvent.path) {
            "$MESSAGE_PATH_PREFIX/$COMMAND_START_REJECTED" -> {
                val sessionClientId = String(messageEvent.data)
                eventSink?.success(mapOf("type" to "startRejected", "sessionClientId" to sessionClientId))
            }
            "$MESSAGE_PATH_PREFIX/$COMMAND_END_REQUESTED" -> {
                val sessionClientId = String(messageEvent.data)
                eventSink?.success(mapOf("type" to "endRequested", "sessionClientId" to sessionClientId))
            }
            "$MESSAGE_PATH_PREFIX/$COMMAND_STARTED_ON_WATCH" -> {
                val sessionClientId = String(messageEvent.data)
                eventSink?.success(mapOf("type" to "startedOnWatch", "sessionClientId" to sessionClientId))
            }
            "$MESSAGE_PATH_PREFIX/$COMMAND_SUMMARY" -> {
                emitSummary(String(messageEvent.data))
            }
            // PhoneWatchSummaryListenerService also receives this same
            // summary message (manifest-declared, so it fires even if this
            // MethodChannel-backed listener isn't attached yet) and buffers
            // it for the next onListen sweep below
            // (docs/40-watch-app-plan.md §5.4).
        }
    }

    private fun emitSummary(summaryJson: String) {
        val payload = JSONObject(summaryJson)
        eventSink?.success(
            mapOf(
                "type" to "summary",
                "payload" to
                    mapOf(
                        "sessionClientId" to payload.optString("sessionClientId"),
                        "activeCalories" to
                            if (payload.has("activeCalories")) payload.optDouble("activeCalories") else null,
                        "averageHeartRate" to
                            if (payload.has("averageHeartRate")) payload.optDouble("averageHeartRate") else null,
                        // Android never gets this from the watch — the phone
                        // itself writes Health Connect and fills it in
                        // (docs/40-watch-app-plan.md §5.2, decided in
                        // workout_resume_prompt.dart's Android branch).
                        "healthWorkoutId" to null,
                    ),
            )
        )
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
        // The moment Dart starts listening (every cold start — see
        // WorkoutResumePrompt) is also the sweep point for summaries that
        // arrived while the Flutter engine wasn't running
        // (docs/40-watch-app-plan.md §5.4).
        for (buffered in WatchSummaryBuffer.drain(appContext)) {
            emitSummary(buffered)
        }
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    companion object {
        private const val TAG = "LifeyWatchBridge"
        private const val CHANNEL_NAME = "lifey/watch"
        private const val EVENT_CHANNEL_NAME = "lifey/watch/events"
        private const val WATCH_CAPABILITY = "lifey_watch_workout"
        private const val MESSAGE_PATH_PREFIX = "/lifey/watch"
        private const val STATE_PATH = "$MESSAGE_PATH_PREFIX/state"
        private const val COMMAND_START = "start"
        private const val COMMAND_STATE = "state"
        private const val COMMAND_END = "end"
        private const val COMMAND_START_REJECTED = "startRejected"
        private const val COMMAND_END_REQUESTED = "endRequested"
        private const val COMMAND_STARTED_ON_WATCH = "startedOnWatch"
        private const val COMMAND_SUMMARY = "summary"
    }
}

private fun Map<String, Any?>.toDataMap(): DataMap {
    val map = DataMap()
    forEach { (key, value) ->
        when (value) {
            is String -> map.putString(key, value)
            is Int -> map.putInt(key, value)
            is Long -> map.putLong(key, value)
            is Double -> map.putDouble(key, value)
            is Boolean -> map.putBoolean(key, value)
        }
    }
    return map
}
