import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/theme/app_theme.dart';
import 'package:lifey/features/workouts/presentation/widgets/workout_header_pills.dart';
import 'package:lifey/l10n/app_localizations.dart';
import 'package:lifey/shared/widgets/ds/lifey_header.dart';

/// LIF-130: with a watch measuring, the timer, the watch mark, the heart rate
/// and the calories were all pills in the header's action slot, so the title
/// shrank to nothing and a three-digit calorie value overflowed the row. Now
/// only the timer stays there and the rest is [WorkoutLiveStrip] under it.
///
/// The test font is wider than the real one, so absolute shrink factors mean
/// little here; what is pinned is the comparison with the old arrangement and
/// the absence of an overflow.
const _timer = WorkoutHeaderPill(icon: Icons.timer_outlined, iconColor: Colors.green, text: '1:23:45');

List<Widget> get _watchPills => const [
      WorkoutHeaderPill(icon: Icons.watch_rounded, iconColor: Colors.green),
      WorkoutHeaderPill(icon: Icons.favorite_rounded, iconColor: Colors.red, text: '142'),
      WorkoutHeaderPill(icon: Icons.local_fire_department_rounded, iconColor: Colors.orange, text: '312'),
    ];

Future<void> _pump(
  WidgetTester tester, {
  required double width,
  required Locale locale,
  double textScale = 1,
  String title = 'Upper A',
  String subtitle = '1 of 3 exercises',
  List<Widget> actions = const [_timer],
  Widget? body,
}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(
        appBar: LifeySubpageHeader(title: title, subtitle: subtitle, actions: actions),
        body: body ?? const SizedBox.shrink(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// How much the header shrank [text] to make it fit: 1.0 is its natural size.
double _scaleOf(WidgetTester tester, String text) {
  final fitted = find.ancestor(of: find.text(text), matching: find.byType(FittedBox)).first;
  final box = tester.getSize(fitted).width;
  final natural = tester.getSize(find.text(text)).width;
  return natural <= box ? 1.0 : box / natural;
}

void main() {
  for (final (name, locale, title, subtitle) in [
    ('English', const Locale('en'), 'Upper A', '1 of 3 exercises'),
    ('Hungarian', const Locale('hu'), 'Felsőtest A', '1. / 3 gyakorlat'),
  ]) {
    for (final width in [360.0, 411.0]) {
      for (final scale in [1.0, 1.3]) {
        testWidgets('the title gets its room back: $name, $width dp, x $scale', (tester) async {
          // The old arrangement: all four pills in the header.
          await _pump(tester,
              width: width, locale: locale, textScale: scale, title: title, subtitle: subtitle,
              actions: [_timer, ..._watchPills]);
          tester.takeException(); // the overflow stripe this ticket is about
          final before = _scaleOf(tester, title);

          // Now: the timer alone, the watch pills in the strip below.
          await _pump(tester,
              width: width, locale: locale, textScale: scale, title: title, subtitle: subtitle,
              body: const Padding(
                padding: EdgeInsets.all(20),
                child: WorkoutLiveStrip(measuringOnWatch: true, heartRate: 142, calories: 312),
              ));
          expect(tester.takeException(), isNull, reason: 'no overflow stripe');
          final after = _scaleOf(tester, title);

          expect(before, lessThan(1.0), reason: 'the old header really did squeeze the title');
          expect(after, greaterThan(before * 1.4));
          expect(_scaleOf(tester, subtitle), greaterThan(before));
        });
      }
    }
  }

  group('the strip', () {
    testWidgets('shows only what the watch reports', (tester) async {
      await _pump(
        tester,
        width: 411,
        locale: const Locale('en'),
        body: const WorkoutLiveStrip(measuringOnWatch: false, calories: 87),
      );

      expect(find.byIcon(Icons.watch_rounded), findsNothing);
      expect(find.byIcon(Icons.favorite_rounded), findsNothing);
      expect(find.text('87'), findsOneWidget);
    });

    testWidgets('is empty, and reports it, with nothing to show', (tester) async {
      const strip = WorkoutLiveStrip(measuringOnWatch: false);
      expect(strip.hasContent, isFalse);
      expect(const WorkoutLiveStrip(measuringOnWatch: true).hasContent, isTrue);
      expect(const WorkoutLiveStrip(measuringOnWatch: false, heartRate: 90).hasContent, isTrue);
    });

    testWidgets('wraps onto a second line instead of overflowing when it cannot fit', (tester) async {
      // On its own, without the header: this is about the strip's own layout.
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          locale: const Locale('hu'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2.0)),
            child: child!,
          ),
          home: const Scaffold(
            body: Padding(
              padding: EdgeInsets.all(20),
              child: WorkoutLiveStrip(measuringOnWatch: true, heartRate: 188, calories: 1234),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final heart = tester.getTopLeft(find.byIcon(Icons.favorite_rounded)).dy;
      final fire = tester.getTopLeft(find.byIcon(Icons.local_fire_department_rounded)).dy;
      expect(fire, greaterThan(heart), reason: 'the calories pill dropped to its own line');
    });
  });
}
