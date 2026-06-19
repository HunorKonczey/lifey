import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/session_events.dart';
import '../../../core/storage/token_storage.dart';
import '../data/auth_repository.dart';
import '../domain/auth_user.dart';

/// Holds the signed-in user (or null when logged out) and drives login,
/// register, and logout. The app router redirects based on this state.
class AuthController extends AsyncNotifier<AuthUser?> {
  AuthRepository get _repo => ref.read(authRepositoryProvider);
  TokenStorage get _storage => ref.read(tokenStorageProvider);

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
  }

  Future<void> logout() async {
    final refreshToken = await _storage.readRefreshToken();
    await _storage.clear();
    state = const AsyncValue.data(null);
    if (refreshToken != null) {
      try {
        await _repo.logout(refreshToken);
      } catch (_) {
        // Best-effort: the token is already gone client-side either way.
      }
    }
  }
}

final authControllerProvider =
    AsyncNotifierProvider<AuthController, AuthUser?>(AuthController.new);
