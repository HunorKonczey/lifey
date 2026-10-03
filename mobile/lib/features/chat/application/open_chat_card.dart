import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/error_message.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../trainer/client_detail/application/client_sessions_controller.dart';
import '../../trainer/client_detail/presentation/widgets/session_detail_sheet.dart';
import '../../workouts/data/workout_session_repository.dart';
import '../../workouts/presentation/open_workout_screens.dart';
import '../domain/chat_card.dart';
import '../domain/chat_peer.dart';

/// Whether a tap on [card] has anywhere to go
/// (docs/chat/83-chat-result-card-plan.md §2.7).
///
/// Decided from what the tapper already holds, never by the chat service: the
/// card has to point at a session (it did not sync before sending otherwise),
/// and either the tapper sent it (their own session) or the sender is their
/// client (the trainer's read). A card from one's own trainer is a snapshot,
/// not a door into the trainer's data.
bool canOpenChatCard({
  required ChatCard card,
  required bool isOwn,
  required ChatPeerRole peerRole,
}) {
  if (card is UnknownChatCard || card.sessionId == null) return false;
  return isOwn || peerRole == ChatPeerRole.client;
}

/// Opens the session behind [card]: the owner's own session screen, or the
/// trainer's detail sheet for [peerUserId] (the client who sent it).
///
/// A session that is gone — deleted since, or never on this device — answers
/// with a plain snackbar: the card stays readable as a snapshot, and a stale
/// card is a normal outcome, not an error (§7).
Future<void> openChatCard(
  BuildContext context,
  WidgetRef ref, {
  required ChatCard card,
  required bool isOwn,
  required int peerUserId,
}) async {
  final sessionId = card.sessionId;
  if (sessionId == null) return;
  final l10n = AppLocalizations.of(context)!;

  if (isOwn) {
    final session = await ref.read(workoutSessionRepositoryProvider).findByServerId(sessionId);
    if (!context.mounted) return;
    if (session == null) {
      AppSnackbar.showInfo(context, title: l10n.chatCardUnavailable);
      return;
    }
    await openSessionScreen(Navigator.of(context, rootNavigator: true), session);
    return;
  }

  try {
    final session = await ref
        .read(clientSessionsControllerProvider(peerUserId).notifier)
        .openById(sessionId);
    if (!context.mounted) return;
    await SessionDetailSheet.show(context, clientId: peerUserId, session: session);
  } on DioException catch (e) {
    if (!context.mounted) return;
    AppSnackbar.showInfo(
      context,
      title: e.response?.statusCode == 404 ? l10n.chatCardUnavailable : friendlyError(e),
    );
  }
}
