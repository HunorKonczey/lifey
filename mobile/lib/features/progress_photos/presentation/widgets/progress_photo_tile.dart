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

    final date = f.shortDate(photo.takenOn);
    final pose = photo.pose == PhotoPose.other ? null : poseLabel(l10n, photo.pose);
    final caption = pose == null ? date : '$date · $pose';
    final captionStyle = t.labelMedium!.copyWith(color: Colors.white, fontWeight: FontWeight.w700);
    const captionPadding = EdgeInsets.fromLTRB(AppSpacing.s8, AppSpacing.s16, AppSpacing.s8, AppSpacing.s8);

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
                    padding: captionPadding,
                    // The tile is a third of the screen, so at a large text size
                    // "Oct 7 · Front" no longer fits one line and the pose used
                    // to be cut off (LIF-124): then the pose gets its own line.
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final oneLine = TextPainter(
                          text: TextSpan(text: caption, style: captionStyle),
                          textDirection: Directionality.of(context),
                          textScaler: MediaQuery.textScalerOf(context),
                          maxLines: 1,
                        )..layout();
                        final stack = pose != null && oneLine.width > constraints.maxWidth;
                        return Text(
                          stack ? '$date\n$pose' : caption,
                          maxLines: stack ? 2 : 1,
                          overflow: TextOverflow.ellipsis,
                          style: captionStyle,
                        );
                      },
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
