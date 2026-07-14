import 'dart:io';

import 'package:firebase_core/firebase_core.dart';

/// Lazily initializes the default Firebase app exactly once — Android push
/// only (iOS never touches Firebase; see docs/30-push-notifications-plan.md).
///
/// Both [AndroidPushTokenSource] and `PushTapHandler` may call this
/// independently and concurrently at app startup, so the in-flight attempt is
/// memoized (rather than just guarding with `Firebase.apps.isEmpty`, which
/// would race if both callers check it before either has actually
/// initialized) — every caller awaits the same single call.
Future<void> ensureFirebaseInitialized() {
  if (!Platform.isAndroid) return Future<void>.value();
  return _initializing ??= _initialize();
}

Future<void>? _initializing;

Future<void> _initialize() async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp();
  }
}
