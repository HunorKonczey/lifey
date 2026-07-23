package com.khunor.lifey

import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification

/**
 * Exists purely so its [ComponentName][android.content.ComponentName] can be
 * passed to `MediaSessionManager.getActiveSessions`/
 * `addOnActiveSessionsChangedListener` — those calls require the caller to
 * name an enabled `NotificationListenerService` belonging to the same app,
 * even though this feature never actually reads notification content (see
 * docs/music/46-workout-music-controls-plan.md §2.1's "prominent disclosure"
 * requirement: only playback state/metadata is used).
 *
 * [onListenerConnected]/[onListenerDisconnected] fire when the OS
 * (un)binds this service in response to the user granting/revoking
 * notification access in Settings — [MediaSessionBridge] uses these to push
 * a fresh state the moment that happens, without [MediaSessionBridge] (or
 * Dart) needing to poll or watch app-resume.
 */
class MusicNotificationListenerService : NotificationListenerService() {
    override fun onListenerConnected() {
        super.onListenerConnected()
        MediaSessionBridge.instance?.onNotificationAccessChanged()
    }

    override fun onListenerDisconnected() {
        super.onListenerDisconnected()
        MediaSessionBridge.instance?.onNotificationAccessChanged()
    }

    // Required override — deliberately empty, this service never inspects
    // notification content, only its own enabled/bound status (see class doc).
    override fun onNotificationPosted(sbn: StatusBarNotification) {}
}
