import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/theme/app_theme.dart';
import 'package:lifey/features/sleep/application/sleep_session_controller.dart';
import 'package:lifey/features/sleep/domain/sleep_session.dart';
import 'package:lifey/features/sleep/presentation/sleep_history_screen.dart';
import 'package:lifey/l10n/app_localizations.dart';
import 'package:lifey/l10n/localization_delegates.dart';
import 'package:material_ui/material_ui.dart';

/// docs/integrations/89 G2.6: the sleep history — the 7-day average, the
/// weekly list and the nap marking.
void main() {
  // Saturday 21 Nov 2026.
  final now = DateTime(2026, 11, 21, 20);

  SleepSession s(String id, DateTime start, DateTime end) => SleepSession(clientId: id, startedAt: start, endedAt: end);

  final night = s('night', DateTime(2026, 11, 20, 23), DateTime(2026, 11, 21, 6, 30));
  final nap = s('nap', DateTime(2026, 11, 21, 14), DateTime(2026, 11, 21, 14, 40));
  final midweek = s('midweek', DateTime(2026, 11, 16, 23), DateTime(2026, 11, 17, 7));
  final lastWeek = s('last', DateTime(2026, 11, 12, 22, 30), DateTime(2026, 11, 13, 6));
  final older = s('older', DateTime(2026, 11, 2, 23), DateTime(2026, 11, 3, 6, 45));

  Future<void> pump(WidgetTester tester, List<SleepSession> sessions, {Locale locale = const Locale('en')}) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sleepSessionControllerProvider.overrideWith(() => _FakeSessions(sessions))],
        child: MaterialApp(
          theme: AppTheme.dark,
          locale: locale,
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SleepHistoryScreen(now: () => now),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the average of the last 7 nights on top, the sessions grouped by week', (tester) async {
    await pump(tester, [nap, night, midweek, lastWeek, older]);

    expect(find.text('7-day average'), findsOneWidget);
    // 7:30 and 8:00; the nap and the older weeks don't count.
    expect(find.textContaining('7:45'), findsOneWidget);
    expect(find.text('From 2 nights'), findsOneWidget);

    expect(find.text('THIS WEEK'), findsOneWidget);
    expect(find.text('LAST WEEK'), findsOneWidget);
    expect(find.text('NOV 2 – NOV 8'), findsOneWidget);
    expect(find.text('23:00–06:30'), findsOneWidget);
  });

  testWidgets('a nap is marked as one, the main sleep is not', (tester) async {
    await pump(tester, [nap, night]);

    expect(find.text('Nap · 14:00–14:40'), findsOneWidget);
    expect(find.byIcon(Icons.snooze_rounded), findsOneWidget);
    expect(find.text('23:00–06:30'), findsOneWidget);
  });

  testWidgets('no night in the last 7 days: the average says so', (tester) async {
    await pump(tester, [older]);

    expect(find.text('No night in the last 7 days'), findsOneWidget);
    expect(find.text('—'), findsOneWidget);
  });

  testWidgets('empty: points to the setting that imports sleep', (tester) async {
    await pump(tester, const []);

    expect(find.text('No sleep yet'), findsOneWidget);
  });

  testWidgets('Hungarian', (tester) async {
    await pump(tester, [nap, night], locale: const Locale('hu'));

    expect(find.text('7 napos átlag'), findsOneWidget);
    expect(find.text('1 éjszaka alapján'), findsOneWidget);
    expect(find.text('Szundi · 14:00–14:40'), findsOneWidget);
    expect(find.text('EZ A HÉT'), findsOneWidget);
  });
}

class _FakeSessions extends SleepSessionController {
  _FakeSessions(this._sessions);
  final List<SleepSession> _sessions;

  @override
  Stream<List<SleepSession>> build() => Stream.value(_sessions);
}
