import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/client_detail_tab.dart';

const _keyPrefix = 'trainer.clientDetail.lastTab.';

/// Which tab the trainer last looked at, **per client** (docs/chat/41 T2 —
/// "az utoljára nézett tab megjegyzése kliensenként", as the web does).
///
/// Per client rather than globally on purpose: one client is being watched
/// for their weight, another for whether they eat enough, and coming back to
/// the tab that answers *that* client's question is the whole point.
class ClientDetailTabPreference {
  Future<ClientDetailTab?> lastTabFor(int clientId) async {
    final prefs = await SharedPreferences.getInstance();
    return ClientDetailTab.fromStorageKey(prefs.getString('$_keyPrefix$clientId'));
  }

  Future<void> setLastTab(int clientId, ClientDetailTab tab) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_keyPrefix$clientId', tab.storageKey);
  }

  /// Drops every client's remembered tab — logout, same "fresh start for
  /// whoever signs in next" policy as the other device-local preferences.
  /// These keys are per client id, so they have to be swept, not removed by
  /// name.
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in prefs.getKeys().where((k) => k.startsWith(_keyPrefix))) {
      await prefs.remove(key);
    }
  }
}

final clientDetailTabPreferenceProvider =
    Provider<ClientDetailTabPreference>((ref) => ClientDetailTabPreference());

/// The remembered tab for one client, defaulting to the overview. Read once
/// when the detail screen opens; the screen writes back through
/// [ClientDetailTabPreference] as the trainer switches tabs.
final lastClientDetailTabProvider =
    FutureProvider.family<ClientDetailTab, int>((ref, clientId) async {
  final stored = await ref.watch(clientDetailTabPreferenceProvider).lastTabFor(clientId);
  return stored ?? ClientDetailTab.overview;
});
