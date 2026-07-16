package com.khunor.lifey

import android.util.Log
import com.google.android.gms.wearable.MessageEvent
import com.google.android.gms.wearable.WearableListenerService

/**
 * Wakes even if the wear app isn't running when the phone's `WatchBridge`
 * sends a Data Layer message (docs/40-watch-app-plan.md §5.1, §5.4) — the F0
 * spike's end-to-end proof. F3 replaces the body with real
 * `ExerciseClient.startExercise()`/`endExercise()` handling and a foreground
 * service promotion.
 */
class PhoneListenerService : WearableListenerService() {
    override fun onMessageReceived(messageEvent: MessageEvent) {
        if (!messageEvent.path.startsWith(MESSAGE_PATH_PREFIX)) return
        Log.i(TAG, "Received ${messageEvent.path} (${messageEvent.data.size} bytes)")
    }

    companion object {
        private const val TAG = "LifeyWatchListener"
        const val MESSAGE_PATH_PREFIX = "/lifey/watch"
    }
}
