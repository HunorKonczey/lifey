package com.khunor.lifey

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.media.MediaMetadata
import android.media.session.MediaController
import android.media.session.MediaSessionManager
import android.media.session.PlaybackState
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.util.Log
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

/**
 * Handles the `lifey/music` MethodChannel + `lifey/music/events` EventChannel
 * that `MusicServiceAndroid` (mobile/lib/core/music/music_service_android.dart)
 * calls into — docs/music/46-workout-music-controls-plan.md §2.1, M2.
 * Registered from MainActivity.configureFlutterEngine.
 *
 * One implementation covers all three providers (Spotify/Apple Music/YouTube
 * Music): `MediaSessionManager` exposes *every* app's active media session to
 * a granted `NotificationListenerService`
 * ([MusicNotificationListenerService]) — this just filters by package name
 * for whichever provider Dart currently has selected. All calls here are
 * cheap local system-service calls (no `Tasks.await`-style blocking like
 * `WatchBridge`'s Wearable Data Layer calls), so everything runs directly on
 * the calling (main/platform) thread.
 */
class MediaSessionBridge(context: Context, messenger: BinaryMessenger) :
    MethodChannel.MethodCallHandler,
    EventChannel.StreamHandler {

    private val appContext = context.applicationContext
    private val mediaSessionManager =
        appContext.getSystemService(Context.MEDIA_SESSION_SERVICE) as MediaSessionManager
    private val listenerComponent = ComponentName(appContext, MusicNotificationListenerService::class.java)
    private val mainHandler = Handler(Looper.getMainLooper())

    private var eventSink: EventChannel.EventSink? = null

    /**
     * The provider id string Dart last sent via `activate`/`selectProvider`
     * (e.g. "spotify") — deliberately not persisted here; `deactivate`
     * clears it, and the next `activate` always supplies it fresh from
     * Dart's own `MusicPreferences` (see `MusicServiceAndroid.activate`'s
     * doc comment). Echoed back verbatim in every emitted event's
     * `"provider"` field, so it must always be exactly one of
     * `MusicProviderId`'s Dart enum member names.
     */
    private var currentProviderId: String? = null
    private var sessionsListenerRegistered = false

    private var trackedController: MediaController? = null
    private var trackedCallback: MediaController.Callback? = null

    private val sessionsListener =
        MediaSessionManager.OnActiveSessionsChangedListener { recomputeAndEmit() }

    init {
        MethodChannel(messenger, CHANNEL_NAME).setMethodCallHandler(this)
        EventChannel(messenger, EVENT_CHANNEL_NAME).setStreamHandler(this)
        instance = this
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "activate" -> {
                currentProviderId = call.argument<String>("providerId")
                registerSessionsListenerIfNeeded()
                recomputeAndEmit()
                result.success(null)
            }
            "selectProvider" -> {
                currentProviderId = call.argument<String>("providerId")
                registerSessionsListenerIfNeeded()
                recomputeAndEmit()
                result.success(null)
            }
            "deactivate" -> {
                unregisterSessionsListener()
                detachControllerCallback()
                currentProviderId = null
                result.success(null)
            }
            "isProviderInstalled" -> {
                result.success(isPackageInstalled(packageNameFor(call.argument("providerId"))))
            }
            "play" -> {
                trackedController?.transportControls?.play()
                result.success(null)
            }
            "pause" -> {
                trackedController?.transportControls?.pause()
                result.success(null)
            }
            "next" -> {
                trackedController?.transportControls?.skipToNext()
                result.success(null)
            }
            "previous" -> {
                trackedController?.transportControls?.skipToPrevious()
                result.success(null)
            }
            "openProviderApp" -> {
                openProviderApp()
                result.success(null)
            }
            "requestPermission" -> {
                openNotificationAccessSettings()
                result.success(null)
            }
            "refresh" -> {
                recomputeAndEmit()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    /**
     * Called by [MusicNotificationListenerService] the moment the OS
     * (un)binds it in response to the user granting/revoking notification
     * access — this is what makes `requestPermission`'s system-settings
     * round trip self-updating on the Dart side without any resume-hook or
     * polling (docs/music/46-workout-music-controls-plan.md §2.1).
     */
    fun onNotificationAccessChanged() {
        mainHandler.post {
            registerSessionsListenerIfNeeded()
            recomputeAndEmit()
        }
    }

    // ---------------------------------------------------------------------
    // Status computation
    // ---------------------------------------------------------------------

    private fun recomputeAndEmit() {
        val providerId = currentProviderId
        if (providerId == null) {
            detachControllerCallback()
            emit("notConfigured", null, null)
            return
        }
        val packageName = packageNameFor(providerId)
        if (packageName == null || !isPackageInstalled(packageName)) {
            detachControllerCallback()
            emit("appNotInstalled", providerId, null)
            return
        }
        if (!hasNotificationAccess()) {
            detachControllerCallback()
            emit("permissionNeeded", providerId, null)
            return
        }
        try {
            val sessions = mediaSessionManager.getActiveSessions(listenerComponent)
            val controller = sessions.firstOrNull { it.packageName == packageName }
            attachControllerCallback(controller)
            if (controller == null) {
                emit("noActiveSession", providerId, null)
            } else {
                emitFromController(controller, providerId)
            }
        } catch (e: SecurityException) {
            Log.w(TAG, "getActiveSessions denied", e)
            emit("permissionNeeded", providerId, null)
        } catch (e: Exception) {
            Log.w(TAG, "recomputeAndEmit failed", e)
            emit("error", providerId, null)
        }
    }

    private fun emitFromController(controller: MediaController, providerId: String) {
        val metadata = controller.metadata
        val playbackState = controller.playbackState
        val isPlaying = playbackState?.state == PlaybackState.STATE_PLAYING
        val playback =
            mapOf(
                "title" to metadata?.getString(MediaMetadata.METADATA_KEY_TITLE),
                "artist" to
                    (
                        metadata?.getString(MediaMetadata.METADATA_KEY_ARTIST)
                            ?: metadata?.getString(MediaMetadata.METADATA_KEY_ALBUM_ARTIST)
                    ),
                "artworkPng" to extractArtworkPng(metadata),
                "isPlaying" to isPlaying,
            )
        emit("connected", providerId, playback)
    }

    private fun emit(status: String, providerId: String?, playback: Map<String, Any?>?) {
        mainHandler.post {
            eventSink?.success(mapOf("status" to status, "provider" to providerId, "playback" to playback))
        }
    }

    // ---------------------------------------------------------------------
    // MediaController tracking — separate from [sessionsListener]: that one
    // only fires when the *set* of active sessions changes, not on every
    // playback tick, so the currently-tracked controller needs its own
    // per-session callback for title/artist/art/play-pause updates.
    // ---------------------------------------------------------------------

    private fun attachControllerCallback(controller: MediaController?) {
        if (controller?.sessionToken == trackedController?.sessionToken) return
        detachControllerCallback()
        if (controller == null) return
        val callback =
            object : MediaController.Callback() {
                override fun onPlaybackStateChanged(state: PlaybackState?) {
                    currentProviderId?.let { emitFromController(controller, it) }
                }

                override fun onMetadataChanged(metadata: MediaMetadata?) {
                    currentProviderId?.let { emitFromController(controller, it) }
                }

                override fun onSessionDestroyed() {
                    trackedController = null
                    trackedCallback = null
                    recomputeAndEmit()
                }
            }
        controller.registerCallback(callback, mainHandler)
        trackedController = controller
        trackedCallback = callback
    }

    private fun detachControllerCallback() {
        trackedCallback?.let { trackedController?.unregisterCallback(it) }
        trackedController = null
        trackedCallback = null
    }

    private fun registerSessionsListenerIfNeeded() {
        if (sessionsListenerRegistered || !hasNotificationAccess()) return
        try {
            mediaSessionManager.addOnActiveSessionsChangedListener(sessionsListener, listenerComponent)
            sessionsListenerRegistered = true
        } catch (e: SecurityException) {
            Log.w(TAG, "addOnActiveSessionsChangedListener denied", e)
        }
    }

    private fun unregisterSessionsListener() {
        if (!sessionsListenerRegistered) return
        mediaSessionManager.removeOnActiveSessionsChangedListener(sessionsListener)
        sessionsListenerRegistered = false
    }

    // ---------------------------------------------------------------------
    // Package / artwork / settings helpers
    // ---------------------------------------------------------------------

    private fun packageNameFor(providerId: String?): String? =
        when (providerId) {
            "spotify" -> "com.spotify.music"
            "appleMusic" -> "com.apple.android.music"
            "youtubeMusic" -> "com.google.android.apps.youtube.music"
            else -> null
        }

    private fun isPackageInstalled(packageName: String?): Boolean {
        if (packageName == null) return false
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                appContext.packageManager.getPackageInfo(packageName, PackageManager.PackageInfoFlags.of(0))
            } else {
                @Suppress("DEPRECATION")
                appContext.packageManager.getPackageInfo(packageName, 0)
            }
            true
        } catch (e: Exception) {
            false
        }
    }

    private fun openProviderApp() {
        val packageName = packageNameFor(currentProviderId) ?: return
        val intent = appContext.packageManager.getLaunchIntentForPackage(packageName) ?: return
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        appContext.startActivity(intent)
    }

    /**
     * The same underlying check `NotificationManagerCompat.
     * getEnabledListenerPackages` performs — read directly rather than
     * pulling in the androidx.core dependency just for this one call.
     */
    private fun hasNotificationAccess(): Boolean {
        val enabled =
            Settings.Secure.getString(appContext.contentResolver, "enabled_notification_listeners")
                ?: return false
        return enabled.split(":").any { ComponentName.unflattenFromString(it) == listenerComponent }
    }

    private fun openNotificationAccessSettings() {
        val intent =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                Intent(Settings.ACTION_NOTIFICATION_LISTENER_DETAIL_SETTINGS).apply {
                    putExtra(
                        Settings.EXTRA_NOTIFICATION_LISTENER_COMPONENT_NAME,
                        listenerComponent.flattenToString(),
                    )
                }
            } else {
                Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
            }
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        try {
            appContext.startActivity(intent)
        } catch (e: Exception) {
            Log.w(TAG, "Could not open notification access settings", e)
        }
    }

    /**
     * Downscaled before PNG-encoding (album art can come in at 1000px+) to
     * keep the EventChannel payload small — this fires on every track
     * change, not just once.
     */
    private fun extractArtworkPng(metadata: MediaMetadata?): ByteArray? {
        val bitmap =
            metadata?.getBitmap(MediaMetadata.METADATA_KEY_ALBUM_ART)
                ?: metadata?.getBitmap(MediaMetadata.METADATA_KEY_ART)
                ?: return null
        return try {
            val scaled = scaleDown(bitmap, MAX_ARTWORK_DIMENSION)
            val stream = ByteArrayOutputStream()
            scaled.compress(Bitmap.CompressFormat.PNG, 90, stream)
            stream.toByteArray()
        } catch (e: Exception) {
            Log.w(TAG, "extractArtworkPng failed", e)
            null
        }
    }

    private fun scaleDown(bitmap: Bitmap, maxDimension: Int): Bitmap {
        val width = bitmap.width
        val height = bitmap.height
        if (width <= maxDimension && height <= maxDimension) return bitmap
        val scale = maxDimension.toFloat() / maxOf(width, height)
        return Bitmap.createScaledBitmap(bitmap, (width * scale).toInt(), (height * scale).toInt(), true)
    }

    // ---------------------------------------------------------------------
    // EventChannel.StreamHandler
    // ---------------------------------------------------------------------

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
        recomputeAndEmit()
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    companion object {
        private const val TAG = "LifeyMediaSessionBridge"
        private const val CHANNEL_NAME = "lifey/music"
        private const val EVENT_CHANNEL_NAME = "lifey/music/events"
        private const val MAX_ARTWORK_DIMENSION = 300

        /**
         * Single instance, set from MainActivity.configureFlutterEngine —
         * lets [MusicNotificationListenerService] (a system-instantiated
         * component this bridge doesn't own) reach back into it.
         */
        var instance: MediaSessionBridge? = null
            private set
    }
}
