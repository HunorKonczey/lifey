import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/network/error_message.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/app_snackbar.dart';
import '../../../../shared/widgets/ds/lifey_segmented.dart';

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
    this.onTyping,
    this.peerTypingName,
    this.initialText,
  });

  /// Text the composer opens with, for a thread entered with something
  /// already to say — the trainer's "message them too" about a session
  /// (docs/chat/41 T3, frame D4). Read once, on first build: after that the
  /// field belongs to whoever is typing in it.

  final String? initialText;

  /// Called on every keystroke; the reporter behind it does the throttling.
  final VoidCallback? onTyping;

  /// Non-null while the peer is writing — the name shown in the band above
  /// the input. The band's space is reserved either way (design D3).
  final String? peerTypingName;

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
    final initialText = widget.initialText;
    if (initialText != null && initialText.isNotEmpty) {
      _controller.text = initialText;
      _hasText = initialText.trim().isNotEmpty;
    }
    _controller.addListener(() {
      final hasText = _controller.text.trim().isNotEmpty;
      if (hasText != _hasText) setState(() => _hasText = hasText);
      // Every keystroke, not just the ones that change _hasText — the
      // throttle upstream is what keeps this from being a request per key.
      widget.onTyping?.call();
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
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context)!;

    // The bar sits on the page colour under a hairline, so the bubbles above
    // it never run through it (canvas: "blur scrim" — nothing scrolls under
    // this bar, so there is nothing to blur).
    return DecoratedBox(
      decoration: BoxDecoration(
        color: p.bg,
        border: Border(top: BorderSide(color: p.hairline)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _TypingBand(name: widget.peerTypingName),
          if (_image != null)
            _PendingImageStrip(
              image: _image!,
              onRemove: () => setState(() => _image = null),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.s16, AppSpacing.s8, AppSpacing.s16, AppSpacing.s12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                SquareIconButton(
                  icon: Icons.add_photo_alternate_outlined,
                  tooltip: l10n.chatAttachImageTooltip,
                  onPressed: () => _showImageSourceSheet(l10n),
                ),
                const SizedBox(width: AppSpacing.s8),
                Expanded(
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 48),
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
                    decoration: BoxDecoration(
                      color: p.card,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: context.elevation.border),
                    ),
                    alignment: Alignment.center,
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      // Grows to five lines, then scrolls inside itself rather
                      // than eating the thread.
                      maxLines: 5,
                      maxLength: widget.maxLength,
                      // The counter only earns its space near the limit — and
                      // even then not inside a 48 dp pill.
                      buildCounter: (_, {required currentLength, required isFocused, required maxLength}) => null,
                      textCapitalization: TextCapitalization.sentences,
                      keyboardType: TextInputType.multiline,
                      style: t.bodyMedium!.copyWith(color: p.text),
                      decoration: InputDecoration(
                        isDense: true,
                        // Transparent: it sits inside its own container; the v2
                        // theme fills fields by default (redesign R0.fix-3).
                        filled: false,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        hintText: l10n.chatComposerHint,
                        hintStyle: t.bodyMedium!.copyWith(color: p.text2),
                        // The theme's 52 dp minimum is for filled fields; this one
                        // lives in a 48 dp pill.
                        constraints: const BoxConstraints(),
                        contentPadding: const EdgeInsets.symmetric(vertical: AppSpacing.s12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.s8),
                IconButton(
                  onPressed: _canSend ? _send : null,
                  tooltip: l10n.chatSendTooltip,
                  icon: const Icon(Icons.arrow_upward_rounded, size: 24),
                  style: IconButton.styleFrom(
                    fixedSize: const Size.square(48),
                    minimumSize: const Size.square(48),
                    shape: const CircleBorder(),
                    backgroundColor: _canSend ? scheme.primary : p.control,
                    foregroundColor: _canSend ? scheme.onPrimary : p.text3,
                    disabledBackgroundColor: p.control,
                    disabledForegroundColor: p.text3,
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

/// "{name} gépel…" with three rising dots, above the input (design D3).
///
/// **Fixed height, always in the tree.** The design says so outright, and the
/// reason is structural: the thread is a reversed list anchored to the bottom,
/// so a band that only existed while someone types would shove the whole
/// conversation up and down as they start and stop. Only the content fades.
class _TypingBand extends StatelessWidget {
  const _TypingBand({required this.name});

  final String? name;

  static const _height = 18.0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final active = name != null;

    return SizedBox(
      // Grows with the text size so the line is never clipped, but is always
      // there — the thread must not jump as the peer starts and stops typing.
      height: MediaQuery.textScalerOf(context).scale(_height),
      child: AnimatedOpacity(
        opacity: active ? 1 : 0,
        duration: const Duration(milliseconds: 150),
        child: !active
            ? const SizedBox.shrink()
            : Padding(
                padding: const EdgeInsets.only(left: AppSpacing.screen, right: AppSpacing.screen),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const _TypingDots(),
                    const SizedBox(width: 7),
                    Flexible(
                      child: Text(
                        l10n.chatIsTyping(name!),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall!.copyWith(
                              fontWeight: FontWeight.w600,
                              color: context.palette.text2,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

/// Three dots rising in turn. One controller drives all three; the stagger is
/// an interval per dot rather than three animations to keep in step.
class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // Eager, not a lazy `late final` initializer — see the identical fix
    // (and its full rationale) in music_sticky_button.dart's
    // _MusicStickyButtonState.initState: a lazy initializer's first access
    // can otherwise end up being dispose() itself, crashing on a
    // TickerMode ancestor lookup against an already-inactive element.
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            // Each dot peaks a sixth of a cycle after the previous one.
            final phase = (_controller.value - index / 6) % 1.0;
            final lift = phase < 0.3 ? (0.3 - (phase - 0.15).abs() * 2) / 0.3 : 0.0;
            return Padding(
              padding: EdgeInsets.only(right: index == 2 ? 0 : 3),
              child: Transform.translate(
                offset: Offset(0, -2 * lift),
                child: Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.35 + 0.65 * lift),
                  ),
                ),
              ),
            );
          }),
        );
      },
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
    final p = context.palette;
    final l10n = AppLocalizations.of(context)!;

    return Container(
      margin: const EdgeInsets.fromLTRB(AppSpacing.s16, AppSpacing.s8, AppSpacing.s16, AppSpacing.s12),
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: BoxDecoration(color: p.card, borderRadius: AppRadius.cardAll),
      child: Row(
        children: [
          Icon(Icons.lock_outline, size: 20, color: p.text2),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: Text(l10n.chatArchivedNotice, style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: p.text2)),
          ),
        ],
      ),
    );
  }
}
