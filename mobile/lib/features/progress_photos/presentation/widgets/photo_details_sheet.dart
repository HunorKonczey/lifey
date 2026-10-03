import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/format/lifey_format.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/ds/lifey_card.dart';
import '../../../../shared/widgets/ds/lifey_sheet.dart';
import '../../application/progress_photo_controller.dart';
import '../../domain/progress_photo.dart';
import 'pose_label.dart';

/// Opens the photo-details sheet: for a freshly picked [file] (uploads on
/// Save) or for an [existing] photo (edits its date, pose and note).
Future<void> showPhotoDetailsSheet(BuildContext context, {File? file, ProgressPhoto? existing}) {
  assert((file == null) != (existing == null), 'pass exactly one of file / existing');
  return showLifeySheet<void>(
    context: context,
    title: AppLocalizations.of(context)!.photosDetailsTitle,
    showClose: true,
    useRootNavigator: true,
    builder: (_) => PhotoDetailsSheet(file: file, existing: existing),
  );
}

/// Date, pose chips, an optional note, Save (docs/80 §7 P6). A new photo is
/// uploaded here, so a failure keeps the sheet open with the picked image
/// intact for another try.
class PhotoDetailsSheet extends ConsumerStatefulWidget {
  const PhotoDetailsSheet({super.key, this.file, this.existing});

  final File? file;
  final ProgressPhoto? existing;

  @override
  ConsumerState<PhotoDetailsSheet> createState() => _PhotoDetailsSheetState();
}

class _PhotoDetailsSheetState extends ConsumerState<PhotoDetailsSheet> {
  final _now = DateTime.now();
  late DateTime _date = widget.existing?.takenOn ?? DateTime(_now.year, _now.month, _now.day);
  late PhotoPose _pose = widget.existing?.pose ?? PhotoPose.front;
  late final _note = TextEditingController(text: widget.existing?.note ?? '');
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: _now,
    );
    if (picked != null && mounted) setState(() => _date = picked);
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _submitting = true;
      _error = null;
    });
    final controller = ref.read(progressPhotoControllerProvider.notifier);
    final note = _note.text.trim().isEmpty ? null : _note.text.trim();
    try {
      final existing = widget.existing;
      if (existing != null) {
        await controller.edit(existing, takenOn: _date, pose: _pose, note: note);
      } else {
        await controller.add(widget.file!, takenOn: _date, pose: _pose, note: note);
      }
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(() => _error = widget.existing != null ? l10n.photoSaveFailedMessage : l10n.photoUploadFailedMessage);
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  bool _isToday(DateTime d) => d.year == _now.year && d.month == _now.month && d.day == _now.day;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final f = LifeyFormat.of(context);
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    final file = widget.file;
    final dateLabel = _isToday(_date) ? l10n.weightHistoryTodayLabel : '${f.weekdayShort(_date)}, ${f.shortDate(_date)}';

    return SingleChildScrollView(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.s8),
          if (file != null) ...[
            SizedBox(
              height: 160,
              child: ClipRRect(
                borderRadius: AppRadius.cardAll,
                child: Image.file(file, fit: BoxFit.cover, errorBuilder: (_, __, ___) => ColoredBox(color: p.nested)),
              ),
            ),
            const SizedBox(height: AppSpacing.s16),
          ],
          Text(l10n.photoPoseLabel, style: t.labelLarge!.copyWith(color: p.text2)),
          const SizedBox(height: AppSpacing.s8),
          Wrap(
            spacing: AppSpacing.s8,
            runSpacing: AppSpacing.s8,
            children: [
              for (final pose in PhotoPose.values)
                ChoiceChip(
                  label: Text(poseLabel(l10n, pose)),
                  selected: pose == _pose,
                  onSelected: _submitting ? null : (_) => setState(() => _pose = pose),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.s16),
          LifeyCard.nested(
            onTap: _submitting ? null : _pickDate,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s16),
            child: Row(
              children: [
                Icon(Icons.calendar_today_rounded, size: 22, color: p.text),
                const SizedBox(width: AppSpacing.s12),
                Expanded(
                  child: Text(dateLabel, style: t.titleMedium!.copyWith(fontWeight: FontWeight.w700, color: p.text)),
                ),
                Icon(Icons.keyboard_arrow_down_rounded, size: 24, color: p.text2),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.s16),
          TextField(
            controller: _note,
            enabled: !_submitting,
            maxLength: 500,
            maxLines: 3,
            minLines: 1,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(labelText: l10n.photoNoteLabel),
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.s8),
            Text(_error!, style: t.bodyMedium!.copyWith(color: context.metricColors.negative)),
          ],
          const SizedBox(height: AppSpacing.s16),
          SizedBox(
            height: 56,
            child: FilledButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(l10n.saveButton),
            ),
          ),
        ],
      ),
    );
  }
}
