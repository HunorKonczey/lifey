plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services") apply false
}

// Android push (docs/30-push-notifications-plan.md, M1b): the google-services
// plugin hard-fails the build if google-services.json is missing, so it's only
// applied once that file exists — a real one, downloaded from the Firebase
// console for the com.khunor.lifey Android app, dropped in next to this file
// (git-ignored; see devops/push-notifications-android.md). Until then, builds
// work exactly as before and Android push is simply not wired up.
if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
}

android {
    namespace = "com.khunor.lifey"
    // flutter.compileSdkVersion=36 is set in gradle.properties (the `health`
    // plugin's androidx.health.connect dependency requires compiling
    // against API 35+); reading it here keeps both app and plugin modules
    // consistent with the same Flutter-recognized override mechanism.
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // Core library desugaring — kept enabled as a safe default for plugins
        // that rely on newer java.time/etc. APIs on older Android API levels.
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.khunor.lifey"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // The `health` plugin (lib/core/health/, Phase 0 of
        // docs/16-apple-health-integration-plan.md) requires 26+ on Android;
        // Flutter's default (24) no longer builds once it's a dependency.
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    // Wearable Data Layer (docs/40-watch-app-plan.md §5.1, §D2) — WatchBridge.kt.
    implementation("com.google.android.gms:play-services-wearable:19.0.0")
}
