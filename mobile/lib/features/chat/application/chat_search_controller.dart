import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/chat_repository.dart';
import '../domain/chat_message.dart';

/// Mirrors `lifey.chat.search-min-length`: below it the server answers with an
/// empty page anyway, so there is no reason to ask.
const chatSearchMinLength = 2;

/// Waited out before each request, so typing a word is one query, not five.
const chatSearchDebounce = Duration(milliseconds: 300);

/// What the search screen is showing right now.
class ChatSearchState {
  const ChatSearchState({
    this.query = '',
    this.results = const [],
    this.loading = false,
    this.failed = false,
  });

  final String query;
  final List<ChatMessage> results;
  final bool loading;

  /// The last request failed. Kept apart from "no results": one says try
  /// again, the other says try another word.
  final bool failed;

  /// True only once a real search has run and come back empty — an idle screen
  /// is not "no results".
  bool get isEmptyResult =>
      !loading && !failed && results.isEmpty && query.trim().length >= chatSearchMinLength;

  bool get isIdle => query.trim().length < chatSearchMinLength;

  ChatSearchState copyWith({
    String? query,
    List<ChatMessage>? results,
    bool? loading,
    bool? failed,
  }) {
    return ChatSearchState(
      query: query ?? this.query,
      results: results ?? this.results,
      loading: loading ?? this.loading,
      failed: failed ?? this.failed,
    );
  }
}

/// Debounced in-thread search.
///
/// The results never touch the local database — see
/// `ChatRepository.searchMessages` for why.
class ChatSearchController extends Notifier<ChatSearchState> {
  ChatSearchController(this.conversationId);

  final int conversationId;

  Timer? _debounce;

  /// Guards against an older, slower request overwriting a newer one's answer.
  int _generation = 0;

  @override
  ChatSearchState build() {
    ref.onDispose(() => _debounce?.cancel());
    return const ChatSearchState();
  }

  void search(String query) {
    _debounce?.cancel();
    final trimmed = query.trim();

    if (trimmed.length < chatSearchMinLength) {
      // Back to idle rather than showing the previous term's hits under a
      // query that no longer produced them.
      _generation++;
      state = ChatSearchState(query: query);
      return;
    }

    state = state.copyWith(query: query, loading: true, failed: false);
    _debounce = Timer(chatSearchDebounce, () => _run(trimmed, ++_generation));
  }

  Future<void> retry() => _run(state.query.trim(), ++_generation);

  Future<void> _run(String query, int generation) async {
    if (query.length < chatSearchMinLength) return;
    try {
      final results = await ref.read(chatRepositoryProvider).searchMessages(conversationId, query);
      if (generation != _generation) return;
      state = state.copyWith(results: results, loading: false, failed: false);
    } catch (_) {
      if (generation != _generation) return;
      // Offline or a flaky network. Distinguished from "no results" so the
      // screen can offer a retry instead of suggesting another word.
      state = state.copyWith(results: const [], loading: false, failed: true);
    }
  }
}

final chatSearchControllerProvider =
    NotifierProvider.family<ChatSearchController, ChatSearchState, int>(
  ChatSearchController.new,
);
