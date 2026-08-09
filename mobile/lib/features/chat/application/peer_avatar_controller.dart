import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/peer_avatar_repository.dart';

/// One peer's picture bytes, or null when there is none to show.
///
/// Keyed by user rather than by conversation: the same person appears in a
/// list row, a thread header and every bubble of theirs, and all of those
/// should share one download. Deliberately **not** autoDispose — leaving a
/// thread and coming back is the most common navigation in the chat, and a
/// re-fetch (even a 304) on every return would be visible as a flicker.
final peerAvatarProvider = FutureProvider.family<Uint8List?, int>((ref, userId) {
  return ref.watch(peerAvatarRepositoryProvider).fetch(userId);
});
