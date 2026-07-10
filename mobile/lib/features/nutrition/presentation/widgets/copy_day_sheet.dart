import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../../../l10n/app_localizations.dart';
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
      padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + bottomPad),
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
              Text(l10n.copyPreviousDayTitle, style: Theme.of(context).textTheme.titleLarge),
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
                for (final day in days) ...[
                  _DayRow(
                    summary: day,
                    showsAppendsNote: widget.hasMealsToday,
                    onTap: () => Navigator.of(context).pop(day),
                  ),
                  const SizedBox(height: 8),
                ],
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

  static final _dayLabel = DateFormat('EEE, MMM d');

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Material(
      color: scheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_dayLabel.format(summary.day), style: theme.textTheme.bodyLarge),
                    const SizedBox(height: 2),
                    Text(
                      l10n.copyDaySheetMealsKcal(
                          summary.mealCount, summary.totalCalories.round()),
                      style: theme.textTheme.labelMedium
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                    if (showsAppendsNote) ...[
                      const SizedBox(height: 2),
                      Text(
                        l10n.copyDayAppendsNote,
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: scheme.onSurfaceVariant.withValues(alpha: 0.7)),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(Icons.chevron_right, size: 18, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
