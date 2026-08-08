import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../data/chat_repository.dart';
import '../../domain/chat_message.dart';

/// One message's picture inside a bubble.
///
/// The box is sized from the metadata the message already carries, so it is
/// reserved before any bytes arrive — a thread of photos never reflows as they
/// load. While the send is still in flight the local file fills that box
/// directly: there is no message id to fetch with yet, and the picture the
/// sender just picked is the best thing to show them.
class ChatAttachmentView extends ConsumerWidget {
  const ChatAttachmentView({
    super.key,
    required this.message,
    required this.uploading,
    this.uploadProgress,
  });

  final ChatMessage message;
  final bool uploading;

  /// 0..1 while the bytes are going out, null when there is nothing to report.
  final double? uploadProgress;

  static const _maxWidth = 240.0;
  static const _maxHeight = 300.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final size = _boxSize();

    return Semantics(
      label: l10n.chatImageAlt,
      button: message.serverId != null,
      child: GestureDetector(
        onTap: message.serverId == null || uploading
            ? null
            : () => _openFullScreen(context, ref, message.serverId!),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            width: size.width,
            height: size.height,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(color: scheme.surfaceContainerHighest),
                _thumbnail(ref),
                if (uploading)
                  ColoredBox(
                    color: scheme.scrim.withValues(alpha: 0.35),
                    child: Center(
                      child: SizedBox(
                        width: 30,
                        height: 30,
                        child: CircularProgressIndicator(
                          // Determinate once the first chunk has gone out;
                          // indeterminate before that, rather than sitting at
                          // a fake zero.
                          value: uploadProgress,
                          strokeWidth: 2.5,
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Size _boxSize() {
    final attachment = message.attachment;
    if (attachment == null) {
      // Nothing but a local file yet — a square placeholder is the only honest
      // guess, and the image fills it with BoxFit.cover either way.
      return const Size(_maxWidth, _maxWidth);
    }
    final scale = [
      _maxWidth / attachment.width,
      _maxHeight / attachment.height,
      1.0,
    ].reduce((a, b) => a < b ? a : b);
    return Size(attachment.width * scale, attachment.height * scale);
  }

  Widget _thumbnail(WidgetRef ref) {
    final localPath = message.attachmentLocalPath;
    if (localPath != null && File(localPath).existsSync()) {
      return Image.file(File(localPath), fit: BoxFit.cover);
    }
    final serverId = message.serverId;
    if (serverId == null) return const SizedBox.shrink();
    return _RemoteImage(
      load: () => ref.read(chatRepositoryProvider).fetchAttachment(serverId),
      cacheKey: 'thumb-$serverId',
    );
  }

  void _openFullScreen(BuildContext context, WidgetRef ref, int serverId) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => _FullScreenImage(messageId: serverId),
    ));
  }
}

/// Bytes fetched once per widget lifetime; the repository handles the on-disk
/// cache and the ETag, so a second open is a local read at worst.
class _RemoteImage extends StatefulWidget {
  const _RemoteImage({required this.load, required this.cacheKey, this.fit = BoxFit.cover});

  final Future<Uint8List?> Function() load;
  final String cacheKey;
  final BoxFit fit;

  @override
  State<_RemoteImage> createState() => _RemoteImageState();
}

class _RemoteImageState extends State<_RemoteImage> {
  late Future<Uint8List?> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.load();
  }

  @override
  void didUpdateWidget(_RemoteImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cacheKey != widget.cacheKey) _future = widget.load();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: _future,
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        if (bytes == null) {
          // No spinner: the box is already the right shape and colour, and a
          // spinner per bubble in a photo-heavy thread is noise.
          return const SizedBox.shrink();
        }
        return Image.memory(bytes, fit: widget.fit, gaplessPlayback: true);
      },
    );
  }
}

/// Tap-to-open full view. A separate request from the thumbnail on purpose:
/// scrolling a thread should cost thumbnails, and the full image only when
/// someone actually wants to look at one.
class _FullScreenImage extends ConsumerWidget {
  const _FullScreenImage({required this.messageId});

  final int messageId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: l10n.chatCloseImageAction,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      extendBodyBehindAppBar: true,
      body: Center(
        child: InteractiveViewer(
          maxScale: 4,
          child: _RemoteImage(
            load: () => ref
                .read(chatRepositoryProvider)
                .fetchAttachment(messageId, thumbnail: false),
            cacheKey: 'full-$messageId',
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}
