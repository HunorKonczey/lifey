import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../../../core/format/lifey_format.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/theme/app_type.dart';
import '../../../../core/theme/contrast.dart';
import '../animated_number.dart';
import '../card_edge_painter.dart';
import '../metric_value.dart';
import '../pressable.dart';
import 'gallery_section.dart';

/// Gallery sections for the R0.1–R0.5 foundation: tokens, type, formatting,
/// motion and icons (docs/redesign/77-mobile-redesign-plan.md R0.6).
final List<GallerySection> foundationSections = [
  GallerySection(
    title: 'Colour',
    source: 'Design System › Színtokenek · D-R0.2 / D-R0.3',
    builder: (_) => const _ColourSection(),
  ),
  GallerySection(
    title: 'Type',
    source: 'Design System › Tipográfia · D-R0.7 / D-R0.8',
    builder: (_) => const _TypeSection(),
  ),
  GallerySection(
    title: 'Formatting',
    source: 'Design System › Tipográfia › Szabályok · R0.4',
    builder: (_) => const _FormatSection(),
  ),
  GallerySection(
    title: 'Spacing & radius',
    source: 'Design System › Térköz, Lekerekítés · D-R0.5 / D-R0.6',
    builder: (_) => const _SpacingRadiusSection(),
  ),
  GallerySection(
    title: 'Elevation',
    source: 'Design System › Eleváció · R0.2',
    builder: (_) => const _ElevationSection(),
  ),
  GallerySection(
    title: 'Motion',
    source: 'Design System › Mozgás · D-R0.13',
    builder: (_) => const _MotionSection(),
  ),
  GallerySection(
    title: 'Icons',
    source: 'Material Symbols → Material Icons mapping · D-R0.10',
    builder: (_) => const _IconSection(),
  ),
];

bool _dark(BuildContext context) => Theme.of(context).brightness == Brightness.dark;

// ---------------------------------------------------------------------------
// Colour
// ---------------------------------------------------------------------------

class _ColourSection extends StatelessWidget {
  const _ColourSection();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final m = context.metricColors;
    final scheme = Theme.of(context).colorScheme;
    final tintAlpha = _dark(context) ? 0.16 : 0.12;
    final metrics = <(String, Color)>[
      ('Calories', m.calories),
      ('Protein', m.protein),
      ('Carbs', m.carbs),
      ('Fat', m.fat),
      ('Water', m.water),
      ('Steps', m.steps),
      ('Weight', m.weight),
      ('Heart', m.heart),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const GalleryCaption('Surfaces'),
        Wrap(spacing: AppSpacing.s8, runSpacing: AppSpacing.s8, children: [
          _Swatch('bg', p.bg),
          _Swatch('card', p.card),
          _Swatch('nested', p.nested),
          _Swatch('control', p.control),
          _Swatch('raised (derived)', p.raised),
          _Swatch('float', p.float),
          _Swatch('scrim', p.scrim),
          _Swatch('hairline', p.hairline),
        ]),
        const GalleryCaption('Text tiers — ratio on each surface'),
        for (final (name, surface) in [('bg', p.bg), ('card', p.card), ('nested', p.nested)])
          Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.s8),
            padding: const EdgeInsets.all(AppSpacing.s12),
            decoration: BoxDecoration(color: surface, borderRadius: AppRadius.controlAll),
            child: Row(children: [
              SizedBox(width: 64, child: Text(name, style: TextStyle(color: p.text3, fontSize: 12))),
              for (final (tier, c) in [('text', p.text), ('text2', p.text2), ('text3', p.text3)])
                Expanded(child: _RatioText(label: tier, color: c, on: surface)),
            ]),
          ),
        const GalleryCaption('Brand — controls only'),
        Wrap(spacing: AppSpacing.s8, runSpacing: AppSpacing.s8, children: [
          _Chip(label: 'primary', fg: scheme.onPrimary, bg: scheme.primary),
          _Chip(label: 'primary tint', fg: p.onPrimaryTint, bg: Color.alphaBlend(p.primaryTint, p.card)),
          _Chip(label: 'role (clay)', fg: p.role, bg: tintOver(p.role, tintAlpha, p.card)),
        ]),
        GalleryCaption('Metrics — text on card, chip at ${(tintAlpha * 100).round()} % tint'),
        for (final (name, c) in metrics)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.s8),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(color: c, borderRadius: AppRadius.tagAll),
              ),
              const SizedBox(width: AppSpacing.s12),
              Expanded(
                child: Wrap(
                  spacing: AppSpacing.s12,
                  runSpacing: AppSpacing.s4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(name, style: Theme.of(context).textTheme.titleSmall),
                    Text(hexOf(c), style: TextStyle(color: p.text3, fontSize: 12)),
                    _RatioText(label: 'card', color: c, on: p.card),
                    _Chip(label: name, fg: c, bg: tintOver(c, tintAlpha, p.card)),
                  ],
                ),
              ),
            ]),
          ),
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch(this.name, this.color);

  final String name;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return SizedBox(
      width: 104,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          height: 48,
          decoration: BoxDecoration(
            color: color,
            borderRadius: AppRadius.controlAll,
            border: Border.all(color: context.elevation.border),
          ),
        ),
        const SizedBox(height: AppSpacing.s4),
        Text(name, style: TextStyle(color: p.text, fontSize: 12, fontWeight: FontWeight.w700)),
        Text(hexOf(color), style: TextStyle(color: p.text3, fontSize: 11)),
      ]),
    );
  }
}

class _RatioText extends StatelessWidget {
  const _RatioText({required this.label, required this.color, required this.on});

  final String label;
  final Color color;
  final Color on;

  @override
  Widget build(BuildContext context) {
    final ratio = contrastRatio(color, on);
    return Text.rich(
      TextSpan(children: [
        TextSpan(text: 'Aa ', style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 16)),
        TextSpan(
          text: '$label ${ratio.toStringAsFixed(1)}:1${ratio < 4.5 ? ' ✗' : ''}',
          style: TextStyle(color: ratio < 4.5 ? Colors.red : color, fontSize: 12),
        ),
      ]),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.fg, required this.bg});

  final String label;
  final Color fg;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    final ratio = contrastRatio(fg, bg);
    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      alignment: Alignment.center,
      decoration: BoxDecoration(color: bg, borderRadius: AppRadius.pill),
      child: Text(
        '$label · ${ratio.toStringAsFixed(1)}',
        style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Type
// ---------------------------------------------------------------------------

class _TypeSection extends StatelessWidget {
  const _TypeSection();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final hu = Localizations.localeOf(context).languageCode == 'hu';
    final f = LifeyFormat.of(context);
    String s(String en, String huText) => hu ? huText : en;
    final roles = <(String, TextStyle?, String)>[
      ('displayLarge · display-xl', t.displayLarge, f.integer(1739)),
      ('displayMedium · display', t.displayMedium, '${f.weight(64.5)} kg'),
      ('headlineMedium · headline', t.headlineMedium, s('Good morning, Anna', 'Jó reggelt, Anna')),
      ('titleLarge · title', t.titleLarge, s('Push day · Bench Press', 'Push nap · Fekvenyomás')),
      ('titleMedium · title-s', t.titleMedium, s('Oats & berries', 'Zabkása bogyókkal')),
      ('bodyLarge · list title', t.bodyLarge, s('Greek yogurt 2%', 'Görög joghurt 2%')),
      ('bodyMedium · body', t.bodyMedium, s('Rolled oats, Greek yogurt 2%, Blueberries', 'Zabpehely, görög joghurt 2%, áfonya')),
      ('bodySmall · body-s', t.bodySmall,
          s('Based on a BMR of 1 384 kcal and a TDEE of 2 145 kcal', 'BMR 1 384 kcal és TDEE 2 145 kcal alapján')),
      ('labelLarge · button', t.labelLarge, s('Apply these goals', 'Célok alkalmazása')),
      ('labelMedium · chip', t.labelMedium, s('Breakfast', 'Reggeli')),
      ('labelSmall · label', t.labelSmall, s('Latest entry · today', 'Legutóbbi bejegyzés · ma')),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (name, style, sample) in roles) _TypeRow(name: name, style: style!, sample: sample),
        const GalleryCaption('Section label (AppType.sectionLabel)'),
        Text(s("Today's meals", 'Mai étkezések').toUpperCase(),
            style: AppType.sectionLabel(color: context.palette.text2)),
        const GalleryCaption('Hero numbers (MetricValue — fixed under dynamic type)'),
        Wrap(
          spacing: AppSpacing.s24,
          runSpacing: AppSpacing.s16,
          crossAxisAlignment: WrapCrossAlignment.end,
          children: [
            MetricValue(value: f.integer(1739), unit: 'kcal', size: 34),
            const MetricValue(value: '1:28', size: 44),
            MetricValue(value: f.distance(4.52), unit: 'km', size: 52),
            MetricValue(value: f.weight(64.5), unit: 'kg', size: 64),
            const MetricValue(value: '24:18', size: 104),
          ],
        ),
      ],
    );
  }
}

class _TypeRow extends StatelessWidget {
  const _TypeRow({required this.name, required this.style, required this.sample});

  final String name;
  final TextStyle style;
  final String sample;

  @override
  Widget build(BuildContext context) {
    final size = style.fontSize ?? 14;
    final line = (style.height ?? 1) * size;
    final tracking = style.letterSpacing == null ? '' : ' · ${(style.letterSpacing! / size * 100).toStringAsFixed(1)} %';
    final weight = style.fontWeight?.value ?? 400;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          '$name — ${size.toStringAsFixed(0)}/${line.toStringAsFixed(0)} · $weight$tracking'
          '${style.fontFeatures?.isNotEmpty ?? false ? ' · tnum' : ''}',
          style: TextStyle(color: context.palette.text3, fontSize: 11),
        ),
        Text(sample, style: style),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------
// Formatting
// ---------------------------------------------------------------------------

class _FormatSection extends StatelessWidget {
  const _FormatSection();

  @override
  Widget build(BuildContext context) {
    final f = LifeyFormat.of(context);
    final day = DateTime(2026, 9, 24, 7, 15);
    final monday = DateTime(2026, 9, 21);
    final rows = <(String, String)>[
      ('kcal(17518.6)', f.kcal(17518.6)),
      ('integer(255960)', f.integer(255960)),
      ('weight(64.5)', f.weight(64.5)),
      ('distance(5.2104)', f.distance(5.2104)),
      ('litres(0.99) · litres(2.6) · litres(1)', '${f.litres(0.99)} · ${f.litres(2.6)} · ${f.litres(1)}'),
      ('signedDelta(−0.1) · (2.5) · (0.04)', '${f.signedDelta(-0.1)} · ${f.signedDelta(2.5)} · ${f.signedDelta(0.04)}'),
      ('percent(0.26)', f.percent(0.26)),
      ('compactAxis(0 / 1200 / 13000)', '${f.compactAxis(0)} · ${f.compactAxis(1200)} · ${f.compactAxis(13000)}'),
      ('dayLabel', f.dayLabel(day)),
      ('shortDayLabel · time', '${f.shortDayLabel(day)} · ${f.time(day)}'),
      ('weekdayNarrow (Mon → Sun)', [for (var i = 0; i < 7; i++) f.weekdayNarrow(monday.add(Duration(days: i)))].join(' ')),
    ];
    final p = context.palette;
    return Container(
      decoration: BoxDecoration(color: p.card, borderRadius: AppRadius.cardAll),
      padding: const EdgeInsets.all(AppSpacing.s16),
      child: Column(children: [
        for (final (call, out) in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.s4),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: Text(call, style: TextStyle(color: p.text3, fontSize: 12))),
              const SizedBox(width: AppSpacing.s12),
              Expanded(child: Text(out, style: Theme.of(context).textTheme.titleSmall)),
            ]),
          ),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------
// Spacing & radius
// ---------------------------------------------------------------------------

class _SpacingRadiusSection extends StatelessWidget {
  const _SpacingRadiusSection();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    const spacing = <(double, String)>[
      (AppSpacing.s4, 'icon ↔ label'),
      (AppSpacing.s8, 'chip gap, tight group'),
      (AppSpacing.s12, 'list-row inner'),
      (AppSpacing.s16, 'card padding'),
      (AppSpacing.s20, 'screen margin'),
      (AppSpacing.s24, 'between cards'),
      (AppSpacing.s32, 'between sections'),
      (AppSpacing.s40, 'above a hero'),
      (AppSpacing.s56, 'screen bottom, above nav'),
    ];
    final radii = <(String, BorderRadius)>[
      ('tag 8', AppRadius.tagAll),
      ('control 14', AppRadius.controlAll),
      ('card 22', AppRadius.cardAll),
      ('hero 30', AppRadius.heroAll),
      ('pill', AppRadius.pill),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (v, use) in spacing)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.s8),
            child: Row(children: [
              SizedBox(width: 32, child: Text('${v.round()}', style: Theme.of(context).textTheme.titleSmall)),
              Container(width: v * 3, height: 14, color: Color.alphaBlend(p.primaryTint, p.card)),
              const SizedBox(width: AppSpacing.s12),
              Expanded(child: Text(use, style: TextStyle(color: p.text2, fontSize: 13))),
            ]),
          ),
        const GalleryCaption('Radius — nested = parent − inset'),
        Wrap(spacing: AppSpacing.s12, runSpacing: AppSpacing.s12, children: [
          for (final (name, r) in radii)
            Column(children: [
              Container(
                width: 88,
                height: 64,
                decoration: BoxDecoration(color: p.card, borderRadius: r, border: Border.all(color: context.elevation.border)),
              ),
              const SizedBox(height: AppSpacing.s4),
              Text(name, style: TextStyle(color: p.text2, fontSize: 12)),
            ]),
        ]),
        const SizedBox(height: AppSpacing.s12),
        Container(
          padding: const EdgeInsets.all(AppSpacing.s16),
          decoration: BoxDecoration(color: p.card, borderRadius: AppRadius.heroAll),
          child: Container(
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: p.nested,
              borderRadius: BorderRadius.circular(AppRadius.nested(AppRadius.hero, AppSpacing.s16)),
            ),
            child: Text('hero 30 − inset 16 = 14', style: TextStyle(color: p.text2, fontSize: 12)),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Elevation
// ---------------------------------------------------------------------------

class _ElevationSection extends StatelessWidget {
  const _ElevationSection();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final e = context.elevation;
    Widget box(String label, Color fill, List<BoxShadow> shadow, Color edge, double radius, {bool border = false}) {
      final r = BorderRadius.circular(radius);
      return Container(
        height: 72,
        margin: const EdgeInsets.only(bottom: AppSpacing.s16),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: r,
          boxShadow: shadow,
          border: border ? Border.all(color: e.border) : null,
        ),
        child: CustomPaint(
          foregroundPainter: CardEdgePainter(color: edge, borderRadius: r),
          child: Center(child: Text(label, style: TextStyle(color: p.text2, fontSize: 13))),
        ),
      );
    }

    return Column(children: [
      box('e0 · hairline border', p.card, const [], const Color(0x00000000), AppRadius.card, border: true),
      box('e1 · card (top light edge in dark)', p.card, e.e1, e.cardEdge, AppRadius.card),
      box('e2 · hero, FAB', p.nested, e.e2, e.heroEdge, AppRadius.hero),
      // e3 sits over busy content so the blur is visible.
      SizedBox(
        height: 88,
        child: Stack(children: [
          Positioned.fill(
            child: Row(children: [
              for (final c in [context.metricColors.calories, context.metricColors.water, context.metricColors.protein])
                Expanded(child: Container(margin: const EdgeInsets.all(6), color: c)),
            ]),
          ),
          Positioned.fill(
            top: 8,
            child: ClipRRect(
              borderRadius: AppRadius.heroAll,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: AppElevation.floatBlur, sigmaY: AppElevation.floatBlur),
                child: box('e3 · nav, sheet — float + blur 24', p.float, e.e3, e.floatEdge, AppRadius.hero),
              ),
            ),
          ),
        ]),
      ),
    ]);
  }
}

// ---------------------------------------------------------------------------
// Motion
// ---------------------------------------------------------------------------

class _MotionSection extends StatefulWidget {
  const _MotionSection();

  @override
  State<_MotionSection> createState() => _MotionSectionState();
}

class _MotionSectionState extends State<_MotionSection> {
  final _random = math.Random(7);
  int _kcal = 1739;
  int _taps = 0;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final f = LifeyFormat.of(context);
    final reduced = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    const specs = <(String, Duration)>[
      ('tap', AppMotion.tap),
      ('set done', AppMotion.setDone),
      ('page', AppMotion.page),
      ('sheet', AppMotion.sheet),
      ('count-up', AppMotion.countUp),
      ('ring / bar fill', AppMotion.fill),
      ('stagger', AppMotion.stagger),
      ('celebration', AppMotion.celebration),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          reduced ? 'Reduced motion is ON — everything should jump.' : 'Reduced motion is off.',
          style: TextStyle(color: p.text3, fontSize: 12),
        ),
        const GalleryCaption('Count-up — AnimatedNumber'),
        // Stacked, not side by side: a hero number never wraps (MetricValue
        // is single-line), so it needs the full width.
        AnimatedNumber(
          value: _kcal,
          semanticsLabel: '${f.kcal(_kcal)} kcal',
          builder: (context, v) => MetricValue(value: f.kcal(v), unit: 'kcal', size: 44),
        ),
        const SizedBox(height: AppSpacing.s12),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton(
            onPressed: () => setState(() => _kcal = 200 + _random.nextInt(3000)),
            child: const Text('New value'),
          ),
        ),
        const GalleryCaption('Tap — Pressable (0.98, no ripple)'),
        Pressable(
          onTap: () => setState(() => _taps++),
          child: Container(
            height: 72,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: p.card, borderRadius: AppRadius.cardAll, boxShadow: context.elevation.e1),
            child: Text('Tapped $_taps×', style: Theme.of(context).textTheme.titleMedium),
          ),
        ),
        const GalleryCaption('Durations'),
        Wrap(spacing: AppSpacing.s8, runSpacing: AppSpacing.s8, children: [
          for (final (name, d) in specs)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: p.control, borderRadius: AppRadius.pill),
              child: Text('$name ${d.inMilliseconds} ms', style: TextStyle(color: p.text2, fontSize: 12)),
            ),
        ]),
        const SizedBox(height: AppSpacing.s8),
        Text('Page transitions: open any screen (shared-axis X) or switch tabs (fade-through).',
            style: TextStyle(color: p.text3, fontSize: 12)),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Icons
// ---------------------------------------------------------------------------

class _IconSection extends StatelessWidget {
  const _IconSection();

  /// Canvas Material Symbol name → the Flutter icons used for it
  /// (outlined = inactive, rounded = active / filled).
  static const List<(String, IconData, IconData)> mapping = [
    ('space_dashboard', Icons.space_dashboard_outlined, Icons.space_dashboard_rounded),
    ('restaurant', Icons.restaurant_outlined, Icons.restaurant_rounded),
    ('fitness_center', Icons.fitness_center_outlined, Icons.fitness_center_rounded),
    ('monitor_weight', Icons.monitor_weight_outlined, Icons.monitor_weight_rounded),
    ('bar_chart', Icons.bar_chart_outlined, Icons.bar_chart_rounded),
    ('local_fire_department', Icons.local_fire_department_outlined, Icons.local_fire_department_rounded),
    ('water_drop', Icons.water_drop_outlined, Icons.water_drop_rounded),
    ('directions_walk', Icons.directions_walk_outlined, Icons.directions_walk_rounded),
    ('directions_run', Icons.directions_run_outlined, Icons.directions_run_rounded),
    ('chat_bubble', Icons.chat_bubble_outline_rounded, Icons.chat_bubble_rounded),
    ('trophy → emoji_events', Icons.emoji_events_outlined, Icons.emoji_events_rounded),
    ('barcode_scanner → qr_code_scanner', Icons.qr_code_scanner_outlined, Icons.qr_code_scanner_rounded),
    ('south / north', Icons.south_rounded, Icons.north_rounded),
    ('arrow_upward', Icons.arrow_upward_outlined, Icons.arrow_upward_rounded),
    ('photo_camera', Icons.photo_camera_outlined, Icons.photo_camera_rounded),
    ('content_copy', Icons.content_copy_outlined, Icons.content_copy_rounded),
    ('tune', Icons.tune_outlined, Icons.tune_rounded),
    ('schedule', Icons.schedule_outlined, Icons.schedule_rounded),
    ('calendar_month', Icons.calendar_month_outlined, Icons.calendar_month_rounded),
    ('favorite', Icons.favorite_outline_rounded, Icons.favorite_rounded),
    ('timer', Icons.timer_outlined, Icons.timer_rounded),
    ('music_note', Icons.music_note_outlined, Icons.music_note_rounded),
    ('flag', Icons.flag_outlined, Icons.flag_rounded),
    ('auto_awesome', Icons.auto_awesome_outlined, Icons.auto_awesome_rounded),
    ('cloud_off', Icons.cloud_off_outlined, Icons.cloud_off_rounded),
    ('star', Icons.star_outline_rounded, Icons.star_rounded),
    ('group', Icons.group_outlined, Icons.group_rounded),
    ('assignment', Icons.assignment_outlined, Icons.assignment_rounded),
    ('view_list', Icons.view_list_outlined, Icons.view_list_rounded),
    ('logout', Icons.logout_outlined, Icons.logout_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(children: [
      for (final (name, inactive, active) in mapping)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(children: [
            Icon(inactive, color: p.text2),
            const SizedBox(width: AppSpacing.s12),
            Icon(active, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: AppSpacing.s16),
            Expanded(child: Text(name, style: TextStyle(color: p.text, fontSize: 13))),
          ]),
        ),
    ]);
  }
}
