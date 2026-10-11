import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/theme/app_tokens.dart';

/// The home-screen widgets draw in their own language (XML on Android, SwiftUI on iOS), so their colours are copies of the app's
/// tokens - and a copy drifts the day somebody changes the palette. This reads the copies and compares them to the tokens
/// (LIF-110; docs/redesign/77 D-R0.2/R0.3), so the widget can no longer silently keep an old look.
///
/// Mapping: widget card = `card`, nested chip = `nested`, progress track = `control`, text = `text`, secondary text = `text2`,
/// calories / steps = the metric colours.
void main() {
  int argb(Color c) => c.toARGB32();

  /// `<color name="widget_x">#FFRRGGBB</color>` -> {widget_x: 0xFFRRGGBB}.
  Map<String, int> androidColors(String path) {
    final xml = File(path).readAsStringSync();
    return {
      for (final m in RegExp(r'<color name="([a-z_]+)">#([0-9A-Fa-f]{8})</color>').allMatches(xml))
        m.group(1)!: int.parse(m.group(2)!, radix: 16),
    };
  }

  /// The `static let light|dark = Palette(...)` block of the iOS widget -> {field: 0xFFRRGGBB}.
  Map<String, int> iosPalette(String theme) {
    final swift = File('ios/LifeyWidgets/TodaySummaryWidget.swift').readAsStringSync();
    final start = swift.indexOf('static let $theme = Palette(');
    expect(start, greaterThanOrEqualTo(0), reason: 'Palette.$theme not found');
    final block = swift.substring(start, swift.indexOf('\n  )', start));
    return {
      for (final m in RegExp(
        r'(\w+): Color\(red: 0x([0-9A-F]{2}) / 255, green: 0x([0-9A-F]{2}) / 255, blue: 0x([0-9A-F]{2}) / 255\)',
      ).allMatches(block))
        m.group(1)!: int.parse('FF${m.group(2)}${m.group(3)}${m.group(4)}', radix: 16),
    };
  }

  group('Android widget', () {
    for (final (name, path, palette, metric) in [
      ('light', 'android/app/src/main/res/values/widget_colors.xml', AppPalette.light, AppMetricColors.light),
      ('dark', 'android/app/src/main/res/values-night/widget_colors.xml', AppPalette.dark, AppMetricColors.dark),
    ]) {
      test('the $name colours are the app tokens', () {
        final colors = androidColors(path);

        expect(colors, hasLength(6));
        expect(colors['widget_container'], argb(palette.card));
        expect(colors['widget_surface'], argb(palette.nested));
        expect(colors['widget_progress_track'], argb(palette.control));
        expect(colors['widget_on_surface'], argb(palette.text));
        expect(colors['widget_on_surface_variant'], argb(palette.text2));
        expect(colors['widget_calories'], argb(metric.calories));
      });
    }
  });

  group('iOS widget and Live Activity palette', () {
    for (final (name, palette, metric) in [
      ('light', AppPalette.light, AppMetricColors.light),
      ('dark', AppPalette.dark, AppMetricColors.dark),
    ]) {
      test('the $name colours are the app tokens', () {
        final colors = iosPalette(name);

        expect(colors, hasLength(7));
        expect(colors['bg'], argb(palette.card));
        expect(colors['container'], argb(palette.nested));
        expect(colors['track'], argb(palette.control));
        expect(colors['onSurface'], argb(palette.text));
        expect(colors['onSurfaceVariant'], argb(palette.text2));
        expect(colors['calories'], argb(metric.calories));
        expect(colors['steps'], argb(metric.steps));
      });
    }

    test('the Live Activity draws from the palette, not from colours of its own', () {
      final swift = File('ios/LifeyWidgets/WorkoutLiveActivity.swift').readAsStringSync();

      expect(swift, isNot(contains('Color(red:')), reason: 'a literal colour would drift from the tokens again');
      expect(swift, isNot(contains('.white')));
      expect(swift, contains('.activityBackgroundTint(Palette.dark.bg)'));
    });
  });
}
