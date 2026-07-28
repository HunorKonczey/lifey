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
import org.json.JSONArray
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
            "ackSetLogged" -> ackSetLogged(call, result)
            "ackStandaloneSession" -> ackStandaloneSession(call, result)
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
     * Answers a `setLogged` event (docs/watch/43-watch-f5-set-logging-plan.md
     * §4.3, §5.1). [sessionClientId] is the one the watch tagged the
     * original `logSet` message with — passed through from Dart rather than
     * remembered here, keeping this bridge stateless like the rest of it.
     * Sent as a plain message via [sendMessage] — no `pushState`-style
     * DataItem fallback, since an ack has no value once stale (the watch
     * simply times out on its own, §7.1).
     */
    private fun ackSetLogged(call: MethodCall, result: MethodChannel.Result) {
        val args = call.arguments as? Map<*, *> ?: return result.success(null)
        val sessionClientId = args["sessionClientId"] as? String ?: return result.success(null)
        val eventId = args["eventId"] as? String ?: return result.success(null)
        val accepted = args["accepted"] as? Boolean ?: return result.success(null)

        val json =
            JSONObject().apply {
                put("sessionClientId", sessionClientId)
                put("eventId", eventId)
                put("accepted", accepted)
            }
        sendMessage(COMMAND_LOG_SET_ACK, json.toString().toByteArray())
        result.success(null)
    }

    /**
     * Answers a `standaloneSessionCompleted` delivery (docs/watch/
     * 44-watch-f6-standalone-plan.md §4.2). No `accepted` field — unlike
     * [ackSetLogged] there's no rejection case, the watch's own
     * pending-session store just retries an un-acked delivery regardless of
     * why it wasn't acked.
     */
    private fun ackStandaloneSession(call: MethodCall, result: MethodChannel.Result) {
        val args = call.arguments as? Map<*, *> ?: return result.success(null)
        val standaloneSessionId = args["standaloneSessionId"] as? String ?: return result.success(null)

        val json = JSONObject().apply { put("standaloneSessionId", standaloneSessionId) }
        sendMessage(COMMAND_STANDALONE_ACK, json.toString().toByteArray())
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
                emitEndRequested(String(messageEvent.data))
            }
            "$MESSAGE_PATH_PREFIX/$COMMAND_STARTED_ON_WATCH" -> {
                val sessionClientId = String(messageEvent.data)
                eventSink?.success(mapOf("type" to "startedOnWatch", "sessionClientId" to sessionClientId))
            }
            "$MESSAGE_PATH_PREFIX/$COMMAND_SUMMARY" -> {
                emitSummary(String(messageEvent.data))
            }
            "$MESSAGE_PATH_PREFIX/$COMMAND_LIVE_METRICS" -> {
                emitLiveMetrics(String(messageEvent.data))
            }
            "$MESSAGE_PATH_PREFIX/$COMMAND_LOG_SET" -> {
                emitSetLogged(String(messageEvent.data))
            }
            "$MESSAGE_PATH_PREFIX/$COMMAND_STANDALONE_SESSION" -> {
                emitStandaloneSession(String(messageEvent.data))
            }
            // PhoneWatchSummaryListenerService also receives this same
            // summary/standaloneSessionCompleted message (manifest-declared,
            // so it fires even if this MethodChannel-backed listener isn't
            // attached yet) and buffers it for the next onListen sweep below
            // (docs/40-watch-app-plan.md §5.4, docs/watch/
            // 44-watch-f6-standalone-plan.md §6/1).
        }
    }

    /**
     * The watch already collected (or skipped) the effort rating itself
     * before sending this — [rpe] is null when skipped. Payload is now JSON
     * (like `start`/`state`) rather than a raw sessionClientId string, so it
     * can carry `rpe` alongside the id.
     */
    private fun emitEndRequested(endRequestedJson: String) {
        val payload = JSONObject(endRequestedJson)
        eventSink?.success(
            mapOf(
                "type" to "endRequested",
                "sessionClientId" to payload.optString("sessionClientId"),
                "rpe" to if (payload.has("rpe")) payload.optInt("rpe") else null,
            ),
        )
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

    private fun emitLiveMetrics(liveMetricsJson: String) {
        val payload = JSONObject(liveMetricsJson)
        eventSink?.success(
            mapOf(
                "type" to "liveMetrics",
                "payload" to
                    mapOf(
                        "sessionClientId" to payload.optString("sessionClientId"),
                        "heartRateBpm" to
                            if (payload.has("heartRateBpm")) payload.optDouble("heartRateBpm") else null,
                        "activeCalories" to
                            if (payload.has("activeCalories")) payload.optDouble("activeCalories") else null,
                    ),
            )
        )
    }

    /**
     * docs/watch/43-watch-f5-set-logging-plan.md §4.1 — no exercise/reps/
     * weight on the wire, the watch is a dumb trigger; `LogSessionScreen`
     * decides what to log from its own current position.
     */
    private fun emitSetLogged(logSetJson: String) {
        val payload = JSONObject(logSetJson)
        eventSink?.success(
            mapOf(
                "type" to "setLogged",
                "sessionClientId" to payload.optString("sessionClientId"),
                "eventId" to payload.optString("eventId"),
                "loggedAtEpochMs" to payload.optLong("loggedAtEpochMs"),
                // The F5b adjust values (docs/watch/48-watch-f5b-set-adjust-plan.md
                // §4.1) — absent for a plain F5a one-tap log. The `has()` guard
                // matters: optInt/optDouble return 0 for a missing key, and a
                // silent 0 kg / 0 reps would look like a deliberate value to the
                // Dart side instead of "no values" (D-F5b.6).
                "reps" to if (payload.has("reps")) payload.optInt("reps") else null,
                "weight" to if (payload.has("weight")) payload.optDouble("weight") else null,
            ),
        )
    }

    /**
     * docs/watch/44-watch-f6-standalone-plan.md §4.1 — the watch's own
     * `standaloneSessionId` becomes the resulting session's `clientId`
     * (idempotency key, D-F6.3); no exercise/reps mapping happens here, that
     * belongs to the Dart-side processor. `healthWorkoutId` is always null
     * on Android — the watch never touches Health Connect, the phone does
     * (D-F6.5), same as [emitSummary].
     */
    private fun emitStandaloneSession(standaloneSessionJson: String) {
        val payload = JSONObject(standaloneSessionJson)
        val setsArray = payload.optJSONArray("sets") ?: JSONArray()
        val sets =
            (0 until setsArray.length()).map { i ->
                val set = setsArray.getJSONObject(i)
                mapOf(
                    "loggedAtEpochMs" to set.optLong("loggedAtEpochMs"),
                    "reps" to set.optInt("reps"),
                    "exerciseIndex" to if (set.has("exerciseIndex")) set.optInt("exerciseIndex") else null,
                )
            }
        eventSink?.success(
            mapOf(
                "type" to "standaloneSession",
                "payload" to
                    mapOf(
                        "standaloneSessionId" to payload.optString("standaloneSessionId"),
                        "templateId" to
                            if (payload.has("templateId")) payload.optString("templateId") else null,
                        "startedAtEpochMs" to payload.optLong("startedAtEpochMs"),
                        "endedAtEpochMs" to payload.optLong("endedAtEpochMs"),
                        "rpe" to if (payload.has("rpe")) payload.optInt("rpe") else null,
                        "sets" to sets,
                        "activeCalories" to
                            if (payload.has("activeCalories")) payload.optDouble("activeCalories") else null,
                        "averageHeartRate" to
                            if (payload.has("averageHeartRate")) payload.optDouble("averageHeartRate")
                            else null,
                        "healthWorkoutId" to null,
                    ),
            ),
        )
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
        // The moment Dart starts listening (every cold start — see
        // WorkoutResumePrompt) is also the sweep point for summaries and
        // standalone sessions that arrived while the Flutter engine wasn't
        // running (docs/40-watch-app-plan.md §5.4, docs/watch/
        // 44-watch-f6-standalone-plan.md §6/1).
        for (buffered in WatchSummaryBuffer.drain(appContext)) {
            emitSummary(buffered)
        }
        for (buffered in WatchStandaloneSessionBuffer.drain(appContext)) {
            emitStandaloneSession(buffered)
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
        private const val COMMAND_LIVE_METRICS = "liveMetrics"
        private const val COMMAND_LOG_SET = "logSet"
        private const val COMMAND_LOG_SET_ACK = "logSetAck"
        private const val COMMAND_STANDALONE_SESSION = "standaloneSessionCompleted"
        private const val COMMAND_STANDALONE_ACK = "standaloneSessionAck"
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
