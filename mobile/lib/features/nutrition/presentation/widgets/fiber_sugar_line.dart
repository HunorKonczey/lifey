import 'package:flutter/material.dart';

import '../../../../core/format/lifey_format.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/theme/app_type.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/fiber_sugar.dart';

/// "Fibre 12 g · Sugar 5 g" under a meal's foods or the day's macros (LIF-148): nothing when no food has a figure, and a "some
/// foods have none" note when only some do, so a partial sum is not mistaken for the whole. Wraps instead of truncating.
class FiberSugarLine extends StatelessWidget {
  const FiberSugarLine({super.key, required this.totals, this.style});

  final FiberSugarTotals totals;

  /// Overrides the default secondary body style.
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    if (totals.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;
    final f = LifeyFormat.of(context);
    final parts = <String>[
      if (totals.fiber != null) l10n.fiberTotalLine(f.gramsFine(totals.fiber!)),
      if (totals.sugar != null) l10n.sugarTotalLine(f.gramsFine(totals.sugar!)),
      if (totals.partial) l10n.fiberSugarPartialNote,
    ];
    return Text(
      parts.join(' \u00b7 '),
      key: const Key('fiber-sugar-line'),
      style: style ??
          Theme.of(context).textTheme.bodySmall!.copyWith(
                height: 1.4,
                fontWeight: FontWeight.w500,
                color: context.palette.text2,
                fontFeatures: AppType.tabular,
              ),
    );
  }
}
