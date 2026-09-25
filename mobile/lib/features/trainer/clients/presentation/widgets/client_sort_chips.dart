import 'package:flutter/material.dart';

import '../../../../../core/theme/app_tokens.dart';
import '../../../../../l10n/app_localizations.dart';
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
    final p = context.palette;
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;

    String label(ClientSortOption option) => switch (option) {
          ClientSortOption.recent => l10n.trainerClientsSortRecentLabel,
          ClientSortOption.leastActive => l10n.trainerClientsSortLeastActiveLabel,
          ClientSortOption.mostMissed => l10n.trainerClientsSortMostMissedLabel,
          ClientSortOption.weightOverdue => l10n.trainerClientsSortWeightOverdueLabel,
        };

    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
        itemCount: ClientSortOption.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.s8),
        itemBuilder: (context, index) {
          final option = ClientSortOption.values[index];
          final on = option == selected;
          return Semantics(
            button: true,
            selected: on,
            label: label(option),
            excludeSemantics: true,
            child: Material(
              color: on ? scheme.primary : p.card,
              shape: StadiumBorder(side: BorderSide(color: on ? scheme.primary : context.elevation.border)),
              child: InkWell(
                customBorder: const StadiumBorder(),
                onTap: () => onSelected(option),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s20),
                  child: Center(
                    child: Text(
                      label(option),
                      maxLines: 1,
                      style: t.labelLarge!.copyWith(
                        fontWeight: on ? FontWeight.w800 : FontWeight.w700,
                        color: on ? scheme.onPrimary : p.text,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
