import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/theme/app_theme.dart';
import 'package:lifey/l10n/app_localizations.dart';
import 'package:lifey/shared/widgets/ds/gallery/design_gallery_screen.dart';
import 'package:lifey/shared/widgets/ds/gallery/gallery_section.dart';

Future<void> _pumpGallery(WidgetTester tester) async {
  // The design's phone: 411 × 923 dp.
  tester.view.physicalSize = const Size(411 * 3, 923 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.light,
    darkTheme: AppTheme.dark,
    themeMode: ThemeMode.dark,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: const DesignGalleryScreen(),
  ));
  await tester.pumpAndSettle();
}

/// Taps a section chip in the toolbar — scrolling the chip row first, since
/// most chips sit off-screen at phone width.
Future<void> _jump(WidgetTester tester, String section) async {
  final chip = find.widgetWithText(ActionChip, section);
  await tester.ensureVisible(chip);
  await tester.pumpAndSettle();
  await tester.tap(chip);
  await tester.pumpAndSettle();
}

Future<void> _toggle(WidgetTester tester, String name) async {
  await tester.tap(find.byKey(ValueKey('gallery-$name')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('renders every section in every toolbar combination without overflow',
      (tester) async {
    await _pumpGallery(tester);
    for (final section in gallerySections) {
      expect(find.text(section.title, skipOffstage: false), findsWidgets);
    }

    // Walk the full matrix — theme × language × text scale × motion — in
    // Gray-code order: every step flips exactly one toggle, and all 16
    // combinations are visited.
    const toggles = ['theme', 'language', 'textScale', 'motion'];
    for (var i = 1; i < 16; i++) {
      final bit = (i & -i).bitLength - 1; // lowest set bit of i
      await tester.tap(find.byKey(ValueKey('gallery-${toggles[bit]}')));
      await tester.pumpAndSettle();
      final error = tester.takeException();
      expect(error, isNull,
          reason: 'combination ${i ^ (i >> 1)} (bits: theme, language, textScale, motion):\n'
              '${error is FlutterError ? error.toStringDeep() : error}');
    }
  });

  testWidgets('Hungarian preview formats dates in Hungarian', (tester) async {
    await _pumpGallery(tester);
    await _toggle(tester, 'language');
    expect(find.text('Csütörtök, szeptember 24.', skipOffstage: false), findsOneWidget);
  });

  testWidgets('the section chips jump to their section', (tester) async {
    await _pumpGallery(tester);
    final icons = gallerySections.last.title;
    final heading = find.descendant(of: find.byType(GalleryHeading), matching: find.text(icons));
    expect(tester.getTopLeft(heading).dy, greaterThan(923)); // far below the fold
    await _jump(tester, icons);
    final y = tester.getTopLeft(heading).dy;
    expect(y, inInclusiveRange(0, 923));
  });

  testWidgets('count-up demo animates to a new value', (tester) async {
    await _pumpGallery(tester);
    await _jump(tester, 'Motion');
    await tester.tap(find.text('New value'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.hasRunningAnimations, isTrue);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
