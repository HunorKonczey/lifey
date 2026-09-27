import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/trainer_client.dart';

/// What the trainer typed into the tablet list pane's "Search clients" field
/// (canvas Lifey 6 › Trainer tablet). Empty means no filter.
///
/// Only the two-pane layout shows the field, and the query is deliberately not
/// persisted: a filter left over from yesterday would hide clients behind a
/// box the trainer has forgotten typing into.
class ClientSearchController extends Notifier<String> {
  @override
  String build() => '';

  void set(String query) => state = query;

  void clear() => state = '';
}

final clientSearchControllerProvider =
    NotifierProvider<ClientSearchController, String>(ClientSearchController.new);

/// The clients whose name or email contains [query], case-insensitively and
/// ignoring the Hungarian accents ("szabo" finds "Szabó"). A blank query keeps
/// everyone, in the order given.
List<TrainerClient> filterClients(List<TrainerClient> clients, String query) {
  final needle = _fold(query.trim());
  if (needle.isEmpty) return clients;
  return [
    for (final client in clients)
      if (_fold(client.displayName).contains(needle) || _fold(client.email).contains(needle)) client,
  ];
}

const _accents = {
  'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ö': 'o', 'ő': 'o', 'ú': 'u', 'ü': 'u', 'ű': 'u',
};

String _fold(String text) {
  final lower = text.toLowerCase();
  final out = StringBuffer();
  for (final rune in lower.runes) {
    final ch = String.fromCharCode(rune);
    out.write(_accents[ch] ?? ch);
  }
  return out.toString();
}
