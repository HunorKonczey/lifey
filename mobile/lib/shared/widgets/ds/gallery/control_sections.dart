import 'package:flutter/material.dart';

import '../../../../core/format/lifey_format.dart';
import '../../../../core/theme/app_component_themes.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../app_snackbar.dart';
import '../../pill_tab_bar.dart';
import '../lifey_segmented.dart';
import '../list_group.dart';
import 'gallery_section.dart';

/// Gallery sections for R0.8: buttons, chips, segmented control, tab bar,
/// list rows, inputs, dialog and snackbar (docs/redesign/
/// 77-mobile-redesign-plan.md R0.8).
final List<GallerySection> controlSections = [
  GallerySection(
    title: 'Buttons',
    source: 'Design System › Alapkomponensek › Gombok · R0.8',
    builder: (_) => const _ButtonsSection(),
  ),
  GallerySection(
    title: 'Chips & switchers',
    source: 'Design System › Chip, Szegmentált váltó · Lifey 2 › tabs · R0.8',
    builder: (_) => const _SwitchersSection(),
  ),
  GallerySection(
    title: 'List rows',
    source: 'Design System › Lista-sor · Lifey 1 › Today’s meals · R0.8',
    builder: (_) => const _ListSection(),
  ),
  GallerySection(
    title: 'Inputs & overlays',
    source: 'Lifey 5 › Login, Log out · Lifey 2 › Add food · R0.8',
    builder: (_) => const _InputsSection(),
  ),
];

bool _hu(BuildContext context) => Localizations.localeOf(context).languageCode == 'hu';

class _ButtonsSection extends StatelessWidget {
  const _ButtonsSection();

  @override
  Widget build(BuildContext context) {
    final hu = _hu(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton(
          style: lifeyLargeButtonStyle,
          onPressed: () {},
          child: Text(hu ? 'Célok alkalmazása' : 'Apply these goals'),
        ),
        const SizedBox(height: AppSpacing.s12),
        Row(children: [
          Expanded(child: OutlinedButton(onPressed: () {}, child: Text(hu ? 'Másodlagos' : 'Secondary'))),
          const SizedBox(width: AppSpacing.s8),
          Expanded(child: TextButton(onPressed: () {}, child: Text(hu ? 'Szöveges gomb' : 'Text button'))),
        ]),
        const SizedBox(height: AppSpacing.s12),
        Wrap(spacing: AppSpacing.s8, runSpacing: AppSpacing.s8, children: [
          FilledButton(onPressed: () {}, child: Text(hu ? 'Alap' : 'Default 48')),
          const FilledButton(onPressed: null, child: Text('Disabled')),
        ]),
        const SizedBox(height: AppSpacing.s16),
        Row(children: [
          FloatingActionButton.extended(
            heroTag: null,
            onPressed: () {},
            icon: const Icon(Icons.add_rounded, size: 24),
            label: Text(hu ? 'Étkezés' : 'Meal'),
          ),
          const SizedBox(width: AppSpacing.s12),
          SquareIconButton(icon: Icons.content_copy_rounded, onPressed: () {}, tooltip: 'Copy'),
        ]),
      ],
    );
  }
}

class _SwitchersSection extends StatefulWidget {
  const _SwitchersSection();

  @override
  State<_SwitchersSection> createState() => _SwitchersSectionState();
}

class _SwitchersSectionState extends State<_SwitchersSection> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 4, vsync: this);
  String _meal = 'b';
  final Set<String> _filters = {'fav'};
  int _range = 7;

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hu = _hu(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const GalleryCaption('Choice chips — single'),
        Wrap(spacing: AppSpacing.s8, runSpacing: AppSpacing.s8, children: [
          for (final (id, en, huLabel) in [('b', 'Breakfast', 'Reggeli'), ('l', 'Lunch', 'Ebéd'), ('d', 'Dinner', 'Vacsora'), ('s', 'Snack', 'Nasi')])
            ChoiceChip(
              label: Text(hu ? huLabel : en),
              selected: _meal == id,
              onSelected: (_) => setState(() => _meal = id),
            ),
        ]),
        const GalleryCaption('Filter chips — multi'),
        Wrap(spacing: AppSpacing.s8, runSpacing: AppSpacing.s8, children: [
          for (final (id, en, huLabel) in [('fav', 'Favourites', 'Kedvencek'), ('hp', 'High protein', 'Magas fehérje'), ('lk', '< 400 kcal', '< 400 kcal')])
            FilterChip(
              label: Text(hu ? huLabel : en),
              selected: _filters.contains(id),
              onSelected: (on) => setState(() => on ? _filters.add(id) : _filters.remove(id)),
            ),
        ]),
        const GalleryCaption('LifeySegmented'),
        LifeySegmented<int>(
          segments: [
            (7, hu ? '7 nap' : '7 days'),
            (30, hu ? '30 nap' : '30 days'),
            (90, hu ? '90 nap' : '90 days'),
            (0, hu ? 'Mind' : 'All'),
          ],
          selected: _range,
          onChanged: (v) => setState(() => _range = v),
        ),
        const GalleryCaption('PillTabBar (has its own 20 px screen margin)'),
        PillTabBar(controller: _tabs, tabs: [
          Tab(text: hu ? 'Étkezések' : 'Meals'),
          Tab(text: hu ? 'Receptek' : 'Recipes'),
          Tab(text: hu ? 'Ételek' : 'Foods'),
          Tab(text: hu ? 'Makrók' : 'Macros'),
        ]),
      ],
    );
  }
}

class _ListSection extends StatelessWidget {
  const _ListSection();

  @override
  Widget build(BuildContext context) {
    final m = context.metricColors;
    final p = context.palette;
    final f = LifeyFormat.of(context);
    final hu = _hu(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListGroup(children: [
          ListRow(
            leading: ListIconHolder(icon: Icons.bakery_dining_rounded, color: m.carbs),
            title: hu ? 'Zabkása bogyókkal' : 'Oats & berries',
            subtitle: hu ? 'Reggeli · 07:15' : 'Breakfast · 07:15',
            trailing: ListRowValue(value: f.kcal(383), unit: 'kcal'),
            onTap: () {},
          ),
          ListRow(
            leading: ListIconHolder(icon: Icons.apple_rounded, color: m.protein),
            title: hu ? 'Nasi' : 'Snack',
            subtitle: hu
                ? 'Alma, mandula, görög joghurt 2%, áfonya, zabpehely · 08:27'
                : 'Apple, Almonds, Greek yogurt 2%, Blueberries, Rolled oats · 08:27',
            trailing: ListRowValue(value: f.kcal(238), unit: 'kcal'),
            onTap: () {},
          ),
          ListRow(
            leading: ListIconHolder(icon: Icons.directions_run_rounded, color: m.calories),
            title: hu ? 'Futás' : 'Running',
            subtitle: hu ? 'K 07:45 · 5,21 km · 28 perc' : 'Tue 07:45 · 5.21 km · 28 min',
            trailing: Icon(Icons.chevron_right_rounded, color: p.text2),
            onTap: () {},
          ),
        ]),
        const SizedBox(height: AppSpacing.s12),
        ListGroup(dividerInset: AppSpacing.s16, children: [
          ListRow(title: hu ? 'Mértékegységek' : 'Units', trailing: Text(hu ? 'Metrikus' : 'Metric', style: TextStyle(color: p.text2))),
          ListRow(title: hu ? 'Nyelv' : 'Language', trailing: Icon(Icons.chevron_right_rounded, color: p.text2), onTap: () {}),
        ]),
      ],
    );
  }
}

class _InputsSection extends StatelessWidget {
  const _InputsSection();

  @override
  Widget build(BuildContext context) {
    final hu = _hu(context);
    final m = context.metricColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          decoration: InputDecoration(
            hintText: hu ? 'Ételek keresése' : 'Search foods',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: const Icon(Icons.qr_code_scanner_rounded),
          ),
        ),
        const SizedBox(height: AppSpacing.s12),
        TextField(
          decoration: InputDecoration(
            labelText: 'Email',
            prefixIcon: const Icon(Icons.mail_outline_rounded),
            errorText: hu ? 'Érvénytelen e-mail cím' : 'Not a valid e-mail address',
          ),
        ),
        const SizedBox(height: AppSpacing.s16),
        Wrap(spacing: AppSpacing.s8, runSpacing: AppSpacing.s8, children: [
          OutlinedButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (context) => AlertDialog(
                icon: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(color: m.heart.withValues(alpha: 0.16), borderRadius: AppRadius.controlAll),
                  child: Icon(Icons.logout_rounded, color: m.heart),
                ),
                iconPadding: const EdgeInsets.fromLTRB(24, 24, 24, 14),
                title: Text(hu ? 'Kijelentkezel a Lifeyból?' : 'Log out of Lifey?'),
                content: Text(hu
                    ? 'A telefonon lévő adataid törlődnek.'
                    : 'Your data on this phone is removed.'),
                actions: [
                  OutlinedButton(onPressed: () => Navigator.pop(context), child: Text(hu ? 'Mégse' : 'Cancel')),
                  FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: m.heart, foregroundColor: const Color(0xFF2A0F0C)),
                    onPressed: () => Navigator.pop(context),
                    child: Text(hu ? 'Kijelentkezés' : 'Log out'),
                  ),
                ],
              ),
            ),
            child: const Text('Dialog'),
          ),
          OutlinedButton(
            onPressed: () => AppSnackbar.showSuccess(context, title: hu ? 'Étkezés mentve' : 'Meal saved', subtitle: '383 kcal'),
            child: const Text('Snackbar ✓'),
          ),
          OutlinedButton(
            onPressed: () => AppSnackbar.showError(context, title: hu ? 'Nem sikerült menteni' : 'Could not save', actionLabel: hu ? 'Újra' : 'Retry', onAction: () {}),
            child: const Text('Snackbar ✗'),
          ),
          PopupMenuButton<int>(
            itemBuilder: (_) => [
              PopupMenuItem(value: 1, child: Text(hu ? 'Másolás' : 'Copy')),
              PopupMenuItem(value: 2, child: Text(hu ? 'Törlés' : 'Delete')),
            ],
            child: const Padding(padding: EdgeInsets.all(12), child: Text('Menu ⋮')),
          ),
        ]),
      ],
    );
  }
}
