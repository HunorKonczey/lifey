import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/theme/app_theme.dart';
import 'package:lifey/core/theme/app_tokens.dart';
import 'package:lifey/l10n/app_localizations.dart';
import 'package:lifey/shared/widgets/ds/lifey_sheet.dart';
import 'package:lifey/shared/widgets/empty_view.dart';
import 'package:lifey/shared/widgets/error_view.dart';

Widget _app(Widget home, {double textScale = 1, bool reducedMotion = false}) => MaterialApp(
      theme: AppTheme.dark,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale), disableAnimations: reducedMotion),
        child: child!,
      ),
      home: home,
    );

/// A page with a button that opens a sheet built by [open].
Widget _opener(void Function(BuildContext) open) =>
    Scaffold(body: Builder(builder: (context) => Center(child: TextButton(onPressed: () => open(context), child: const Text('open')))));

void main() {
  group('showLifeySheet', () {
    testWidgets('title, handle, trailing value; radius 30 on top; 40 % backdrop', (tester) async {
      await tester.pumpWidget(_app(_opener((c) => showLifeySheet<void>(
            context: c,
            title: 'Add water',
            trailing: const Text('0.99 / 2.60 L'),
            builder: (_) => const SizedBox(height: 64),
          ))));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Add water'), findsOneWidget);
      expect(find.text('0.99 / 2.60 L'), findsOneWidget);
      final handle = find.descendant(
        of: find.byType(LifeySheet),
        matching: find.byWidgetPredicate((w) => w is Container && w.constraints?.maxWidth == 36),
      );
      expect(tester.getSize(handle), const Size(36, 4));
      final theme = AppTheme.dark.bottomSheetTheme;
      expect((theme.shape! as RoundedRectangleBorder).borderRadius,
          const BorderRadius.vertical(top: Radius.circular(AppRadius.hero)));
      expect(theme.modalBarrierColor!.a, closeTo(0.4, 0.005));
      expect(theme.backgroundColor, AppPalette.dark.nested);
    });

    testWidgets('the close button dismisses it', (tester) async {
      await tester.pumpWidget(_app(_opener((c) => showLifeySheet<void>(
            context: c,
            title: 'Log weight',
            showClose: true,
            builder: (_) => const SizedBox(height: 40),
          ))));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(find.text('Log weight'), findsNothing);
    });

    testWidgets('tall content scrolls instead of overflowing, even at 130 %', (tester) async {
      await tester.pumpWidget(_app(
        _opener((c) => showLifeySheet<void>(
              context: c,
              title: 'Add food',
              builder: (_) => Column(children: [for (var i = 0; i < 40; i++) SizedBox(height: 48, child: Text('food $i'))]),
            )),
        textScale: 1.3,
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('under reduced motion it is up at once', (tester) async {
      await tester.pumpWidget(_app(
        _opener((c) => showLifeySheet<void>(context: c, title: 'Quick', builder: (_) => const SizedBox(height: 40))),
        reducedMotion: true,
      ));
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump();
      // (The opener's own ink ripple is still running, so compare positions
      // rather than asking whether anything animates.)
      final first = tester.getTopLeft(find.byType(LifeySheet));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.byType(LifeySheet)), first);
    });
  });

  group('EmptyView', () {
    testWidgets('icon holder, header title and both actions', (tester) async {
      final handle = tester.ensureSemantics();
      var main = 0, secondary = 0;
      await tester.pumpWidget(_app(Scaffold(
        body: EmptyView(
          icon: Icons.restaurant_rounded,
          title: 'No meals yet today',
          subtitle: "Log breakfast, or copy yesterday's meals in one tap.",
          action: FilledButton(onPressed: () => main++, child: const Text('Add meal')),
          secondaryAction: OutlinedButton(onPressed: () => secondary++, child: const Text('Copy a day')),
        ),
      )));
      expect(tester.getSemantics(find.text('No meals yet today')), isSemantics(isHeader: true));
      await tester.tap(find.text('Add meal'));
      await tester.tap(find.text('Copy a day'));
      expect((main, secondary), (1, 1));
      handle.dispose();
    });

    testWidgets('a v1 call site (action only) still works; narrow + 130 % does not overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_app(
        Scaffold(
          body: EmptyView(
            icon: Icons.fitness_center_rounded,
            title: 'Még nincs edzésed ezen a héten',
            subtitle: 'Indíts egy edzést a lenti gombbal, vagy válassz egy sablont.',
            action: FilledButton(onPressed: () {}, child: const Text('Edzés indítása')),
          ),
        ),
        textScale: 1.3,
      ));
      expect(tester.takeException(), isNull);
    });
  });

  group('ErrorView', () {
    testWidgets('default title and friendly message; retry is a 48 dp action', (tester) async {
      var retries = 0;
      await tester.pumpWidget(_app(Scaffold(body: ErrorView(error: Exception('boom'), onRetry: () => retries++))));
      expect(find.text('Something went wrong'), findsOneWidget);
      final retry = find.widgetWithText(TextButton, 'Retry');
      expect(tester.getSize(retry).height, greaterThanOrEqualTo(48));
      await tester.tap(retry);
      expect(retries, 1);
    });

    testWidgets('the design copy can replace title and message', (tester) async {
      await tester.pumpWidget(_app(Scaffold(
        body: ErrorView(
          error: Exception('offline'),
          title: 'Recipe ideas are unavailable',
          message: 'AI features need a connection. Your recipes and logs still work offline.',
        ),
      )));
      expect(find.text('Recipe ideas are unavailable'), findsOneWidget);
      expect(find.textContaining('still work offline'), findsOneWidget);
      expect(find.byType(TextButton), findsNothing); // no retry without onRetry
    });
  });
}
