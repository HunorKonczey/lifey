import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/features/workouts/presentation/widgets/gps_explainer_sheet.dart';
import 'package:lifey/l10n/app_localizations.dart';

/// C4a.2, M26 — the one-time GPS explainer shown before the first-ever
/// DISTANCE-family quick-start. `quick_start_sheet_test.dart`'s own
/// "GPS explainer" group covers when it shows and what each choice does
/// end-to-end; this file only covers the sheet's own content/return value.

/// Pumps a screen with a button that opens [GpsExplainerSheet] and stores
/// its eventual result in [onResult] once the sheet is dismissed.
Future<void> _pumpTrigger(WidgetTester tester, void Function(GpsExplainerChoice?) onResult) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async => onResult(await showGpsExplainerSheet(context)),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the title, body, all three bullets, and both buttons', (tester) async {
    await _pumpTrigger(tester, (_) {});

    expect(find.text('So we can see where you ran'), findsOneWidget);
    expect(
      find.text(
        'We use your location to calculate distance, pace, and your route. It stays on your phone and works offline.',
      ),
      findsOneWidget,
    );
    expect(find.text('Route and km splits'), findsOneWidget);
    expect(find.text('Live pace while you run'), findsOneWidget);
    expect(find.text('We never upload anything'), findsOneWidget);
    expect(find.text('Allow location'), findsOneWidget);
    expect(find.text('Start without GPS'), findsOneWidget);
    expect(find.text('You can enter the distance manually afterward.'), findsOneWidget);
  });

  testWidgets('tapping "Allow location" pops GpsExplainerChoice.requestPermission', (tester) async {
    GpsExplainerChoice? result;
    await _pumpTrigger(tester, (r) => result = r);

    await tester.tap(find.text('Allow location'));
    await tester.pumpAndSettle();

    expect(result, GpsExplainerChoice.requestPermission);
  });

  testWidgets('tapping "Start without GPS" pops GpsExplainerChoice.skipGps', (tester) async {
    GpsExplainerChoice? result;
    await _pumpTrigger(tester, (r) => result = r);

    await tester.tap(find.text('Start without GPS'));
    await tester.pumpAndSettle();

    expect(result, GpsExplainerChoice.skipGps);
  });
}
