import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/application/auth_controller.dart';

/// Roles of the signed-in user, straight from the access token's `roles`
/// claim (see `AuthUser.fromAccessToken`) — no extra endpoint, no profile
/// call (docs/chat/40-trainer-chat-plan.md §6.1).
final currentRolesProvider = Provider<List<String>>((ref) {
  return ref.watch(authControllerProvider).value?.roles ?? const [];
});

/// Whether the signed-in user can coach someone.
///
/// This is deliberately *not* exclusive: a trainer is also a `ROLE_USER` with
/// their own workout log, and may well have a trainer of their own. So this
/// answers "can they act as a trainer", never "are they a trainer instead of
/// a client" — the chat screens branch on it in exactly three places (list
/// header, "new conversation" button, empty-state copy) and are otherwise
/// role-agnostic.
final isTrainerProvider = Provider<bool>((ref) {
  return ref.watch(currentRolesProvider).contains('ROLE_TRAINER');
});

/// The signed-in user's own id — which side of a thread "me" is on.
final currentUserIdProvider = Provider<int?>((ref) {
  return ref.watch(authControllerProvider).value?.id;
});
