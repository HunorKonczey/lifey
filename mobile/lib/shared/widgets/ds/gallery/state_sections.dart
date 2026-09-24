import 'package:flutter/material.dart';

import '../../../../core/format/lifey_format.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../empty_view.dart';
import '../../error_view.dart';
import '../lifey_sheet.dart';
import 'gallery_section.dart';

/// Gallery section for R0.12: bottom sheet, empty state, error state
/// (docs/redesign/77-mobile-redesign-plan.md R0.12).
final List<GallerySection> stateSections = [
  GallerySection(
    title: 'Sheets & states',
    source: 'Design System › Bottom sheet, Üres állapot, Hibaállapot · R0.12',
    builder: (_) => const _StatesSection(),
  ),
];

bool _hu(BuildContext context) => Localizations.localeOf(context).languageCode == 'hu';

class _StatesSection extends StatelessWidget {
  const _StatesSection();

  @override
  Widget build(BuildContext context) {
    final hu = _hu(context);
    final m = context.metricColors;
    final f = LifeyFormat.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(spacing: AppSpacing.s8, runSpacing: AppSpacing.s8, children: [
          FilledButton(
            onPressed: () => showLifeySheet<void>(
              context: context,
              title: hu ? 'Víz hozzáadása' : 'Add water',
              trailing: Text(
                '${f.litres(0.99)} / ${f.litres(2.6)} L',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: m.water),
              ),
              builder: (context) => Row(children: [
                for (final (i, v) in [0.25, 0.5, 1.0].indexed) ...[
                  if (i > 0) const SizedBox(width: AppSpacing.s8),
                  Expanded(
                    child: Container(
                      height: 64,
                      decoration: BoxDecoration(color: m.water.withValues(alpha: 0.14), borderRadius: AppRadius.controlAll),
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Text(f.litres(v), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: m.water)),
                        Text('L', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.palette.text2)),
                      ]),
                    ),
                  ),
                ],
              ]),
            ),
            child: const Text('Sheet with value'),
          ),
          OutlinedButton(
            onPressed: () => showLifeySheet<void>(
              context: context,
              title: hu ? 'Súly rögzítése' : 'Log weight',
              showClose: true,
              builder: (context) => FilledButton(onPressed: () => Navigator.pop(context), child: Text(hu ? 'Mentés' : 'Save')),
            ),
            child: const Text('Sheet with close'),
          ),
        ]),
        const GalleryCaption('Empty state'),
        SizedBox(
          height: 300,
          child: EmptyView(
            icon: Icons.restaurant_rounded,
            title: hu ? 'Ma még nincs étkezés' : 'No meals yet today',
            subtitle: hu
                ? 'Rögzítsd a reggelit, vagy másold át a tegnapi étkezéseket egy koppintással.'
                : "Log breakfast, or copy yesterday's meals in one tap.",
            action: FilledButton(onPressed: () {}, child: Text(hu ? 'Étkezés' : 'Add meal')),
            secondaryAction: OutlinedButton(onPressed: () {}, child: Text(hu ? 'Nap másolása' : 'Copy a day')),
          ),
        ),
        const GalleryCaption('Error state'),
        SizedBox(
          height: 220,
          child: ErrorView(
            error: Exception('offline'),
            title: hu ? 'A receptötletek nem érhetők el' : 'Recipe ideas are unavailable',
            message: hu
                ? 'Az AI-funkciókhoz kapcsolat kell. A receptjeid és a naplód offline is működnek.'
                : 'AI features need a connection. Your recipes and logs still work offline.',
            onRetry: () {},
          ),
        ),
      ],
    );
  }
}
