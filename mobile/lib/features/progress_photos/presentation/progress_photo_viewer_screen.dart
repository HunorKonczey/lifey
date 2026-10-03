import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/lifey_format.dart';
import '../../../core/network/error_message.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/ds/lifey_header.dart';
import '../application/progress_photo_controller.dart';
import '../domain/progress_photo.dart';
import 'widgets/photo_details_sheet.dart';
import 'widgets/pose_label.dart';

/// One photo, full screen and pinch-zoomable, with its date, pose and note,
/// and the edit / delete actions (docs/80 §7 P6). Looks the photo up in the
/// timeline by [photoId], so an edit made here shows immediately and a delete
/// (here or elsewhere) simply closes the screen.
class ProgressPhotoViewerScreen extends ConsumerWidget {
  const ProgressPhotoViewerScreen({super.key, required this.photoId});

  final int photoId;

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.photoDeleteTitle),
        content: Text(l10n.photoDeleteMessage),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: Text(l10n.cancelButton)),
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: Text(l10n.deleteButton)),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref.read(progressPhotoControllerProvider.notifier).remove(photoId);
      if (!context.mounted) return;
      AppSnackbar.showInfo(context, title: l10n.photoDeletedMessage);
      Navigator.of(context).maybePop();
    } catch (e) {
      if (context.mounted) AppSnackbar.showError(context, title: friendlyError(e));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final f = LifeyFormat.of(context);
    final p = context.palette;
    final t = Theme.of(context).textTheme;

    final photos = ref.watch(progressPhotoControllerProvider).value;
    ProgressPhoto? photo;
    for (final candidate in photos ?? const <ProgressPhoto>[]) {
      if (candidate.id == photoId) photo = candidate;
    }
    if (photo == null) {
      // Deleted (or the list is still loading / failed): nothing to show.
      return Scaffold(
        appBar: const LifeySubpageHeader(title: ''),
        body: photos == null ? const Center(child: CircularProgressIndicator()) : const SizedBox.shrink(),
      );
    }

    final shown = photo;
    final full = ref.watch(progressPhotoImageProvider(photoId));
    final thumb = ref.watch(progressPhotoThumbnailProvider(photoId)).value;

    return Scaffold(
      appBar: LifeySubpageHeader(
        title: f.shortDate(shown.takenOn),
        subtitle: shown.pose == PhotoPose.other ? null : poseLabel(l10n, shown.pose),
        actions: [
          HeaderIconButton(
            icon: Icons.edit_outlined,
            tooltip: l10n.photoEditAction,
            onPressed: () => showPhotoDetailsSheet(context, existing: shown),
          ),
          HeaderIconButton(
            icon: Icons.delete_outline_rounded,
            tooltip: l10n.photoDeleteAction,
            onPressed: () => _delete(context, ref),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: full.when(
                data: (bytes) => bytes == null && thumb == null
                    ? Text(l10n.photoImageUnavailableMessage, style: t.bodyMedium!.copyWith(color: p.text2))
                    : InteractiveViewer(
                        maxScale: 5,
                        child: Image.memory(bytes ?? thumb!, fit: BoxFit.contain, gaplessPlayback: true),
                      ),
                // The thumbnail is usually already cached: show it while the
                // full image loads rather than a bare spinner.
                loading: () => thumb != null
                    ? Image.memory(thumb, fit: BoxFit.contain, gaplessPlayback: true)
                    : const CircularProgressIndicator(),
                error: (_, __) => thumb != null
                    ? Image.memory(thumb, fit: BoxFit.contain)
                    : Text(l10n.photoImageUnavailableMessage, style: t.bodyMedium!.copyWith(color: p.text2)),
              ),
            ),
          ),
          if (shown.note != null)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.screen),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(shown.note!, style: t.bodyLarge!.copyWith(color: p.text)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
