/// Abstraction over "get a push token for this device" so the shared
/// registration logic (docs/30-push-notifications-plan.md, M2) doesn't need
/// to know whether it's talking to APNs (iOS, via the native `lifey/push`
/// channel) or FCM (Android, via [AndroidPushTokenSource]).
abstract class PushTokenSource {
  /// `"IOS"` or `"ANDROID"` — sent as-is as the `platform` field of
  /// `PUT /api/v1/push/devices`.
  String get platform;

  /// Requests notification permission if needed, then returns the current
  /// push token — or `null` if permission was denied (or the platform isn't
  /// supported by this source). No nag UI on denial; the caller should just
  /// retry on the next cold start.
  Future<String?> getToken();

  /// Emits a new token whenever the provider rotates it out from under the
  /// app (e.g. FCM's `onTokenRefresh`). Not every source necessarily rotates
  /// independently of [getToken] — an empty stream is a valid implementation.
  Stream<String> get onTokenRefreshed;
}
