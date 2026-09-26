import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/chat_message.dart';
import 'chat_attachment_view.dart';

/// One message.
///
/// Two things here are load-bearing rather than decorative:
///
/// * **Status is never colour alone.** Each state has its own icon *shape*
///   (clock → check → double check → filled double check → error), and the
///   whole bubble carries a spoken equivalent through [Semantics], because
///   the ticks are the only thing telling a sender their message got through.
/// * **Only our own messages have a status.** Anything received is simply
///   there; a tick on it would be meaningless.
class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.isOwn,
    required this.senderName,
    required this.showTail,
    this.receiptState,
    this.onRetry,
    this.onDelete,
    this.uploadProgress,
  });

  /// 0..1 while this message's picture is uploading; null otherwise.
  final double? uploadProgress;

  final ChatMessage message;
  final bool isOwn;
  final String senderName;

  /// The tick to draw, when the caller knows more than the row does.
  /// `delivered`/`read` are derived from the thread's peer cursors rather than
  /// stored on the message, so a caller without a conversation in hand can
  /// omit this and get the message's own state.
  final ChatMessageState? receiptState;

  ChatMessageState get _state => receiptState ?? message.state;

  /// Last message of a same-sender run: the one that shows the time and the
  /// status under it, and the flattened "tail" corner. Consecutive messages
  /// group.
  final bool showTail;

  final VoidCallback? onRetry;
  final VoidCallback? onDelete;

  static const _tailRadius = 8.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final p = context.palette;
    final t = theme.textTheme;
    final l10n = AppLocalizations.of(context)!;
    final time = DateFormat.Hm(Localizations.localeOf(context).languageCode)
        .format(message.createdAt);
    const radius = AppRadius.card;

    // Own messages are the brand colour with its own "on" text, the peer's the
    // card surface (canvas Lifey 5 › 7).
    final bubbleColor = isOwn ? scheme.primary : p.card;

    return Semantics(
      label: l10n.chatMessageSemantics(
        senderName,
        time,
        message.isDeleted
            ? l10n.chatDeletedMessage
            : _spokenBody(l10n),
        isOwn ? _statusLabel(l10n) : '',
      ),
      excludeSemantics: true,
      child: Padding(
        padding: EdgeInsets.only(
          // Tight inside a run, roomier between runs — the grouping the
          // design asks for is spacing, not a separator.
          top: showTail ? 2 : 1,
          bottom: showTail ? AppSpacing.s12 : 2,
        ),
        child: Column(
          crossAxisAlignment: isOwn ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onLongPress: message.isDeleted ? null : () => _showActions(context, l10n),
              child: Container(
                constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.8),
                // A picture wants to fill its bubble, not float in it.
                padding: message.hasAttachment && !message.isDeleted
                    ? const EdgeInsets.all(AppSpacing.s4)
                    : const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s12),
                decoration: BoxDecoration(
                  color: bubbleColor,
                  border: isOwn ? null : Border.all(color: context.elevation.border),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(radius),
                    topRight: const Radius.circular(radius),
                    // The flattened corner stands in for a drawn tail.
                    bottomLeft: Radius.circular(!isOwn && showTail ? _tailRadius : radius),
                    bottomRight: Radius.circular(isOwn && showTail ? _tailRadius : radius),
                  ),
                ),
                child: _body(context, scheme, l10n),
              ),
            ),
            // Time and receipt sit under the bubble, not inside it.
            if (showTail)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.s4, left: AppSpacing.s4, right: AppSpacing.s4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(time, style: t.bodySmall!.copyWith(color: p.text3)),
                    if (isOwn) ...[
                      const SizedBox(width: AppSpacing.s4),
                      _StatusIcon(state: _state),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _body(BuildContext context, ColorScheme scheme, AppLocalizations l10n) {
    if (message.isDeleted) {
      return Text(
        l10n.chatDeletedMessage,
        style: Theme.of(context).textTheme.bodyMedium!.copyWith(
              fontStyle: FontStyle.italic,
              color: isOwn ? scheme.onPrimary.withValues(alpha: 0.8) : context.palette.text2,
            ),
      );
    }
    if (message.hasAttachment) {
      final caption = message.body;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          ChatAttachmentView(
            message: message,
            uploading: _state == ChatMessageState.pending,
            uploadProgress: uploadProgress,
          ),
          // No empty text row under a caption-less picture — the image is the
          // whole message.
          if (caption != null && caption.isNotEmpty) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12, vertical: AppSpacing.s4),
              child: _text(context, caption, scheme),
            ),
          ],
        ],
      );
    }
    // Plain Text, not SelectableText: on touch both selection and the
    // long-press menu below want the same gesture, and they fight for it.
    // The menu wins because it is what the design specifies, and its "Copy"
    // action covers the same need more reliably than a drag-to-select would
    // inside a 74%-width bubble.
    return _text(context, message.body ?? '', scheme);
  }

  Widget _text(BuildContext context, String value, ColorScheme scheme) {
    return Text(
      value,
      style: Theme.of(context).textTheme.bodyMedium!.copyWith(
            color: isOwn ? scheme.onPrimary : context.palette.text,
          ),
    );
  }

  /// A picture with no caption still has to be announced as something.
  String _spokenBody(AppLocalizations l10n) {
    final body = message.body ?? '';
    if (!message.hasAttachment) return body;
    return body.isEmpty ? l10n.chatImageAlt : '${l10n.chatImageAlt}: $body';
  }

  String _statusLabel(AppLocalizations l10n) {
    return switch (_state) {
      ChatMessageState.pending => l10n.chatStatusPending,
      ChatMessageState.sent => l10n.chatStatusSent,
      ChatMessageState.delivered => l10n.chatStatusDelivered,
      ChatMessageState.read => l10n.chatStatusRead,
      ChatMessageState.failed => l10n.chatStatusFailed,
    };
  }

  Future<void> _showActions(BuildContext context, AppLocalizations l10n) async {
    // The press is what opened this, and a long press has no visual "armed"
    // state to see — the tap that confirms it is the buzz, same as the set
    // logger's long-press actions.
    unawaited(HapticFeedback.mediumImpact());
    final failed = _state == ChatMessageState.failed;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Nothing to copy from a picture with no caption.
            if ((message.body ?? '').isNotEmpty)
              ListTile(
                leading: const Icon(Icons.content_copy),
                title: Text(l10n.chatCopyAction),
                onTap: () async {
                  await Clipboard.setData(ClipboardData(text: message.body!));
                  if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                },
              ),
            // Resend is only meaningful on something that actually failed —
            // shown disabled elsewhere would just be noise.
            if (failed && onRetry != null)
              ListTile(
                leading: const Icon(Icons.refresh),
                title: Text(l10n.chatResendAction),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  onRetry!();
                },
              ),
            if (isOwn && onDelete != null)
              ListTile(
                leading: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
                title: Text(l10n.chatDeleteAction),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  onDelete!();
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _StatusIcon extends StatelessWidget {
  const _StatusIcon({required this.state});

  final ChatMessageState state;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final quiet = context.palette.text3;
    final (icon, color) = switch (state) {
      ChatMessageState.pending => (Icons.schedule, quiet),
      ChatMessageState.sent => (Icons.check, quiet),
      ChatMessageState.delivered => (Icons.done_all, quiet),
      // The one state that gets the accent colour — "they've seen it" is the
      // only status worth drawing the eye.
      ChatMessageState.read => (Icons.done_all, scheme.primary),
      ChatMessageState.failed => (Icons.error_outline, scheme.error),
    };
    return Icon(icon, size: 16, color: color);
  }
}
