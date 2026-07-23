import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/health/health_controller.dart';
import '../../../core/health/health_preferences.dart';
import '../../../core/local_db/database_provider.dart';
import '../../../core/music/music_controller.dart';
import '../../../core/music/music_preferences.dart';
import '../../../core/network/session_events.dart';
import '../../../core/notifications/notification_service.dart';
import '../../../core/push/push_token_registrar.dart';
import '../../../core/push/weigh_in_reminder_preferences.dart';
import '../../../core/storage/token_storage.dart';
import '../../../core/sync/connectivity_sync_controller.dart';
import '../../my_trainers/application/my_trainers_controller.dart';
import '../../recipes/data/recipe_image_repository.dart';
import '../../settings/application/avatar_controller.dart';
import '../../settings/data/avatar_repository.dart';
import '../../trainer_invite/application/trainer_invite_controller.dart';
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
    // Cold start while already signed in — (re-)registers the push token,
    // e.g. after an APNs/FCM rotation that happened while the app was closed.
    unawaited(ref.read(pushTokenRegistrarProvider).register());
    return AuthUser.fromAccessToken(accessToken);
  }

  Future<void> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
  }) async {
    await _repo.register(email: email, password: password, firstName: firstName, lastName: lastName);
    await login(email: email, password: password);
  }

  Future<void> login({required String email, required String password}) async {
    final tokens = await _repo.login(email: email, password: password);
    await _storage.save(accessToken: tokens.accessToken, refreshToken: tokens.refreshToken);
    state = AsyncValue.data(AuthUser.fromAccessToken(tokens.accessToken));
    unawaited(ref.read(pushTokenRegistrarProvider).register());
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
    unawaited(ref.read(pushTokenRegistrarProvider).register());
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
    // Must run before storage.clear() below — the DELETE call needs the
    // still-valid access token to identify the caller.
    await ref.read(pushTokenRegistrarProvider).unregister();
    await _storage.clear();
    // Wipe the offline cache too, so a different account signing in on this
    // device doesn't inherit this account's settings, weight, meals, etc.
    await ref.read(appDatabaseProvider).clearAllData();
    await ref.read(healthPreferencesProvider).clear();
    // Same reasoning as healthPreferences.clear() above — a device-local
    // notification schedule shouldn't carry over to whoever logs in next.
    await NotificationService.cancelWeighInReminder();
    await ref.read(weighInReminderPreferencesProvider).clear();
    // Same "fresh start for whoever logs in next" policy as the two clears
    // above, even though the choice itself is device-local rather than
    // account-specific (docs/music/46-workout-music-controls-plan.md §3.1).
    await ref.read(musicPreferencesProvider).clear();
    await ref.read(avatarRepositoryProvider).clearCache();
    await ref.read(recipeImageRepositoryProvider).clearCache();
    // clearCache()/clear() above only wipe on-disk/secure storage; these
    // controllers (not autoDispose) would otherwise keep serving this
    // account's data to whichever account signs in next in the same app
    // session.
    ref.invalidate(avatarControllerProvider);
    ref.invalidate(myTrainersControllerProvider);
    ref.invalidate(trainerInviteControllerProvider);
    ref.invalidate(healthControllerProvider);
    ref.invalidate(musicControllerProvider);
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
