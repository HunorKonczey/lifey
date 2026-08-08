import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_config.dart';
import 'dio_client.dart';

/// Runtime configuration handed to the app by the backend
/// (docs/chat/44-chat-service-extraction-plan.md §7.1).
@immutable
class ClientConfig {
  const ClientConfig({required this.chatBaseUrl, required this.ttl});

  /// Empty means "the chat is served by the main API" — the pre-split state,
  /// and the rollback. Never treat empty as an error.
  final String chatBaseUrl;
  final Duration ttl;

  static const fallback = ClientConfig(chatBaseUrl: '', ttl: Duration(hours: 6));

  @override
  bool operator ==(Object other) =>
      other is ClientConfig && other.chatBaseUrl == chatBaseUrl && other.ttl == ttl;

  @override
  int get hashCode => Object.hash(chatBaseUrl, ttl);
}

/// Fetches and caches [ClientConfig].
///
/// **Why the app asks instead of compiling this in.** The API base URL is a
/// compile-time constant ([ApiConfig]), so if the chat service's URL were one
/// too, rolling a bad chat deploy back would mean an App Store review — one to
/// three days, in the middle of the incident. Asking the server turns that into
/// an environment variable.
///
/// Cached in [SharedPreferences] rather than fetched on every launch, so a cold
/// start with no network still knows where the chat is. It is not a secret and
/// it is not user data, which is why plain prefs and not secure storage.
class ClientConfigRepository {
  ClientConfigRepository(this._dio);

  final Dio _dio;

  static const _chatBaseUrlKey = 'clientConfig.chatBaseUrl';
  static const _ttlSecondsKey = 'clientConfig.ttlSeconds';

  Future<ClientConfig> readCached() async {
    final prefs = await SharedPreferences.getInstance();
    final url = prefs.getString(_chatBaseUrlKey);
    if (url == null) return ClientConfig.fallback;
    return ClientConfig(
      chatBaseUrl: url,
      ttl: Duration(seconds: prefs.getInt(_ttlSecondsKey) ?? ClientConfig.fallback.ttl.inSeconds),
    );
  }

  /// Asks the API. **Never throws**: a config endpoint that is down or slow must
  /// not stop the app starting, so a failure keeps whatever was cached.
  Future<ClientConfig> refresh() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/client-config');
      final data = response.data!;
      final config = ClientConfig(
        chatBaseUrl: (data['chatBaseUrl'] as String?) ?? '',
        ttl: Duration(seconds: (data['configTtlSeconds'] as num?)?.toInt() ??
            ClientConfig.fallback.ttl.inSeconds),
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_chatBaseUrlKey, config.chatBaseUrl);
      await prefs.setInt(_ttlSecondsKey, config.ttl.inSeconds);
      return config;
    } catch (_) {
      return readCached();
    }
  }
}

final clientConfigRepositoryProvider = Provider<ClientConfigRepository>((ref) {
  return ClientConfigRepository(ref.watch(dioClientProvider));
});

/// The config the app is currently running on.
///
/// Starts from the cached value so [chatBaseUrlProvider] can be read
/// synchronously while `Dio` clients are built, then refreshes in the
/// background. When the answer changes, everything watching the chat base URL
/// is rebuilt — which is what makes the SSE stream reconnect to the new host
/// without an app restart.
class ClientConfigController extends Notifier<ClientConfig> {
  @override
  ClientConfig build() {
    // Re-asked on every foreground, so a change of chat host — or a rollback —
    // reaches a running app within one resume instead of waiting for the next
    // cold start. Someone who leaves the app open for days would otherwise
    // never see it.
    //
    // The observer lives here rather than on ConnectivitySyncController, which
    // would be the obvious home: that controller (indirectly) watches
    // chatDioProvider, so a config change would rebuild the very object whose
    // resume handler asked for it. This provider depends on nothing that the
    // answer can change, so there is no cycle.
    final listener = _ResumeListener(reload);
    WidgetsBinding.instance.addObserver(listener);
    ref.onDispose(() => WidgetsBinding.instance.removeObserver(listener));

    unawaited(_load());
    return ClientConfig.fallback;
  }

  ClientConfigRepository get _repository => ref.read(clientConfigRepositoryProvider);

  Future<void> _load() async {
    state = await _repository.readCached();
    state = await _repository.refresh();
  }

  /// Re-asks the API. Call on resume, so a change of chat host — or a rollback —
  /// reaches a running app within one foreground cycle rather than at the next
  /// launch.
  Future<void> reload() async {
    state = await _repository.refresh();
  }
}

final clientConfigProvider =
    NotifierProvider<ClientConfigController, ClientConfig>(ClientConfigController.new);

class _ResumeListener extends WidgetsBindingObserver {
  _ResumeListener(this._onResume);

  final Future<void> Function() _onResume;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_onResume());
    }
  }
}

/// Where chat traffic goes.
///
/// Falls back to the main API's base URL whenever the server has not named a
/// chat service — which covers the pre-split state, a rollback, and a
/// config endpoint that could not be reached. The failure direction is
/// deliberate: the worst case is chat requests hitting an API that answers 404,
/// not an app pointing at nothing.
final chatBaseUrlProvider = Provider<String>((ref) {
  final configured = ref.watch(clientConfigProvider).chatBaseUrl;
  return configured.isEmpty ? ApiConfig.baseUrl : configured;
});
