import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/network/error_message.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/app_snackbar.dart';

/// The message input.
///
/// Never disabled by connectivity — that is the point of the optimistic send:
/// what you type offline is written locally and goes out on its own later.
/// The only thing that replaces it is an archived thread, where there is
/// genuinely nothing to send to.
class ChatComposer extends StatefulWidget {
  const ChatComposer({
    super.key,
    required this.onSend,
    this.maxLength = 2000,
    this.maxAttachmentBytes = 8 * 1024 * 1024,
  });

  /// [image] is null for a plain text message. A picture may travel with an
  /// empty body — on its own it is already a complete message.
  final void Function(String body, File? image) onSend;

  /// Mirrors the server's `lifey.chat.attachment-max-bytes`, so an oversized
  /// picture is refused at the picker instead of after the upload.
  final int maxAttachmentBytes;

  /// Matches the server's `lifey.chat.max-body-length`; enforced here so an
  /// over-long message is stopped at the keyboard rather than by a 400.
  final int maxLength;

  @override
  State<ChatComposer> createState() => _ChatComposerState();
}

class _ChatComposerState extends State<ChatComposer> {
  final _controller = TextEditingController();
  bool _hasText = false;
  File? _image;

  bool get _canSend => _hasText || _image != null;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final hasText = _controller.text.trim().isNotEmpty;
      if (hasText != _hasText) setState(() => _hasText = hasText);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    final image = _image;
    if (text.isEmpty && image == null) return;
    _controller.clear();
    setState(() => _image = null);
    widget.onSend(text, image);
  }

  Future<void> _pickImage(ImageSource source, AppLocalizations l10n) async {
    final XFile? picked;
    try {
      // Downscaled and re-compressed by the picker before it ever reaches the
      // network: the server bounds it again, but there is no reason to upload
      // a 12MP original over a phone connection to have it shrunk on arrival.
      picked = await ImagePicker().pickImage(source: source, maxWidth: 1600, imageQuality: 90);
    } catch (e) {
      if (mounted) AppSnackbar.showError(context, title: friendlyError(e));
      return;
    }
    if (picked == null) return;

    final file = File(picked.path);
    if (await file.length() > widget.maxAttachmentBytes) {
      if (mounted) AppSnackbar.showError(context, title: l10n.chatImageTooLarge);
      return;
    }
    if (mounted) setState(() => _image = file);
  }

  Future<void> _showImageSourceSheet(AppLocalizations l10n) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(l10n.chatTakePhotoAction),
              onTap: () {
                Navigator.of(sheetContext).pop();
                unawaited(_pickImage(ImageSource.camera, l10n));
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(l10n.chatChooseImageAction),
              onTap: () {
                Navigator.of(sheetContext).pop();
                unawaited(_pickImage(ImageSource.gallery, l10n));
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_image != null) _PendingImageStrip(
          image: _image!,
          onRemove: () => setState(() => _image = null),
        ),
        Container(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 10),
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: IconButton(
              onPressed: () => _showImageSourceSheet(l10n),
              tooltip: l10n.chatAttachImageTooltip,
              icon: const Icon(Icons.image_outlined, size: 21),
              style: IconButton.styleFrom(foregroundColor: scheme.onSurfaceVariant),
            ),
          ),
          Expanded(
            child: TextField(
              controller: _controller,
              minLines: 1,
              // Grows to five lines, then scrolls inside itself rather than
              // eating the thread.
              maxLines: 5,
              maxLength: widget.maxLength,
              textCapitalization: TextCapitalization.sentences,
              keyboardType: TextInputType.multiline,
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 14.5,
                fontWeight: FontWeight.w500,
                color: scheme.onSurface,
              ),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                // The counter only earns its space near the limit.
                counterText: '',
                hintText: l10n.chatComposerHint,
                hintStyle: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 14.5,
                  fontWeight: FontWeight.w500,
                  color: scheme.onSurfaceVariant,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: IconButton(
              onPressed: _canSend ? _send : null,
              tooltip: l10n.chatSendTooltip,
              icon: const Icon(Icons.send_rounded, size: 20),
              style: IconButton.styleFrom(
                backgroundColor: _canSend ? scheme.primary : scheme.surfaceContainerHighest,
                foregroundColor: _canSend ? scheme.onPrimary : scheme.onSurfaceVariant,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.input),
                ),
              ),
            ),
          ),
        ],
      ),
        ),
      ],
    );
  }
}

/// The picked picture, above the input, until it is sent or dropped.
class _PendingImageStrip extends StatelessWidget {
  const _PendingImageStrip({required this.image, required this.onRemove});

  final File image;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(image, width: 56, height: 56, fit: BoxFit.cover),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              l10n.chatImageReady,
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          IconButton(
            onPressed: onRemove,
            tooltip: l10n.chatRemoveImageAction,
            icon: const Icon(Icons.close, size: 18),
            style: IconButton.styleFrom(foregroundColor: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// Replaces the composer once the relationship has ended: the history stays,
/// the input goes (docs/chat/40-trainer-chat-plan.md §1.3/1).
class ArchivedComposerNotice extends StatelessWidget {
  const ArchivedComposerNotice({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        children: [
          Icon(Icons.lock_outline, size: 18, color: scheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              l10n.chatArchivedNotice,
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: scheme.onSurfaceVariant,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
