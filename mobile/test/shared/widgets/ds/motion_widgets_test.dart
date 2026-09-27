import 'package:flutter/gestures.dart' show kPressTimeout;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/theme/app_tokens.dart';
import 'package:lifey/shared/widgets/ds/animated_number.dart';
import 'package:lifey/shared/widgets/ds/pressable.dart';

Widget _host(Widget child, {bool reducedMotion = false}) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reducedMotion),
        child: Scaffold(body: Center(child: child)),
      ),
    );

Widget _number(num value, {bool reducedMotion = false, String? label}) => _host(
      AnimatedNumber(
        value: value,
        semanticsLabel: label,
        builder: (context, v) => Text(v.round().toString()),
      ),
      reducedMotion: reducedMotion,
    );

int _shown(WidgetTester tester) =>
    int.parse(tester.widget<Text>(find.byType(Text)).data!);

void main() {
  group('AnimatedNumber', () {
    testWidgets('first build shows the value — no count-up from 0', (tester) async {
      await tester.pumpWidget(_number(1739));
      expect(_shown(tester), 1739);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('rolls from the old value to the new one in 600 ms', (tester) async {
      await tester.pumpWidget(_number(1000));
      await tester.pumpWidget(_number(2000));
      await tester.pump(AppMotion.countUp ~/ 2);
      final mid = _shown(tester);
      expect(mid, greaterThan(1000));
      expect(mid, lessThan(2000));
      await tester.pump(AppMotion.countUp);
      expect(_shown(tester), 2000);
    });

    testWidgets('an equal value on rebuild does not animate (plan §9 risk 7)', (tester) async {
      await tester.pumpWidget(_number(621));
      await tester.pumpWidget(_number(621));
      expect(tester.hasRunningAnimations, isFalse);
      expect(_shown(tester), 621);
    });

    testWidgets('a change mid-animation continues from what is on screen', (tester) async {
      await tester.pumpWidget(_number(0));
      await tester.pumpWidget(_number(1000));
      await tester.pump(AppMotion.countUp ~/ 2);
      final shown = _shown(tester);
      await tester.pumpWidget(_number(500));
      await tester.pump();
      // Starts from the in-between value, not jumping back to 0 or up to 1000.
      expect((_shown(tester) - shown).abs(), lessThan(50));
      await tester.pumpAndSettle();
      expect(_shown(tester), 500);
    });

    testWidgets('reduced motion lands on the final value at once', (tester) async {
      await tester.pumpWidget(_number(100, reducedMotion: true));
      await tester.pumpWidget(_number(900, reducedMotion: true));
      await tester.pump();
      expect(_shown(tester), 900);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('screen readers get the final label, not in-between digits', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_number(100, label: '100 kcal'));
      await tester.pumpWidget(_number(900, label: '900 kcal'));
      await tester.pump(AppMotion.countUp ~/ 2);
      expect(find.bySemanticsLabel('900 kcal'), findsOneWidget);
      await tester.pumpAndSettle();
      handle.dispose();
    });
  });

  group('Pressable', () {
    double scaleOf(WidgetTester tester) =>
        tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale;

    testWidgets('scales to 0.98 while pressed and back on release', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_host(Pressable(
        onTap: () => taps++,
        child: const SizedBox(width: 200, height: 100),
      )));
      final gesture = await tester.startGesture(tester.getCenter(find.byType(SizedBox).last));
      // Tap-down is reported after kPressTimeout — Flutter's own delay that
      // keeps a scroll from flashing every card it starts on.
      await tester.pump(kPressTimeout);
      expect(scaleOf(tester), Pressable.pressedScale);
      await gesture.up();
      await tester.pump();
      expect(scaleOf(tester), 1);
      expect(taps, 1);
    });

    testWidgets('long press fires and releases the scale', (tester) async {
      var long = 0;
      await tester.pumpWidget(_host(Pressable(
        onLongPress: () => long++,
        child: const SizedBox(width: 200, height: 100),
      )));
      await tester.longPress(find.byType(SizedBox).last);
      await tester.pump();
      expect(long, 1);
      expect(scaleOf(tester), 1);
    });

    testWidgets('without callbacks it is just the child', (tester) async {
      await tester.pumpWidget(_host(const Pressable(child: SizedBox(width: 10, height: 10))));
      expect(find.byType(AnimatedScale), findsNothing);
      expect(find.byType(GestureDetector), findsNothing);
    });

    testWidgets('is announced as a button', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_host(Pressable(
        onTap: () {},
        semanticsLabel: 'Water',
        child: const SizedBox(width: 50, height: 50),
      )));
      expect(
        tester.getSemantics(find.bySemanticsLabel('Water')),
        matchesSemantics(label: 'Water', isButton: true, hasTapAction: true),
      );
      handle.dispose();
    });
  });
}
