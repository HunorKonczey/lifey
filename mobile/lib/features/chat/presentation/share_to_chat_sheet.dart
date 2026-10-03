import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/error_message.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/ds/lifey_sheet.dart';
import '../../settings/application/settings_controller.dart';
import '../../settings/domain/user_settings.dart';
import '../application/chat_share.dart';
import '../domain/chat_card.dart';
import 'widgets/chat_avatar.dart';
import 'widgets/chat_card_view.dart';

/// Previews a result card, takes an optional note and sends it to the chosen
/// thread (docs/chat/83-chat-result-card-plan.md §4).
///
/// Shows the card as it will arrive; asks *who* only when there is more than
/// one person (the newest thread is preselected); and on success closes
/// itself, then confirms on the **caller's** snackbar with a way into the
/// thread — the sheet's own context is gone by then.
///
/// [resolveSessionId] fills in the session's server id at send time when the
/// card was built before the session had synced (§2.6).
Future<void> showShareToChatSheet(
  BuildContext context, {
  required ChatCard card,
  Future<int?> Function()? resolveSessionId,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final sent = await showLifeySheet<({ChatShareTarget target, int conversationId})>(
    context: context,
    title: l10n.shareToChatTitle,
    useRootNavigator: true,
    builder: (_) => ShareToChatSheet(card: card, resolveSessionId: resolveSessionId),
  );
  if (sent == null || !context.mounted) return;
  AppSnackbar.showSuccess(
    context,
    title: l10n.shareToChatSent(sent.target.peer.displayName),
    actionLabel: l10n.shareToChatOpenChat,
    onAction: () => context.push('/chat/${sent.conversationId}'),
  );
}

class ShareToChatSheet extends ConsumerStatefulWidget {
  const ShareToChatSheet({super.key, required this.card, this.resolveSessionId});

  final ChatCard card;
  final Future<int?> Function()? resolveSessionId;

  @override
  ConsumerState<ShareToChatSheet> createState() => _ShareToChatSheetState();
}

class _ShareToChatSheetState extends ConsumerState<ShareToChatSheet> {
  final _caption = TextEditingController();
  int _selected = 0;
  bool _sending = false;

  /// What the body of a card note allows; the server's own bound is far higher,
  /// this is only about a caption staying a caption.
  static const _captionMax = 280;

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  Future<void> _send(List<ChatShareTarget> targets) async {
    if (_sending) return;
    final target = targets[_selected.clamp(0, targets.length - 1)];
    setState(() => _sending = true);
    try {
      final conversationId = await ref.read(chatShareServiceProvider).share(
            target: target,
            card: widget.card,
            caption: _caption.text,
            resolveSessionId: widget.resolveSessionId,
          );
      if (mounted) Navigator.of(context).pop((target: target, conversationId: conversationId));
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      AppSnackbar.showError(context, title: friendlyError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    final targets = ref.watch(chatShareTargetsProvider);
    final unitSystem = ref.watch(settingsControllerProvider).value?.unitSystem ?? UnitSystem.metric;

    return targets.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.s24),
        child: Center(child: CircularProgressIndicator()),
      ),
      // An unreadable target list is the same as having nobody to send to: the
      // entry points hide themselves for it, so this is only a race.
      error: (_, __) => const SizedBox.shrink(),
      data: (list) {
        if (list.isEmpty) return const SizedBox.shrink();
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: ChatCardView(card: widget.card, isOwn: true, unitSystem: unitSystem),
            ),
            const SizedBox(height: AppSpacing.s16),
            TextField(
              controller: _caption,
              maxLength: _captionMax,
              maxLines: 2,
              minLines: 1,
              textInputAction: TextInputAction.done,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(hintText: l10n.shareToChatNoteHint, counterText: ''),
            ),
            if (list.length > 1) ...[
              const SizedBox(height: AppSpacing.s16),
              Text(
                l10n.shareToChatPickPeer,
                style: t.labelLarge!.copyWith(fontWeight: FontWeight.w700, color: p.text2),
              ),
              const SizedBox(height: AppSpacing.s4),
              RadioGroup<int>(
                groupValue: _selected,
                onChanged: (value) => setState(() => _selected = value ?? 0),
                child: Column(
                  children: [
                    for (var i = 0; i < list.length; i++)
                      RadioListTile<int>(
                        value: i,
                        contentPadding: EdgeInsets.zero,
                        secondary: ChatAvatar(
                          monogram: list[i].peer.monogram,
                          userId: list[i].peer.userId,
                          size: 40,
                        ),
                        title: Text(list[i].peer.displayName),
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.s20),
            SizedBox(
              height: 56,
              child: FilledButton(
                onPressed: _sending ? null : () => _send(list),
                child: _sending
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                    : Text(l10n.shareToChatSend),
              ),
            ),
          ],
        );
      },
    );
  }
}
