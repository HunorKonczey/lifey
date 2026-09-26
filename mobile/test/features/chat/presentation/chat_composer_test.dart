import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/theme/app_theme.dart';
import 'package:lifey/features/chat/presentation/widgets/chat_composer.dart';
import 'package:lifey/features/chat/presentation/widgets/day_divider.dart';
import 'package:lifey/l10n/app_localizations.dart';

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  ThemeData? theme,
  Locale locale = const Locale('en'),
  double textScale = 1,
  Size size = const Size(390, 844),
}) async {
  tester.view.physicalSize = size * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: theme ?? AppTheme.dark,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, c) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
        child: c!,
      ),
      home: Scaffold(
        body: Column(mainAxisAlignment: MainAxisAlignment.end, crossAxisAlignment: CrossAxisAlignment.stretch, children: [child]),
      ),
    ),
  );
  // The typing dots animate for ever, so there is nothing to settle.
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  group('ChatComposer (canvas 7)', () {
    testWidgets('a 48 dp field between the picture button and a round send button', (tester) async {
      await _pump(tester, ChatComposer(onSend: (_, __) {}));

      expect(find.byIcon(Icons.add_photo_alternate_outlined), findsOneWidget);
      expect(find.byIcon(Icons.arrow_upward_rounded), findsOneWidget);
      final pill = find.ancestor(of: find.byType(TextField), matching: find.byType(Container)).first;
      expect(tester.getSize(pill).height, 48);
      final send = tester.getSize(find.widgetWithIcon(IconButton, Icons.arrow_upward_rounded));
      expect(send, const Size.square(48));
    });

    testWidgets('send is off until there is something to send, then hands the text over', (tester) async {
      String? sent;
      await _pump(tester, ChatComposer(onSend: (body, File? _) => sent = body));

      final sendFinder = find.widgetWithIcon(IconButton, Icons.arrow_upward_rounded);
      expect(tester.widget<IconButton>(sendFinder).onPressed, isNull);

      await tester.enterText(find.byType(TextField), '  Perfect, I will try that  ');
      await tester.pump();
      expect(tester.widget<IconButton>(sendFinder).onPressed, isNotNull);

      await tester.tap(sendFinder);
      await tester.pump();
      expect(sent, 'Perfect, I will try that');
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, isEmpty);
    });

    for (final (name, locale) in [('English', const Locale('en')), ('Hungarian', const Locale('hu'))]) {
      testWidgets('fits a 360 dp phone at × 1.3 in $name, dark and light', (tester) async {
        for (final theme in [AppTheme.dark, AppTheme.light]) {
          await _pump(
            tester,
            ChatComposer(onSend: (_, __) {}, peerTypingName: 'Mark Trainer'),
            theme: theme,
            locale: locale,
            textScale: 1.3,
            size: const Size(360, 740),
          );
          expect(tester.takeException(), isNull);
        }
      });
    }

    testWidgets('an archived thread swaps the input for a notice on the card surface', (tester) async {
      await _pump(tester, const ArchivedComposerNotice());

      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    });
  });

  testWidgets('the day divider is a quiet pill', (tester) async {
    await _pump(tester, DayDivider(day: DateTime.now()));

    expect(find.text('Today'), findsOneWidget);
  });
}
