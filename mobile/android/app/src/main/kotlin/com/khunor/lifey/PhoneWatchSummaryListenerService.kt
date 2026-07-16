package com.khunor.lifey

import com.google.android.gms.wearable.MessageEvent
import com.google.android.gms.wearable.WearableListenerService

/**
 * Manifest-declared counterpart to [WatchBridge]'s live `MessageClient`
 * listener: this one wakes even if the Flutter engine isn't running, so a
 * workout summary sent right as the phone app was killed still gets
 * buffered (docs/40-watch-app-plan.md §5.4). [WatchBridge] drains
 * [WatchSummaryBuffer] the moment Dart starts listening again.
 */
class PhoneWatchSummaryListenerService : WearableListenerService() {
    override fun onMessageReceived(messageEvent: MessageEvent) {
        if (messageEvent.path != SUMMARY_PATH) return
        WatchSummaryBuffer.add(this, String(messageEvent.data))
    }

    companion object {
        private const val SUMMARY_PATH = "/lifey/watch/summary"
    }
}
