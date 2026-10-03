import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/format/lifey_format.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/progress_photo_controller.dart';
import '../../domain/progress_photo.dart';
import 'pose_label.dart';

/// One square cell of the timeline grid: the thumbnail (a neutral placeholder
/// until it arrives or when it cannot be loaded) with the date, and the pose
/// when the person tagged one, over a bottom scrim.
class ProgressPhotoTile extends ConsumerWidget {
  const ProgressPhotoTile({super.key, required this.photo, required this.onTap});

  final ProgressPhoto photo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final f = LifeyFormat.of(context);
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    final bytes = ref.watch(progressPhotoThumbnailProvider(photo.id)).value;

    final caption = photo.pose == PhotoPose.other
        ? f.shortDate(photo.takenOn)
        : '${f.shortDate(photo.takenOn)} · ${poseLabel(l10n, photo.pose)}';

    return Semantics(
      button: true,
      label: caption,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.control),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (bytes != null)
                Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true)
              else
                ColoredBox(
                  color: p.nested,
                  child: Icon(Icons.photo_outlined, color: p.text3),
                ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black.withValues(alpha: 0.7)],
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.s8, AppSpacing.s16, AppSpacing.s8, AppSpacing.s8),
                    child: Text(
                      caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.labelMedium!.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                    ),
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
