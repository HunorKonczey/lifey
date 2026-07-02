/// Google Sign-In OAuth client IDs for the Google Cloud Console project (see
/// docs/20-social-login-plan.md). These aren't secrets — they're public
/// identifiers baked into every build — but can still be overridden at
/// run/build time without touching this file:
///   flutter run --dart-define=GOOGLE_SERVER_CLIENT_ID=... --dart-define=GOOGLE_IOS_CLIENT_ID=...
/// which is useful when testing against a different Google Cloud project.
class GoogleAuthConfig {
  const GoogleAuthConfig._();

  static const String _serverClientIdOverride =
      String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');
  static const String _iosClientIdOverride =
      String.fromEnvironment('GOOGLE_IOS_CLIENT_ID');

  /// The Web OAuth client. This is what ends up as the Google ID token's
  /// `aud` claim, which is what the backend (`lifey.oauth.google.client-ids`)
  /// verifies — see mobile/README.md for where to get this value.
  static const String _serverClientId =
      '1086901320421-n8uplm3rvqmaq3de8u8mf2ap9c27i6ui.apps.googleusercontent.com';

  /// The iOS OAuth client. Required by the native SDK to drive the sign-in
  /// UI on iOS; unused on Android.
  static const String _iosClientId =
      '1086901320421-qfnu12ba4k4uhf6pl2aanra5pk1rp2la.apps.googleusercontent.com';

  static String get serverClientId =>
      _serverClientIdOverride.isNotEmpty ? _serverClientIdOverride : _serverClientId;

  static String get iosClientId =>
      _iosClientIdOverride.isNotEmpty ? _iosClientIdOverride : _iosClientId;
}
