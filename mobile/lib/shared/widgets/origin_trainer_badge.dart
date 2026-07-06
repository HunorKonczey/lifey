import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/my_trainers/application/my_trainers_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../core/theme/app_tokens.dart';

/// Small "Edzőtől" pill shown on a trainer-assigned template/recipe card
/// (docs/personal_trainer/05-mobil-terv.md §2, design in 06-design.md §4).
/// Tapping it reveals which trainer it came from — resolved from the
/// already-cached [myTrainersControllerProvider] list rather than a
/// dedicated lookup, since that's the same trainer the client sees in
/// Settings § "Edzőim".
class OriginTrainerBadge extends ConsumerWidget {
  const OriginTrainerBadge({super.key, required this.originTrainerId});

  final int originTrainerId;

  String? _trainerEmail(WidgetRef ref) {
    final trainers = ref.read(myTrainersControllerProvider).value ?? const [];
    for (final trainer in trainers) {
      if (trainer.trainerId == originTrainerId) return trainer.trainerEmail;
    }
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;

    // Watched (not just read on tap) so the provider is already resolved by
    // the time the badge is tapped — otherwise this would be the first
    // subscriber and _trainerEmail would read an unresolved AsyncLoading.
    ref.watch(myTrainersControllerProvider);

    return GestureDetector(
      onTap: () => _showOriginSheet(context, ref, l10n),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: scheme.tertiaryContainer,
          borderRadius: AppRadius.pill,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.school, size: 12, color: scheme.onTertiaryContainer),
            const SizedBox(width: 4),
            Text(
              l10n.originTrainerBadgeLabel,
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: scheme.onTertiaryContainer,
                height: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showOriginSheet(BuildContext context, WidgetRef ref, AppLocalizations l10n) {
    final email = _trainerEmail(ref);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetCtx) {
        final scheme = Theme.of(sheetCtx).colorScheme;
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.school, color: scheme.tertiary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l10n.originTrainerSheetTitle,
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                email != null
                    ? l10n.originTrainerSheetBody(email)
                    : l10n.originTrainerUnknown,
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  color: scheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
