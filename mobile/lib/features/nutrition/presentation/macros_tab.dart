import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/date_range_filter_bar.dart';
import '../../../shared/widgets/empty_view.dart';
import '../../../shared/widgets/error_view.dart';
import '../application/daily_macros_controller.dart';
import '../application/meal_controller.dart';
import '../domain/daily_macros.dart';

final _kcalFmt = NumberFormat('#,##0');

/// "Macros" tab: daily macro totals filtered by date range.
///
/// Each row is one calendar day, showing calorie total prominently and
/// protein/carbs/fat as compact coloured icon+value chips below.
class MacrosTab extends ConsumerStatefulWidget {
  const MacrosTab({
    super.key,
    this.topPadding = 0,
    this.filter = DateRangeFilter.week,
  });

  final double topPadding;
  final DateRangeFilter filter;

  @override
  ConsumerState<MacrosTab> createState() => _MacrosTabState();
}

class _MacrosTabState extends ConsumerState<MacrosTab> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(dailyMacrosProvider);
    final l10n = AppLocalizations.of(context)!;
    final bottomPad = MediaQuery.paddingOf(context).bottom;

    return state.when(
      data: (days) {
        final filtered =
            days.where((d) => widget.filter.matches(d.day)).toList();

        if (days.isEmpty || filtered.isEmpty) {
          return RefreshIndicator(
            displacement: widget.topPadding,
            onRefresh: () => ref.read(mealControllerProvider.notifier).refresh(),
            child: EmptyView(
              icon: Icons.pie_chart_outline,
              title: days.isEmpty
                  ? l10n.noMacroDataTitle
                  : l10n.noMacroDataInRangeTitle,
              subtitle: days.isEmpty ? null : l10n.tryWiderDateFilterMessage,
            ),
          );
        }

        return RefreshIndicator(
          displacement: widget.topPadding,
          onRefresh: () => ref.read(mealControllerProvider.notifier).refresh(),
          child: ListView.builder(
            padding: EdgeInsets.fromLTRB(12, widget.topPadding, 12, bottomPad + 88),
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final day = filtered[index];
              final now = DateTime.now();
              final today = DateTime(now.year, now.month, now.day);
              if (day.day == today) {
                return _FeaturedDayCard(day: day);
              }
              return _DailyMacroCard(day: day);
            },
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => ErrorView(
        error: error,
        onRetry: () => ref.read(mealControllerProvider.notifier).refresh(),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Featured day card (today) — large calorie + proportion bar + macro pills
// ---------------------------------------------------------------------------

class _FeaturedDayCard extends StatelessWidget {
  const _FeaturedDayCard({required this.day});

  final DailyMacros day;

  static final _dateFmt = DateFormat('EEE, MMM d');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final mc = context.metricColors;
    final l10n = AppLocalizations.of(context)!;

    return Card(
      elevation: 0,
      color: scheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top row: day label + calorie total ──────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.weightHistoryTodayLabel,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      _dateFmt.format(day.day),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Icon(Icons.local_fire_department, size: 22, color: mc.calories),
                const SizedBox(width: 5),
                Text(
                  _kcalFmt.format(day.calories.round()),
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: scheme.onSurface,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'kcal',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // ── Stacked macro proportion bar ─────────────────────────────
            _MacroProportionBar(
              protein: day.protein,
              carbs: day.carbs,
              fat: day.fat,
              proteinColor: mc.protein,
              carbsColor: mc.carbs,
              fatColor: mc.fat,
            ),

            const SizedBox(height: 13),

            // ── Macro pills row ──────────────────────────────────────────
            IntrinsicHeight(
              child: Row(
                children: [
                  Expanded(
                    child: _MacroPill(
                      icon: Icons.egg_alt,
                      color: mc.protein,
                      value: day.protein,
                      label: l10n.proteinLabel,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _MacroPill(
                      icon: Icons.bakery_dining,
                      color: mc.carbs,
                      value: day.carbs,
                      label: l10n.carbsLabel,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _MacroPill(
                      icon: Icons.water_drop,
                      color: mc.fat,
                      value: day.fat,
                      label: l10n.fatLabel,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Stacked horizontal macro proportion bar
// ---------------------------------------------------------------------------

class _MacroProportionBar extends StatelessWidget {
  const _MacroProportionBar({
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.proteinColor,
    required this.carbsColor,
    required this.fatColor,
  });

  final double protein;
  final double carbs;
  final double fat;
  final Color proteinColor;
  final Color carbsColor;
  final Color fatColor;

  @override
  Widget build(BuildContext context) {
    final total = protein + carbs + fat;

    if (total <= 0) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: Container(
          height: 9,
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(
        height: 9,
        child: Row(
          children: [
            Flexible(
              flex: (protein / total * 1000).round(),
              child: Container(color: proteinColor),
            ),
            Flexible(
              flex: (carbs / total * 1000).round(),
              child: Container(color: carbsColor),
            ),
            Flexible(
              flex: (fat / total * 1000).round(),
              child: Container(color: fatColor),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Macro pill — coloured icon + value (large) + label below
// ---------------------------------------------------------------------------

class _MacroPill extends StatelessWidget {
  const _MacroPill({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final double value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 4),
              Text(
                value.round().toString(),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: color,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: 2),
              Text(
                'g',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Daily macro card (compact — prior days)
// ---------------------------------------------------------------------------

class _DailyMacroCard extends StatelessWidget {
  const _DailyMacroCard({required this.day});

  final DailyMacros day;

  static final _fallbackDate = DateFormat('EEE, MMM d');

  String _dayLabel(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = day.day;
    final diff = today.difference(d).inDays;
    if (diff == 0) return l10n.weightHistoryTodayLabel;
    if (diff == 1) return l10n.weightHistoryYesterdayLabel;
    return _fallbackDate.format(d);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final mc = context.metricColors;

    return Card(
      elevation: 0,
      color: scheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top row: day label + calorie total ──────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  _dayLabel(context),
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                Icon(Icons.local_fire_department, size: 16, color: mc.calories),
                const SizedBox(width: 4),
                Text(
                  _kcalFmt.format(day.calories.round()),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: scheme.onSurface,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(width: 3),
                Text(
                  'kcal',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // ── Bottom row: protein · carbs · fat ───────────────────────
            Row(
              children: [
                _MacroChip(icon: Icons.egg_alt, color: mc.protein, value: day.protein),
                const SizedBox(width: 16),
                _MacroChip(icon: Icons.bakery_dining, color: mc.carbs, value: day.carbs),
                const SizedBox(width: 16),
                _MacroChip(icon: Icons.water_drop, color: mc.fat, value: day.fat),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Macro chip — coloured icon + "value g" (compact, for prior-day cards)
// ---------------------------------------------------------------------------

class _MacroChip extends StatelessWidget {
  const _MacroChip({
    required this.icon,
    required this.color,
    required this.value,
  });

  final IconData icon;
  final Color color;
  final double value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 4),
        Text(
          '${value.round()} g',
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: color,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}
