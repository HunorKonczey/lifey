package com.khunor.lifey

import io.flutter.embedding.android.FlutterFragmentActivity

// FlutterFragmentActivity (not FlutterActivity): the health plugin's Android
// 14+ permission flow uses registerForActivityResult, which needs a
// ComponentActivity — see docs/26-android-health-connect-integration-plan.md.
class MainActivity : FlutterFragmentActivity()
