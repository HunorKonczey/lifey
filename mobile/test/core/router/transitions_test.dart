import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/router/transitions.dart';
import 'package:lifey/core/theme/app_theme.dart';
import 'package:lifey/core/theme/app_tokens.dart';

/// A counter whose state must survive tab switches.
class _Counter extends StatefulWidget {
  const _Counter(this.name);
  final String name;
  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int taps = 0;
  @override
  Widget build(BuildContext context) => TextButton(
        onPressed: () => setState(() => taps++),
        child: Text('${widget.name} $taps'),
      );
}

Widget _tabs(int index, {bool reducedMotion = false}) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reducedMotion),
        child: Scaffold(
          body: FadeThroughBranchContainer(
            currentIndex: index,
            children: const [_Counter('A'), _Counter('B'), _Counter('C')],
          ),
        ),
      ),
    );

double _opacityOf(WidgetTester tester, String textStartsWith) {
  final fade = find.ancestor(
    of: find.textContaining(textStartsWith),
    matching: find.byType(FadeTransition),
  );
  return tester.widget<FadeTransition>(fade.first).opacity.value;
}

void main() {
  group('page transitions theme', () {
    test('Android gets shared-axis X, iOS keeps Cupertino (swipe-back)', () {
      for (final theme in [AppTheme.dark, AppTheme.light]) {
        final builders = theme.pageTransitionsTheme.builders;
        expect(builders[TargetPlatform.android], isA<SharedAxisXPageTransitionsBuilder>());
        expect(builders[TargetPlatform.iOS], isA<CupertinoPageTransitionsBuilder>());
      }
      expect(const SharedAxisXPageTransitionsBuilder().transitionDuration, AppMotion.page);
    });

    testWidgets('a push completes in 300 ms and the new page slides in from the right',
        (tester) async {
      final nav = GlobalKey<NavigatorState>();
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.dark,
        navigatorKey: nav,
        home: const Scaffold(body: Text('first')),
      ));
      nav.currentState!.push(MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('second')),
      ));
      await tester.pump();
      await tester.pump(AppMotion.page ~/ 2);
      final mid = tester.getTopLeft(find.byType(Scaffold).last).dx;
      expect(mid, greaterThan(0));
      expect(mid, lessThan(SharedAxisXPageTransitionsBuilder.offset));
      await tester.pump(AppMotion.page);
      expect(tester.getTopLeft(find.byType(Scaffold).last).dx, 0);
      expect(find.text('second'), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));
  });

  group('FadeThroughBranchContainer', () {
    testWidgets('only the active tab is on stage when idle', (tester) async {
      await tester.pumpWidget(_tabs(0));
      expect(find.text('A 0'), findsOneWidget);
      expect(find.text('B 0'), findsNothing); // Offstage hides it from finders
      expect(find.text('B 0', skipOffstage: false), findsOneWidget);
    });

    testWidgets('fades the old tab out first, then the new one in', (tester) async {
      await tester.pumpWidget(_tabs(0));
      await tester.pumpWidget(_tabs(1));
      await tester.pump(const Duration(milliseconds: 45)); // 15 %
      expect(_opacityOf(tester, 'A'), inExclusiveRange(0, 1));
      expect(_opacityOf(tester, 'B'), 0);
      await tester.pump(const Duration(milliseconds: 105)); // 50 %
      expect(find.text('A 0'), findsOneWidget); // still mounted while leaving…
      expect(_opacityOf(tester, 'A'), 0); // …but already invisible
      expect(_opacityOf(tester, 'B'), inExclusiveRange(0, 1));
      await tester.pumpAndSettle();
      expect(find.text('A 0'), findsNothing);
      expect(_opacityOf(tester, 'B'), 1);
    });

    testWidgets('tab state survives switching away and back', (tester) async {
      await tester.pumpWidget(_tabs(0));
      await tester.tap(find.text('A 0'));
      await tester.pump();
      await tester.pumpWidget(_tabs(2));
      await tester.pumpAndSettle();
      await tester.pumpWidget(_tabs(0));
      await tester.pumpAndSettle();
      expect(find.text('A 1'), findsOneWidget);
    });

    testWidgets('the leaving tab does not take taps', (tester) async {
      await tester.pumpWidget(_tabs(0));
      await tester.pumpWidget(_tabs(1));
      await tester.pump(const Duration(milliseconds: 30));
      await tester.tap(find.text('A 0'), warnIfMissed: false);
      await tester.pumpAndSettle();
      await tester.pumpWidget(_tabs(0));
      await tester.pumpAndSettle();
      expect(find.text('A 0'), findsOneWidget);
    });

    testWidgets('reduced motion switches instantly', (tester) async {
      await tester.pumpWidget(_tabs(0, reducedMotion: true));
      await tester.pumpWidget(_tabs(1, reducedMotion: true));
      await tester.pump();
      expect(tester.hasRunningAnimations, isFalse);
      expect(find.text('B 0'), findsOneWidget);
      expect(find.text('A 0'), findsNothing);
    });
  });
}
