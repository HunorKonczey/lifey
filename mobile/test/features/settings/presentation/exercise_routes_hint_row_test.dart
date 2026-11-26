import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/health/cardio_import_controller.dart';
import 'package:lifey/core/health/health_connect_route_access.dart';
import 'package:lifey/core/health/health_controller.dart';
import 'package:lifey/core/theme/app_theme.dart';
import 'package:lifey/features/settings/presentation/widgets/settings_integrations.dart';
import 'package:lifey/l10n/app_localizations.dart';
import 'package:lifey/l10n/localization_delegates.dart';
import 'package:material_ui/material_ui.dart';

/// docs/integrations/89 G1.8, LIF-223: the Android hint that leads to Health Connect's Exercise routes permission.
class _FakeHealth extends HealthController {
  _FakeHealth(this._on);
  final bool _on;

  @override
  Future<bool> build() async => _on;
}

class _FakeCardioImport extends CardioImportController {
  _FakeCardioImport(this._status);
  final CardioImportStatus _status;

  @override
  Future<CardioImportStatus> build() async => _status;
}

class _FakeAccess extends HealthConnectRouteAccess {
  _FakeAccess({required this.granted, this.android = true, this.opens = true}) : super(isAvailable: android);

  bool? granted;
  final bool android;
  final bool opens;
  int opened = 0;
  int checks = 0;

  @override
  Future<bool?> routePermissionGranted() async {
    checks++;
    return granted;
  }

  @override
  Future<bool> openHealthConnect() async {
    opened++;
    return opens;
  }
}

Future<void> _pump(
  WidgetTester tester,
  _FakeAccess access, {
  bool health = true,
  CardioImportStatus status = const CardioImportStatus(enabled: true),
  Locale locale = const Locale('en'),
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        healthControllerProvider.overrideWith(() => _FakeHealth(health)),
        cardioImportControllerProvider.overrideWith(() => _FakeCardioImport(status)),
        healthConnectRouteAccessProvider.overrideWithValue(access),
      ],
      child: MaterialApp(
        theme: AppTheme.dark,
        locale: locale,
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: ExerciseRoutesHintRow()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

final _title = find.text('Route maps from other apps');

void main() {
  testWidgets('Android, import on, routes not granted: the row explains and opens Health Connect', (tester) async {
    final access = _FakeAccess(granted: false);
    await _pump(tester, access);

    expect(_title, findsOneWidget);
    expect(find.text('For maps of imported runs, allow exercise routes in Health Connect › Lifey › Additional access'), findsOneWidget);

    await tester.tap(_title);
    await tester.pumpAndSettle();
    expect(access.opened, 1);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('below Android 14 the grant is unknown, so the row stays', (tester) async {
    await _pump(tester, _FakeAccess(granted: null));

    expect(_title, findsOneWidget);
  });

  testWidgets('granted: no row', (tester) async {
    await _pump(tester, _FakeAccess(granted: true));

    expect(_title, findsNothing);
  });

  testWidgets('import off, Health off, or the workout permission gone: no row, the row above has the story', (tester) async {
    await _pump(tester, _FakeAccess(granted: false), status: const CardioImportStatus(enabled: false));
    expect(_title, findsNothing);

    await _pump(tester, _FakeAccess(granted: false), health: false);
    expect(_title, findsNothing);

    await _pump(tester, _FakeAccess(granted: false), status: const CardioImportStatus(enabled: true, permissionMissing: true));
    expect(_title, findsNothing);
  });

  testWidgets('iOS (no Health Connect): no row', (tester) async {
    await _pump(tester, _FakeAccess(granted: false, android: false));

    expect(_title, findsNothing);
  });

  testWidgets('coming back from Health Connect with the grant hides the row', (tester) async {
    final access = _FakeAccess(granted: false);
    await _pump(tester, access);
    expect(_title, findsOneWidget);

    access.granted = true;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(access.checks, 2);
    expect(_title, findsNothing);
  });

  testWidgets('when Health Connect will not open, a snackbar says where to go', (tester) async {
    await _pump(tester, _FakeAccess(granted: false, opens: false));

    await tester.tap(_title);
    await tester.pumpAndSettle();

    expect(find.textContaining('Lifey › Additional access, and allow exercise routes'), findsOneWidget);
  });

  testWidgets('Hungarian', (tester) async {
    await _pump(tester, _FakeAccess(granted: false), locale: const Locale('hu'));

    expect(find.text('Útvonaltérkép más appokból'), findsOneWidget);
  });

  group('HealthConnectRouteAccess', () {
    TestWidgetsFlutterBinding.ensureInitialized();
    const channel = MethodChannel('lifey/health_connect');

    tearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null));

    test('asks the native side, and reads a channel error as unknown / not opened', () async {
      final calls = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call.method);
        if (call.method == 'routePermissionGranted') return false;
        throw PlatformException(code: 'boom');
      });
      final access = HealthConnectRouteAccess(isAvailable: true);

      expect(await access.routePermissionGranted(), isFalse);
      expect(await access.openHealthConnect(), isFalse);
      expect(calls, ['routePermissionGranted', 'openHealthConnect']);
    });

    test('off Android it never calls the channel', () async {
      var called = false;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
        called = true;
        return true;
      });
      final access = HealthConnectRouteAccess(isAvailable: false);

      expect(await access.routePermissionGranted(), isNull);
      expect(await access.openHealthConnect(), isFalse);
      expect(called, isFalse);
    });
  });
}
