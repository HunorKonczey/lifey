import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/theme/app_theme.dart';
import 'package:lifey/features/workouts/data/workout_session_repository.dart';
import 'package:lifey/features/workouts/domain/personal_record.dart';
import 'package:lifey/features/workouts/presentation/widgets/exercise_session_card.dart';
import 'package:lifey/l10n/app_localizations.dart';

/// The calls the card makes back to the screen.
class _Calls {
  final markDone = <int>[];
  final reopen = <int>[];
  final edit = <(int, double?, int?)>[];
  final delete = <int>[];
  final duplicate = <int>[];
  final addSet = <bool>[];
}

ExerciseBlock _bench({List<SetRow>? rows, PrBaseline? baseline}) => ExerciseBlock(
      exerciseClientId: 'bench',
      exerciseName: 'Bench Press',
      rows: rows ??
          [
            SetRow(weight: 50, reps: 8, doneAt: DateTime(2026, 9, 24, 8)),
            SetRow(),
            SetRow(),
            SetRow(),
          ],
    )
      ..previousSets = const [
        PreviousSetHint(weight: 47.5, reps: 8),
        PreviousSetHint(weight: 47.5, reps: 8),
        PreviousSetHint(weight: 47.5, reps: 8),
        PreviousSetHint(weight: 47.5, reps: 7),
      ]
      ..prBaseline = baseline;

Future<_Calls> _pump(
  WidgetTester tester,
  ExerciseBlock block, {
  Locale locale = const Locale('en'),
  double textScale = 1,
  double width = 411,
  ThemeData? theme,
}) async {
  tester.view.physicalSize = Size(width * 2.625, 1200 * 2.625);
  tester.view.devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);
  final calls = _Calls();
  await tester.pumpWidget(
    MaterialApp(
      theme: theme ?? AppTheme.dark,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ExerciseSessionCard(
            block: block,
            onRowMarkDone: calls.markDone.add,
            onRowReopen: calls.reopen.add,
            onRowEdit: (i, w, r) => calls.edit.add((i, w, r)),
            onRowDelete: calls.delete.add,
            onRowDuplicate: calls.duplicate.add,
            onAddSet: calls.addSet.add,
            onRemoveExercise: () {},
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return calls;
}

/// A tap that waits out the row's double-tap window (300 ms) — the row
/// duplicates on a double-tap, so a single tap on a child is only delivered
/// once that recogniser has given up.
Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.tap(finder);
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  testWidgets('the canvas card: name, best line, column header, four rows, "Add set"', (tester) async {
    final baseline = PrBaseline.fromSets([(weight: 50, reps: 8, performedAt: DateTime(2026, 9, 1))]);
    await _pump(tester, _bench(baseline: baseline));

    expect(find.text('Bench Press'), findsOneWidget);
    expect(find.text('Best 50 kg × 8 · e1RM 63.3 kg'), findsOneWidget);
    for (final label in ['SET', 'PREV.', 'KG', 'REPS']) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    expect(find.text('Add set'), findsOneWidget);
    for (final n in ['1', '2', '3', '4']) {
      expect(find.text(n), findsOneWidget, reason: 'set $n');
    }
  });

  testWidgets('no best line until the history is loaded, or without a weighted set', (tester) async {
    await _pump(tester, _bench());
    expect(find.textContaining('Best'), findsNothing);
  });

  testWidgets('rows are 52 dp tall and the check is a 40 dp button', (tester) async {
    await _pump(tester, _bench());

    final row = find.ancestor(of: find.text('2'), matching: find.byType(AnimatedContainer)).first;
    expect(tester.getSize(row).height, greaterThanOrEqualTo(52));
    final check = find.byIcon(Icons.check_rounded).first;
    final button = find.ancestor(of: check, matching: find.byType(InkWell)).first;
    expect(tester.getSize(button), const Size.square(40));
  });

  testWidgets('a done row is tinted with the improvement colour, a plan row is not', (tester) async {
    await _pump(tester, _bench());

    Color? tint(String setNumber) {
      final container = tester.widget<AnimatedContainer>(
        find.ancestor(of: find.text(setNumber), matching: find.byType(AnimatedContainer)).first,
      );
      return (container.decoration as BoxDecoration).color;
    }

    expect(tint('1')!.a, greaterThan(0));
    expect(tint('2'), Colors.transparent);
  });

  testWidgets('a plan row shows last time faintly in its pills and in PREV', (tester) async {
    await _pump(tester, _bench());

    expect(find.text('47.5×8'), findsWidgets);
    expect(find.text('47.5'), findsWidgets); // the KG pills of the plan rows
  });

  testWidgets('a done row: 50 with ↑, 8, its PREV stays', (tester) async {
    await _pump(tester, _bench());

    expect(find.text('50'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_upward_rounded), findsOneWidget); // 50 > 47.5
    expect(find.byIcon(Icons.remove_rounded), findsOneWidget); // reps unchanged
  });

  testWidgets('a set that set a record carries the trophy', (tester) async {
    final block = _bench();
    block.rows.first.prTypes = {PrType.maxWeight};
    await _pump(tester, block);

    expect(find.byIcon(Icons.emoji_events_rounded), findsOneWidget);
  });

  testWidgets('the check of a done row reopens it', (tester) async {
    final calls = await _pump(tester, _bench());

    await _tap(tester, find.byIcon(Icons.check_rounded).first);

    expect(calls.reopen, [0]);
  });

  testWidgets("the check of a plan row logs last time's set", (tester) async {
    final calls = await _pump(tester, _bench());

    await _tap(tester, find.byIcon(Icons.check_rounded).at(1));

    expect(calls.edit, [(1, 47.5, 8)]);
    expect(calls.markDone, isEmpty);
  });

  testWidgets('the check of a plan row that already has values just marks it done', (tester) async {
    final calls = await _pump(tester, _bench(rows: [SetRow(weight: 52.5, reps: 6)]));

    await _tap(tester, find.byIcon(Icons.check_rounded).first);

    expect(calls.markDone, [0]);
    expect(calls.edit, isEmpty);
  });

  testWidgets('a plan row with nothing to log opens the editor', (tester) async {
    final block = _bench(rows: [SetRow()]);
    block.previousSets = const [];
    await _pump(tester, block);

    await _tap(tester, find.byIcon(Icons.check_rounded).first);
    await tester.pumpAndSettle();

    expect(find.text('Edit set'), findsOneWidget);
  });

  testWidgets('tapping a pill opens the editor with the row values; Save reports them', (tester) async {
    final calls = await _pump(tester, _bench());

    await _tap(tester, find.text('50'));
    await tester.pumpAndSettle();
    expect(find.text('Edit set'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextFormField, '50'), '52.5');
    await _tap(tester, find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(calls.edit, [(0, 52.5, 8)]);
  });

  testWidgets('long-press opens Duplicate / Remove; Remove reports the row', (tester) async {
    final calls = await _pump(tester, _bench());

    await tester.longPress(find.text('3'));
    await tester.pumpAndSettle();
    expect(find.text('Duplicate'), findsOneWidget);
    await _tap(tester, find.text('Remove'));
    await tester.pumpAndSettle();

    expect(calls.delete, [2]);
  });

  testWidgets('"Add set" adds a set', (tester) async {
    final calls = await _pump(tester, _bench());

    await _tap(tester, find.text('Add set'));
    await tester.pumpAndSettle();

    expect(calls.addSet, [false]);
  });

  testWidgets('HU x1.3: the SET and PREV. labels do not run into each other', (tester) async {
    await _pump(tester, _bench(), locale: const Locale('hu'), textScale: 1.3, width: 360);

    final set = tester.getTopRight(find.text('SZETT')).dx;
    final previous = tester.getTopLeft(find.text('ELŐZŐ')).dx;
    expect(previous - set, greaterThanOrEqualTo(4));
  });

  for (final width in [411.0, 360.0]) {
    for (final scale in [1.0, 1.3]) {
      testWidgets('no overflow at ${width.toInt()} dp, text x$scale, HU, light', (tester) async {
        final baseline = PrBaseline.fromSets([(weight: 122.5, reps: 8, performedAt: DateTime(2026, 9, 1))]);
        final block = _bench(baseline: baseline);
        block.rows.first.prTypes = {PrType.maxWeight, PrType.estimatedOneRm};
        await _pump(tester, block, locale: const Locale('hu'), width: width, textScale: scale, theme: AppTheme.light);

        final error = tester.takeException();
        expect(error is FlutterError ? error.toStringDeep() : error, isNull);
      });
    }
  }
}
