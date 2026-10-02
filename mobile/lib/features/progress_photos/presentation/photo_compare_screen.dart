import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/lifey_format.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ds/lifey_header.dart';
import '../../../shared/widgets/ds/lifey_sheet.dart';
import '../application/progress_photo_controller.dart';
import '../domain/photo_compare.dart';
import '../domain/progress_photo.dart';
import 'widgets/pose_label.dart';
import 'widgets/progress_photo_tile.dart';

/// Side-by-side compare (docs/80 §2.7): two photos from the timeline in equal
/// panes with their dates and the days between them. Starts on the oldest and
/// newest; tapping a pane picks another photo for that side. A client-side
/// view — both images come from the same endpoints the viewer uses.
class PhotoCompareScreen extends ConsumerStatefulWidget {
  const PhotoCompareScreen({super.key});

  @override
  ConsumerState<PhotoCompareScreen> createState() => _PhotoCompareScreenState();
}

class _PhotoCompareScreenState extends ConsumerState<PhotoCompareScreen> {
  int? _beforeId;
  int? _afterId;

  ProgressPhoto? _find(List<ProgressPhoto> photos, int? id) {
    for (final p in photos) {
      if (p.id == id) return p;
    }
    return null;
  }

  Future<void> _pick(List<ProgressPhoto> photos, {required bool before}) async {
    final picked = await showLifeySheet<ProgressPhoto>(
      context: context,
      title: AppLocalizations.of(context)!.photosComparePickTitle,
      showClose: true,
      useRootNavigator: true,
      builder: (sheetContext) => GridView.builder(
        shrinkWrap: true,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: AppSpacing.s8,
          crossAxisSpacing: AppSpacing.s8,
        ),
        itemCount: photos.length,
        itemBuilder: (_, i) => ProgressPhotoTile(
          photo: photos[i],
          onTap: () => Navigator.of(sheetContext).pop(photos[i]),
        ),
      ),
    );
    if (picked == null || !mounted) return;
    setState(() => before ? _beforeId = picked.id : _afterId = picked.id);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    final photos = ref.watch(progressPhotoControllerProvider).value ?? const <ProgressPhoto>[];
    final defaults = defaultCompareSelection(photos);

    // A chosen photo that has since been deleted falls back to the default.
    final before = _find(photos, _beforeId) ?? defaults?.before;
    final after = _find(photos, _afterId) ?? defaults?.after;

    return Scaffold(
      appBar: LifeySubpageHeader(title: l10n.photosCompareTitle),
      body: before == null || after == null
          ? const SizedBox.shrink()
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.screen),
                child: Column(
                  children: [
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _Pane(
                              caption: l10n.photosCompareBefore,
                              photo: before,
                              onTap: () => _pick(photos, before: true),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.s12),
                          Expanded(
                            child: _Pane(
                              caption: l10n.photosCompareAfter,
                              photo: after,
                              onTap: () => _pick(photos, before: false),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s12),
                    Text(
                      l10n.photosCompareDaysApart(daysBetween(before.takenOn, after.takenOn)),
                      style: t.titleMedium!.copyWith(fontWeight: FontWeight.w700, color: p.text2),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _Pane extends ConsumerWidget {
  const _Pane({required this.caption, required this.photo, required this.onTap});

  final String caption;
  final ProgressPhoto photo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final f = LifeyFormat.of(context);
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    final full = ref.watch(progressPhotoImageProvider(photo.id)).value;
    final thumb = ref.watch(progressPhotoThumbnailProvider(photo.id)).value;
    final bytes = full ?? thumb;

    final date = photo.pose == PhotoPose.other
        ? f.shortDate(photo.takenOn)
        : '${f.shortDate(photo.takenOn)} · ${poseLabel(l10n, photo.pose)}';

    // The whole pane (caption, picture, date) is the tap target for re-picking.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(caption, textAlign: TextAlign.center, style: t.labelLarge!.copyWith(color: p.text2)),
          const SizedBox(height: AppSpacing.s4),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.control),
              child: bytes == null
                  ? ColoredBox(color: p.nested, child: Icon(Icons.photo_outlined, color: p.text3))
                  : Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true),
            ),
          ),
          const SizedBox(height: AppSpacing.s8),
          Text(
            date,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: t.bodyMedium!.copyWith(fontWeight: FontWeight.w600, color: p.text),
          ),
        ],
      ),
    );
  }
}
