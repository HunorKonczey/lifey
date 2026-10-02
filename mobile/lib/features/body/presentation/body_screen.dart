import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ds/lifey_header.dart';
import '../../../shared/widgets/ds/lifey_segmented.dart';
import '../../measurements/presentation/body_measurements_tab.dart';
import '../../progress_photos/presentation/add_progress_photo.dart';
import '../../progress_photos/presentation/progress_photos_tab.dart';

enum BodyTab { measurements, photos }

/// Body (docs/80): how the body changes besides weight — measurements and a
/// photo timeline, on two tabs under one header. Reached from the Weight
/// screen. Each tab brings its own floating action.
class BodyScreen extends ConsumerStatefulWidget {
  const BodyScreen({super.key, this.initialTab = BodyTab.measurements});

  final BodyTab initialTab;

  @override
  ConsumerState<BodyScreen> createState() => _BodyScreenState();
}

class _BodyScreenState extends ConsumerState<BodyScreen> {
  late BodyTab _tab = widget.initialTab;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: LifeySubpageHeader(title: l10n.bodyTitle),
      floatingActionButton: switch (_tab) {
        BodyTab.measurements => FloatingActionButton.extended(
            onPressed: () => BodyMeasurementsTab.logMeasurement(context, ref),
            icon: const Icon(Icons.add),
            label: Text(l10n.logFabLabel),
          ),
        BodyTab.photos => FloatingActionButton.extended(
            onPressed: () => startAddProgressPhoto(context),
            icon: const Icon(Icons.add_a_photo_outlined),
            label: Text(l10n.photosAddButton),
          ),
      },
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.s8, AppSpacing.screen, AppSpacing.s8),
            child: LifeySegmented<BodyTab>(
              segments: [
                (BodyTab.measurements, l10n.bodyTabMeasurements),
                (BodyTab.photos, l10n.bodyTabPhotos),
              ],
              selected: _tab,
              onChanged: (tab) => setState(() => _tab = tab),
            ),
          ),
          Expanded(
            child: switch (_tab) {
              BodyTab.measurements => const BodyMeasurementsTab(),
              BodyTab.photos => const ProgressPhotosTab(),
            },
          ),
        ],
      ),
    );
  }
}
