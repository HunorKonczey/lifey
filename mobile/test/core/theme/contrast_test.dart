import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/theme/app_theme.dart';
import 'package:lifey/core/theme/app_tokens.dart';

/// WCAG 2.x contrast ratio. A translucent [fg] is composited onto [bg] first,
/// the way it renders.
double contrast(Color fg, Color bg) {
  final a = Color.alphaBlend(fg, bg).computeLuminance();
  final b = bg.computeLuminance();
  final hi = a > b ? a : b;
  final lo = a > b ? b : a;
  return (hi + 0.05) / (lo + 0.05);
}

/// The fill a tinted chip draws on a card: [metric] at [alpha] over [card].
Color tint(Color metric, double alpha, Color card) =>
    Color.alphaBlend(metric.withValues(alpha: alpha), card);

const double aa = 4.5;

void main() {
  // The canvas (docs/redesign/Lifey Design System.dc.html › Színtokenek)
  // prints ratios 2–4 % higher than WCAG's formula gives for the same hexes;
  // the guarantee we test is AA, plus a floor under the text tiers so a
  // later palette tweak can't quietly flatten the hierarchy.
  group('dark palette', () {
    const p = AppPalette.dark;
    final scheme = AppTheme.dark.colorScheme;

    test('text tiers keep their hierarchy on bg', () {
      expect(contrast(p.text, p.bg), greaterThanOrEqualTo(15));
      expect(contrast(p.text2, p.bg), greaterThanOrEqualTo(8.5));
      expect(contrast(p.text3, p.bg), greaterThanOrEqualTo(5.5));
    });

    test('every text tier is AA on every surface it sits on', () {
      for (final surface in [p.bg, p.card, p.nested]) {
        for (final text in [p.text, p.text2, p.text3]) {
          expect(contrast(text, surface), greaterThanOrEqualTo(aa),
              reason: '$text on $surface');
        }
      }
    });

    test('primary and onPrimary', () {
      expect(contrast(scheme.onPrimary, scheme.primary), greaterThanOrEqualTo(8.5));
    });

    test('primary tint text is AA', () {
      expect(contrast(p.onPrimaryTint, Color.alphaBlend(p.primaryTint, p.card)),
          greaterThanOrEqualTo(aa));
      expect(contrast(scheme.onPrimaryContainer, scheme.primaryContainer),
          greaterThanOrEqualTo(aa));
    });

    test('metric colours are AA on card and on their own 16 % chip tint', () {
      for (final m in _metrics(AppMetricColors.dark)) {
        expect(contrast(m, p.card), greaterThanOrEqualTo(aa), reason: '$m on card');
        // Canvas: "Tinted chip · 16% háttér, 100% szöveg, AA ≥ 6:1".
        expect(contrast(m, tint(m, 0.16, p.card)), greaterThanOrEqualTo(aa),
            reason: '$m on its tint');
      }
    });

    test('surface ladder rises monotonically', () {
      final ladder = [p.bg, p.card, p.nested, p.control, p.raised];
      for (var i = 1; i < ladder.length; i++) {
        expect(ladder[i].computeLuminance(), greaterThan(ladder[i - 1].computeLuminance()));
      }
    });
  });

  group('light palette', () {
    const p = AppPalette.light;
    final scheme = AppTheme.light.colorScheme;

    test('text tiers keep their hierarchy on bg', () {
      expect(contrast(p.text, p.bg), greaterThanOrEqualTo(15));
      expect(contrast(p.text2, p.bg), greaterThanOrEqualTo(6.5));
      expect(contrast(p.text3, p.bg), greaterThanOrEqualTo(4.7));
    });

    test('every text tier is AA on every surface it sits on', () {
      for (final surface in [p.bg, p.card, p.nested]) {
        for (final text in [p.text, p.text2, p.text3]) {
          expect(contrast(text, surface), greaterThanOrEqualTo(aa),
              reason: '$text on $surface');
        }
      }
    });

    test('primary and onPrimary', () {
      expect(contrast(scheme.onPrimary, scheme.primary), greaterThanOrEqualTo(6.5));
    });

    test('primary tint text is AA', () {
      expect(contrast(p.onPrimaryTint, Color.alphaBlend(p.primaryTint, p.card)),
          greaterThanOrEqualTo(aa));
      expect(contrast(scheme.onPrimaryContainer, scheme.primaryContainer),
          greaterThanOrEqualTo(aa));
    });

    test('metric colours are text-safe on bg, card and their 12 % chip tint', () {
      for (final m in _metrics(AppMetricColors.light)) {
        expect(contrast(m, p.bg), greaterThanOrEqualTo(aa), reason: '$m on bg');
        expect(contrast(m, p.card), greaterThanOrEqualTo(aa), reason: '$m on card');
        // Canvas: "Tinted chip · 12% háttér, sötét szöveg, AA ≥ 4.8:1" — the
        // promise the shared-lightness light set was tuned to keep.
        expect(contrast(m, tint(m, 0.12, p.card)), greaterThanOrEqualTo(4.8),
            reason: '$m on its tint');
      }
    });

    test('surface ladder darkens with nesting, cards stay white', () {
      expect(p.card, const Color(0xFFFFFFFF));
      final ladder = [p.card, p.nested, p.control, p.raised];
      for (var i = 1; i < ladder.length; i++) {
        expect(ladder[i].computeLuminance(), lessThan(ladder[i - 1].computeLuminance()));
      }
    });
  });

  test('protein is no longer the brand primary (D-R0.3)', () {
    expect(AppMetricColors.dark.protein, isNot(AppTheme.dark.colorScheme.primary));
    expect(AppMetricColors.light.protein, isNot(AppTheme.light.colorScheme.primary));
  });

  test('semantic roles alias their metric', () {
    for (final m in [AppMetricColors.dark, AppMetricColors.light]) {
      expect(m.improvement, m.protein);
      expect(m.record, m.carbs);
      expect(m.decrease, m.weight);
      expect(m.increase, m.calories);
    }
  });
}

List<Color> _metrics(AppMetricColors m) =>
    [m.calories, m.protein, m.carbs, m.fat, m.water, m.steps, m.weight, m.heart];
