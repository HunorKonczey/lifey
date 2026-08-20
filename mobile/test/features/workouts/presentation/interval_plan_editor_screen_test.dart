import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/features/workouts/application/cardio_interval_plan_controller.dart';
import 'package:lifey/features/workouts/domain/cardio_interval_plan.dart';
import 'package:lifey/features/workouts/presentation/interval_plan_editor_screen.dart';
import 'package:lifey/l10n/app_localizations.dart';

/// docs/cardio/60 C7.4 — kész-ha: "Egy 4×(4+3) perces terv 6 koppintásból
/// összeáll; a teljes hossz élőben látszik" (a 4×(4+3) plan comes together in
/// six taps, and the total length is visible live). Both halves are asserted
/// here by tapping the real screen, plus the M37 pieces that carry them: the
/// three header numbers, the block's own arithmetic line, and the intensity
/// picker.

class FakeIntervalPlanController extends CardioIntervalPlanController {
  FakeIntervalPlanController();

  final saved = <({String name, List<IntervalStep> steps})>[];
  final updated = <({String clientId, String name, List<IntervalStep> steps})>[];

  @override
  Stream<List<CardioIntervalPlan>> build() => Stream.value(const []);

  @override
  Future<String> createPlan({required String name, required List<IntervalStep> steps}) async {
    saved.add((name: name, steps: steps));
    return 'plan-1';
  }

  @override
  Future<void> updatePlan({
    required String clientId,
    required String name,
    required List<IntervalStep> steps,
  }) async {
    updated.add((clientId: clientId, name: name, steps: steps));
  }
}

Future<void> pumpEditor(
  WidgetTester tester,
  FakeIntervalPlanController controller, {
  CardioIntervalPlan? plan,
  ValueChanged<IntervalPlanEditorResult?>? onPopped,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        cardioIntervalPlanControllerProvider.overrideWith(() => controller),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  final result = await Navigator.of(context).push<IntervalPlanEditorResult>(
                    MaterialPageRoute(
                      builder: (_) => IntervalPlanEditorScreen(plan: plan),
                    ),
                  );
                  onPopped?.call(result);
                },
                child: const Text('open'),
              ),
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
  testWidgets('the empty state offers a ready-made plan, not an explanation',
      (tester) async {
    await pumpEditor(tester, FakeIntervalPlanController());

    expect(find.text('Build a plan'), findsOneWidget);
    expect(find.text('Start with the 4x4'), findsOneWidget);
    // Nothing to save yet.
    final saveButton = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(saveButton.onPressed, isNull);
  });

  testWidgets('the starter offer builds the whole 38:00 plan in one tap', (tester) async {
    await pumpEditor(tester, FakeIntervalPlanController());

    await tester.tap(find.text('Start with the 4x4'));
    await tester.pumpAndSettle();

    // 5:00 + 4×(4:00 + 3:00) + 5:00 — the three header numbers, live.
    expect(find.text('38:00'), findsOneWidget); // total length
    expect(find.text('10'), findsOneWidget); // sections
    expect(find.text('16:00'), findsOneWidget); // hard time
  });

  testWidgets('a 4x(4+3) plan is one tap on Repeat, and the header updates live',
      (tester) async {
    await pumpEditor(tester, FakeIntervalPlanController());

    // Before: an empty plan reads 0:00.
    expect(find.text('0:00'), findsNWidgets(2)); // total length + hard time

    await tester.tap(find.text('Repeat'));
    await tester.pumpAndSettle();

    // 4×(4:00 + 3:00) = 28:00, of which 4×4:00 = 16:00 is hard, over 8 sections.
    expect(find.text('28:00'), findsOneWidget); // header total
    expect(find.text('16:00'), findsOneWidget);
    expect(find.text('8'), findsOneWidget);
    // The block shows its arithmetic, which is where the user checks it.
    expect(find.text('4 × 7:00 = 28:00'), findsOneWidget);
  });

  testWidgets('the repeat counter edits in place and every number follows',
      (tester) async {
    await pumpEditor(tester, FakeIntervalPlanController());
    await tester.tap(find.text('Repeat'));
    await tester.pumpAndSettle();

    // The counter's + comes before the footer's "Section" button in the tree.
    await tester.tap(find.byIcon(Icons.add).first);
    await tester.pumpAndSettle();

    expect(find.text('×5'), findsOneWidget);
    expect(find.text('5 × 7:00 = 35:00'), findsOneWidget);
    expect(find.text('35:00'), findsOneWidget); // header total
    expect(find.text('20:00'), findsOneWidget); // hard time
  });

  testWidgets('tapping a section opens the duration stepper and intensity picker',
      (tester) async {
    await pumpEditor(tester, FakeIntervalPlanController());
    await tester.tap(find.text('Section'));
    await tester.pumpAndSettle();

    // The card, not the header's total — both read 5:00, only the card is tappable.
    await tester.tap(find.widgetWithText(InkWell, '5:00'));
    await tester.pumpAndSettle();

    expect(find.text('DURATION'), findsOneWidget);
    expect(find.text('TARGET INTENSITY'), findsOneWidget);
    // The three-step scale, and the note explaining why it isn't a resistance level.
    expect(find.text('easy'), findsWidgets);
    expect(find.text('moderate'), findsOneWidget);
    expect(find.text('hard'), findsOneWidget);
    expect(
      find.textContaining('every machine runs a different scale'),
      findsOneWidget,
    );

    // One tap on + moves the section by 15 s, and the header total follows.
    await tester.tap(find.byIcon(Icons.add).last);
    await tester.pumpAndSettle();
    expect(find.text('5:15'), findsWidgets);
  });

  testWidgets('changing the intensity to hard moves the time into the hard column',
      (tester) async {
    await pumpEditor(tester, FakeIntervalPlanController());
    await tester.tap(find.text('Section'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(InkWell, '5:00'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('hard'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(200, 10)); // dismiss the sheet
    await tester.pumpAndSettle();

    // Total unchanged, but all of it is hard now.
    expect(find.text('5:00'), findsWidgets);
    expect(find.textContaining('9–10/10'), findsOneWidget);
  });

  testWidgets('Save only stores the plan and pops without asking to start it',
      (tester) async {
    final controller = FakeIntervalPlanController();
    IntervalPlanEditorResult? result;
    await pumpEditor(tester, controller, onPopped: (r) => result = r);

    await tester.tap(find.text('Start with the 4x4'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Tuesday intervals');
    // The starter plan is taller than the viewport: scroll far enough for the
    // footer to be built, then bring it fully into view.
    await tester.drag(find.byType(ReorderableListView), const Offset(0, -800));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save only'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save only'));
    await tester.pumpAndSettle();

    expect(controller.saved, hasLength(1));
    expect(controller.saved.single.name, 'Tuesday intervals');
    // Warm-up, block, cool-down — the tree, not a flat list of ten.
    final steps = controller.saved.single.steps;
    expect(steps.map((s) => s.type),
        [IntervalStepType.step, IntervalStepType.repeat, IntervalStepType.step]);
    expect(steps[1].repeatCount, 4);
    expect(steps[1].children.map((c) => c.durationSeconds), [240, 180]);
    expect(result!.planClientId, 'plan-1');
    expect(result!.start, isFalse);
  });

  testWidgets('Save and start reports back that the session should begin',
      (tester) async {
    final controller = FakeIntervalPlanController();
    IntervalPlanEditorResult? result;
    await pumpEditor(tester, controller, onPopped: (r) => result = r);

    await tester.tap(find.text('Repeat'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save and start'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save and start'));
    await tester.pumpAndSettle();

    expect(result!.start, isTrue);
    // No name typed — the plan still gets one rather than saving blank.
    expect(controller.saved.single.name, 'Interval plan');
  });

  testWidgets('an existing plan opens filled in and updates in place', (tester) async {
    final controller = FakeIntervalPlanController();
    const plan = CardioIntervalPlan(
      clientId: 'plan-9',
      name: 'Sprints',
      steps: [
        IntervalStep.block(repeatCount: 6, children: [
          IntervalStep.section(intensity: IntervalIntensity.hard, durationSeconds: 30),
          IntervalStep.section(intensity: IntervalIntensity.easy, durationSeconds: 90),
        ]),
      ],
    );
    await pumpEditor(tester, controller, plan: plan);

    expect(find.text('Sprints'), findsOneWidget);
    expect(find.text('×6'), findsOneWidget);
    expect(find.text('12:00'), findsOneWidget); // header total
    expect(find.text('3:00'), findsOneWidget); // hard time: 6 × 0:30

    await tester.ensureVisible(find.text('Save only'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save only'));
    await tester.pumpAndSettle();

    expect(controller.saved, isEmpty);
    expect(controller.updated.single.clientId, 'plan-9');
    expect(controller.updated.single.steps.single.repeatCount, 6);
  });

  testWidgets('a block collapses to one summary row', (tester) async {
    await pumpEditor(tester, FakeIntervalPlanController());
    await tester.tap(find.text('Repeat'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.expand_less));
    await tester.pumpAndSettle();

    expect(find.text('4× (4:00 hard + 3:00 easy)'), findsOneWidget);
    expect(find.text('REPEAT BLOCK'), findsNothing);
    // Collapsing is a view state, not an edit: the numbers are untouched.
    expect(find.text('28:00'), findsNWidgets(2)); // header total + the collapsed row's own
  });
}
