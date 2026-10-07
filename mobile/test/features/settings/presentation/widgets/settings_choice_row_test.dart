import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/theme/app_theme.dart';
import 'package:lifey/features/settings/domain/user_settings.dart';
import 'package:lifey/features/settings/presentation/widgets/settings_kit.dart';
import 'package:lifey/l10n/app_localizations.dart';

/// LIF-125: at 1.0 text scale the Hungarian "Mértékegységek" shared a line with
/// the Metrikus / Angolszász pill and broke mid-word ("Mértékegy / ségek").
Future<void> _pump(
  WidgetTester tester, {
  required Locale locale,
  required double width,
  double textScale = 1,
}) async {
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(
        body: Builder(builder: (context) {
          final l10n = AppLocalizations.of(context)!;
          return Column(
            children: [
              SettingsChoiceRow(
                icon: Icons.straighten_rounded,
                title: l10n.unitsLabel,
                control: InlinePillSegment<UnitSystem>(
                  options: [
                    (UnitSystem.metric, l10n.unitsMetricShort),
                    (UnitSystem.imperial, l10n.unitsImperialShort),
                  ],
                  selected: UnitSystem.metric,
                  onChanged: (_) {},
                ),
              ),
              SettingsChoiceRow(
                icon: Icons.dark_mode_outlined,
                title: l10n.themeLabel,
                control: InlinePillSegment<ThemePreference>(
                  options: [
                    (ThemePreference.light, l10n.themeLight),
                    (ThemePreference.dark, l10n.themeDark),
                    (ThemePreference.system, l10n.optionSystem),
                  ],
                  selected: ThemePreference.system,
                  onChanged: (_) {},
                ),
              ),
            ],
          );
        }),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// One line of the title, however it is styled: the row's own text height at
/// this scale, taken from a one-word label that cannot wrap.
double _oneLine(WidgetTester tester, String word) => tester.getSize(find.text(word)).height;

void main() {
  for (final width in [360.0, 393.0, 412.0]) {
    for (final scale in [1.0, 1.15]) {
      testWidgets('Hungarian "Mértékegységek" stays whole at $width dp, x $scale', (tester) async {
        await _pump(tester, locale: const Locale('hu'), width: width, textScale: scale);

        expect(tester.takeException(), isNull);
        final units = tester.getSize(find.text('Mértékegységek'));
        // "Téma" never wraps, so its height is the height of one line.
        expect(units.height, closeTo(_oneLine(tester, 'Téma'), 0.5));
      });
    }
  }

  testWidgets('English keeps the pill on the title line at 412 dp', (tester) async {
    await _pump(tester, locale: const Locale('en'), width: 412);

    final title = tester.getTopLeft(find.text('Units')).dy;
    final pill = tester.getTopLeft(find.text('Metric')).dy;
    // Same band: the pill is beside the title, not stacked under it.
    expect((pill - title).abs(), lessThan(24));
  });

  testWidgets('a large text size still stacks the pill under the title', (tester) async {
    await _pump(tester, locale: const Locale('hu'), width: 412, textScale: 1.5);

    final title = tester.getTopLeft(find.text('Mértékegységek')).dy;
    final pill = tester.getTopLeft(find.text('Metrikus')).dy;
    expect(pill, greaterThan(title + 24));
  });
}
