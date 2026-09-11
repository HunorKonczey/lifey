import 'package:flutter/material.dart';

import '../../../../../l10n/app_localizations.dart';
import '../../domain/compliance.dart';

/// The four sort options as a horizontally scrolling chip row (frame B3).
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
    final scheme = Theme.of(context).colorScheme;

    String label(ClientSortOption option) => switch (option) {
          ClientSortOption.recent => l10n.trainerClientsSortRecentLabel,
          ClientSortOption.leastActive => l10n.trainerClientsSortLeastActiveLabel,
          ClientSortOption.mostMissed => l10n.trainerClientsSortMostMissedLabel,
          ClientSortOption.weightOverdue => l10n.trainerClientsSortWeightOverdueLabel,
        };

    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: ClientSortOption.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final option = ClientSortOption.values[index];
          return ChoiceChip(
            label: Text(label(option)),
            selected: option == selected,
            onSelected: (_) => onSelected(option),
            showCheckmark: false,
            selectedColor: scheme.tertiaryContainer,
            labelStyle: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: option == selected
                  ? scheme.onTertiaryContainer
                  : scheme.onSurfaceVariant,
            ),
          );
        },
      ),
    );
  }
}
