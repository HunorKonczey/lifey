import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/health/health_preferences.dart';
import '../../../core/local_db/database_provider.dart';
import '../../../core/network/session_events.dart';
import '../../../core/storage/token_storage.dart';
import '../../../core/sync/connectivity_sync_controller.dart';
import '../../settings/application/avatar_controller.dart';
import '../../settings/data/avatar_repository.dart';
import '../data/auth_repository.dart';
import '../data/google_auth_service.dart';
import '../domain/auth_user.dart';

/// Holds the signed-in user (or null when logged out) and drives login,
/// register, and logout. The app router redirects based on this state.
class AuthController extends AsyncNotifier<AuthUser?> {
  AuthRepository get _repo => ref.read(authRepositoryProvider);
  TokenStorage get _storage => ref.read(tokenStorageProvider);
  GoogleAuthService get _googleAuth => ref.read(googleAuthServiceProvider);

  @override
  Future<AuthUser?> build() async {
    // The auth interceptor clears storage itself before firing this; we just
    // need to drop the in-memory signed-in state to match.
    ref.listen(sessionExpiredProvider, (_, __) {
      state = const AsyncValue.data(null);
    });

    final accessToken = await _storage.readAccessToken();
    if (accessToken == null) return null;
    return AuthUser.fromAccessToken(accessToken);
  }

  Future<void> register({required String email, required String password}) async {
    await _repo.register(email: email, password: password);
    await login(email: email, password: password);
  }

  Future<void> login({required String email, required String password}) async {
    final tokens = await _repo.login(email: email, password: password);
    await _storage.save(accessToken: tokens.accessToken, refreshToken: tokens.refreshToken);
    state = AsyncValue.data(AuthUser.fromAccessToken(tokens.accessToken));
    // Sign-in doesn't itself trigger a connectivity-restore or app-resume
    // event, so kick off the initial pull explicitly instead of waiting for
    // one of those triggers (or the 60s timer) to happen to fire.
    unawaited(ref.read(connectivitySyncControllerProvider).refreshNow());
  }

  /// Runs the native Google sign-in flow and exchanges the ID token for our
  /// own token pair. Returns false without side effects if the user cancels
  /// the account picker, so the caller can show a distinct message for that.
  Future<bool> loginWithGoogle() async {
    final idToken = await _googleAuth.signIn();
    if (idToken == null) return false;

    final tokens = await _repo.loginWithGoogle(idToken);
    await _storage.save(accessToken: tokens.accessToken, refreshToken: tokens.refreshToken);
    state = AsyncValue.data(AuthUser.fromAccessToken(tokens.accessToken));
    unawaited(ref.read(connectivitySyncControllerProvider).refreshNow());
    // The backend imports the Google picture asynchronously after this call
    // already returned, so an immediate refetch can still race it and cache
    // a "no avatar" result. Refetch once now and once more after a delay to
    // pick up the import once it lands.
    ref.invalidate(avatarControllerProvider);
    unawaited(
      Future.delayed(const Duration(seconds: 3), () {
        if (ref.exists(avatarControllerProvider)) {
          ref.invalidate(avatarControllerProvider);
        }
      }),
    );
    return true;
  }

  Future<void> forgotPassword(String email) => _repo.forgotPassword(email);

  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) =>
      _repo.resetPassword(email: email, code: code, newPassword: newPassword);

  /// Verifies the current password, sets the new one, and — since the backend
  /// revokes every refresh token on change — applies the fresh pair it returns
  /// so this device stays signed in without a full re-login.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final tokens = await _repo.changePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
    );
    await _storage.save(accessToken: tokens.accessToken, refreshToken: tokens.refreshToken);
    state = AsyncValue.data(AuthUser.fromAccessToken(tokens.accessToken));
  }

  Future<void> logout() async {
    final refreshToken = await _storage.readRefreshToken();
    await _storage.clear();
    // Wipe the offline cache too, so a different account signing in on this
    // device doesn't inherit this account's settings, weight, meals, etc.
    await ref.read(appDatabaseProvider).clearAllData();
    await ref.read(healthPreferencesProvider).clear();
    await ref.read(avatarRepositoryProvider).clearCache();
    state = const AsyncValue.data(null);
    if (refreshToken != null) {
      try {
        await _repo.logout(refreshToken);
      } catch (_) {
        // Best-effort: the token is already gone client-side either way.
      }
    }
    try {
      await _googleAuth.signOut();
    } catch (_) {
      // Best-effort: doesn't affect our own session either way.
    }
  }
}

final authControllerProvider =
    AsyncNotifierProvider<AuthController, AuthUser?>(AuthController.new);
