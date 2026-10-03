import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/chat_share.dart';
import '../../domain/chat_card.dart';
import '../share_to_chat_sheet.dart';

/// Whether there is anyone to share with — and, until that is known, no.
///
/// The entry points hide their button instead of disabling it: a greyed-out
/// "Share" that can never be pressed (a user with no trainer) is clutter, not
/// information (docs/chat/83-chat-result-card-plan.md §1.2).
bool _canShare(WidgetRef ref) => ref.watch(chatShareTargetsProvider).value?.isNotEmpty ?? false;

/// The header action of a finished-session screen: a share icon that opens
/// [showShareToChatSheet] with a card built **when pressed**, so it reflects the
/// screen's numbers at that moment rather than at build time.
class ShareToChatIconButton extends ConsumerWidget {
  const ShareToChatIconButton({
    super.key,
    required this.buildCard,
    this.resolveSessionId,
    this.tooltip,
  });

  final ChatCard Function() buildCard;
  final Future<int?> Function()? resolveSessionId;

  /// Defaults to "Share in chat"; the record rows pass their own wording.
  final String? tooltip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!_canShare(ref)) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;
    return IconButton(
      onPressed: () => showShareToChatSheet(
        context,
        card: buildCard(),
        resolveSessionId: resolveSessionId,
      ),
      tooltip: tooltip ?? l10n.shareInChatButton,
      icon: Icon(Icons.ios_share_rounded, size: 22, color: context.palette.text2),
    );
  }
}

/// The labelled button for the end-of-workout sheet.
class ShareToChatButton extends ConsumerWidget {
  const ShareToChatButton({super.key, required this.buildCard, this.resolveSessionId});

  final ChatCard Function() buildCard;
  final Future<int?> Function()? resolveSessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!_canShare(ref)) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;
    return SizedBox(
      height: 56,
      child: OutlinedButton.icon(
        onPressed: () => showShareToChatSheet(
          context,
          card: buildCard(),
          resolveSessionId: resolveSessionId,
        ),
        icon: const Icon(Icons.ios_share_rounded, size: 20),
        label: Text(l10n.shareInChatButton),
      ),
    );
  }
}
