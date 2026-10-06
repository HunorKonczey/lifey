import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/off_search_preferences.dart';
import '../data/off_search_repository.dart';
import '../domain/off_search.dart';

/// What the add-meal-entry sheet shows for the OpenFoodFacts option (docs/84): the checkbox, whether a request is under
/// way (or about to be, while typing settles), and the last answer.
class OffSearchState {
  const OffSearchState({
    this.enabled = false,
    this.pending = false,
    this.result,
    this.failed = false,
  });

  /// The "Search OpenFoodFacts too" checkbox.
  final bool enabled;

  /// A request is running or about to start; the previous [result] stays visible meanwhile, so the list does not
  /// flash empty on every letter.
  final bool pending;

  /// The last answer; `null` before there is one and whenever nothing is being searched.
  final OffSearchResult? result;

  /// Our own request failed (no connectivity, timeout, an unreadable answer): shown like `unavailable`.
  final bool failed;

  List<OffSearchItem> get items => result?.items ?? const [];

  OffNote? get note => offSearchNote(result, failed: failed);

  OffSearchState copyWith({bool? enabled, bool? pending, OffSearchResult? result, bool? failed, bool clearResult = false}) {
    return OffSearchState(
      enabled: enabled ?? this.enabled,
      pending: pending ?? this.pending,
      result: clearResult ? null : (result ?? this.result),
      failed: failed ?? this.failed,
    );
  }
}

/// Runs the OpenFoodFacts name search for the add-meal-entry sheet (docs/84 D10): nothing is requested unless the box is
/// ticked; the typed text is cleaned, debounced and needs 3+ letters or digits; a newer keystroke cancels the request in
/// flight and a late answer to an older text is ignored; the same search again within ten minutes is answered from memory.
/// Online-only: no drift read, no outbox entry. Auto-disposed with the sheet; the checkbox is remembered per device.
class OffSearchController extends Notifier<OffSearchState> {
  static const cacheLifetime = Duration(minutes: 10);

  /// Overridable so a test can move time; the backend caches for the same ten minutes.
  DateTime Function() now = DateTime.now;

  Timer? _debounce;
  CancelToken? _inFlight;
  int _generation = 0;
  bool _disposed = false;
  bool _touched = false;
  String _query = '';
  String _lang = 'en';
  final Map<String, ({DateTime at, OffSearchResult result})> _cache = {};

  @override
  OffSearchState build() {
    ref.onDispose(() {
      _disposed = true;
      _debounce?.cancel();
      _inFlight?.cancel();
    });
    _loadPreference();
    return const OffSearchState();
  }

  Future<void> _loadPreference() async {
    final bool saved;
    try {
      saved = await ref.read(offSearchPreferencesProvider).isEnabled();
    } catch (_) {
      return; // storage unavailable: the box simply starts off
    }
    // A choice made while the preference was still loading wins over the stored one.
    if (_disposed || _touched) return;
    state = state.copyWith(enabled: saved);
  }

  /// The checkbox. Ticking it searches what is already typed; unticking stops everything and forgets the answer.
  void setEnabled(bool enabled) {
    _touched = true;
    state = state.copyWith(enabled: enabled);
    // Not remembered if the write fails; the box still works for this sheet.
    unawaited(ref.read(offSearchPreferencesProvider).setEnabled(enabled).catchError((Object _) {}));
    if (enabled) {
      queryChanged(_query, _lang);
    } else {
      _stop();
    }
  }

  /// The text in the search field changed. [lang] is the app's language (`offSearchLang`).
  void queryChanged(String query, String lang) {
    _query = query;
    _lang = lang;
    if (!state.enabled) return;
    final text = sanitizeOffQuery(query);
    if (!isOffSearchable(text)) {
      _stop();
      return;
    }
    final cached = _cached(lang, text);
    if (cached != null) {
      _debounce?.cancel();
      _inFlight?.cancel();
      _generation++;
      state = state.copyWith(pending: false, result: cached, failed: false);
      return;
    }
    state = state.copyWith(pending: true);
    _debounce?.cancel();
    _debounce = Timer(offSearchDebounce, () => _run(text, lang));
  }

  Future<void> _run(String text, String lang) async {
    _inFlight?.cancel();
    final token = CancelToken();
    _inFlight = token;
    final generation = ++_generation;
    try {
      final result = await ref.read(offSearchRepositoryProvider).search(text, lang, cancelToken: token);
      if (_disposed || generation != _generation) return;
      if (result.status == OffSearchStatus.ok) _cache['$lang|$text'] = (at: now(), result: result);
      state = state.copyWith(pending: false, result: result, failed: false);
    } on DioException catch (e) {
      if (_disposed || generation != _generation || CancelToken.isCancel(e)) return;
      _fail();
    } catch (_) {
      if (_disposed || generation != _generation) return;
      _fail(); // an answer that could not be read
    }
  }

  void _fail() => state = state.copyWith(pending: false, failed: true, clearResult: true);

  /// Nothing is being searched: no timer, no request, no answer.
  void _stop() {
    _debounce?.cancel();
    _inFlight?.cancel();
    _generation++;
    state = state.copyWith(pending: false, failed: false, clearResult: true);
  }

  OffSearchResult? _cached(String lang, String text) {
    final hit = _cache['$lang|$text'];
    if (hit == null) return null;
    if (now().difference(hit.at) >= cacheLifetime) {
      _cache.remove('$lang|$text');
      return null;
    }
    return hit.result;
  }
}

final offSearchControllerProvider =
    NotifierProvider.autoDispose<OffSearchController, OffSearchState>(OffSearchController.new);
