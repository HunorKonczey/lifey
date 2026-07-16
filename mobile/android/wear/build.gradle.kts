plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}

// Standalone Wear OS companion module (docs/40-watch-app-plan.md §5.1) — not
// a Flutter module, so it doesn't apply the flutter-gradle-plugin and can't
// read the `flutter.*` extension; it reads the same compileSdk override
// property (gradle.properties) the phone `:app` module uses, so both stay in
// lockstep without hardcoding the number twice.
android {
    namespace = "com.khunor.lifey"
    compileSdk = (property("flutter.compileSdkVersion") as String).toInt()

    defaultConfig {
        // Same applicationId as the phone app — required for the Wearable
        // Data Layer (MessageClient/DataClient/CapabilityClient) to see this
        // as the companion of com.khunor.lifey (docs/40-watch-app-plan.md §5.1).
        applicationId = "com.khunor.lifey"
        minSdk = 30
        targetSdk = compileSdk
        versionCode = 1
        versionName = "1.0"
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    buildTypes {
        release {
            // Debug-signed for now, matching the phone `:app` module — the
            // Data Layer requires matching signatures between the two APKs
            // during development (docs/40-watch-app-plan.md §5.1,
            // devops/deploy-watch-testing.md).
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    implementation("com.google.android.gms:play-services-wearable:19.0.0")
}
