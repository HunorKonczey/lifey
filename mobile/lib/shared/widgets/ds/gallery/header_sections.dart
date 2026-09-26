import 'package:flutter/material.dart';

import '../../../../core/format/lifey_format.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../adaptive_bottom_nav.dart';
import '../../nav_collapse_controller.dart';
import '../lifey_header.dart';
import '../list_group.dart';
import '../monogram_avatar.dart';
import '../section_label.dart';
import 'gallery_section.dart';

/// Gallery section for R0.10. A pinned sliver header can't live inside the
/// gallery's own scroll view, so the section opens two real demo screens —
/// what the emulator review checks the header against the canvases with
/// (docs/redesign/77-mobile-redesign-plan.md R0.10).
final List<GallerySection> headerSections = [
  GallerySection(
    title: 'Headers',
    source: 'Design System › Fejléc · Lifey 1 top/scrolled · Lifey 2 Edit meal · Lifey 5 chat · R0.10',
    builder: (_) => const _HeadersSection(),
  ),
  GallerySection(
    title: 'Bottom nav',
    source: 'Design System › Alsó navigáció · Lifey 1 · R0.11',
    builder: (_) => const _NavSection(),
  ),
];

/// The real nav in a fixed box: tap tabs to see the pill travel, toggle the
/// scrolled (56 px) state.
class _NavSection extends StatefulWidget {
  const _NavSection();

  @override
  State<_NavSection> createState() => _NavSectionState();
}

class _NavSectionState extends State<_NavSection> {
  final _collapse = NavCollapseController();
  int _index = 0;

  @override
  void dispose() {
    _collapse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hu = _hu(context);
    final labels = hu
        ? ['Áttekintés', 'Étrend', 'Edzések', 'Súly', 'Statisztika']
        : ['Today', 'Nutrition', 'Workouts', 'Weight', 'Stats'];
    const icons = [
      (Icons.space_dashboard_outlined, Icons.space_dashboard_rounded),
      (Icons.restaurant_outlined, Icons.restaurant_rounded),
      (Icons.fitness_center_outlined, Icons.fitness_center_rounded),
      (Icons.monitor_weight_outlined, Icons.monitor_weight_rounded),
      (Icons.bar_chart_outlined, Icons.bar_chart_rounded),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton(
            onPressed: () => setState(() => _collapse.collapsed ? _collapse.expand() : _collapse.collapse()),
            child: Text(_collapse.collapsed ? 'Expand (68)' : 'Collapse (56)'),
          ),
        ),
        const SizedBox(height: AppSpacing.s8),
        // The nav keeps its own 16 px from the edges of this box.
        Container(
          color: context.palette.card,
          child: MediaQuery.removePadding(
            context: context,
            removeBottom: true,
            child: NavCollapseScope(
              controller: _collapse,
              child: AdaptiveBottomNav(
                selectedIndex: _index,
                onDestinationSelected: (i) => setState(() => _index = i),
                destinations: [
                  for (var i = 0; i < labels.length; i++)
                    AdaptiveNavDestination(icon: icons[i].$1, selectedIcon: icons[i].$2, label: labels[i]),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

bool _hu(BuildContext context) => Localizations.localeOf(context).languageCode == 'hu';

class _HeadersSection extends StatelessWidget {
  const _HeadersSection();

  @override
  Widget build(BuildContext context) {
    // The demos inherit the preview's theme, locale and text scale.
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context);
    final media = MediaQuery.of(context);
    void open(Widget screen) => Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (routeContext) => Theme(
            data: theme,
            child: Localizations.override(
              context: routeContext,
              locale: locale,
              child: MediaQuery(
                data: MediaQuery.of(routeContext).copyWith(
                  textScaler: media.textScaler,
                  disableAnimations: media.disableAnimations,
                ),
                child: screen,
              ),
            ),
          ),
        ));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Scroll the demos: nothing may show unblurred under the status bar; the large title '
          'shrinks 30 → 20, the date overline fades, the hairline appears once content is under it.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.palette.text3),
        ),
        const SizedBox(height: AppSpacing.s12),
        Wrap(spacing: AppSpacing.s8, runSpacing: AppSpacing.s8, children: [
          FilledButton(onPressed: () => open(const LargeTitleDemo()), child: const Text('Large title (Today)')),
          OutlinedButton(onPressed: () => open(const SubpageDemo()), child: const Text('Subpage (chat)')),
        ]),
      ],
    );
  }
}

/// Today-style page: date overline, greeting, chat + avatar, a long list.
class LargeTitleDemo extends StatelessWidget {
  const LargeTitleDemo({super.key});

  @override
  Widget build(BuildContext context) {
    final hu = _hu(context);
    final f = LifeyFormat.of(context);
    final m = context.metricColors;
    return Scaffold(
      body: CustomScrollView(slivers: [
        LifeyHeader(
          overline: f.dayLabel(DateTime(2026, 9, 24)),
          title: hu ? 'Jó reggelt, Anna' : 'Good morning, Anna',
          actions: [
            HeaderIconButton(
              icon: Icons.chat_bubble_outline_rounded,
              tooltip: hu ? 'Üzenetek' : 'Messages',
              showDot: true,
              onPressed: () {},
            ),
            const MonogramAvatar(name: 'Anna Kovács'),
          ],
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.s16, AppSpacing.screen, AppSpacing.s56),
          sliver: SliverList.list(children: [
            SectionLabel(hu ? 'Mai étkezések' : "Today's meals"),
            const SizedBox(height: AppSpacing.s8),
            for (var block = 0; block < 5; block++) ...[
              ListGroup(children: [
                for (var i = 0; i < 4; i++)
                  ListRow(
                    leading: ListIconHolder(icon: Icons.restaurant_rounded, color: [m.carbs, m.protein, m.calories, m.fat][i]),
                    title: '${hu ? 'Étkezés' : 'Meal'} ${block * 4 + i + 1}',
                    subtitle: hu ? 'Reggeli · 07:15' : 'Breakfast · 07:15',
                    trailing: ListRowValue(value: f.kcal(383 - i * 40), unit: 'kcal'),
                  ),
              ]),
              const SizedBox(height: AppSpacing.s24),
            ],
          ]),
        ),
      ]),
    );
  }
}

/// Chat-style subpage: back, avatar, name + status, search action.
class SubpageDemo extends StatelessWidget {
  const SubpageDemo({super.key});

  @override
  Widget build(BuildContext context) {
    final hu = _hu(context);
    final m = context.metricColors;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: LifeySubpageHeader(
        leading: MonogramAvatar(name: 'Mark Trainer', color: MonogramAvatar.colorFor('Mark Trainer', m)),
        title: 'Mark Trainer',
        subtitle: hu ? 'Az edződ · online' : 'Your trainer · online',
        subtitleColor: m.positive,
        actions: [
          HeaderIconButton(icon: Icons.search_rounded, tooltip: hu ? 'Keresés' : 'Search', onPressed: () {}),
        ],
      ),
      body: ListView.builder(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.screen,
          MediaQuery.paddingOf(context).top + 60 + AppSpacing.s16,
          AppSpacing.screen,
          AppSpacing.s56,
        ),
        itemCount: 40,
        itemBuilder: (context, i) => Align(
          alignment: i.isEven ? Alignment.centerLeft : Alignment.centerRight,
          child: Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.s8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: i.isEven ? context.palette.card : Theme.of(context).colorScheme.primary,
              borderRadius: AppRadius.cardAll,
            ),
            child: Text(
              '${hu ? 'Üzenet' : 'Message'} ${i + 1}',
              style: TextStyle(color: i.isEven ? context.palette.text : Theme.of(context).colorScheme.onPrimary),
            ),
          ),
        ),
      ),
    );
  }
}
