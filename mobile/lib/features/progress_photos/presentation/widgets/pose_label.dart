import '../../../../l10n/app_localizations.dart';
import '../../domain/progress_photo.dart';

/// Localised name of a [PhotoPose].
String poseLabel(AppLocalizations l10n, PhotoPose pose) => switch (pose) {
      PhotoPose.front => l10n.photoPoseFront,
      PhotoPose.side => l10n.photoPoseSide,
      PhotoPose.back => l10n.photoPoseBack,
      PhotoPose.other => l10n.photoPoseOther,
    };
