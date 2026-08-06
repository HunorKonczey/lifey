import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../../../l10n/app_localizations.dart';
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
    final l10n = AppLocalizations.of(context)!;
    final unread = conversation.hasUnread;
    final archived = conversation.isArchived;

    final preview = conversation.lastMessagePreview == null
        ? (conversation.lastMessageAt == null ? '' : l10n.chatDeletedMessage)
        : '${isOwnLastMessage ? l10n.chatOwnMessagePrefix : ''}${conversation.lastMessagePreview}';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.input),
        child: Opacity(
          // An archived thread is still readable, just visibly past.
          opacity: archived ? 0.6 : 1,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Row(
              children: [
                ChatAvatar(monogram: conversation.peer.monogram),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              conversation.peer.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 14.5,
                                fontWeight: unread ? FontWeight.w800 : FontWeight.w600,
                                color: scheme.onSurface,
                              ),
                            ),
                          ),
                          if (showRoleLabel) ...[
                            const SizedBox(width: 6),
                            _RoleLabel(role: conversation.peer.role),
                          ],
                          if (archived) ...[
                            const SizedBox(width: 6),
                            _MetaChip(label: l10n.chatArchivedLabel),
                          ],
                          // A muted thread still shows its unread dot — the
                          // mute silences the notification, not the count.
                          if (conversation.isMuted && !archived) ...[
                            const SizedBox(width: 6),
                            Icon(
                              Icons.notifications_off,
                              size: 14,
                              color: scheme.onSurfaceVariant,
                              semanticLabel: l10n.chatMutedLabel,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        preview,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 12.5,
                          fontWeight: unread ? FontWeight.w600 : FontWeight.w500,
                          color: unread ? scheme.onSurface : scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _timeLabel(context),
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 11,
                        fontWeight: unread ? FontWeight.w700 : FontWeight.w500,
                        color: unread ? scheme.primary : scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (unread)
                      Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          color: scheme.primary,
                          shape: BoxShape.circle,
                        ),
                      )
                    else
                      const SizedBox(height: 9),
                  ],
                ),
              ],
            ),
          ),
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
    return _MetaChip(
      label: role == ChatPeerRole.trainer
          ? l10n.chatPeerRoleTrainerLabel
          : l10n.chatPeerRoleClientLabel,
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'PlusJakartaSans',
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
