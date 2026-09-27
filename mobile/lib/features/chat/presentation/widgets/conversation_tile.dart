import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/ds/tinted_chip.dart';
import '../../domain/chat_conversation.dart';
import '../../domain/chat_peer.dart';
import 'chat_avatar.dart';

/// One row of the conversation list.
///
/// An unread row is emphasised with **weight and the accent dot only** — no
/// separate background. Ten unread rows with their own fill would read as an
/// alert state rather than a list.
class ConversationTile extends StatelessWidget {
  const ConversationTile({
    super.key,
    required this.conversation,
    required this.isOwnLastMessage,
    required this.showRoleLabel,
    required this.onTap,
  });

  final ChatConversation conversation;

  /// Prefixes the preview with "You: " so a row doesn't look like the peer
  /// wrote what you last said.
  final bool isOwnLastMessage;

  /// Only true on a *mixed* list (a trainer who also has a trainer of their
  /// own). On a uniform list the label would be noise on every row.
  final bool showRoleLabel;

  final VoidCallback onTap;

  String _timeLabel(BuildContext context) {
    final at = conversation.lastMessageAt;
    if (at == null) return '';
    final locale = Localizations.localeOf(context).languageCode;
    final now = DateTime.now();
    final sameDay = at.year == now.year && at.month == now.month && at.day == now.day;
    if (sameDay) return DateFormat.Hm(locale).format(at);
    if (now.difference(at).inDays < 7) return DateFormat.E(locale).format(at);
    return DateFormat.MMMd(locale).format(at);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context)!;
    final unread = conversation.hasUnread;
    final archived = conversation.isArchived;

    final ownPrefix = isOwnLastMessage ? l10n.chatOwnMessagePrefix : '';
    // Three cases share a null preview: no messages yet, a tombstone, and a
    // picture sent without a caption — only the attachment flag separates the
    // last one from the tombstone.
    final String preview;
    if (conversation.lastMessageHasAttachment) {
      final caption = conversation.lastMessagePreview;
      preview = '$ownPrefix${l10n.chatImagePreview}'
          '${caption == null || caption.isEmpty ? '' : ' $caption'}';
    } else if (conversation.lastMessagePreview == null) {
      preview = conversation.lastMessageAt == null ? '' : l10n.chatDeletedMessage;
    } else {
      preview = '$ownPrefix${conversation.lastMessagePreview}';
    }

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s12),
        child: Row(
          children: [
            ChatAvatar(
              monogram: conversation.peer.monogram,
              userId: conversation.peer.userId,
              size: 48,
            ),
            const SizedBox(width: AppSpacing.s16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // A Wrap, not a Row: at large text the name and its labels
                  // (role, archived, muted) go onto a second line instead of
                  // running out of the row.
                  Wrap(
                    spacing: AppSpacing.s8,
                    runSpacing: AppSpacing.s4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        conversation.peer.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.titleMedium!.copyWith(
                          fontWeight: unread ? FontWeight.w800 : FontWeight.w700,
                          // An archived thread is still readable, just visibly
                          // past — a quieter tier, not an alpha.
                          color: archived ? p.text2 : p.text,
                        ),
                      ),
                      if (showRoleLabel) _RoleLabel(role: conversation.peer.role),
                      if (archived) TintedChip(label: l10n.chatArchivedLabel, color: p.text2),
                      // A muted thread still shows its unread dot — the mute
                      // silences the notification, not the count.
                      if (conversation.isMuted && !archived)
                        Icon(Icons.notifications_off, size: 16, color: p.text3, semanticLabel: l10n.chatMutedLabel),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    preview,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.bodyMedium!.copyWith(
                      fontWeight: unread ? FontWeight.w600 : FontWeight.w500,
                      color: archived ? p.text3 : (unread ? p.text : p.text2),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.s12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _timeLabel(context),
                  style: t.bodySmall!.copyWith(
                    fontWeight: unread ? FontWeight.w700 : FontWeight.w500,
                    color: unread ? scheme.primary : p.text3,
                  ),
                ),
                const SizedBox(height: 6),
                if (unread)
                  Container(width: 10, height: 10, decoration: BoxDecoration(color: scheme.primary, shape: BoxShape.circle))
                else
                  const SizedBox(height: 10),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// "YOUR TRAINER" / "YOUR CLIENT". Text, never a colour code — the design is
/// explicit that colour must not be what distinguishes the two.
class _RoleLabel extends StatelessWidget {
  const _RoleLabel({required this.role});

  final ChatPeerRole role;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return TintedChip(
      label: role == ChatPeerRole.trainer ? l10n.chatPeerRoleTrainerLabel : l10n.chatPeerRoleClientLabel,
      color: context.palette.text2,
    );
  }
}
