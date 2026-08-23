import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/watch/watch_template_sync_controller.dart';
import 'package:lifey/core/watch/watch_workout_service.dart';
import 'package:lifey/features/workouts/application/watch_template_sync.dart';

/// Records what actually reached the channel, so the tests assert on pushes
/// rather than on the debounce timer's internals.
class _FakeWatchService extends WatchWorkoutService {
  _FakeWatchService({super.isAvailable = true});

  final pushes = <WatchQuickStartPayload>[];

  @override
  Future<void> syncTemplates(WatchQuickStartPayload payload) async {
    pushes.add(payload);
  }
}

/// A mutable stand-in for [watchTemplateSyncPayloadProvider]. Riverpod 3 has
/// no `StateProvider`, so a plain [Notifier] plays the "source the test
/// drives" role.
class _PayloadSource extends Notifier<WatchQuickStartPayload?> {
  _PayloadSource(this._initial);
  final WatchQuickStartPayload? _initial;

  @override
  WatchQuickStartPayload? build() => _initial;

  void emit(WatchQuickStartPayload? value) => state = value;
}

/// The ranked half is what almost every test here varies, so `allCardio`
/// defaults to a fixed stand-in — only the language-change test passes its
/// own.
WatchQuickStartPayload _payload(
  List<WatchQuickStartEntryPayload> entries, {
  List<WatchQuickStartCardioEntry> allCardio = const [
    WatchQuickStartCardioEntry(activityType: 'RUNNING', title: 'Running'),
  ],
}) {
  return WatchQuickStartPayload(entries: entries, allCardio: allCardio);
}

WatchQuickStartTemplateEntry _template(String id, {String? title, int restSeconds = 90}) {
  return WatchQuickStartTemplateEntry(
    WatchTemplatePayload(
      templateId: id,
      title: title ?? id,
      exercises: [
        WatchTemplateExercisePayload(
          exerciseId: 'bench',
          name: 'Bench Press',
          restSeconds: restSeconds,
        ),
      ],
    ),
  );
}

void main() {
  /// The controller debounces, so every test needs the clock advanced past
  /// it. `testWidgets` gives a fake clock that `pump` drives, which beats
  /// waiting two real seconds per case — and needs no production-side hook
  /// to shorten the delay.
  const pastDebounce = Duration(seconds: 3);

  /// [payload] is a test-local source the tests mutate to simulate the real
  /// provider re-deriving. Overriding it directly (rather than all four
  /// underlying controllers) keeps these tests about the *pushing*; what the
  /// payload should contain is watch_template_sync_test.dart's job.
  ({ProviderContainer container, _PayloadSource payload, _FakeWatchService service}) buildHarness({
    WatchQuickStartPayload? initial,
    bool isAvailable = true,
  }) {
    final source = NotifierProvider<_PayloadSource, WatchQuickStartPayload?>(
      () => _PayloadSource(initial),
    );
    final service = _FakeWatchService(isAvailable: isAvailable);
    final container = ProviderContainer(
      overrides: [
        watchWorkoutServiceProvider.overrideWithValue(service),
        watchTemplateSyncPayloadProvider.overrideWith((ref) => ref.watch(source)),
      ],
    );
    addTearDown(container.dispose);
    return (
      container: container,
      payload: container.read(source.notifier),
      service: service,
    );
  }

  testWidgets('pushes the first payload once the debounce elapses', (tester) async {
    final harness = buildHarness(initial: _payload([_template('push')]));

    harness.container.listen(watchTemplateSyncControllerProvider, (_, __) {});
    await tester.pump(pastDebounce);

    final entry = harness.service.pushes.single.entries.single as WatchQuickStartTemplateEntry;
    expect(entry.template.templateId, 'push');
  });

  testWidgets('does not push before the debounce elapses', (tester) async {
    final harness = buildHarness(initial: _payload([_template('push')]));

    harness.container.listen(watchTemplateSyncControllerProvider, (_, __) {});
    await tester.pump(const Duration(milliseconds: 500));

    expect(harness.service.pushes, isEmpty);

    // Let the pending timer fire so the test doesn't end with it live.
    await tester.pump(pastDebounce);
  });

  testWidgets('pushes again when the payload actually changes', (tester) async {
    final harness = buildHarness(initial: _payload([_template('push')]));
    harness.container.listen(watchTemplateSyncControllerProvider, (_, __) {});
    await tester.pump(pastDebounce);

    harness.payload.emit(_payload([_template('push'), _template('legs')]));
    await tester.pump(pastDebounce);

    expect(harness.service.pushes, hasLength(2));
    expect(
      harness.service.pushes.last.entries.map((e) => (e as WatchQuickStartTemplateEntry).template.templateId),
      ['push', 'legs'],
    );
  });

  testWidgets('skips a re-emission that carries an identical payload', (tester) async {
    // Drift streams re-emit on any write to their tables, so one logical
    // change can arrive several times — a push costs a round trip, so an
    // unchanged payload must not spend one.
    final harness = buildHarness(initial: _payload([_template('push')]));
    harness.container.listen(watchTemplateSyncControllerProvider, (_, __) {});
    await tester.pump(pastDebounce);

    harness.payload.emit(_payload([_template('push')]));
    await tester.pump(pastDebounce);

    expect(harness.service.pushes, hasLength(1));
  });

  testWidgets('notices a change inside a template, not just a new one', (tester) async {
    // Renaming an exercise or changing the rest setting moves the payload
    // without changing the template list itself.
    final harness = buildHarness(initial: _payload([_template('push')]));
    harness.container.listen(watchTemplateSyncControllerProvider, (_, __) {});
    await tester.pump(pastDebounce);

    harness.payload.emit(_payload([_template('push', restSeconds: 150)]));
    await tester.pump(pastDebounce);

    expect(harness.service.pushes, hasLength(2));
    final entry = harness.service.pushes.last.entries.single as WatchQuickStartTemplateEntry;
    expect(entry.template.exercises.single.restSeconds, 150);
  });

  testWidgets('never pushes while the payload is null (sources still loading)', (tester) async {
    // Null means "don't know yet" — pushing an empty list here would order
    // the watch to wipe a good cache at every cold start.
    final harness = buildHarness(initial: null);

    harness.container.listen(watchTemplateSyncControllerProvider, (_, __) {});
    await tester.pump(pastDebounce);

    expect(harness.service.pushes, isEmpty);
  });

  testWidgets('pushes an empty list once that is a real answer', (tester) async {
    // Starts unknown, then resolves to "you have no templates" — that has to
    // reach the watch so it clears whatever it still holds.
    final harness = buildHarness(initial: null);
    harness.container.listen(watchTemplateSyncControllerProvider, (_, __) {});
    await tester.pump(pastDebounce);

    harness.payload.emit(_payload(const []));
    await tester.pump(pastDebounce);

    expect(harness.service.pushes.single.entries, isEmpty);
  });

  testWidgets('collapses a burst of changes into a single push', (tester) async {
    final harness = buildHarness(initial: _payload([_template('a')]));
    harness.container.listen(watchTemplateSyncControllerProvider, (_, __) {});

    harness.payload.emit(_payload([_template('b')]));
    await tester.pump(const Duration(milliseconds: 100));
    harness.payload.emit(_payload([_template('c')]));
    await tester.pump(const Duration(milliseconds: 100));
    harness.payload.emit(_payload([_template('d')]));
    await tester.pump(pastDebounce);

    final entry = harness.service.pushes.single.entries.single as WatchQuickStartTemplateEntry;
    expect(entry.template.templateId, 'd');
  });

  testWidgets('pushes when only the all-types list changed (language switch)', (tester) async {
    // The two halves change for different reasons: switching the account's
    // language rewrites every pre-localized title, including the all-types
    // screen's, while the ranking itself is untouched. A dedup key that only
    // covered `entries` would leave that screen in the old language until
    // some unrelated ranking change happened to force a push.
    final harness = buildHarness(initial: _payload([_template('push')]));
    harness.container.listen(watchTemplateSyncControllerProvider, (_, __) {});
    await tester.pump(pastDebounce);

    harness.payload.emit(_payload(
      [_template('push')],
      allCardio: const [WatchQuickStartCardioEntry(activityType: 'RUNNING', title: 'Futás')],
    ));
    await tester.pump(pastDebounce);

    expect(harness.service.pushes, hasLength(2));
    expect(harness.service.pushes.last.allCardio.single.title, 'Futás');
  });

  testWidgets('does nothing at all on a platform with no watch support', (tester) async {
    final harness = buildHarness(initial: _payload([_template('push')]), isAvailable: false);

    harness.container.listen(watchTemplateSyncControllerProvider, (_, __) {});
    await tester.pump(pastDebounce);

    expect(harness.service.pushes, isEmpty);
  });
}
