import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/theme/app_theme.dart';
import 'package:lifey/core/theme/app_tokens.dart';
import 'package:lifey/shared/widgets/ds/card_edge_painter.dart';

void main() {
  group('AppMotion.of', () {
    Future<Duration> resolve(WidgetTester tester, {required bool reduced}) async {
      late Duration result;
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(disableAnimations: reduced),
          child: Builder(builder: (context) {
            result = AppMotion.of(context, AppMotion.countUp);
            return const SizedBox();
          }),
        ),
      );
      return result;
    }

    testWidgets('keeps the duration normally', (tester) async {
      expect(await resolve(tester, reduced: false), AppMotion.countUp);
    });

    testWidgets('is zero under reduced motion', (tester) async {
      expect(await resolve(tester, reduced: true), Duration.zero);
    });

    testWidgets('keeps the duration when there is no MediaQuery', (tester) async {
      late Duration result;
      await tester.pumpWidget(Builder(builder: (context) {
        result = AppMotion.of(context, AppMotion.page);
        return const SizedBox();
      }));
      expect(result, AppMotion.page);
    });
  });

  group('AppRadius', () {
    test('four steps', () {
      expect([AppRadius.tag, AppRadius.control, AppRadius.card, AppRadius.hero], [8, 14, 22, 30]);
    });

    test('nested radius = parent − inset, never negative', () {
      expect(AppRadius.nested(AppRadius.hero, 16), 14);
      expect(AppRadius.nested(AppRadius.tag, 12), 0);
    });
  });

  test('both themes carry the elevation extension', () {
    expect(AppTheme.dark.extension<AppElevation>(), AppElevation.dark);
    expect(AppTheme.light.extension<AppElevation>(), AppElevation.light);
  });

  test('light theme has no light edge, dark cards have no drop shadow', () {
    expect(AppElevation.light.cardEdge.a, 0);
    expect(AppElevation.dark.e1, isEmpty);
    expect(AppElevation.light.e1, isNotEmpty);
  });

  group('CardEdgePainter', () {
    const size = Size(200, 100);
    final radius = BorderRadius.circular(AppRadius.card);
    final band = CardEdgePainter.edgePath(size, radius, 1);

    test('paints along the top edge only', () {
      expect(band.contains(const Offset(100, 0.5)), isTrue);
      expect(band.contains(const Offset(100, 2)), isFalse);
      expect(band.contains(const Offset(100, 99.5)), isFalse);
    });

    test('follows the corner radius instead of a square corner', () {
      expect(band.contains(const Offset(0.5, 0.5)), isFalse);
    });
  });
}
