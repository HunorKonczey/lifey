import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/health/health_controller.dart';
import 'package:lifey/core/health/sleep_import_controller.dart';
import 'package:lifey/core/theme/app_theme.dart';
import 'package:lifey/features/sleep/application/sleep_session_controller.dart';
import 'package:lifey/features/sleep/domain/sleep_session.dart';
import 'package:lifey/features/sleep/presentation/widgets/sleep_tile.dart';
import 'package:lifey/l10n/app_localizations.dart';
import 'package:lifey/l10n/localization_delegates.dart';
import 'package:lifey/shared/widgets/ds/metric_bar.dart';
import 'package:material_ui/material_ui.dart';

/// docs/integrations/89 G2.5: the Today sleep tile's three states (stages,
/// duration only, no data) and when it shows at all.
void main() {
  final now = DateTime(2026, 11, 21, 9);

  SleepSession night({bool staged = true, DateTime? end}) {
    final ended = end ?? DateTime(2026, 11, 21, 6, 10);
    return SleepSession(
      clientId: 'n',
      startedAt: ended.subtract(const Duration(hours: 7, minutes: 30)),
      endedAt: ended,
      asleepMinutes: staged ? 420 : null,
      deepMinutes: staged ? 80 : null,
      lightMinutes: staged ? 230 : null,
      remMinutes: staged ? 110 : null,
      awakeMinutes: staged ? 30 : null,
    );
  }

  Future<void> pump(
    WidgetTester tester, {
    required List<SleepSession> sessions,
    bool health = true,
    bool importOn = true,
    Locale locale = const Locale('en'),
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sleepSessionControllerProvider.overrideWith(() => _FakeSessions(sessions)),
          healthControllerProvider.overrideWith(() => _FakeHealth(health)),
          sleepImportControllerProvider.overrideWith(() => _FakeImport(importOn)),
        ],
        child: MaterialApp(
          theme: AppTheme.dark,
          locale: locale,
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: TodaySleepTile(now: () => now)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('stages: duration, bedtime–wake-up line, stage bar and legend', (tester) async {
    await pump(tester, sessions: [night()]);

    expect(find.text('Sleep'), findsOneWidget);
    expect(find.textContaining('7:30'), findsOneWidget);
    expect(find.text('22:40–06:10'), findsOneWidget);
    expect(find.byType(RatioBar), findsOneWidget);
    expect(find.text('Deep 1:20'), findsOneWidget);
    expect(find.text('Light 3:50'), findsOneWidget);
    expect(find.text('REM 1:50'), findsOneWidget);
    expect(find.text('Awake 0:30'), findsOneWidget);
  });

  testWidgets('duration only: no stage bar', (tester) async {
    await pump(tester, sessions: [night(staged: false)]);

    expect(find.textContaining('7:30'), findsOneWidget);
    expect(find.text('22:40–06:10'), findsOneWidget);
    expect(find.byType(RatioBar), findsNothing);
  });

  testWidgets('no data: nothing ended today, so the tile says so', (tester) async {
    // Yesterday's night is not last night.
    await pump(tester, sessions: [night(end: DateTime(2026, 11, 20, 6, 10))]);

    expect(find.text('—'), findsOneWidget);
    expect(find.text('Nothing recorded last night'), findsOneWidget);
    expect(find.byType(RatioBar), findsNothing);
  });

  testWidgets('the main sleep wins over the nap of the same day', (tester) async {
    final nap = SleepSession(
      clientId: 'nap',
      startedAt: DateTime(2026, 11, 21, 8),
      endedAt: DateTime(2026, 11, 21, 8, 40),
    );
    await pump(tester, sessions: [nap, night()]);

    expect(find.text('22:40–06:10'), findsOneWidget);
  });

  testWidgets('hidden for a user who neither imports sleep nor has any', (tester) async {
    await pump(tester, sessions: const [], importOn: false);
    expect(find.text('Sleep'), findsNothing);

    await pump(tester, sessions: const [], health: false);
    expect(find.text('Sleep'), findsNothing);
  });

  testWidgets('import on but no night yet: the no-data state shows', (tester) async {
    await pump(tester, sessions: const []);

    expect(find.text('Nothing recorded last night'), findsOneWidget);
  });

  testWidgets('Hungarian', (tester) async {
    await pump(tester, sessions: [night()], locale: const Locale('hu'));

    expect(find.text('Alvás'), findsOneWidget);
    expect(find.textContaining('7:30 ó'), findsOneWidget);
    expect(find.text('Mély 1:20'), findsOneWidget);
  });
}

class _FakeSessions extends SleepSessionController {
  _FakeSessions(this._sessions);
  final List<SleepSession> _sessions;

  @override
  Stream<List<SleepSession>> build() => Stream.value(_sessions);
}

class _FakeHealth extends HealthController {
  _FakeHealth(this._on);
  final bool _on;

  @override
  Future<bool> build() async => _on;
}

class _FakeImport extends SleepImportController {
  _FakeImport(this._on);
  final bool _on;

  @override
  Future<SleepImportStatus> build() async => SleepImportStatus(enabled: _on);
}
