package com.khunor.lifey

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

private const val CHANNEL = "lifey/health_connect"
private const val READ_EXERCISE_ROUTES = "android.permission.health.READ_EXERCISE_ROUTES"
private const val HEALTH_CONNECT_PACKAGE = "com.google.android.apps.healthdata"

/**
 * The two Health Connect calls the `health` plugin does not offer, for the
 * cardio import's route hint (docs/integrations/89 G1.8, LIF-223). Other
 * apps' workout routes are readable only with the *Exercise routes*
 * permission. No in-app request asks for it (the plugin does not run
 * `ExerciseRouteRequestContract`), so the user has to grant it in Health
 * Connect itself. This bridge says whether they have, and opens Health
 * Connect so they can.
 *
 * Same plain-MethodChannel-class pattern as [ShortcutsBridge].
 */
class HealthConnectBridge(private val activity: Activity, messenger: BinaryMessenger) {
    init {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "routePermissionGranted" -> result.success(routePermissionGranted())
                "openHealthConnect" -> result.success(openHealthConnect())
                else -> result.notImplemented()
            }
        }
    }

    /**
     * Whether the *Exercise routes* permission is granted. From Android 14
     * Health Connect permissions are ordinary runtime permissions, so the
     * platform check answers. Below that they live in the Health Connect app
     * and this returns null: unknown.
     */
    private fun routePermissionGranted(): Boolean? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.UPSIDE_DOWN_CAKE) return null
        return activity.checkSelfPermission(READ_EXERCISE_ROUTES) == PackageManager.PERMISSION_GRANTED
    }

    /**
     * Opens Health Connect, where Lifey is one tap away under "Your health
     * apps" (then Additional access › Access exercise routes). False when it
     * could not open.
     *
     * From Android 14 Lifey's own permission page
     * (`MANAGE_HEALTH_PERMISSIONS`) needs `GRANT_RUNTIME_PERMISSIONS`, a
     * system-only permission (seen on the emulator: "Permission Denial"), so
     * Health Connect's home is the deepest page an app may open. The Health
     * Connect app of Android 13 and lower still takes the app-page intent, so
     * that is tried first there.
     */
    private fun openHealthConnect(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            return start(Intent("android.health.connect.action.HEALTH_HOME_SETTINGS"))
        }
        val appPage = Intent("androidx.health.ACTION_MANAGE_HEALTH_PERMISSIONS")
            .setPackage(HEALTH_CONNECT_PACKAGE)
            .putExtra(Intent.EXTRA_PACKAGE_NAME, activity.packageName)
        val home = Intent("androidx.health.ACTION_HEALTH_CONNECT_SETTINGS").setPackage(HEALTH_CONNECT_PACKAGE)
        return start(appPage) || start(home)
    }

    private fun start(intent: Intent): Boolean = try {
        activity.startActivity(intent)
        true
    } catch (_: ActivityNotFoundException) {
        false
    } catch (_: SecurityException) {
        false
    }
}
