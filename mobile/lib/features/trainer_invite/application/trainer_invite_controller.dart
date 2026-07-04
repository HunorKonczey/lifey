import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/trainer_invite_repository.dart';
import '../domain/trainer_invite.dart';

/// Pending trainer invites for the current user, refreshed on app start and
/// on foreground resume (see docs/personal_trainer/05-mobil-terv.md §1) —
/// there's no push infrastructure, so this is the entire "notification".
class TrainerInviteController extends AsyncNotifier<List<TrainerInvite>>
    with WidgetsBindingObserver {
  TrainerInviteRepository get _repo => ref.read(trainerInviteRepositoryProvider);

  @override
  Future<List<TrainerInvite>> build() async {
    WidgetsBinding.instance.addObserver(this);
    ref.onDispose(() => WidgetsBinding.instance.removeObserver(this));
    return _repo.fetchPending();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(refresh());
    }
  }

  Future<void> refresh() async {
    // Offline/failed refreshes stay silent — the invite is valid for 24h, so
    // it'll simply be picked up on the next successful poll.
    try {
      state = AsyncData(await _repo.fetchPending());
    } catch (_) {
      // keep showing whatever we had
    }
  }

  Future<void> respond(int inviteId, {required bool accept}) async {
    await _repo.respond(inviteId, accept: accept);
    final current = state.value ?? [];
    state = AsyncData(current.where((invite) => invite.id != inviteId).toList());
  }
}

final trainerInviteControllerProvider =
    AsyncNotifierProvider<TrainerInviteController, List<TrainerInvite>>(
  TrainerInviteController.new,
);
