import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/theme/app_theme.dart';
import 'package:lifey/core/theme/app_tokens.dart';
import 'package:lifey/features/trainer/shared/trainer_view_badge.dart';
import 'package:lifey/l10n/app_localizations.dart';

void main() {
  group('the trainer shell is the client app\'s family (R6.1)', () {
    test('no `tertiary` accent is used anywhere under features/trainer or in the trainer shell widgets', () {
      final roots = [Directory('lib/features/trainer'), Directory('lib/shared/widgets')];
      final offenders = <String>[];
      for (final root in roots) {
        for (final file in root.listSync(recursive: true).whereType<File>()) {
          final path = file.path.replaceAll('\\', '/');
          if (!path.endsWith('.dart')) continue;
          if (path.startsWith('lib/shared/widgets/') && !path.contains('trainer_')) continue;
          if (RegExp(r'[Tt]ertiary').hasMatch(file.readAsStringSync())) offenders.add(path);
        }
      }
      expect(offenders, isEmpty, reason: 'the role is the clay palette.role mark, not a second green');
    });

    for (final (mode, theme) in [('dark', AppTheme.dark), ('light', AppTheme.light)]) {
      testWidgets('the TRAINER mark is clay on a clay tint ($mode)', (tester) async {
        await tester.pumpWidget(MaterialApp(
          theme: theme,
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: Center(child: TrainerViewBadge())),
        ));

        final text = tester.widget<Text>(find.text('TRAINER'));
        final context = tester.element(find.text('TRAINER'));
        expect(text.style!.color, context.palette.role);
        final box = tester.widget<Container>(find.ancestor(of: find.text('TRAINER'), matching: find.byType(Container)).first);
        final fill = (box.decoration! as BoxDecoration).color!;
        expect(fill.a, lessThan(0.3)); // a tint, not a solid fill
        expect(fill.r, closeTo(context.palette.role.r, 0.01));
      });
    }
  });
}
