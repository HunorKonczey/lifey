import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/theme/app_theme.dart';
import 'package:lifey/core/theme/app_tokens.dart';
import 'package:lifey/l10n/app_localizations.dart';
import 'package:lifey/shared/widgets/ds/delta_chip.dart';
import 'package:lifey/shared/widgets/ds/lifey_card.dart';
import 'package:lifey/shared/widgets/ds/monogram_avatar.dart';
import 'package:lifey/shared/widgets/ds/pressable.dart';
import 'package:lifey/shared/widgets/ds/section_label.dart';
import 'package:lifey/shared/widgets/ds/tinted_chip.dart';

Widget _host(Widget child, {ThemeData? theme, Locale locale = const Locale('en')}) => MaterialApp(
      theme: theme ?? AppTheme.dark,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: Center(child: child)),
    );

BoxDecoration _decorationOf(WidgetTester tester, Finder within) => tester
    .widget<DecoratedBox>(find.descendant(of: within, matching: find.byType(DecoratedBox)).first)
    .decoration as BoxDecoration;

void main() {
  group('LifeyCard', () {
    testWidgets('card: surface-1, radius 22, padding 16', (tester) async {
      await tester.pumpWidget(_host(const LifeyCard(child: SizedBox(width: 50, height: 20))));
      final d = _decorationOf(tester, find.byType(LifeyCard));
      expect(d.color, AppPalette.dark.card);
      expect(d.borderRadius, BorderRadius.circular(AppRadius.card));
      expect(tester.getSize(find.byType(LifeyCard)), const Size(82, 52));
    });

    testWidgets('hero: radius 30, padding 20', (tester) async {
      await tester.pumpWidget(_host(const LifeyCard.hero(child: SizedBox(width: 50, height: 20))));
      final d = _decorationOf(tester, find.byType(LifeyCard));
      expect(d.borderRadius, BorderRadius.circular(AppRadius.hero));
      expect(tester.getSize(find.byType(LifeyCard)), const Size(90, 60));
    });

    testWidgets('nested: surface-2, no shadow', (tester) async {
      await tester.pumpWidget(_host(const LifeyCard.nested(child: SizedBox(width: 10, height: 10))));
      final d = _decorationOf(tester, find.byType(LifeyCard));
      expect(d.color, AppPalette.dark.nested);
      expect(d.boxShadow, isNull);
    });

    testWidgets('light cards cast the warm e1 shadow', (tester) async {
      await tester.pumpWidget(_host(const LifeyCard(child: SizedBox()), theme: AppTheme.light));
      expect(_decorationOf(tester, find.byType(LifeyCard)).boxShadow, AppElevation.light.e1);
    });

    testWidgets('only tappable cards get the press feedback', (tester) async {
      await tester.pumpWidget(_host(const LifeyCard(child: SizedBox())));
      expect(find.byType(Pressable), findsNothing);
      var taps = 0;
      await tester.pumpWidget(_host(LifeyCard(onTap: () => taps++, child: const SizedBox(width: 40, height: 40))));
      await tester.tap(find.byType(LifeyCard));
      expect(taps, 1);
      expect(find.byType(InkWell), findsNothing); // no ripple
    });
  });

  group('SectionLabel', () {
    testWidgets('renders caps, reads sentence case as a header', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_host(const SectionLabel("Today's meals")));
      expect(find.text("TODAY'S MEALS"), findsOneWidget);
      expect(
        tester.getSemantics(find.bySemanticsLabel("Today's meals")),
        matchesSemantics(label: "Today's meals", isHeader: true),
      );
      handle.dispose();
    });

    testWidgets('the action is a 48 dp target', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_host(SizedBox(
        width: 360,
        child: SectionLabel('Recent workouts', actionLabel: 'See all', onAction: () => taps++),
      )));
      final button = find.widgetWithText(TextButton, 'See all');
      expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
      await tester.tap(button);
      expect(taps, 1);
    });
  });

  group('TintedChip (D-R0.4)', () {
    Color bgOf(WidgetTester tester) =>
        (tester.widget<Container>(find.descendant(of: find.byType(TintedChip), matching: find.byType(Container)).first)
                .decoration! as BoxDecoration)
            .color!;

    testWidgets('dark: 16 % tint, text in the metric colour', (tester) async {
      final c = AppMetricColors.dark.protein;
      await tester.pumpWidget(_host(TintedChip(label: '100 g to go', color: c)));
      expect(bgOf(tester).a, closeTo(0.16, 0.005));
      expect(tester.widget<Text>(find.text('100 g to go')).style!.color, c);
      expect(tester.getSize(find.byType(TintedChip)).height, greaterThanOrEqualTo(26));
    });

    testWidgets('light: 12 % tint', (tester) async {
      await tester.pumpWidget(_host(
        TintedChip(label: 'x', color: AppMetricColors.light.protein),
        theme: AppTheme.light,
      ));
      expect(bgOf(tester).a, closeTo(0.12, 0.005));
    });

    testWidgets('medium is 32 tall', (tester) async {
      await tester.pumpWidget(_host(TintedChip(label: 'x', color: AppMetricColors.dark.fat, size: TintedChipSize.medium)));
      expect(tester.getSize(find.byType(TintedChip)).height, greaterThanOrEqualTo(32));
    });
  });

  group('DeltaChip', () {
    TintedChip chip(WidgetTester tester) => tester.widget<TintedChip>(find.byType(TintedChip));

    testWidgets('arrow: down arrow, unsigned number, weight blue', (tester) async {
      await tester.pumpWidget(_host(const DeltaChip.arrow(value: -0.1, unit: 'kg')));
      expect(chip(tester).label, '0.1 kg');
      expect(chip(tester).icon, Icons.south_rounded);
      expect(chip(tester).color, AppMetricColors.dark.decrease);
    });

    testWidgets('signed: real minus, no arrow; up is calorie orange', (tester) async {
      await tester.pumpWidget(_host(const DeltaChip.signed(value: -0.1)));
      expect(chip(tester).label, '−0.1');
      expect(chip(tester).icon, isNull);
      await tester.pumpWidget(_host(const DeltaChip.signed(value: 0.3)));
      expect(chip(tester).label, '+0.3');
      expect(chip(tester).color, AppMetricColors.dark.increase);
    });

    testWidgets('a change that rounds to zero is neutral and has no arrow', (tester) async {
      await tester.pumpWidget(_host(const DeltaChip.arrow(value: 0.02, unit: 'kg')));
      expect(chip(tester).icon, isNull);
      expect(chip(tester).color, AppPalette.dark.text2);
      expect(chip(tester).label, '0.0 kg');
    });

    testWidgets('colour override — progress toward a goal', (tester) async {
      await tester.pumpWidget(_host(DeltaChip.arrow(value: -1.4, suffix: 'in 30 d', color: AppMetricColors.dark.improvement)));
      expect(chip(tester).color, AppMetricColors.dark.protein);
      expect(chip(tester).label, '1.4 in 30 d');
    });

    testWidgets('screen readers hear the direction in words, per language', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_host(const DeltaChip.arrow(value: -0.1, unit: 'kg')));
      expect(find.bySemanticsLabel('down 0.1 kg'), findsOneWidget);
      await tester.pumpWidget(_host(const DeltaChip.arrow(value: -0.1, unit: 'kg'), locale: const Locale('hu')));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('0,1 kg csökkenés'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('record and improvement keep their fixed colours', (tester) async {
      await tester.pumpWidget(_host(const RecordChip(label: '2 PRs')));
      expect(chip(tester).color, AppMetricColors.dark.carbs);
      expect(chip(tester).icon, Icons.emoji_events_rounded);
      await tester.pumpWidget(_host(const ImprovementChip(label: '+2.5 kg')));
      expect(chip(tester).color, AppMetricColors.dark.protein);
      expect(chip(tester).icon, Icons.arrow_upward_rounded);
    });
  });

  group('MonogramAvatar', () {
    test('initials come from the name, not the e-mail', () {
      expect(MonogramAvatar.initialsFor('Anna Kovács', 'zed@mail.com'), 'AK');
      expect(MonogramAvatar.initialsFor('  Éva   Mária  Szűcs ', null), 'ÉS');
      expect(MonogramAvatar.initialsFor('anna', null), 'A');
      expect(MonogramAvatar.initialsFor('Ödön Őri', null), 'ÖŐ');
    });

    test('falls back to the e-mail, then to "?"', () {
      expect(MonogramAvatar.initialsFor(null, 'anna.kovacs@mail.com'), 'A');
      expect(MonogramAvatar.initialsFor('   ', 'bence@mail.com'), 'B');
      expect(MonogramAvatar.initialsFor(null, null), '?');
    });

    test('a person keeps the same hue', () {
      const m = AppMetricColors.dark;
      expect(MonogramAvatar.colorFor('Bence Nagy', m), MonogramAvatar.colorFor('Bence Nagy', m));
      expect([m.water, m.steps, m.fat, m.carbs, m.calories, m.weight], contains(MonogramAvatar.colorFor('x', m)));
    });

    testWidgets('announced by name, initials hidden from screen readers', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_host(const MonogramAvatar(name: 'Anna Kovács')));
      expect(find.text('AK'), findsOneWidget);
      expect(find.bySemanticsLabel('Anna Kovács'), findsOneWidget);
      expect(find.bySemanticsLabel('AK'), findsNothing);
      handle.dispose();
    });

    testWidgets('initials do not grow with dynamic type', (tester) async {
      await tester.pumpWidget(MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
        child: _host(const MonogramAvatar(name: 'Anna Kovács')),
      ));
      expect(tester.getSize(find.byType(MonogramAvatar)), const Size.square(44));
    });
  });
}
