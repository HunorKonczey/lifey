import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../../core/network/error_message.dart';
import '../../../../../core/theme/app_tokens.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../../shared/widgets/app_snackbar.dart';
import '../../../../chat/data/chat_repository.dart';
import '../../../clients/domain/trainer_client.dart';
import '../../../shared/client_avatar.dart';

/// The client detail screen's header card: who am I looking at, since when,
/// and the one way out of read-only — writing to them (frame C1).
class ClientDetailHeader extends ConsumerStatefulWidget {
  const ClientDetailHeader({super.key, required this.client});

  final TrainerClient client;

  @override
  ConsumerState<ClientDetailHeader> createState() => _ClientDetailHeaderState();
}

class _ClientDetailHeaderState extends ConsumerState<ClientDetailHeader> {
  bool _openingChat = false;

  Future<void> _openChat() async {
    if (_openingChat) return;
    setState(() => _openingChat = true);
    try {
      final conversationId = await ref
          .read(chatRepositoryProvider)
          .openConversationWith(widget.client.userId);
      if (mounted) context.push('/chat/$conversationId');
    } catch (error) {
      if (mounted) AppSnackbar.showError(context, title: friendlyError(error));
    } finally {
      if (mounted) setState(() => _openingChat = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final client = widget.client;
    final dateFormat = DateFormat.yMMMd(Localizations.localeOf(context).toString());

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      padding: const EdgeInsets.fromLTRB(4, 8, 8, 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: AppRadius.cardAll,
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                onPressed: () => context.pop(),
              ),
              const Spacer(),
              if (_openingChat)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else
                PopupMenuButton<void>(
                  tooltip: l10n.trainerClientActionsTooltip,
                  position: PopupMenuPosition.under,
                  icon: const Icon(Icons.more_horiz),
                  itemBuilder: (context) => [
                    PopupMenuItem<void>(
                      onTap: _openChat,
                      child: Row(
                        children: [
                          Icon(Icons.chat_bubble_outline,
                              size: 20, color: scheme.onSurfaceVariant),
                          const SizedBox(width: 12),
                          Text(l10n.trainerMessageClientAction),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                // The one screen that is about this person and nobody else,
                // so it is where their face belongs.
                ClientAvatar(client: client, size: 52, showPhoto: true),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        client.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        client.email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.trainerClientSinceLabel(
                          dateFormat.format(client.activeSince.toLocal()),
                        ),
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
