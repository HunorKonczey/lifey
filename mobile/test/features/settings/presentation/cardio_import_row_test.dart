import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/health/cardio_import_controller.dart';
import 'package:lifey/core/health/health_controller.dart';
import 'package:lifey/core/theme/app_theme.dart';
import 'package:lifey/features/settings/presentation/widgets/settings_integrations.dart';
import 'package:lifey/l10n/app_localizations.dart';
import 'package:lifey/l10n/localization_delegates.dart';
import 'package:material_ui/material_ui.dart';

/// docs/integrations/89 G1.6: the "Cardio from other apps" row. The line
/// under the title always tells the truth: it depends on Health being on,
/// says what on and off mean, and shows a revoked Health Connect permission.
class _FakeHealth extends HealthController {
  _FakeHealth(this._on);
  final bool _on;

  @override
  Future<bool> build() async => _on;
}

class _FakeCardioImport extends CardioImportController {
  _FakeCardioImport(this._initial);
  final CardioImportStatus _initial;
  final toggles = <bool>[];
  int permissionRequests = 0;

  @override
  Future<CardioImportStatus> build() async => _initial;

  @override
  Future<void> setEnabled(bool enabled) async {
    toggles.add(enabled);
    state = AsyncData(CardioImportStatus(enabled: enabled));
  }

  @override
  Future<void> requestPermissionAgain() async => permissionRequests++;
}

Future<_FakeCardioImport> _pump(
  WidgetTester tester, {
  required bool health,
  required CardioImportStatus status,
  Locale locale = const Locale('en'),
}) async {
  final fake = _FakeCardioImport(status);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        healthControllerProvider.overrideWith(() => _FakeHealth(health)),
        cardioImportControllerProvider.overrideWith(() => fake),
      ],
      child: MaterialApp(
        theme: AppTheme.dark,
        locale: locale,
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: CardioImportRow()),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return fake;
}

Switch _switch(WidgetTester tester) => tester.widget<Switch>(find.byType(Switch));

void main() {
  testWidgets('off: says only Lifey workouts count, and turning it on calls the controller', (tester) async {
    final fake = await _pump(tester, health: true, status: const CardioImportStatus(enabled: false));

    expect(find.text('Cardio from other apps'), findsOneWidget);
    expect(find.text('Off · only workouts recorded in Lifey'), findsOneWidget);
    expect(_switch(tester).value, isFalse);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(fake.toggles, [true]);
    expect(find.text('On · runs and rides from apps like Garmin Connect show up here'), findsOneWidget);
  });

  testWidgets('Health off: the switch is disabled and shown off, whatever the stored opt-in says', (tester) async {
    await _pump(tester, health: false, status: const CardioImportStatus(enabled: true));

    expect(find.text('Turn on Health first'), findsOneWidget);
    expect(_switch(tester).value, isFalse);
    expect(_switch(tester).onChanged, isNull);
  });

  testWidgets('a revoked permission says so, and tapping the row asks again', (tester) async {
    final fake = await _pump(
      tester,
      health: true,
      status: const CardioImportStatus(enabled: true, permissionMissing: true),
    );

    expect(find.text('Permission needed · tap to allow'), findsOneWidget);
    await tester.tap(find.text('Cardio from other apps'));
    await tester.pumpAndSettle();
    expect(fake.permissionRequests, 1);
  });

  testWidgets('Hungarian', (tester) async {
    await _pump(tester, health: true, status: const CardioImportStatus(enabled: false), locale: const Locale('hu'));

    expect(find.text('Cardio más appokból'), findsOneWidget);
    expect(find.text('Ki · csak a Lifey-ban rögzített edzések látszanak'), findsOneWidget);
  });
}
