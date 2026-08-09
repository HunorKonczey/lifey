import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../../l10n/app_localizations.dart';
import '../../domain/chat_message.dart';
import 'chat_attachment_view.dart';
import 'chat_avatar.dart';

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
    required this.showAvatar,
    required this.peerMonogram,
    this.peerUserId,
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

  /// Last message of a same-sender run: the one that shows the time, the
  /// status and the flattened "tail" corner. Consecutive messages group.
  final bool showTail;

  /// Peer-side runs show the avatar once, next to the last bubble.
  final bool showAvatar;
  final String peerMonogram;

  /// Whose picture that avatar shows. Null falls back to the monogram — the
  /// same behaviour as a peer who has no picture set.
  final int? peerUserId;

  final VoidCallback? onRetry;
  final VoidCallback? onDelete;

  static const _radius = 18.0;
  static const _tailRadius = 6.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final isDark = theme.brightness == Brightness.dark;
    final time = DateFormat.Hm(Localizations.localeOf(context).languageCode)
        .format(message.createdAt);

    final bubbleColor = isOwn
        ? scheme.primary.withValues(alpha: isDark ? 0.20 : 0.13)
        : scheme.surfaceContainerHigh;

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
          bottom: showTail ? 8 : 1,
        ),
        child: Row(
          mainAxisAlignment: isOwn ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isOwn)
              SizedBox(
                width: 36,
                child: showAvatar ? ChatAvatar(monogram: peerMonogram, userId: peerUserId, size: 30) : null,
              ),
            Flexible(
              child: GestureDetector(
                onLongPress: message.isDeleted ? null : () => _showActions(context, l10n),
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.sizeOf(context).width * 0.74,
                  ),
                  // A picture wants to fill its bubble, not float in it.
                  padding: message.hasAttachment && !message.isDeleted
                      ? const EdgeInsets.all(4)
                      : const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
                  decoration: BoxDecoration(
                    color: bubbleColor,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(_radius),
                      topRight: const Radius.circular(_radius),
                      // The flattened corner stands in for a drawn tail.
                      bottomLeft: Radius.circular(
                        !isOwn && showTail ? _tailRadius : _radius,
                      ),
                      bottomRight: Radius.circular(
                        isOwn && showTail ? _tailRadius : _radius,
                      ),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _body(context, scheme, l10n),
                      if (showTail) ...[
                        const SizedBox(height: 3),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              time,
                              style: TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 10.5,
                                fontWeight: FontWeight.w500,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                            if (isOwn) ...[
                              const SizedBox(width: 4),
                              _StatusIcon(state: _state),
                            ],
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
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
        style: TextStyle(
          fontFamily: 'PlusJakartaSans',
          fontSize: 14,
          fontStyle: FontStyle.italic,
          color: scheme.onSurfaceVariant,
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
            _text(caption, scheme),
          ],
        ],
      );
    }
    // Plain Text, not SelectableText: on touch both selection and the
    // long-press menu below want the same gesture, and they fight for it.
    // The menu wins because it is what the design specifies, and its "Copy"
    // action covers the same need more reliably than a drag-to-select would
    // inside a 74%-width bubble.
    return _text(message.body ?? '', scheme);
  }

  Widget _text(String value, ColorScheme scheme) {
    return Text(
      value,
      style: TextStyle(
        fontFamily: 'PlusJakartaSans',
        fontSize: 14.5,
        fontWeight: FontWeight.w500,
        height: 1.35,
        color: scheme.onSurface,
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
    final (icon, color) = switch (state) {
      ChatMessageState.pending => (Icons.schedule, scheme.onSurfaceVariant),
      ChatMessageState.sent => (Icons.check, scheme.onSurfaceVariant),
      ChatMessageState.delivered => (Icons.done_all, scheme.onSurfaceVariant),
      // The one state that gets the accent colour — "they've seen it" is the
      // only status worth drawing the eye.
      ChatMessageState.read => (Icons.done_all, scheme.primary),
      ChatMessageState.failed => (Icons.error_outline, scheme.error),
    };
    return Icon(icon, size: 13, color: color);
  }
}
