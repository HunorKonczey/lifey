import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/shared/widgets/ds/sparkline.dart';

void main() {
  group('sparklineYs', () {
    test('the highest value is at the top, the lowest at the bottom, inset by the padding', () {
      final ys = sparklineYs([60, 65, 70], 56);
      expect(ys.first, closeTo(51.5, 1e-9));
      expect(ys.last, closeTo(4.5, 1e-9));
      expect(ys[1], closeTo(28, 1e-9));
    });

    test('a flat series is centred', () {
      expect(sparklineYs([64.5, 64.5, 64.5], 56), [28, 28, 28]);
    });

    test('empty in, empty out', () => expect(sparklineYs([], 56), isEmpty));

    test('a falling weight draws a falling line (y grows downwards)', () {
      final ys = sparklineYs([66, 65, 64.5], 56);
      expect(ys.first, lessThan(ys.last));
    });
  });

  testWidgets('keeps its 120 × 56 box, and draws nothing for fewer than two values', (tester) async {
    await tester.pumpWidget(const Directionality(
      textDirection: TextDirection.ltr,
      child: Column(children: [
        Sparkline(key: ValueKey('two'), values: [1, 2], color: Colors.blue),
        Sparkline(key: ValueKey('one'), values: [1], color: Colors.blue),
      ]),
    ));
    expect(tester.getSize(find.byKey(const ValueKey('two'))), const Size(120, 56));
    expect(tester.getSize(find.byKey(const ValueKey('one'))), const Size(120, 56));
  });
}
