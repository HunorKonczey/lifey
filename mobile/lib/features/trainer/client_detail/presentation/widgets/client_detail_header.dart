import 'package:flutter/material.dart';

import '../../../../../core/format/lifey_format.dart';
import '../../../../../core/theme/app_tokens.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../../shared/widgets/ds/lifey_header.dart';
import '../../../clients/domain/trainer_client.dart';
import '../../../shared/client_avatar.dart';
import 'client_action_bar.dart';

/// The client detail screen's header (canvas Lifey 6, client overview): the
/// subpage header — round back button, the client's monogram, their name over
/// "Client since 24 Sep 2026", and a ⋮ menu — as a drop-in `Scaffold.appBar`.
///
/// The one screen that is about this person and nobody else, so it is where
/// their face belongs ([ClientAvatar.showPhoto]). Messaging and scheduling are
/// buttons under the tabs, not in here; the menu keeps the quieter way to the
/// chat.
class ClientDetailHeader extends StatelessWidget implements PreferredSizeWidget {
  const ClientDetailHeader({
    super.key,
    required this.client,
    required this.onMessage,
    this.showBack = true,
    this.openingChat = false,
  });

  final TrainerClient client;

  /// Opens the chat with this client.
  final VoidCallback onMessage;

  /// False in the tablet layout's detail pane, where nothing was pushed.
  final bool showBack;

  /// The chat is being opened: the menu button gives way to a spinner so a
  /// second tap cannot start a second conversation.
  final bool openingChat;

  @override
  Size get preferredSize => const LifeySubpageHeader(title: '').preferredSize;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final p = context.palette;

    return LifeySubpageHeader(
      title: client.displayName,
      subtitle: l10n.trainerClientSinceLabel(
        LifeyFormat.of(context).fullDate(client.activeSince.toLocal()),
      ),
      leading: ClientAvatar(client: client, size: 48, showPhoto: true),
      showBack: showBack,
      actions: [
        if (openingChat)
          const SizedBox.square(
            dimension: 44,
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.s12),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        else
          PopupMenuButton<void>(
            tooltip: l10n.trainerClientActionsTooltip,
            position: PopupMenuPosition.under,
            icon: const Icon(Icons.more_vert_rounded, size: 22),
            style: IconButton.styleFrom(
              fixedSize: const Size.square(44),
              minimumSize: const Size.square(44),
              tapTargetSize: MaterialTapTargetSize.padded,
              backgroundColor: p.nested,
              foregroundColor: p.text,
              shape: const CircleBorder(),
            ),
            itemBuilder: (context) => [
              PopupMenuItem<void>(
                onTap: onMessage,
                child: Row(
                  children: [
                    Icon(Icons.chat_bubble_outline_rounded, size: 20, color: p.text2),
                    const SizedBox(width: AppSpacing.s12),
                    Flexible(child: Text(l10n.trainerMessageClientAction)),
                  ],
                ),
              ),
            ],
          ),
      ],
    );
  }
}

/// The header of the tablet's wide detail pane (canvas Lifey 6 › Trainer
/// tablet): the 56 dp monogram, the name at 26/800 over "Client since …", and
/// Message / Schedule at the right — there is no back button (nothing was
/// pushed) and no ⋮ (the buttons are the menu).
class ClientDetailWideHeader extends StatelessWidget {
  const ClientDetailWideHeader({
    super.key,
    required this.client,
    required this.onMessage,
    required this.onSchedule,
    this.openingChat = false,
  });

  final TrainerClient client;
  final VoidCallback onMessage;
  final VoidCallback onSchedule;
  final bool openingChat;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final t = Theme.of(context).textTheme;
    final p = context.palette;

    return Padding(
      padding: const EdgeInsets.fromLTRB(edge, AppSpacing.s24, edge, AppSpacing.s16),
      child: Row(
        children: [
          ClientAvatar(client: client, size: 56, showPhoto: true),
          const SizedBox(width: 14),
          Expanded(
            child: Semantics(
              header: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(client.displayName, maxLines: 2, overflow: TextOverflow.ellipsis, style: t.headlineSmall!.copyWith(color: p.text)),
                  const SizedBox(height: 2),
                  Text(
                    l10n.trainerClientSinceLabel(LifeyFormat.of(context).fullDate(client.activeSince.toLocal())),
                    style: t.bodyMedium!.copyWith(color: p.text2),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.s16),
          ClientActionButtons(onMessage: onMessage, onSchedule: onSchedule, busy: openingChat, expand: false),
        ],
      ),
    );
  }

  /// The wide pane's side margin (canvas: 32).
  static const double edge = AppSpacing.s32;
}
