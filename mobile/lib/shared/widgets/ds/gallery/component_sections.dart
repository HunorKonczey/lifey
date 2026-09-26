import 'package:flutter/material.dart';

import '../../../../core/format/lifey_format.dart';
import '../../../../core/theme/app_tokens.dart';
import '../delta_chip.dart';
import '../lifey_card.dart';
import '../metric_value.dart';
import '../monogram_avatar.dart';
import '../notice_card.dart';
import '../section_label.dart';
import '../tinted_chip.dart';
import 'gallery_section.dart';

/// Gallery sections for the base components, one list per R0 step that adds
/// them (docs/redesign/77-mobile-redesign-plan.md R0.7 onwards).
final List<GallerySection> componentSections = [
  GallerySection(
    title: 'Cards & labels',
    source: 'Design System › Alapkomponensek › Kártya · R0.7',
    builder: (_) => const _CardsSection(),
  ),
  GallerySection(
    title: 'Chips & avatars',
    source: 'Design System › Színtokenek › Tinted chip · D-R0.4 · R0.7',
    builder: (_) => const _ChipsSection(),
  ),
  GallerySection(
    title: 'Notice cards',
    source: 'Lifey 1 › contextual cards (derived) · R1.8',
    builder: (_) => const _NoticeSection(),
  ),
];

bool _hu(BuildContext context) => Localizations.localeOf(context).languageCode == 'hu';

class _CardsSection extends StatefulWidget {
  const _CardsSection();

  @override
  State<_CardsSection> createState() => _CardsSectionState();
}

class _CardsSectionState extends State<_CardsSection> {
  int _taps = 0;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final hu = _hu(context);
    final f = LifeyFormat.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionLabel(
          hu ? 'Mai étkezések' : "Today's meals",
          actionLabel: hu ? 'Összes' : 'See all',
          onAction: () {},
        ),
        const SizedBox(height: AppSpacing.s8),
        LifeyCard(
          onTap: () => setState(() => _taps++),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('card · r22 · pad 16 · e1', style: Theme.of(context).textTheme.titleMedium),
                Text('Tap me — scales to 0.98, no ripple ($_taps)',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: p.text2)),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: AppSpacing.s24),
        LifeyCard.hero(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('hero · r30 · pad 20', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.s12),
            MetricValue(value: f.integer(1739), unit: hu ? 'kcal maradt' : 'kcal left', size: 34),
            const SizedBox(height: AppSpacing.s16),
            LifeyCard.nested(
              radius: AppRadius.nested(AppRadius.hero, AppSpacing.s20),
              child: Text('nested · surface-2 · r = 30 − 20 = 10',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: p.text2)),
            ),
          ]),
        ),
        const SizedBox(height: AppSpacing.s24),
        SectionLabel(hu ? 'Legutóbbi edzések' : 'Recent workouts'),
        const SizedBox(height: AppSpacing.s8),
        LifeyCard(
          padding: EdgeInsets.zero,
          child: Column(children: [
            for (final (i, row) in [
              (hu ? 'Zabkása bogyókkal' : 'Oats & berries', hu ? 'Reggeli · 07:15' : 'Breakfast · 07:15'),
              (hu ? 'Nasi' : 'Snack', hu ? 'Alma, mandula · 08:27' : 'Apple, Almonds · 08:27'),
            ].indexed) ...[
              if (i > 0) Divider(height: 1, thickness: 1, indent: 16, endIndent: 16, color: p.hairline),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(row.$1, style: Theme.of(context).textTheme.titleMedium),
                      Text(row.$2, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: p.text2)),
                    ]),
                  ),
                  Text('${f.kcal(383 - i * 145)} kcal', style: Theme.of(context).textTheme.titleSmall),
                ]),
              ),
            ],
          ]),
        ),
        const SizedBox(height: AppSpacing.s8),
        Text('One card, rows split by hairlines — never a card in a card.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: p.text3)),
      ],
    );
  }
}

class _ChipsSection extends StatelessWidget {
  const _ChipsSection();

  @override
  Widget build(BuildContext context) {
    final m = context.metricColors;
    final hu = _hu(context);
    final f = LifeyFormat.of(context);
    Widget row(List<Widget> children) =>
        Wrap(spacing: AppSpacing.s8, runSpacing: AppSpacing.s8, children: children);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const GalleryCaption('TintedChip — canvas row (medium 32)'),
        row([
          TintedChip(label: '${f.integer(1739)} ${hu ? 'kcal maradt' : 'kcal left'}', color: m.calories, size: TintedChipSize.medium),
          TintedChip(label: hu ? 'még 100 g' : '100 g to go', color: m.protein, size: TintedChipSize.medium),
          TintedChip(label: 'PR ${f.integer(50)} kg', color: m.record, size: TintedChipSize.medium),
          TintedChip(label: '${f.signedDelta(-0.1)} kg', color: m.weight, size: TintedChipSize.medium),
        ]),
        const GalleryCaption('TintedChip — small 26, all metrics'),
        row([
          for (final (name, c) in [
            ('Calories', m.calories), ('Protein', m.protein), ('Carbs', m.carbs), ('Fat', m.fat),
            ('Water', m.water), ('Steps', m.steps), ('Weight', m.weight), ('Heart', m.heart),
          ])
            TintedChip(label: name, color: c),
        ]),
        const GalleryCaption('DeltaChip — arrow (tile, hero)'),
        row([
          const DeltaChip.arrow(value: -0.1, unit: 'kg'),
          DeltaChip.arrow(value: -0.1, suffix: hu ? 'ma' : 'today'),
          DeltaChip.arrow(value: -1.4, suffix: hu ? '30 napban' : 'in 30 d', color: m.improvement),
          const DeltaChip.arrow(value: 0.3, unit: 'kg'),
          const DeltaChip.arrow(value: 0.02, unit: 'kg'),
        ]),
        const GalleryCaption('DeltaChip — signed (history rows)'),
        row(const [
          DeltaChip.signed(value: -0.1),
          DeltaChip.signed(value: -0.3),
          DeltaChip.signed(value: 0.3),
          DeltaChip.signed(value: 0),
        ]),
        const GalleryCaption('Record 🏆 carbs gold · improvement ↑ protein green'),
        row([
          RecordChip(label: hu ? '2 PR' : '2 PRs'),
          ImprovementChip(label: '+${f.weight(2.5)} kg'),
        ]),
        const GalleryCaption('MonogramAvatar — 44 / 48 / 56, self olive, others by name'),
        Wrap(spacing: AppSpacing.s12, runSpacing: AppSpacing.s12, crossAxisAlignment: WrapCrossAlignment.center, children: [
          const MonogramAvatar(name: 'Anna Kovács'),
          const MonogramAvatar(name: 'Anna Kovács', size: 56),
          for (final n in ['Bence Nagy', 'Mark Trainer', 'Eszter Szabó', 'Gábor Tóth'])
            MonogramAvatar(name: n, size: 48, color: MonogramAvatar.colorFor(n, m)),
          const MonogramAvatar(email: 'anna.kovacs@mail.com'),
          const MonogramAvatar(),
        ]),
      ],
    );
  }
}

/// The contextual cards of the Today screen: brand-olive for the app's own
/// nudges, clay for anything a trainer sent.
class _NoticeSection extends StatelessWidget {
  const _NoticeSection();

  @override
  Widget build(BuildContext context) {
    final hu = _hu(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        NoticeCard(
          icon: Icons.eco_rounded,
          title: hu ? 'Fejezd be a profilodat' : 'Finish your profile',
          body: hu
              ? 'Pár kérdés, és a célok a te adataidra épülnek.'
              : 'A few questions, and your goals are based on your own numbers.',
          actionLabel: hu ? 'Beállítás' : 'Set up',
          onAction: () {},
          onDismiss: () {},
          dismissTooltip: hu ? 'Elrejtés' : 'Dismiss',
        ),
        const SizedBox(height: AppSpacing.s12),
        NoticeCard(
          icon: Icons.auto_awesome_rounded,
          title: hu ? 'Elkészült a heti összefoglalód' : 'Your weekly recap is ready',
          actionLabel: hu ? 'Megnézem' : 'View',
          onAction: () {},
          onDismiss: () {},
          dismissTooltip: hu ? 'Elrejtés' : 'Dismiss',
        ),
        const SizedBox(height: AppSpacing.s12),
        NoticeCard(
          icon: Icons.bolt_rounded,
          overline: hu ? 'Ajánlott edzés' : 'Recommended workout',
          title: 'Push day',
          onTap: () {},
          trailing: Icon(Icons.play_circle_fill_rounded, size: 30, color: Theme.of(context).colorScheme.primary),
        ),
        const SizedBox(height: AppSpacing.s12),
        NoticeCard(
          icon: Icons.info_outline_rounded,
          accent: context.palette.role,
          title: hu ? 'Az edződ Pro-ja lejárt' : "Your coach's Pro has ended",
          body: hu ? 'Az adataid megvannak, semmi sem veszett el.' : 'Your data is all still here.',
          onDismiss: () {},
          dismissTooltip: hu ? 'Elrejtés' : 'Dismiss',
        ),
      ],
    );
  }
}
