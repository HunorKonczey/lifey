import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'google_auth_config.dart';

/// Thin wrapper around google_sign_in v7's singleton API. Initialization
/// happens lazily on first use rather than at app startup, since sign-in
/// isn't needed until the user taps "Continue with Google".
class GoogleAuthService {
  bool _initialized = false;

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    await GoogleSignIn.instance.initialize(
      // Android doesn't take a `clientId` (it's matched by package name +
      // signing SHA-1 registered in the Console) — passing one anyway is a
      // clientConfigurationError that the Credential Manager surfaces as a
      // plain "canceled" result right after account selection, with no
      // visible error screen, per google_sign_in_android's troubleshooting
      // notes. Only iOS needs its own client id here.
      clientId: (!kIsWeb && Platform.isIOS) ? GoogleAuthConfig.iosClientId : null,
      serverClientId: GoogleAuthConfig.serverClientId,
    );
    _initialized = true;
  }

  /// Runs the interactive Google sign-in flow and returns the ID token to
  /// exchange at `/auth/social/google`, or null if the user cancelled.
  Future<String?> signIn() async {
    await _ensureInitialized();
    try {
      final account = await GoogleSignIn.instance.authenticate();
      return account.authentication.idToken;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      rethrow;
    }
  }

  /// Best-effort — clears the native SDK's cached account so the next sign-in
  /// prompts for an account again instead of silently reusing this one.
  Future<void> signOut() async {
    if (!_initialized) return;
    await GoogleSignIn.instance.signOut();
  }
}

final googleAuthServiceProvider = Provider<GoogleAuthService>((ref) {
  return GoogleAuthService();
});
