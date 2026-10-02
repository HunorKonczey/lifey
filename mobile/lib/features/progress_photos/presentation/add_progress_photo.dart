import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/network/error_message.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/ds/lifey_sheet.dart';
import 'widgets/photo_details_sheet.dart';

/// "Add photo": choose camera or gallery, pick, then the details sheet, which
/// uploads on Save (docs/80 §7 P6).
Future<void> startAddProgressPhoto(BuildContext context) async {
  final l10n = AppLocalizations.of(context)!;
  final source = await showLifeySheet<ImageSource>(
    context: context,
    title: l10n.photosAddButton,
    showClose: true,
    useRootNavigator: true,
    builder: (sheetContext) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          leading: const Icon(Icons.photo_camera_outlined),
          title: Text(l10n.photosSourceCamera),
          onTap: () => Navigator.of(sheetContext).pop(ImageSource.camera),
        ),
        ListTile(
          leading: const Icon(Icons.photo_library_outlined),
          title: Text(l10n.photosSourceGallery),
          onTap: () => Navigator.of(sheetContext).pop(ImageSource.gallery),
        ),
      ],
    ),
  );
  if (source == null || !context.mounted) return;

  final XFile? picked;
  try {
    // Downscaled by the picker before it reaches the network; the server
    // bounds it again (1600 px) and strips the metadata.
    picked = await ImagePicker().pickImage(source: source, maxWidth: 1600, imageQuality: 90);
  } catch (e) {
    if (context.mounted) AppSnackbar.showError(context, title: friendlyError(e));
    return;
  }
  if (picked == null || !context.mounted) return;

  await showPhotoDetailsSheet(context, file: File(picked.path));
}
