import 'dart:async';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';

import 'firebase_bootstrap.dart';
import 'push_token_source.dart';

/// FCM-backed [PushTokenSource] for Android (docs/30-push-notifications-plan.md,
/// M1b). iOS registers through the native `lifey/push` platform channel
/// instead (M1) and never touches Firebase — this class no-ops on every
/// other platform, so it's safe to construct unconditionally.
///
/// Since LIF-191 the "token" is a Firebase Installation ID (FID), not an FCM
/// registration token: firebase_messaging 17 deprecates `getToken()` /
/// `onTokenRefresh` in favour of `register()` / `onRegistered`, which needs the
/// `firebase_messaging_installation_id_enabled` manifest flag. The backend sends
/// to it with `Message.setFid()`.
class AndroidPushTokenSource implements PushTokenSource {
  /// How long [getToken] waits for `onRegistered` after `register()`. The
  /// registration is a network round trip to FCM; on timeout the caller
  /// simply retries on the next cold start, like a denied permission.
  static const registrationTimeout = Duration(seconds: 30);

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
    final messaging = FirebaseMessaging.instance;
    final settings = await messaging.requestPermission();
    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      return null;
    }

    // Subscribe before register() so the FID it reports can't be missed. The
    // plugin backs onRegistered with a LiveData, so a FID already reported in
    // this process is replayed to a new listener as well.
    final fid = messaging.onRegistered.first.timeout(registrationTimeout);
    try {
      await messaging.register();
    } catch (_) {
      fid.ignore(); // don't leave the pending wait as an unhandled error
      rethrow;
    }
    try {
      return await fid;
    } on TimeoutException {
      return null;
    }
  }

  @override
  Stream<String> get onTokenRefreshed {
    if (!Platform.isAndroid) return const Stream.empty();
    // Firebase must already be initialized by the time anything subscribes —
    // callers are expected to have called getToken() first (the normal
    // registration flow always does). A re-registration under a new FID
    // arrives here, the FID equivalent of the old onTokenRefresh.
    return FirebaseMessaging.instance.onRegistered;
  }
}
