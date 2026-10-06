import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/features/nutrition/application/off_search_controller.dart';
import 'package:lifey/features/nutrition/data/off_search_preferences.dart';
import 'package:lifey/features/nutrition/data/off_search_repository.dart';
import 'package:lifey/features/nutrition/domain/off_search.dart';

class _Call {
  _Call(this.text, this.lang, this.token) : completer = Completer<OffSearchResult>();
  final String text;
  final String lang;
  final CancelToken? token;
  final Completer<OffSearchResult> completer;
}

/// Every request waits for the test to answer it, so ordering and cancellation can be driven by hand.
class _FakeRepo implements OffSearchRepository {
  final calls = <_Call>[];

  @override
  Future<OffSearchResult> search(String text, String lang, {CancelToken? cancelToken}) {
    final call = _Call(text, lang, cancelToken);
    calls.add(call);
    return call.completer.future;
  }
}

class _FakePrefs implements OffSearchPreferences {
  _FakePrefs({this.stored = false});
  bool stored;
  final writes = <bool>[];
  Completer<bool>? gate;

  @override
  Future<bool> isEnabled() => gate?.future ?? Future.value(stored);

  @override
  Future<void> setEnabled(bool enabled) async {
    stored = enabled;
    writes.add(enabled);
  }
}

OffSearchResult _ok(String barcode, {bool fellBack = false}) => OffSearchResult(
      status: OffSearchStatus.ok,
      language: 'hu',
      fellBackToEnglish: fellBack,
      items: [OffSearchItem(barcode: barcode, name: 'Item $barcode', caloriesPer100g: 100, proteinPer100g: 10)],
    );

void main() {
  late _FakeRepo repo;
  late _FakePrefs prefs;
  late ProviderContainer container;

  OffSearchController controller() => container.read(offSearchControllerProvider.notifier);
  OffSearchState state() => container.read(offSearchControllerProvider);

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  Future<void> start({bool stored = false}) async {
    repo = _FakeRepo();
    prefs = _FakePrefs(stored: stored);
    container = ProviderContainer(overrides: [
      offSearchRepositoryProvider.overrideWithValue(repo),
      offSearchPreferencesProvider.overrideWithValue(prefs),
    ]);
    addTearDown(container.dispose);
    container.listen(offSearchControllerProvider, (_, __) {}); // the provider is auto-disposed: keep it alive
    await settle();
  }

  Future<void> debounce() => Future<void>.delayed(offSearchDebounce + const Duration(milliseconds: 20));

  test('off by default: typing makes no request and nothing is pending', () async {
    await start();

    controller().queryChanged('csirkemell', 'hu');
    await debounce();

    expect(repo.calls, isEmpty);
    expect(state().enabled, isFalse);
    expect(state().pending, isFalse);
  });

  test('ticked: pending at once, the request only after the debounce, with the cleaned text and the language', () async {
    await start();
    controller().setEnabled(true);

    controller().queryChanged('Csirkemell', 'hu');
    expect(state().pending, isTrue);
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(repo.calls, isEmpty);

    await debounce();
    expect(repo.calls, hasLength(1));
    expect(repo.calls.single.text, 'csirkemell');
    expect(repo.calls.single.lang, 'hu');

    repo.calls.single.completer.complete(_ok('1'));
    await settle();
    expect(state().pending, isFalse);
    expect(state().items.single.barcode, '1');
    expect(state().failed, isFalse);
  });

  test('typing a word is one request, not one per letter', () async {
    await start();
    controller().setEnabled(true);

    for (final text in ['cs', 'csi', 'csir', 'csirk', 'csirkemell']) {
      controller().queryChanged(text, 'hu');
      await Future<void>.delayed(const Duration(milliseconds: 60));
    }
    await debounce();

    expect(repo.calls.map((c) => c.text), ['csirkemell']);
  });

  test('under three letters nothing is requested, and deleting letters cancels the wait', () async {
    await start();
    controller().setEnabled(true);

    controller().queryChanged('cs', 'hu');
    expect(state().pending, isFalse);

    controller().queryChanged('tej', 'hu');
    expect(state().pending, isTrue);
    controller().queryChanged('te', 'hu'); // deleted before the debounce ran out
    expect(state().pending, isFalse);
    await debounce();

    expect(repo.calls, isEmpty);
  });

  test('a newer text cancels the request in flight, and a late answer to the older text is ignored', () async {
    await start();
    controller().setEnabled(true);
    controller().queryChanged('tej', 'hu');
    await debounce();
    final first = repo.calls.single;

    controller().queryChanged('tejföl', 'hu');
    await debounce();
    final second = repo.calls.last;
    expect(first.token!.isCancelled, isTrue);

    second.completer.complete(_ok('new'));
    await settle();
    first.completer.complete(_ok('old')); // arrives late
    await settle();

    expect(state().items.single.barcode, 'new');
  });

  test('the previous answer stays visible while the next one is on its way', () async {
    await start();
    controller().setEnabled(true);
    controller().queryChanged('tej', 'hu');
    await debounce();
    repo.calls.single.completer.complete(_ok('1'));
    await settle();

    controller().queryChanged('tejföl', 'hu');

    expect(state().pending, isTrue);
    expect(state().items.single.barcode, '1');
  });

  test('a failed request (no connectivity) reads as unavailable and drops the old answer', () async {
    await start();
    controller().setEnabled(true);
    controller().queryChanged('tej', 'hu');
    await debounce();

    repo.calls.single.completer.completeError(DioException(
      requestOptions: RequestOptions(path: '/foods/off-search'),
      type: DioExceptionType.connectionError,
    ));
    await settle();

    expect(state().failed, isTrue);
    expect(state().pending, isFalse);
    expect(state().items, isEmpty);
    expect(state().note, OffNote.unavailable);
  });

  test('an answer that cannot be read is a failure too, not a crash', () async {
    await start();
    controller().setEnabled(true);
    controller().queryChanged('tej', 'hu');
    await debounce();

    repo.calls.single.completer.completeError(const FormatException('not json'));
    await settle();

    expect(state().failed, isTrue);
  });

  test('a rate-limited answer is shown as such, with no items', () async {
    await start();
    controller().setEnabled(true);
    controller().queryChanged('tej', 'hu');
    await debounce();

    repo.calls.single.completer.complete(
        const OffSearchResult(status: OffSearchStatus.rateLimited, language: 'hu', fellBackToEnglish: false, items: []));
    await settle();

    expect(state().note, OffNote.rateLimited);
    expect(state().items, isEmpty);
  });

  test('the English fallback is carried through as a note', () async {
    await start();
    controller().setEnabled(true);
    controller().queryChanged('pumpkin', 'hu');
    await debounce();

    repo.calls.single.completer.complete(_ok('9', fellBack: true));
    await settle();

    expect(state().note, OffNote.fellBack);
  });

  group('the answers are remembered for ten minutes', () {
    test('the same search again is answered from memory, no second request', () async {
      await start();
      controller().setEnabled(true);
      controller().queryChanged('tej', 'hu');
      await debounce();
      repo.calls.single.completer.complete(_ok('1'));
      await settle();

      controller().queryChanged('sajt', 'hu');
      controller().queryChanged('Tej', 'hu'); // same text once cleaned

      expect(state().pending, isFalse);
      expect(state().items.single.barcode, '1');
      await debounce();
      expect(repo.calls, hasLength(1));
    });

    test('the language is part of the key', () async {
      await start();
      controller().setEnabled(true);
      controller().queryChanged('pasta', 'en');
      await debounce();
      repo.calls.last.completer.complete(_ok('en-answer'));
      await settle();

      controller().queryChanged('pasta', 'hu');
      await debounce();

      expect(repo.calls, hasLength(2));
      expect(repo.calls.last.lang, 'hu');
    });

    test('after ten minutes it asks again', () async {
      await start();
      var clock = DateTime(2026, 10, 6, 12);
      controller().now = () => clock;
      controller().setEnabled(true);
      controller().queryChanged('tej', 'hu');
      await debounce();
      repo.calls.single.completer.complete(_ok('1'));
      await settle();

      clock = clock.add(const Duration(minutes: 9, seconds: 59));
      controller().queryChanged('tej', 'hu');
      expect(state().pending, isFalse); // still remembered

      clock = clock.add(const Duration(seconds: 2));
      controller().queryChanged('tej', 'hu');
      expect(state().pending, isTrue);
      await debounce();
      expect(repo.calls, hasLength(2));
    });

    test('an unavailable or rate-limited answer is never remembered', () async {
      await start();
      controller().setEnabled(true);
      controller().queryChanged('tej', 'hu');
      await debounce();
      repo.calls.single.completer.complete(
          const OffSearchResult(status: OffSearchStatus.unavailable, language: 'hu', fellBackToEnglish: false, items: []));
      await settle();

      controller().queryChanged('sajt', 'hu');
      controller().queryChanged('tej', 'hu');
      await debounce();

      expect(repo.calls.where((c) => c.text == 'tej'), hasLength(2));
    });
  });

  group('the checkbox', () {
    test('is remembered per device: the stored choice is read when the sheet opens', () async {
      await start(stored: true);

      expect(state().enabled, isTrue);
    });

    test('ticking is written, unticking too', () async {
      await start();

      controller().setEnabled(true);
      controller().setEnabled(false);

      expect(prefs.writes, [true, false]);
    });

    test('ticking searches what is already typed', () async {
      await start();
      controller().queryChanged('csirkemell', 'hu'); // typed first, box still off
      await debounce();
      expect(repo.calls, isEmpty);

      controller().setEnabled(true);
      await debounce();

      expect(repo.calls.single.text, 'csirkemell');
    });

    test('unticking cancels the request in flight and forgets the answer', () async {
      await start();
      controller().setEnabled(true);
      controller().queryChanged('tej', 'hu');
      await debounce();
      final call = repo.calls.single;

      controller().setEnabled(false);

      expect(call.token!.isCancelled, isTrue);
      expect(state().pending, isFalse);
      expect(state().result, isNull);
      call.completer.complete(_ok('late'));
      await settle();
      expect(state().result, isNull);
    });

    test('a choice made while the stored one is still loading wins', () async {
      repo = _FakeRepo();
      prefs = _FakePrefs(stored: true)..gate = Completer<bool>();
      container = ProviderContainer(overrides: [
        offSearchRepositoryProvider.overrideWithValue(repo),
        offSearchPreferencesProvider.overrideWithValue(prefs),
      ]);
      addTearDown(container.dispose);
      container.listen(offSearchControllerProvider, (_, __) {});

      controller().setEnabled(false); // the user unticks before the stored "on" arrives
      prefs.gate!.complete(true);
      await settle();

      expect(state().enabled, isFalse);
    });
  });

  test('disposing the sheet with a request in flight cancels it and does not throw when it answers', () async {
    await start();
    controller().setEnabled(true);
    controller().queryChanged('tej', 'hu');
    await debounce();
    final call = repo.calls.single;

    container.dispose();

    expect(call.token!.isCancelled, isTrue);
    call.completer.complete(_ok('late'));
    await settle(); // nothing to assert beyond "no exception"
  });
}
