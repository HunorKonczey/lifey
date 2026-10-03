import 'package:flutter/material.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/body_measurement.dart';

/// Localised name of a measurement site.
String measurementSiteLabel(AppLocalizations l10n, MeasurementSite site) => switch (site) {
      MeasurementSite.waist => l10n.measurementSiteWaist,
      MeasurementSite.chest => l10n.measurementSiteChest,
      MeasurementSite.hips => l10n.measurementSiteHips,
      MeasurementSite.arm => l10n.measurementSiteArm,
      MeasurementSite.thigh => l10n.measurementSiteThigh,
    };

/// Choice chips, one per [MeasurementSite], wrapping onto a second line on a
/// narrow phone rather than scrolling (five chips overflow 411 dp).
class MeasurementSiteChips extends StatelessWidget {
  const MeasurementSiteChips({super.key, required this.selected, required this.onSelected});

  final MeasurementSite selected;
  final ValueChanged<MeasurementSite> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Wrap(
      spacing: AppSpacing.s8,
      runSpacing: AppSpacing.s8,
      children: [
        for (final site in MeasurementSite.values)
          ChoiceChip(
            label: Text(measurementSiteLabel(l10n, site)),
            selected: site == selected,
            onSelected: (_) => onSelected(site),
          ),
      ],
    );
  }
}
