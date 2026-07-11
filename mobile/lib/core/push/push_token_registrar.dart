import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/dio_client.dart';
import 'android_push_token_source.dart';
import 'ios_push_token_source.dart';
import 'push_token_source.dart';

/// Registers this device's push token with the backend
/// (`PUT /api/v1/push/devices`) after login and at cold start while already
/// authenticated, keeps it current across token rotation for the rest of the
/// app session, and unregisters it (`DELETE .../{token}`) on logout — see
/// docs/30-push-notifications-plan.md, M2.
///
/// Never throws: a push-registration hiccup must never break login, cold
/// start, or logout. Every I/O call is wrapped and swallowed internally.
class PushTokenRegistrar {
  PushTokenRegistrar(this._dio, this._tokenSource);

  final Dio _dio;
  final PushTokenSource _tokenSource;

  StreamSubscription<String>? _rotationSubscription;

  /// The token from the most recent successful `PUT` — used by [unregister]
  /// so logout doesn't need a second native/permission round-trip just to
  /// find out what to delete.
  String? _lastRegisteredToken;

  /// Call after login and once at cold start while already authenticated.
  /// Idempotent — re-running just re-`PUT`s (the backend upserts by token).
  Future<void> register() async {
    try {
      final token = await _tokenSource.getToken();
      if (token != null) await _put(token);
      // Subscribe only after getToken(): on Android that call is what
      // initializes Firebase, and onTokenRefreshed touches
      // FirebaseMessaging.instance, which throws [core/no-app] otherwise.
      // Idempotent across repeat calls via the `??=` guard.
      _rotationSubscription ??= _tokenSource.onTokenRefreshed.listen(
        (token) => unawaited(_put(token)),
      );
    } catch (_) {
      // Best-effort — see class doc.
    }
  }

  /// Call on logout, before the auth token is dropped (the request needs it).
  Future<void> unregister() async {
    await _rotationSubscription?.cancel();
    _rotationSubscription = null;

    final token = _lastRegisteredToken;
    _lastRegisteredToken = null;
    if (token == null) return;

    try {
      await _dio.delete('/push/devices/$token');
    } catch (_) {
      // Best-effort: logout must succeed regardless (offline, network error,
      // etc). Leaving the row registered to this user until the next login
      // re-owns it (PushDeviceServiceImpl#register on the backend) is
      // harmless — it can only be re-owned, never leak more than "a
      // notification arrived" to whoever uses the device next.
    }
  }

  Future<void> _put(String token) async {
    try {
      await _dio.put('/push/devices', data: {
        'platform': _tokenSource.platform,
        'token': token,
      });
      _lastRegisteredToken = token;
    } catch (_) {
      // Best-effort — see class doc.
    }
  }
}

PushTokenSource _platformTokenSource() {
  if (Platform.isIOS) return IosPushTokenSource();
  if (Platform.isAndroid) return AndroidPushTokenSource();
  return const _UnsupportedPushTokenSource();
}

/// Desktop/web — push isn't offered there; every call is a no-op.
class _UnsupportedPushTokenSource implements PushTokenSource {
  const _UnsupportedPushTokenSource();

  @override
  String get platform => 'UNKNOWN';

  @override
  Future<String?> getToken() async => null;

  @override
  Stream<String> get onTokenRefreshed => const Stream.empty();
}

final pushTokenRegistrarProvider = Provider<PushTokenRegistrar>((ref) {
  return PushTokenRegistrar(ref.watch(dioClientProvider), _platformTokenSource());
});
