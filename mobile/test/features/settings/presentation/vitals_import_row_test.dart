import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/health/vitals_import_controller.dart';
import 'package:lifey/core/health/health_controller.dart';
import 'package:lifey/core/theme/app_theme.dart';
import 'package:lifey/features/settings/presentation/widgets/settings_integrations.dart';
import 'package:lifey/l10n/app_localizations.dart';
import 'package:lifey/l10n/localization_delegates.dart';
import 'package:material_ui/material_ui.dart';

/// docs/integrations/89 G3.3: the "Resting heart rate & HRV" row. The line
/// under the title always tells the truth: it depends on Health being on,
/// says what on and off mean, and shows a revoked Health Connect permission.
class _FakeHealth extends HealthController {
  _FakeHealth(this._on);
  final bool _on;

  @override
  Future<bool> build() async => _on;
}

class _FakeVitalsImport extends VitalsImportController {
  _FakeVitalsImport(this._initial);
  final VitalsImportStatus _initial;
  final toggles = <bool>[];
  int permissionRequests = 0;

  @override
  Future<VitalsImportStatus> build() async => _initial;

  @override
  Future<void> setEnabled(bool enabled) async {
    toggles.add(enabled);
    state = AsyncData(VitalsImportStatus(enabled: enabled));
  }

  @override
  Future<void> requestPermissionAgain() async => permissionRequests++;
}

Future<_FakeVitalsImport> _pump(
  WidgetTester tester, {
  required bool health,
  required VitalsImportStatus status,
  Locale locale = const Locale('en'),
}) async {
  final fake = _FakeVitalsImport(status);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        healthControllerProvider.overrideWith(() => _FakeHealth(health)),
        vitalsImportControllerProvider.overrideWith(() => fake),
      ],
      child: MaterialApp(
        theme: AppTheme.dark,
        locale: locale,
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: VitalsImportRow()),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return fake;
}

Switch _switch(WidgetTester tester) => tester.widget<Switch>(find.byType(Switch));

void main() {
  testWidgets('off: says Lifey has no resting HR or HRV, and turning it on calls the controller', (tester) async {
    final fake = await _pump(tester, health: true, status: const VitalsImportStatus(enabled: false));

    expect(find.text('Resting heart rate & HRV'), findsOneWidget);
    expect(find.text('Off · no resting heart rate or HRV in Lifey'), findsOneWidget);
    expect(_switch(tester).value, isFalse);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(fake.toggles, [true]);
    expect(find.text('On · daily values from apps like Garmin Connect show up here'), findsOneWidget);
  });

  testWidgets('Health off: the switch is disabled and shown off, whatever the stored opt-in says', (tester) async {
    await _pump(tester, health: false, status: const VitalsImportStatus(enabled: true));

    expect(find.text('Turn on Health first'), findsOneWidget);
    expect(_switch(tester).value, isFalse);
    expect(_switch(tester).onChanged, isNull);
  });

  testWidgets('a revoked permission says so, and tapping the row asks again', (tester) async {
    final fake = await _pump(
      tester,
      health: true,
      status: const VitalsImportStatus(enabled: true, permissionMissing: true),
    );

    expect(find.text('Permission needed · tap to allow'), findsOneWidget);
    await tester.tap(find.text('Resting heart rate & HRV'));
    await tester.pumpAndSettle();
    expect(fake.permissionRequests, 1);
  });

  testWidgets('Hungarian', (tester) async {
    await _pump(tester, health: true, status: const VitalsImportStatus(enabled: false), locale: const Locale('hu'));

    expect(find.text('Nyugalmi pulzus és HRV'), findsOneWidget);
    expect(find.text('Ki · a Lifey nem lát nyugalmi pulzust és HRV-t'), findsOneWidget);
  });
}
