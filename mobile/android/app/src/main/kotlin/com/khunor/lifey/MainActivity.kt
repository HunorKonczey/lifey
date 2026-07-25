package com.khunor.lifey

import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine

// FlutterFragmentActivity (not FlutterActivity): the health plugin's Android
// 14+ permission flow uses registerForActivityResult, which needs a
// ComponentActivity — see docs/26-android-health-connect-integration-plan.md.
class MainActivity : FlutterFragmentActivity() {
    private var watchBridge: WatchBridge? = null
    private var mediaSessionBridge: MediaSessionBridge? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // docs/40-watch-app-plan.md §5.1, §6.1.
        watchBridge = WatchBridge(this, flutterEngine.dartExecutor.binaryMessenger)
        // docs/music/46-workout-music-controls-plan.md §2.1, M2.
        mediaSessionBridge = MediaSessionBridge(this, flutterEngine.dartExecutor.binaryMessenger)
    }
}
