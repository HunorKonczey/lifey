pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "9.0.1" apply false
    id("org.jetbrains.kotlin.android") version "2.3.20" apply false
    // Android push (docs/30-push-notifications-plan.md, M1b) — reads
    // app/google-services.json, generated from the Firebase console for the
    // com.khunor.lifey Android app. Not committed (see .gitignore); the app
    // module fails to build without a real file in place.
    id("com.google.gms.google-services") version "4.5.0" apply false
}

include(":app")
