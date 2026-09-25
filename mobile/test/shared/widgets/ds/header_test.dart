import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/theme/app_theme.dart';
import 'package:lifey/l10n/app_localizations.dart';
import 'package:lifey/shared/widgets/ds/gallery/header_sections.dart';
import 'package:lifey/shared/widgets/ds/lifey_header.dart';

const double _statusBar = 24;

Widget _app(Widget home, {double textScale = 1}) => MaterialApp(
      theme: AppTheme.dark,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          padding: const EdgeInsets.only(top: _statusBar),
          viewPadding: const EdgeInsets.only(top: _statusBar),
          textScaler: TextScaler.linear(textScale),
        ),
        child: child!,
      ),
      home: home,
    );

Widget _largeTitlePage({String title = 'Good morning, Anna', String? overline = 'Thursday, 24 Sep'}) => Scaffold(
      body: CustomScrollView(slivers: [
        LifeyHeader(
          title: title,
          overline: overline,
          actions: [
            HeaderIconButton(icon: Icons.chat_bubble_outline_rounded, tooltip: 'Messages', showDot: true, onPressed: () {}),
          ],
        ),
        SliverList.list(children: [for (var i = 0; i < 60; i++) SizedBox(height: 48, child: Text('row $i'))]),
      ]),
    );

double _titleSize(WidgetTester tester, String title) => tester.widget<Text>(find.text(title)).style!.fontSize!;

void main() {
  group('LifeyHeader (large title)', () {
    testWidgets('expanded: 30 px title under the date overline', (tester) async {
      await tester.pumpWidget(_app(_largeTitlePage()));
      expect(_titleSize(tester, 'Good morning, Anna'), 30);
      expect(find.text('Thursday, 24 Sep'), findsOneWidget);
    });

    testWidgets('a collapsedTitle replaces the greeting once scrolled (canvas: "Today")', (tester) async {
      Widget page() => Scaffold(
            body: CustomScrollView(slivers: [
              const LifeyHeader(title: 'Good morning, Anna', collapsedTitle: 'Today'),
              SliverList.list(children: [for (var i = 0; i < 60; i++) SizedBox(height: 48, child: Text('row $i'))]),
            ]),
          );
      double opacityOf(WidgetTester t, String text) => t
          .widget<Opacity>(find.ancestor(of: find.text(text), matching: find.byType(Opacity)).first)
          .opacity;

      await tester.pumpWidget(_app(page()));
      expect(opacityOf(tester, 'Good morning, Anna'), 1);
      expect(opacityOf(tester, 'Today'), 0);

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
      await tester.pumpAndSettle();
      expect(opacityOf(tester, 'Good morning, Anna'), 0);
      expect(opacityOf(tester, 'Today'), 1);
      expect(tester.widget<Text>(find.text('Today')).style!.fontSize, 20);
    });

    testWidgets('screen readers get the expanded title only', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_app(Scaffold(
        body: CustomScrollView(slivers: [
          const LifeyHeader(title: 'Good morning, Anna', collapsedTitle: 'Today'),
          SliverList.list(children: const [SizedBox(height: 900)]),
        ]),
      )));
      expect(find.bySemanticsLabel('Good morning, Anna'), findsOneWidget);
      expect(find.bySemanticsLabel('Today'), findsNothing);
      handle.dispose();
    });

    testWidgets('scrolled: shrinks to a 20 px title in a status bar + 52 px bar', (tester) async {
      await tester.pumpWidget(_app(_largeTitlePage()));
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
      await tester.pumpAndSettle();
      expect(_titleSize(tester, 'Good morning, Anna'), 20);
      // LifeyHeader is a sliver; measure the box it paints.
      final header = find.descendant(of: find.byType(LifeyHeader), matching: find.byType(Stack)).first;
      expect(tester.getTopLeft(header).dy, 0); // pinned over the status bar
      expect(tester.getSize(header).height, _statusBar + 52);
      // The scrim is up: blurred and nearly opaque, so no row shows through.
      expect(find.descendant(of: find.byType(LifeyHeader), matching: find.byType(BackdropFilter)), findsOneWidget);
    });

    testWidgets('a long Hungarian title at 130 % takes two lines without overflow', (tester) async {
      await tester.pumpWidget(_app(
        _largeTitlePage(title: 'Jó reggelt, Kovácsné Szabó Annamária', overline: 'Csütörtök, szeptember 24.'),
        textScale: 1.3,
      ));
      expect(tester.takeException(), isNull);
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('the title is a header, read once; buttons are 48 dp targets', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_app(_largeTitlePage()));
      expect(find.bySemanticsLabel('Good morning, Anna'), findsOneWidget);
      expect(tester.getSemantics(find.text('Good morning, Anna')), isSemantics(isHeader: true));
      expect(tester.getSize(find.byType(IconButton)), const Size.square(48));
      handle.dispose();
    });
  });

  group('LifeySubpageHeader', () {
    Widget pushed({VoidCallback? onBack, bool extend = false}) => Scaffold(
          extendBodyBehindAppBar: extend,
          appBar: LifeySubpageHeader(title: 'Mark Trainer', subtitle: 'Your trainer · online', onBack: onBack),
          body: ListView(children: [for (var i = 0; i < 60; i++) SizedBox(height: 48, child: Text('m $i'))]),
        );

    testWidgets('a long title shrinks to fit beside a Save button instead of ending in an ellipsis', (tester) async {
      tester.view.physicalSize = const Size(360 * 3, 800 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_app(
        Scaffold(
          appBar: LifeySubpageHeader(
            title: 'Étkezés szerkesztése',
            actions: [FilledButton(onPressed: () {}, child: const Text('Mentés'))],
          ),
        ),
        textScale: 1.3,
      ));
      await tester.pumpAndSettle();

      final text = tester.widget<Text>(find.text('Étkezés szerkesztése'));
      expect(text.overflow, isNot(TextOverflow.ellipsis));
      expect(text.softWrap, isFalse);
      expect(find.ancestor(of: find.text('Étkezés szerkesztése'), matching: find.byType(FittedBox)), findsOneWidget);
      expect(tester.takeException(), isNull);
      // Scaled down, but still inside the row: left of the button.
      expect(tester.getTopRight(find.text('Étkezés szerkesztése')).dx, lessThan(tester.getTopLeft(find.text('Mentés')).dx));
    });

    Future<void> openPushed(WidgetTester tester, Widget page) async {
      await tester.pumpWidget(_app(Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page)),
            child: const Text('open'),
          ),
        ),
      )));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('pushed: a round back button pops the route', (tester) async {
      await openPushed(tester, pushed());
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.text('open'), findsOneWidget);
    });

    testWidgets('a root page gets no back button', (tester) async {
      await tester.pumpWidget(_app(pushed()));
      expect(find.byTooltip('Back'), findsNothing);
    });

    testWidgets('title 18 with a subtitle; the hairline appears only after scrolling', (tester) async {
      await openPushed(tester, pushed(extend: true));
      expect(tester.widget<Text>(find.text('Mark Trainer')).style!.fontSize, 18);

      Color hairline() {
        final box = tester.widget<DecoratedBox>(find.descendant(
          of: find.byType(LifeySubpageHeader),
          matching: find.byWidgetPredicate((w) => w is DecoratedBox && (w.decoration as BoxDecoration).border != null),
        ));
        return ((box.decoration as BoxDecoration).border! as Border).bottom.color;
      }

      expect(hairline().a, 0);
      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(hairline().a, greaterThan(0));
    });

    testWidgets('sits below the status bar, covering it with the scrim', (tester) async {
      await tester.pumpWidget(_app(pushed()));
      final header = find.byType(LifeySubpageHeader);
      expect(tester.getTopLeft(header).dy, 0);
      expect(tester.getSize(header).height, _statusBar + 60);
    });
  });

  group('StatusBarScrim', () {
    testWidgets('covers exactly the status bar', (tester) async {
      await tester.pumpWidget(_app(const Scaffold(body: Stack(children: [SizedBox.expand(), StatusBarScrim()]))));
      final scrim = find.byType(BackdropFilter);
      expect(tester.getSize(scrim).height, _statusBar);
      expect(tester.getTopLeft(scrim).dy, 0);
    });
  });

  group('gallery header demos (what the emulator review uses)', () {
    for (final (name, demo) in [('large title', const LargeTitleDemo()), ('subpage', const SubpageDemo())]) {
      for (final scale in [1.0, 1.3]) {
        testWidgets('$name at ${(scale * 100).round()} % scrolls cleanly', (tester) async {
          await tester.pumpWidget(_app(demo, textScale: scale));
          await tester.drag(find.byType(Scrollable).first, const Offset(0, -1200));
          await tester.pumpAndSettle();
          await tester.drag(find.byType(Scrollable).first, const Offset(0, 1200));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        });
      }
    }
  });
}
