import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/ds/lifey_header.dart' show OverlapInsetSliver;
import '../../../core/entitlements/entitlement_providers.dart';
import '../../../core/format/lifey_format.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_type.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ds/animated_number.dart';
import '../../../shared/widgets/ds/lifey_card.dart';
import '../../../shared/widgets/ds/metric_bar.dart';
import '../../../shared/widgets/ds/progress_ring.dart';
import '../../../shared/widgets/ds/section_label.dart';
import '../../../shared/widgets/ds/tinted_chip.dart';
import '../../../shared/widgets/empty_view.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/history_boundary_row.dart';
import '../../settings/application/settings_controller.dart';
import '../../settings/domain/user_settings.dart';
import '../application/daily_macros_controller.dart';
import '../application/meal_controller.dart';
import '../domain/daily_macros.dart';
import '../domain/meal_days.dart';

/// How many earlier days the "Last 7 days" list looks back.
const macroHistoryDays = 7;

/// "Macros" tab (docs/redesign/77-mobile-redesign-plan.md R2.8; canvas Lifey 2
/// › 2.4): today's calories with the share of the goal and **three macro
/// rings** — each against its own goal — over a "LAST 7 DAYS" group of one row
/// per day: date, kcal, a bar of the day's P / C / F split and the three gram
/// values in their colours.
///
/// The old Today / Week / All range filter is gone (the canvas has no filter,
/// only the fixed week); days older than a week are in the Meals tab's
/// "All meals". Days without a logged meal have no row.
class MacrosTab extends ConsumerWidget {
  const MacrosTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dailyMacrosProvider);
    final settings = ref.watch(settingsControllerProvider).value ?? const UserSettings.defaults();
    final l10n = AppLocalizations.of(context)!;
    final f = LifeyFormat.of(context);
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    final cutoff = ref.watch(historyCutoffProvider);

    return state.when(
      data: (days) {
        if (days.isEmpty) {
          return RefreshIndicator(
            onRefresh: () => ref.read(mealControllerProvider.notifier).refresh(),
            child: EmptyView(icon: Icons.pie_chart_outline, title: l10n.noMacroDataTitle),
          );
        }
        final now = DateTime.now();
        final today = dateOnly(now);
        final oldest = DateTime(now.year, now.month, now.day - macroHistoryDays);
        DailyMacros? todayTotals;
        for (final d in days) {
          if (d.day == today) todayTotals = d;
        }
        // Newest first already; "last 7 days" = the seven before today.
        final earlier = days.where((d) => d.day.isBefore(today) && !d.day.isBefore(oldest)).toList();
        // The free history window (`67` §3.2, D-P6) — layered on top of the
        // week, never a change to [dailyMacrosProvider] itself.
        final visible =
            cutoff == null ? earlier : earlier.where((d) => !d.day.toLocal().isBefore(cutoff)).toList();
        final truncated = visible.length < earlier.length;

        return RefreshIndicator(
          onRefresh: () => ref.read(mealControllerProvider.notifier).refresh(),
          child: CustomScrollView(physics: const AlwaysScrollableScrollPhysics(), slivers: [const OverlapInsetSliver(), SliverPadding(padding: EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.s8, AppSpacing.screen, bottomPad + 88), sliver: SliverList.list(children: [
              _TodayCard(totals: todayTotals, settings: settings),
              if (visible.isNotEmpty || truncated) ...[
                const SizedBox(height: AppSpacing.s16),
                SectionLabel(l10n.macrosLastDaysTitle),
                const SizedBox(height: AppSpacing.s8),
                if (visible.isNotEmpty)
                  LifeyCard(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.s4),
                    child: Column(
                      children: [
                        for (final (i, day) in visible.indexed) ...[
                          if (i > 0) Divider(height: 1, thickness: 1, indent: AppSpacing.s16, color: context.palette.hairline),
                          _DayRow(day: day, label: f.shortDayLabel(day.day)),
                        ],
                      ],
                    ),
                  ),
                if (truncated) ...[
                  const SizedBox(height: AppSpacing.s8),
                  const HistoryBoundaryRow(),
                ],
              ],
            ]))]),
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
// Today — big kcal, share of the goal, three macro rings
// ---------------------------------------------------------------------------

class _TodayCard extends StatelessWidget {
  const _TodayCard({required this.totals, required this.settings});

  final DailyMacros? totals;
  final UserSettings settings;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final f = LifeyFormat.of(context);
    final p = context.palette;
    final mc = context.metricColors;

    final calories = totals?.calories ?? 0;
    final goal = settings.dailyCalorieGoal;
    final hasGoal = goal != null && goal > 0;

    return LifeyCard(
      padding: const EdgeInsets.all(AppSpacing.s20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.weightHistoryTodayLabel,
            style: Theme.of(context).textTheme.bodyMedium!.copyWith(fontWeight: FontWeight.w600, color: p.text2),
          ),
          const SizedBox(height: AppSpacing.s4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.end,
                  children: [
                    AnimatedNumber(
                      value: calories,
                      builder: (context, v) => Text(
                        f.kcal(v),
                        style: TextStyle(
                          fontFamily: AppType.fontFamily,
                          fontSize: 44,
                          height: 1.1,
                          letterSpacing: -0.02 * 44,
                          fontWeight: FontWeight.w800,
                          color: p.text,
                          fontFeatures: AppType.tabular,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        hasGoal ? ' ${l10n.dayBudgetOfGoal(f.kcal(goal))}' : ' kcal',
                        style: TextStyle(
                          fontFamily: AppType.fontFamily,
                          fontSize: 16,
                          height: 1.2,
                          fontWeight: FontWeight.w600,
                          color: p.text2,
                          fontFeatures: AppType.tabular,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (hasGoal) ...[
                const SizedBox(width: AppSpacing.s8),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: TintedChip(label: f.percent(calories / goal), color: mc.calories),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.s20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _MacroRing(
                  value: totals?.protein ?? 0,
                  goal: settings.dailyProteinGoal,
                  label: l10n.proteinLabel,
                  color: mc.protein,
                ),
              ),
              Expanded(
                child: _MacroRing(
                  value: totals?.carbs ?? 0,
                  goal: settings.dailyCarbsGoal,
                  label: l10n.carbsLabel,
                  color: mc.carbs,
                ),
              ),
              Expanded(
                child: _MacroRing(
                  value: totals?.fat ?? 0,
                  goal: settings.dailyFatGoal,
                  label: l10n.fatLabel,
                  color: mc.fat,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One macro: an 88 px ring against its goal with the grams in the middle,
/// and the macro's name in its colour under it. Past the goal the ring runs a
/// second lap; without a goal it stays empty and shows just the grams.
class _MacroRing extends StatelessWidget {
  const _MacroRing({required this.value, required this.goal, required this.label, required this.color});

  final double value;
  final int? goal;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final f = LifeyFormat.of(context);
    final p = context.palette;
    final hasGoal = goal != null && goal! > 0;
    return Column(
      children: [
        ProgressRing(
          size: 88,
          color: color,
          progress: hasGoal ? value / goal! : 0,
          semanticsLabel: hasGoal ? '$label ${f.grams(value)} / ${f.grams(goal!)} g' : '$label ${f.grams(value)} g',
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.s12),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    f.grams(value),
                    style: TextStyle(
                      fontFamily: AppType.fontFamily,
                      fontSize: 22,
                      height: 1.1,
                      fontWeight: FontWeight.w800,
                      color: p.text,
                      fontFeatures: AppType.tabular,
                    ),
                  ),
                  Text(
                    hasGoal ? '/ ${f.grams(goal!)} g' : 'g',
                    style: TextStyle(
                      fontFamily: AppType.fontFamily,
                      fontSize: 12,
                      height: 1.2,
                      fontWeight: FontWeight.w600,
                      color: p.text2,
                      fontFeatures: AppType.tabular,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.s8),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: AppType.fontFamily,
            fontSize: 15,
            height: 1.2,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// One earlier day
// ---------------------------------------------------------------------------

class _DayRow extends StatelessWidget {
  const _DayRow({required this.day, required this.label});

  final DailyMacros day;
  final String label;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final f = LifeyFormat.of(context);
    final p = context.palette;
    final mc = context.metricColors;
    final t = Theme.of(context).textTheme;

    // Grey like the canvas: the bar above carries the colours.
    final macroStyle = TextStyle(
      fontFamily: AppType.fontFamily,
      fontSize: 13,
      height: 1.2,
      fontWeight: FontWeight.w600,
      color: p.text2,
      fontFeatures: AppType.tabular,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(label, style: t.titleMedium!.copyWith(fontSize: 16, height: 1.25, color: p.text)),
              ),
              const SizedBox(width: AppSpacing.s8),
              Text.rich(
                TextSpan(children: [
                  TextSpan(
                    text: f.kcal(day.calories),
                    style: TextStyle(
                      fontFamily: AppType.fontFamily,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: p.text,
                      fontFeatures: AppType.tabular,
                    ),
                  ),
                  TextSpan(
                    text: ' kcal',
                    style: TextStyle(
                      fontFamily: AppType.fontFamily,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: p.text2,
                    ),
                  ),
                ]),
                maxLines: 1,
                softWrap: false,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s8),
          // The day's split: each macro's share of its own calories, so the
          // bar always adds up to the whole.
          RatioBar(
            segments: [
              (value: day.protein * 4, color: mc.protein),
              (value: day.carbs * 4, color: mc.carbs),
              (value: day.fat * 9, color: mc.fat),
            ],
          ),
          const SizedBox(height: AppSpacing.s8),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            runSpacing: AppSpacing.s4,
            spacing: AppSpacing.s12,
            children: [
              Text('${l10n.macroLetterProtein} ${f.grams(day.protein)}', style: macroStyle),
              Text('${l10n.macroLetterCarbs} ${f.grams(day.carbs)}', style: macroStyle),
              Text('${l10n.macroLetterFat} ${f.grams(day.fat)}', style: macroStyle),
            ],
          ),
        ],
      ),
    );
  }
}
