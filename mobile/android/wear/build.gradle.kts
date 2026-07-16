plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
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

    // Compose for Wear OS UI (docs/40-watch-app-plan.md §5.1, F3).
    buildFeatures {
        compose = true
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

    // Compose for Wear OS UI (docs/40-watch-app-plan.md §5, F3).
    implementation(platform("androidx.compose:compose-bom:2026.06.00"))
    implementation("androidx.activity:activity-compose:1.9.3")
    implementation("androidx.wear.compose:compose-material:1.4.1")
    implementation("androidx.wear.compose:compose-foundation:1.4.1")
    implementation("androidx.compose.ui:ui-tooling-preview")
    debugImplementation("androidx.compose.ui:ui-tooling")

    // Health Services — live HR/kcal during the strength-training exercise
    // (docs/40-watch-app-plan.md §5.3). Pinned to the stable release; the
    // 1.1.0 line was still pre-release (rc) as of this writing.
    implementation("androidx.health:health-services-client:1.0.0")

    // ExerciseClient's async methods return a Guava ListenableFuture; this
    // gives them a Kotlin coroutine `.await()` instead of manual callbacks.
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-guava:1.10.2")
    // MessageClient/NodeClient/DataClient methods return a Play Services
    // Task (a different type from ListenableFuture above) — same idea, the
    // matching `.await()` extension for that type.
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-play-services:1.10.2")
    implementation("androidx.core:core-ktx:1.15.0")
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.8.7")
}
