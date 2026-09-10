import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../clients/application/trainer_clients_controller.dart';
import '../data/trainer_invites_repository.dart';
import '../domain/sent_invite.dart';

/// Invites this trainer is waiting on.
class TrainerInvitesController extends AsyncNotifier<List<SentInvite>> {
  @override
  Future<List<SentInvite>> build() {
    return ref.read(trainerInvitesRepositoryProvider).findPending();
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(
      () => ref.read(trainerInvitesRepositoryProvider).findPending(),
    );
  }

  /// Sends one. Throws on a rejected address — the form is where that gets
  /// explained, because the reason matters ("already your client" is not the
  /// same problem as a typo).
  Future<void> invite(String email) async {
    await ref.read(trainerInvitesRepositoryProvider).invite(email.trim());
    await refresh();
  }

  Future<void> cancel(int inviteId) async {
    await ref.read(trainerInvitesRepositoryProvider).cancel(inviteId);
    state = AsyncData([
      for (final invite in state.value ?? const <SentInvite>[])
        if (invite.id != inviteId) invite,
    ]);
  }
}

final trainerInvitesControllerProvider =
    AsyncNotifierProvider<TrainerInvitesController, List<SentInvite>>(
  TrainerInvitesController.new,
);

/// Accepting an invite turns the invitee into a client, and the client list is
/// the only place that shows it. Nothing on this device knows when that
/// happens, so the list is re-read whenever the trainer opens the invites
/// screen — cheap, and it keeps the two from disagreeing.
final refreshAfterInvitesProvider = Provider<Future<void> Function()>((ref) {
  return () => ref.read(trainerClientsControllerProvider.notifier).refresh();
});
