package com.khunor.lifey

import com.google.android.gms.wearable.MessageEvent
import com.google.android.gms.wearable.WearableListenerService

/**
 * Manifest-declared counterpart to [WatchBridge]'s live `MessageClient`
 * listener: this one wakes even if the Flutter engine isn't running, so a
 * workout summary or a standalone-session delivery sent right as the phone
 * app was killed still gets buffered (docs/40-watch-app-plan.md §5.4,
 * docs/watch/44-watch-f6-standalone-plan.md §6/1 — the standalone case is
 * the more important one to cover here: the phone is typically
 * pocketed/backgrounded when that delivery lands, unlike the live-app-open
 * summary case this service was originally built for). [WatchBridge] drains
 * both [WatchSummaryBuffer] and [WatchStandaloneSessionBuffer] the moment
 * Dart starts listening again.
 */
class PhoneWatchSummaryListenerService : WearableListenerService() {
    override fun onMessageReceived(messageEvent: MessageEvent) {
        when (messageEvent.path) {
            SUMMARY_PATH -> WatchSummaryBuffer.add(this, String(messageEvent.data))
            STANDALONE_SESSION_PATH -> WatchStandaloneSessionBuffer.add(this, String(messageEvent.data))
        }
    }

    companion object {
        private const val SUMMARY_PATH = "/lifey/watch/summary"
        private const val STANDALONE_SESSION_PATH = "/lifey/watch/standaloneSessionCompleted"
    }
}
