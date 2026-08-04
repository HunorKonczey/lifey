import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/features/workouts/presentation/open_workout_screens.dart';

void main() {
  setUp(resetOpenWorkoutScreens);
  tearDown(resetOpenWorkoutScreens);

  test('nothing is open to begin with', () {
    expect(isWorkoutScreenOpenFor('sess-1'), isFalse);
  });

  test('a screen showing a session suppresses a second push for it', () {
    openWorkoutScreen('sess-1');

    expect(isWorkoutScreenOpenFor('sess-1'), isTrue);
  });

  test('a screen for another session never suppresses this one', () {
    openWorkoutScreen('sess-1');

    expect(isWorkoutScreenOpenFor('sess-2'), isFalse);
  });

  test('a template screen with no session yet suppresses nothing', () {
    // A workout started from a template creates no row until its first edit;
    // meanwhile a watch-started session needs its own screen (and its Live
    // Activity) — this is the case the old global bool got wrong.
    openWorkoutScreen(null);

    expect(isWorkoutScreenOpenFor('watch-session'), isFalse);
  });

  test('a template screen claims its session once it persists one', () {
    final screen = openWorkoutScreen(null);

    screen.sessionClientId = 'sess-1';

    expect(isWorkoutScreenOpenFor('sess-1'), isTrue);
  });

  test('closing a screen releases only its own session', () {
    final first = openWorkoutScreen('sess-1');
    openWorkoutScreen('sess-2');

    closeWorkoutScreen(first);

    expect(isWorkoutScreenOpenFor('sess-1'), isFalse);
    expect(isWorkoutScreenOpenFor('sess-2'), isTrue);
  });

  test("closing another screen doesn't unguard a live workout", () {
    // The old bool was cleared by *any* dispose — e.g. a finished session
    // opened on top of a running one — which then let a duplicate screen be
    // pushed over the live workout.
    openWorkoutScreen('running');
    final finished = openWorkoutScreen('finished');

    closeWorkoutScreen(finished);

    expect(isWorkoutScreenOpenFor('running'), isTrue);
  });

  test('closing the same screen twice is harmless', () {
    final screen = openWorkoutScreen('sess-1');

    closeWorkoutScreen(screen);
    closeWorkoutScreen(screen);

    expect(isWorkoutScreenOpenFor('sess-1'), isFalse);
  });

  test('two screens for the same session both have to close before it frees up', () {
    final first = openWorkoutScreen('sess-1');
    final second = openWorkoutScreen('sess-1');

    closeWorkoutScreen(first);
    expect(isWorkoutScreenOpenFor('sess-1'), isTrue);

    closeWorkoutScreen(second);
    expect(isWorkoutScreenOpenFor('sess-1'), isFalse);
  });
}
