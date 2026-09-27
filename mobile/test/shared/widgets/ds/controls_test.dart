import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/theme/app_theme.dart';
import 'package:lifey/core/theme/app_tokens.dart';
import 'package:lifey/l10n/app_localizations.dart';
import 'package:lifey/shared/widgets/app_snackbar.dart';
import 'package:lifey/shared/widgets/ds/lifey_segmented.dart';
import 'package:lifey/shared/widgets/ds/list_group.dart';
import 'package:lifey/shared/widgets/pill_tab_bar.dart';

Widget _host(Widget child, {ThemeData? theme, double textScale = 1, double width = 371}) => MaterialApp(
      theme: theme ?? AppTheme.dark,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
          child: Scaffold(body: Center(child: SizedBox(width: width, child: child))),
        ),
      ),
    );

void main() {
  group('component themes (R0.8)', () {
    for (final (name, theme) in [('dark', AppTheme.dark), ('light', AppTheme.light)]) {
      test('$name: buttons are ≥ 48 dp with radius 14', () {
        final filled = theme.filledButtonTheme.style!;
        expect(filled.minimumSize!.resolve({})!.height, 48);
        final shape = filled.shape!.resolve({})! as RoundedRectangleBorder;
        expect(shape.borderRadius, const BorderRadius.all(Radius.circular(AppRadius.control)));
        expect(theme.outlinedButtonTheme.style!.minimumSize!.resolve({})!.height, 48);
        expect(theme.textButtonTheme.style!.minimumSize!.resolve({})!.height, 48);
      });

      test('$name: secondary (outlined) button sits on surface-2', () {
        final p = theme.extension<AppPalette>()!;
        expect(theme.outlinedButtonTheme.style!.backgroundColor!.resolve({}), p.nested);
      });

      test('$name: selected chip is solid brand olive, unselected surface-2', () {
        final chip = theme.chipTheme;
        expect(chip.color!.resolve({WidgetState.selected}), theme.colorScheme.primary);
        expect(chip.color!.resolve({}), theme.extension<AppPalette>()!.nested);
      });

      test('$name: inputs fill with surface-3 and focus with a 1.5 px olive ring', () {
        final input = theme.inputDecorationTheme;
        expect(input.fillColor, theme.extension<AppPalette>()!.control);
        final focused = input.focusedBorder! as OutlineInputBorder;
        expect(focused.borderSide.color, theme.colorScheme.primary);
        expect(focused.borderSide.width, 1.5);
      });

      test('$name: dialogs have the hero radius', () {
        final shape = theme.dialogTheme.shape! as RoundedRectangleBorder;
        expect(shape.borderRadius, const BorderRadius.all(Radius.circular(AppRadius.hero)));
      });
    }

    testWidgets('a themed FilledButton really lays out 48 tall', (tester) async {
      await tester.pumpWidget(_host(FilledButton(onPressed: () {}, child: const Text('Save'))));
      expect(tester.getSize(find.byType(FilledButton)).height, 48);
    });

    // R0 emulator review: a WidgetStateTextStyle in ChipThemeData left every
    // chip label without a colour (near-invisible in light). Assert the
    // colour that actually reaches the rendered paragraph.
    for (final (name, theme) in [('dark', AppTheme.dark), ('light', AppTheme.light)]) {
      testWidgets('$name: chip labels render in text / onPrimary colours', (tester) async {
        await tester.pumpWidget(MaterialApp(
          theme: theme,
          home: Scaffold(body: Column(children: [
            ActionChip(label: const Text('action'), onPressed: () {}),
            FilterChip(label: const Text('off'), selected: false, onSelected: (_) {}),
            FilterChip(label: const Text('on'), selected: true, onSelected: (_) {}),
          ])),
        ));
        Color? rendered(String text) => tester.renderObject<RenderParagraph>(find.text(text)).text.style?.color;
        final p = theme.extension<AppPalette>()!;
        expect(rendered('action'), p.text);
        expect(rendered('off'), p.text);
        expect(rendered('on'), theme.colorScheme.onPrimary);
      });
    }

    testWidgets('a selected ChoiceChip is at least 40 tall', (tester) async {
      await tester.pumpWidget(_host(ChoiceChip(label: const Text('Breakfast'), selected: true, onSelected: (_) {})));
      expect(tester.getSize(find.byType(ChoiceChip)).height, greaterThanOrEqualTo(40));
    });
  });

  group('ListGroup / ListRow', () {
    testWidgets('one card, hairlines between rows, inset under the text', (tester) async {
      await tester.pumpWidget(_host(ListGroup(children: [
        for (final t in ['A', 'B', 'C'])
          ListRow(
            leading: ListIconHolder(icon: Icons.apple_rounded, color: AppMetricColors.dark.protein),
            title: t,
            trailing: const ListRowValue(value: '383', unit: 'kcal'),
          ),
      ])));
      final dividers = tester.widgetList<Divider>(find.byType(Divider));
      expect(dividers, hasLength(2));
      expect(dividers.first.indent, 74);
      expect(tester.getSize(find.byType(ListIconHolder).first), const Size.square(44));
    });

    testWidgets('rows are at least 48 tall and long subtitles wrap instead of truncating at one line',
        (tester) async {
      await tester.pumpWidget(_host(const ListGroup(children: [
        ListRow(title: 'Snack'),
        ListRow(
          title: 'Snack',
          subtitle: 'Apple, Almonds, Greek yogurt 2%, Blueberries, Rolled oats, Honey · 08:27',
        ),
      ])));
      final rows = find.byType(ListRow);
      expect(tester.getSize(rows.first).height, greaterThanOrEqualTo(48));
      final subtitle = tester.renderObject<RenderParagraph>(find.textContaining('Apple'));
      expect(subtitle.size.height, greaterThan(20)); // two lines, not one
      expect(tester.takeException(), isNull);
    });

    testWidgets('a tappable row reacts', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_host(ListGroup(children: [ListRow(title: 'Language', onTap: () => taps++)])));
      await tester.tap(find.text('Language'));
      expect(taps, 1);
    });
  });

  group('LifeySegmented', () {
    Widget segmented(int selected, ValueChanged<int> onChanged) => LifeySegmented<int>(
          segments: const [(7, '7 nap'), (30, '30 nap'), (90, '90 nap'), (0, 'Mind')],
          selected: selected,
          onChanged: onChanged,
        );

    testWidgets('tapping a segment selects it; 48 tall in all', (tester) async {
      var value = 7;
      await tester.pumpWidget(_host(StatefulBuilder(
        builder: (context, setState) => segmented(value, (v) => setState(() => value = v)),
      )));
      expect(tester.getSize(find.byType(LifeySegmented<int>)).height, 48);
      await tester.tap(find.text('90 nap'));
      await tester.pumpAndSettle();
      expect(value, 90);
    });

    testWidgets('marks the selected segment for screen readers', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_host(segmented(30, (_) {})));
      expect(tester.getSemantics(find.text('30 nap')), matchesSemantics(label: '30 nap', isSelected: true, isButton: true, hasSelectedState: true, isInMutuallyExclusiveGroup: true, hasTapAction: true));
      handle.dispose();
    });

    testWidgets('light theme: the selected pill is the brand green with white text', (tester) async {
      await tester.pumpWidget(_host(segmented(30, (_) {}), theme: AppTheme.light));
      final label = tester.widget<Text>(find.text('30 nap'));
      expect(label.style!.color, Colors.white);
      final pill = tester.widgetList<DecoratedBox>(find.descendant(of: find.byType(LifeySegmented<int>), matching: find.byType(DecoratedBox)))
          .map((d) => d.decoration).whereType<BoxDecoration>().where((d) => d.color == AppTheme.light.colorScheme.primary);
      expect(pill, isNotEmpty);
    });

    testWidgets('a locked segment wears a lock, stays tappable and is read out as gated', (tester) async {
      final handle = tester.ensureSemantics();
      final taps = <int>[];
      await tester.pumpWidget(_host(LifeySegmented<int>(
        segments: const [(7, '7 d'), (30, '30 d'), (0, 'All')],
        selected: 30,
        locked: const {0},
        onChanged: taps.add,
      )));
      expect(find.byIcon(Icons.lock_rounded), findsOneWidget);
      expect(find.bySemanticsLabel('All — Pro required'), findsOneWidget);
      await tester.tap(find.text('All'));
      expect(taps, [0]);
      handle.dispose();
    });

    testWidgets('fits a narrow phone at 130 % without overflow', (tester) async {
      await tester.pumpWidget(_host(segmented(7, (_) {}), textScale: 1.3, width: 280));
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('PillTabBar: 46 tall, no overflow with Hungarian tabs at 130 %', (tester) async {
    await tester.pumpWidget(_host(
      DefaultTabController(
        length: 4,
        child: Builder(builder: (context) => PillTabBar(
          controller: DefaultTabController.of(context),
          tabs: const [Tab(text: 'Étkezések'), Tab(text: 'Receptek'), Tab(text: 'Ételek'), Tab(text: 'Makrók')],
        )),
      ),
      textScale: 1.3,
    ));
    expect(tester.takeException(), isNull);
    final track = find.descendant(of: find.byType(PillTabBar), matching: find.byType(Container)).first;
    expect(tester.getSize(track).height, 46);
    // The pills themselves get the full 38 px (no border eating into them).
    expect(tester.getSize(find.byType(TabBar)).height, 38);
  });

  group('AppSnackbar', () {
    Future<void> show(WidgetTester tester, ThemeData theme, void Function(BuildContext) fn) async {
      await tester.pumpWidget(MaterialApp(
        theme: theme,
        home: Scaffold(body: Builder(builder: (context) => TextButton(onPressed: () => fn(context), child: const Text('go')))),
      ));
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
    }

    testWidgets('success uses the positive green, close button is a 48 dp target', (tester) async {
      await show(tester, AppTheme.light, (c) => AppSnackbar.showSuccess(c, title: 'Meal saved'));
      final icon = tester.widget<Icon>(find.byIcon(Icons.check_circle_rounded));
      expect(icon.color, AppMetricColors.dark.positive);
      expect(tester.getSize(find.byType(IconButton)).height, greaterThanOrEqualTo(48));
    });

    testWidgets('stays an inverse (dark) surface in the light theme', (tester) async {
      await show(tester, AppTheme.light, (c) => AppSnackbar.showInfo(c, title: 'Reminder set'));
      final title = tester.widget<Text>(find.text('Reminder set'));
      expect(title.style!.color, AppPalette.dark.text);
    });

    testWidgets('an action is a 48 dp target too', (tester) async {
      var taps = 0;
      await show(tester, AppTheme.dark, (c) => AppSnackbar.showError(c, title: 'Could not save', actionLabel: 'Retry', onAction: () => taps++));
      final retry = find.widgetWithText(TextButton, 'Retry');
      expect(tester.getSize(retry).height, greaterThanOrEqualTo(48));
      await tester.tap(retry);
      expect(taps, 1);
    });
  });

  testWidgets('SquareIconButton is 48 × 48', (tester) async {
    await tester.pumpWidget(_host(Center(child: SquareIconButton(icon: Icons.content_copy_rounded, onPressed: () {}, tooltip: 'Copy'))));
    expect(tester.getSize(find.byType(IconButton)), const Size.square(48));
  });
}
