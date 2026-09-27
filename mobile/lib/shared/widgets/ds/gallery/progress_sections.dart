import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/format/lifey_format.dart';
import '../../../../core/theme/app_tokens.dart';
import '../delta_chip.dart';
import '../lifey_card.dart';
import '../metric_bar.dart';
import '../metric_tile.dart';
import '../metric_value.dart';
import '../progress_ring.dart';
import '../tinted_chip.dart';
import 'gallery_section.dart';

/// Gallery sections for R0.9: rings, bars, ratio bar, metric tiles
/// (docs/redesign/77-mobile-redesign-plan.md R0.9).
final List<GallerySection> progressSections = [
  GallerySection(
    title: 'Rings & bars',
    source: 'Lifey 1 › hero · Lifey 2 › Macros, week strip, day budget · R0.9',
    builder: (_) => const _ProgressSection(),
  ),
  GallerySection(
    title: 'Metric tiles',
    source: 'Design System › Metrikacsempe · Lifey 1 › Water, Steps, Weight · R0.9',
    builder: (_) => const _TilesSection(),
  ),
];

bool _hu(BuildContext context) => Localizations.localeOf(context).languageCode == 'hu';

class _ProgressSection extends StatefulWidget {
  const _ProgressSection();

  @override
  State<_ProgressSection> createState() => _ProgressSectionState();
}

class _ProgressSectionState extends State<_ProgressSection> {
  final _random = math.Random(3);
  // The canvas day: 621 of 2 360 kcal; P 29/129, C 88/313, F 20/66.
  double _eaten = 621;
  double _protein = 29, _carbs = 88, _fat = 20;
  int _key = 0;

  void _randomize() => setState(() {
        _eaten = 200 + _random.nextInt(3000).toDouble();
        _protein = _random.nextInt(170).toDouble();
        _carbs = _random.nextInt(360).toDouble();
        _fat = _random.nextInt(90).toDouble();
      });

  @override
  Widget build(BuildContext context) {
    final m = context.metricColors;
    final p = context.palette;
    final f = LifeyFormat.of(context);
    final hu = _hu(context);
    const goal = 2360.0;
    final left = goal - _eaten;
    final macros = [
      (hu ? 'Fehérje' : 'Protein', _protein, 129.0, m.protein),
      (hu ? 'Szénhidrát' : 'Carbs', _carbs, 313.0, m.carbs),
      (hu ? 'Zsír' : 'Fat', _fat, 66.0, m.fat),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(spacing: AppSpacing.s8, runSpacing: AppSpacing.s8, children: [
          FilledButton(onPressed: _randomize, child: const Text('New values')),
          OutlinedButton(onPressed: () => setState(() => _key++), child: const Text('Replay entrance')),
        ]),
        const GalleryCaption('Hero composition (dashboard canvas)'),
        LifeyCard.hero(
          key: ValueKey(_key),
          child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            ProgressRing(
              progress: _eaten / goal,
              color: m.calories,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                MetricValue(value: f.kcal(left.abs()), size: 34),
                Text(
                  left >= 0 ? (hu ? 'kcal maradt' : 'kcal left') : (hu ? 'kcal túllépés' : 'kcal over'),
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: p.text2),
                ),
              ]),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                for (final (i, (name, v, g, c)) in macros.indexed) ...[
                  if (i > 0) const SizedBox(height: 14),
                  // The HU canvas rule: when label + value don't fit (dynamic
                  // type), the value drops under the label — never truncates.
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    spacing: AppSpacing.s8,
                    children: [
                      Text(name, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: p.text2)),
                      Text('${f.grams(v)} / ${f.grams(g)} g', style: Theme.of(context).textTheme.titleSmall),
                    ],
                  ),
                  const SizedBox(height: 6),
                  MetricBar(progress: v / g, color: c, delay: AppMotion.staggered(i)),
                ],
              ]),
            ),
          ]),
        ),
        const GalleryCaption('Rings — 0 %, 22 %, 100 %, 130 %, 300 % (overflow lap)'),
        Wrap(spacing: AppSpacing.s12, runSpacing: AppSpacing.s12, children: [
          for (final v in [0.0, 0.22, 1.0, 1.3, 3.0])
            ProgressRing(
              progress: v,
              color: m.calories,
              size: 88,
              child: Text('${(v * 100).round()}%', style: Theme.of(context).textTheme.titleSmall),
            ),
        ]),
        const GalleryCaption('Macro rings 88 (staggered) and week-strip rings 30'),
        Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          for (final (i, (_, v, g, c)) in macros.indexed)
            ProgressRing(progress: v / g, color: c, size: 88, delay: AppMotion.staggered(i),
                child: Text(f.grams(v), style: Theme.of(context).textTheme.titleLarge)),
        ]),
        const SizedBox(height: AppSpacing.s12),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          for (final v in [0.62, 0.95, 1.08, 0.4, 0.77, 0.9, _eaten / goal])
            ProgressRing(progress: v, color: m.calories, size: 30),
        ]),
        const GalleryCaption('Day budget — RatioBar against the kcal goal'),
        LifeyCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(child: MetricValue(value: f.kcal(_eaten), unit: '/ ${f.kcal(goal)} kcal', size: 28)),
              TintedChip(label: '${f.kcal(left.abs())} ${left >= 0 ? (hu ? 'maradt' : 'left') : (hu ? 'túl' : 'over')}', color: m.calories),
            ]),
            const SizedBox(height: AppSpacing.s12),
            RatioBar(total: goal, segments: [
              (value: _protein * 4, color: m.protein),
              (value: _carbs * 4, color: m.carbs),
              (value: _fat * 9, color: m.fat),
            ]),
          ]),
        ),
        const GalleryCaption('RatioBar — 100 % split (macros tab, 7 days)'),
        RatioBar(segments: [
          (value: 104 * 4, color: m.protein),
          (value: 188 * 4, color: m.carbs),
          (value: 58 * 9, color: m.fat),
        ]),
      ],
    );
  }
}

class _TilesSection extends StatelessWidget {
  const _TilesSection();

  @override
  Widget build(BuildContext context) {
    final m = context.metricColors;
    final f = LifeyFormat.of(context);
    final hu = _hu(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(
              child: MetricTile(
                icon: Icons.water_drop_rounded,
                label: hu ? 'Víz' : 'Water',
                value: f.litres(0.99),
                unit: '/ ${f.litres(2.6)} L',
                color: m.water,
                progress: 0.99 / 2.6,
                onAction: () {},
                actionTooltip: hu ? 'Víz hozzáadása' : 'Add water',
              ),
            ),
            const SizedBox(width: AppSpacing.s12),
            Expanded(
              child: MetricTile(
                icon: Icons.directions_walk_rounded,
                label: hu ? 'Lépések' : 'Steps',
                value: f.integer(6412),
                unit: hu ? '/ ${f.integer(10000)}' : 'of ${f.integer(10000)}',
                color: m.steps,
                progress: 0.6412,
              ),
            ),
          ]),
        ),
        const SizedBox(height: AppSpacing.s12),
        MetricTile(
          icon: Icons.monitor_weight_rounded,
          label: hu ? 'Súly' : 'Weight',
          value: f.weight(64.5),
          unit: 'kg',
          color: m.weight,
          delta: const DeltaChip.arrow(value: -0.1, unit: 'kg'),
          subline: hu ? 'Legutóbbi bejegyzés · ma' : 'Latest entry · today',
          onTap: () {},
        ),
      ],
    );
  }
}
