import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';

import 'firebase_bootstrap.dart';
import 'push_token_source.dart';

/// FCM-backed [PushTokenSource] for Android (docs/30-push-notifications-plan.md,
/// M1b). iOS registers through the native `lifey/push` platform channel
/// instead (M1) and never touches Firebase — this class no-ops on every
/// other platform, so it's safe to construct unconditionally.
class AndroidPushTokenSource implements PushTokenSource {
  @override
  String get platform => 'ANDROID';

  @override
  Future<String?> getToken() async {
    if (!Platform.isAndroid) return null;
    await ensureFirebaseInitialized();

    // Triggers the Android 13+ POST_NOTIFICATIONS system prompt; a no-op
    // returning `authorized` on older Android. iOS-specific params
    // (alert/badge/sound/etc.) default fine here since this path never runs
    // on iOS.
    final settings = await FirebaseMessaging.instance.requestPermission();
    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      return null;
    }
    return FirebaseMessaging.instance.getToken();
  }

  @override
  Stream<String> get onTokenRefreshed {
    if (!Platform.isAndroid) return const Stream.empty();
    // Firebase must already be initialized by the time anything subscribes —
    // callers are expected to have called getToken() first (the normal
    // registration flow always does).
    return FirebaseMessaging.instance.onTokenRefresh;
  }
}
