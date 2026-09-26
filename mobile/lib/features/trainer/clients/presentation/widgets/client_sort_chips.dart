import 'package:flutter/material.dart';

import '../../../../../l10n/app_localizations.dart';
import '../../../shared/filter_pill_row.dart';
import '../../domain/compliance.dart';

/// The four sort options as a horizontally scrolling pill row (canvas Lifey 6:
/// the chosen one filled in the primary colour).
///
/// Not a dropdown: on a phone a header menu hides the current choice behind a
/// tap, and the sort is the thing the trainer changes most often on this
/// screen. The semantics are the web's `sortClients` exactly — this widget
/// only picks the option.
class ClientSortChips extends StatelessWidget {
  const ClientSortChips({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final ClientSortOption selected;
  final ValueChanged<ClientSortOption> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    String label(ClientSortOption option) => switch (option) {
          ClientSortOption.recent => l10n.trainerClientsSortRecentLabel,
          ClientSortOption.leastActive => l10n.trainerClientsSortLeastActiveLabel,
          ClientSortOption.mostMissed => l10n.trainerClientsSortMostMissedLabel,
          ClientSortOption.weightOverdue => l10n.trainerClientsSortWeightOverdueLabel,
        };

    return FilterPillRow(
      pills: [
        for (final option in ClientSortOption.values)
          (label: label(option), selected: option == selected, onTap: () => onSelected(option)),
      ],
    );
  }
}
