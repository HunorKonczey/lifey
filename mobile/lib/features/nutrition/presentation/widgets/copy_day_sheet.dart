import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/format/lifey_format.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/ds/list_group.dart';
import '../../application/meal_controller.dart';
import '../../domain/day_meals_summary.dart';

/// Bottom sheet listing the last 7 days that have logged meals (today
/// excluded), for "copy a previous day" onto today. Pops with the picked
/// [DayMealsSummary]; the caller performs the actual copy so it can show a
/// single consistent snackbar shared with the "copy yesterday" empty-state
/// shortcut.
class CopyDaySheet extends ConsumerStatefulWidget {
  const CopyDaySheet({super.key, required this.hasMealsToday});

  /// Whether today already has meals — shown as a note on each row so
  /// copying is understood to append, not replace.
  final bool hasMealsToday;

  @override
  ConsumerState<CopyDaySheet> createState() => _CopyDaySheetState();
}

/// How many past days [CopyDaySheet] fetches from (today inclusive) and,
/// after excluding today, how many rows it can show at most.
const _lookbackDays = 8;

class _CopyDaySheetState extends ConsumerState<CopyDaySheet> {
  late final Future<List<DayMealsSummary>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<DayMealsSummary>> _load() async {
    final meals =
        await ref.read(mealControllerProvider.notifier).recentMeals(days: _lookbackDays);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return groupMealsByDay(meals).where((d) => d.day != today).toList();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final bottomPad = MediaQuery.paddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.s8, AppSpacing.screen, AppSpacing.s20 + bottomPad),
      child: FutureBuilder<List<DayMealsSummary>>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final days = snapshot.data!;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text(l10n.copyPreviousDayTitle, style: Theme.of(context).textTheme.headlineSmall),
              ),
              const SizedBox(height: 12),
              if (days.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Text(
                    l10n.noMealsToCopyMessage,
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                )
              else
                ListGroup(
                  dividerInset: AppSpacing.s16,
                  children: [
                    for (final day in days)
                      _DayRow(
                        summary: day,
                        showsAppendsNote: widget.hasMealsToday,
                        onTap: () => Navigator.of(context).pop(day),
                      ),
                  ],
                ),
            ],
          );
        },
      ),
    );
  }
}

class _DayRow extends StatelessWidget {
  const _DayRow({
    required this.summary,
    required this.showsAppendsNote,
    required this.onTap,
  });

  final DayMealsSummary summary;
  final bool showsAppendsNote;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final p = context.palette;

    final t = Theme.of(context).textTheme;

    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      LifeyFormat.of(context).shortDayLabel(summary.day),
                      style: t.bodyMedium!.copyWith(fontWeight: FontWeight.w700, height: 1.3, color: p.text),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      l10n.copyDaySheetMealsKcal(summary.mealCount, summary.totalCalories.round()),
                      style: t.bodySmall!.copyWith(height: 1.4, color: p.text2),
                    ),
                    if (showsAppendsNote)
                      Text(l10n.copyDayAppendsNote, style: t.bodySmall!.copyWith(height: 1.4, color: p.text2)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: p.text2),
            ],
          ),
        ),
      ),
    );
  }
}
