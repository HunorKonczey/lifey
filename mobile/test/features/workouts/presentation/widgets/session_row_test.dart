import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/sync/sync_status_provider.dart';
import 'package:lifey/core/theme/app_theme.dart';
import 'package:lifey/features/settings/domain/user_settings.dart';
import 'package:lifey/features/workouts/domain/workout_session.dart';
import 'package:lifey/features/workouts/presentation/widgets/session_row.dart';
import 'package:lifey/l10n/app_localizations.dart';
import 'package:lifey/shared/widgets/ds/tinted_chip.dart';

final _wed = DateTime(2026, 9, 23, 17, 30);

WorkoutSession _strength({String? name = 'Pull day', int minutes = 34, int sets = 7}) => WorkoutSession(
      clientId: 's',
      exercises: const [],
      sets: [
        for (var i = 0; i < sets; i++)
          ExerciseSet(
            exerciseClientId: 'e${i % 4}',
            exerciseName: ['Deadlift', 'Pull Up', 'Barbell Row', 'Bicep Curl'][i % 4],
            reps: 8,
            weight: 60,
            performedAt: _wed.add(Duration(minutes: i)),
          ),
      ],
      startedAt: _wed,
      finishedAt: _wed.add(Duration(minutes: minutes)),
      templateName: name,
    );

WorkoutSession _run({double? hr, bool health = false, double meters = 5210, int seconds = 1660}) => WorkoutSession(
      clientId: 'r',
      exercises: const [],
      sets: const [],
      startedAt: DateTime(2026, 9, 22, 7, 45),
      finishedAt: DateTime(2026, 9, 22, 7, 45).add(Duration(seconds: seconds)),
      sessionKind: 'CARDIO',
      activityType: 'RUNNING',
      movingSeconds: seconds,
      averageHeartRate: hr,
      healthWorkoutId: health ? 'hc' : null,
      cardio: CardioMetrics(distanceMeters: meters),
    );

Future<void> _pump(
  WidgetTester tester,
  WorkoutSession session, {
  int prs = 0,
  SessionRowDate date = SessionRowDate.weekday,
  UnitSystem units = UnitSystem.metric,
  Locale locale = const Locale('en'),
  double textScale = 1,
  double width = 411,
}) async {
  tester.view.physicalSize = Size(width * 2.625, 923 * 2.625);
  tester.view.devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [syncStatusByClientIdProvider.overrideWithValue(const {})],
      child: MaterialApp(
        theme: AppTheme.dark,
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Scaffold(
          body: SessionRow(
            session: session,
            unitSystem: units,
            prCount: prs,
            date: date,
            onTap: () {},
            onLongPress: () {},
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

/// All the row's rich text, with no-break spaces and the zero-width breaks read
/// as plain characters.
String _rich(WidgetTester tester) => tester
    .widgetList<RichText>(find.byType(RichText))
    .map((r) => r.text.toPlainText().replaceAll(' ', ' ').replaceAll('​', ''))
    .join('|');

void main() {
  testWidgets('strength: title, "Wed 17:30 · 34 min · 7 sets · 3,360 kg", the exercises', (tester) async {
    await _pump(tester, _strength());

    expect(find.text('Pull day'), findsOneWidget);
    expect(_rich(tester), contains('Wed 17:30 · 34 min · 7 sets · 3,360 kg'));
    expect(find.text('Deadlift, Pull Up, Barbell Row, Bicep Curl'), findsOneWidget);
    expect(find.byIcon(Icons.fitness_center_rounded), findsOneWidget);
  });

  testWidgets('under "Today" the row leaves the weekday out', (tester) async {
    await _pump(tester, _strength(), date: SessionRowDate.none);

    expect(_rich(tester), contains('34 min · 7 sets'));
    expect(_rich(tester), isNot(contains('Wed')));
  });

  testWidgets('an older week is dated, not weekday-named', (tester) async {
    await _pump(tester, _strength(), date: SessionRowDate.date);

    expect(_rich(tester), contains('Sep 23 17:30 · 34 min'));
  });

  testWidgets('a template-less strength session is titled "Strength"', (tester) async {
    await _pump(tester, _strength(name: null));

    expect(find.text('Strength'), findsOneWidget);
  });

  testWidgets('cardio: distance, pace and average heart rate — the heart rate in the heart colour', (tester) async {
    await _pump(tester, _run(hr: 156, health: true));

    expect(_rich(tester), contains('Tue 07:45 · 5.21 km · 5:19 /km · 156 bpm'));
    expect(find.text('Heart rate from Health Connect'), findsOneWidget);
    final bpm = tester
        .widgetList<RichText>(find.byType(RichText))
        .expand((r) => _spans(r.text))
        .firstWhere((s) => (s.text ?? '').contains('bpm'));
    expect(bpm.style?.color, isNotNull);
  });

  testWidgets('no heart rate, no source line', (tester) async {
    await _pump(tester, _run());

    expect(_rich(tester), isNot(contains('bpm')));
    expect(find.textContaining('Heart rate from'), findsNothing);
  });

  testWidgets('the record chip counts the session\'s PRs', (tester) async {
    await _pump(tester, _strength(), prs: 2);

    expect(find.byType(TintedChip), findsOneWidget);
    expect(find.text('2 PRs'), findsOneWidget);
  });

  testWidgets('one PR reads in the singular; none shows no chip', (tester) async {
    await _pump(tester, _strength(), prs: 1);
    expect(find.text('1 PR'), findsOneWidget);

    await _pump(tester, _strength());
    expect(find.byType(TintedChip), findsNothing);
  });

  testWidgets('imperial: miles, pace per mile, pounds', (tester) async {
    await _pump(tester, _run(), units: UnitSystem.imperial);
    expect(_rich(tester), contains('3.24 mi'));
    expect(_rich(tester), contains('/mi'));

    await _pump(tester, _strength(), units: UnitSystem.imperial);
    expect(_rich(tester), contains('7,408 lb'));
  });

  testWidgets('Hungarian: decimal comma, the health source line is one line of the row', (tester) async {
    await _pump(tester, _run(hr: 156, health: true), locale: const Locale('hu'));

    expect(_rich(tester), contains('5,21 km'));
    expect(find.textContaining('Health Connect'), findsOneWidget);
  });

  for (final width in [411.0, 360.0]) {
    for (final scale in [1.0, 1.3]) {
      testWidgets('no overflow at ${width.toInt()} dp, text x$scale, HU, with a record', (tester) async {
        await _pump(
          tester,
          _run(hr: 156, health: true),
          prs: 2,
          locale: const Locale('hu'),
          textScale: scale,
          width: width,
        );
        expect(tester.takeException(), isNull);

        await _pump(tester, _strength(name: 'Hosszú nevű edzésterv a hét közepére'), prs: 12, locale: const Locale('hu'), textScale: scale, width: width);
        expect(tester.takeException(), isNull);
      });
    }
  }
}

Iterable<TextSpan> _spans(InlineSpan span) sync* {
  if (span is TextSpan) {
    yield span;
    for (final child in span.children ?? const <InlineSpan>[]) {
      yield* _spans(child);
    }
  }
}
