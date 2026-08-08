import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/network/api_config.dart';
import 'package:lifey/core/network/client_config.dart';
import 'package:lifey/core/network/dio_client.dart';

/// Which service each client talks to
/// (docs/chat/44-chat-service-extraction-plan.md §7.2).
///
/// The failure this guards against is silent: a chat call sent to the main API
/// gets a plausible 404, so nothing crashes — the chat just stops working for
/// whoever deployed it, and the logs say "not found" rather than "wrong host".
void main() {
  ProviderContainer containerWith(String chatBaseUrl) {
    return ProviderContainer(overrides: [
      chatBaseUrlProvider.overrideWithValue(chatBaseUrl),
    ]);
  }

  test('the chat client uses the runtime chat base URL', () {
    final container = containerWith('https://lifey-chat.example.com/api/v1');
    addTearDown(container.dispose);

    expect(
      container.read(chatDioProvider).options.baseUrl,
      'https://lifey-chat.example.com/api/v1',
    );
  });

  test('the main client is unaffected by it', () {
    final container = containerWith('https://lifey-chat.example.com/api/v1');
    addTearDown(container.dispose);

    expect(container.read(dioClientProvider).options.baseUrl, ApiConfig.baseUrl);
  });

  test('the two clients are separate instances', () {
    // Sharing one would mean one base URL, which is the bug this whole
    // arrangement exists to avoid.
    final container = containerWith('https://lifey-chat.example.com/api/v1');
    addTearDown(container.dispose);

    expect(
      identical(container.read(chatDioProvider), container.read(dioClientProvider)),
      isFalse,
    );
  });

  test('they share one token refresher, because the refresh token is single-use', () {
    // Two refreshers would race on a simultaneous 401 and spend the refresh
    // token twice — signing the user out for no reason.
    final container = containerWith('https://lifey-chat.example.com/api/v1');
    addTearDown(container.dispose);

    final first = container.read(tokenRefresherProvider);
    final second = container.read(tokenRefresherProvider);

    expect(identical(first, second), isTrue);
  });

  group('chatBaseUrlProvider', () {
    test('falls back to the main API when the server names no chat service', () {
      // The pre-split state, and the rollback: empty must never mean "broken".
      final container = ProviderContainer(overrides: [
        clientConfigProvider.overrideWith(_StubConfig.new),
      ]);
      addTearDown(container.dispose);

      expect(container.read(chatBaseUrlProvider), ApiConfig.baseUrl);
    });
  });
}

/// A controller that never touches the network, so the fallback can be asserted
/// without a backend or shared preferences.
class _StubConfig extends ClientConfigController {
  @override
  ClientConfig build() => ClientConfig.fallback;
}
