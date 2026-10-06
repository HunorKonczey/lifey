import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/format/lifey_format.dart';
import '../../../../core/sync/connectivity_status_provider.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/off_search_controller.dart';
import '../../domain/off_search.dart';

/// The OpenFoodFacts option's pieces (docs/84), shared by the add-food-to-meal sheet and the create-food sheet: the
/// checkbox, one result row, and the results block with its single status line. They all read `offSearchControllerProvider`.

/// "Also search the OpenFoodFacts food database": off until ticked, then remembered per device. Online only — offline it is
/// disabled with a hint, because the rest of the app is offline-first and must stay so. Ticked, a one-line hint says what it
/// is: a public volunteer-run database, what is typed is sent to it, and its values can be incomplete.
class OffSearchToggle extends ConsumerWidget {
  const OffSearchToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(offSearchControllerProvider);
    final l10n = AppLocalizations.of(context)!;
    final p = context.palette;
    final offline = ref.watch(isOfflineProvider).value ?? false;
    return CheckboxListTile(
      key: const ValueKey('off-search-toggle'),
      contentPadding: EdgeInsets.zero,
      dense: true,
      controlAffinity: ListTileControlAffinity.leading,
      value: state.enabled,
      onChanged: offline ? null : (v) => ref.read(offSearchControllerProvider.notifier).setEnabled(v ?? false),
      title: Text(l10n.offSearchLabel),
      // What this is and where the results come from: offline why it is off, ticked what is being searched.
      subtitle: offline
          ? Text(l10n.offSearchOffline, style: TextStyle(color: p.text3))
          : state.enabled
              ? Text(l10n.offSearchHint, key: const ValueKey('off-search-hint'), style: TextStyle(color: p.text3))
              : null,
    );
  }
}

/// One OpenFoodFacts product as a row: name with the "OFF" tag, the brand (or "OpenFoodFacts"), "110 kcal".
class OffResultRow extends StatelessWidget {
  const OffResultRow({super.key, required this.item, required this.onTap});

  final OffSearchItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final f = LifeyFormat.of(context);
    final t = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context)!;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(TextSpan(children: [
                      TextSpan(text: item.name, style: t.bodyMedium!.copyWith(fontWeight: FontWeight.w700, color: p.text)),
                      TextSpan(text: '  ${l10n.offSearchTag}', style: t.labelSmall!.copyWith(color: p.text2, fontWeight: FontWeight.w700)),
                    ])),
                    Text(item.brand ?? 'OpenFoodFacts', style: t.bodySmall!.copyWith(color: p.text3)),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.s8),
              Text('${f.kcal(item.caloriesPer100g)} kcal', style: t.bodySmall!.copyWith(color: p.text2)),
            ],
          ),
        ),
      ),
    );
  }
}

/// The results block: "FROM THE OPENFOODFACTS DATABASE", then the rows and exactly one line below them — searching /
/// nothing found / the English fallback / unavailable / rate-limited — or, before three letters are typed, the hint to type
/// more. [typed] is the text being searched; [onPick] gets the tapped product. Watches the controller itself, so it is
/// right even inside an autocomplete overlay that does not rebuild with its sheet.
class OffResultsBody extends ConsumerWidget {
  const OffResultsBody({super.key, required this.typed, required this.onPick});

  final String typed;
  final ValueChanged<OffSearchItem> onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final off = ref.watch(offSearchControllerProvider);
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context)!;

    Widget line(String text, String key) => Padding(
          key: ValueKey(key),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s12),
          child: Text(text, style: t.bodySmall!.copyWith(color: p.text3)),
        );

    final note = off.note;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.s16, AppSpacing.s12, AppSpacing.s16, AppSpacing.s4),
          child: Text(l10n.offSearchSection.toUpperCase(),
              key: const ValueKey('off-section-title'), style: t.labelSmall!.copyWith(color: p.text3, fontWeight: FontWeight.w700)),
        ),
        if (!isOffSearchable(typed))
          line(l10n.offSearchTypeMore, 'off-type-more')
        else ...[
          for (final item in off.items) OffResultRow(item: item, onTap: () => onPick(item)),
          if (off.pending)
            line(l10n.offSearchSearching, 'off-searching')
          else if (note != null)
            line(
              switch (note) {
                OffNote.fellBack => l10n.offSearchFellBack,
                OffNote.unavailable => l10n.offSearchUnavailable,
                OffNote.rateLimited => l10n.offSearchRateLimited,
              },
              'off-note-${note.name}',
            )
          else if (off.items.isEmpty)
            line(l10n.offSearchNoResults, 'off-no-results'),
        ],
      ],
    );
  }
}
