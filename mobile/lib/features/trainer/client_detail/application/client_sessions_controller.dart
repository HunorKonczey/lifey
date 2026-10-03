import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/client_detail_repository.dart';
import '../domain/client_workout_session.dart';

/// How many sessions one page holds. Matches the backend's own default, so
/// the first page costs exactly one round trip.
const clientSessionPageSize = 20;

/// What the client's workouts tab is showing right now.
class ClientSessionsState {
  const ClientSessionsState({
    this.sessions = const [],
    this.loading = true,
    this.loadingMore = false,
    this.hasMore = false,
    this.error,
    this.adopted = const [],
  });

  final List<ClientWorkoutSession> sessions;

  /// Sessions opened by id from outside the paged list — a chat card pointing
  /// at one the trainer has not scrolled to (docs/chat/83 §2.8). Kept apart
  /// from [sessions] so they never appear as rows out of order, and read
  /// through [byId] so the detail sheet and the comment editor cannot tell
  /// the difference.
  final List<ClientWorkoutSession> adopted;

  ClientWorkoutSession? byId(int sessionId) {
    for (final session in sessions) {
      if (session.id == sessionId) return session;
    }
    for (final session in adopted) {
      if (session.id == sessionId) return session;
    }
    return null;
  }

  /// The first page is on its way — the tab shows a spinner.
  final bool loading;

  /// A further page is on its way; the rows already on screen stay put.
  final bool loadingMore;

  final bool hasMore;

  /// Only ever set for a failed *first* page. A failed "load more" leaves the
  /// list intact and surfaces itself through the footer instead of throwing
  /// away everything the trainer was reading.
  final Object? error;

  ClientSessionsState copyWith({
    List<ClientWorkoutSession>? sessions,
    bool? loading,
    bool? loadingMore,
    bool? hasMore,
    Object? error,
    bool clearError = false,
    List<ClientWorkoutSession>? adopted,
  }) {
    return ClientSessionsState(
      sessions: sessions ?? this.sessions,
      loading: loading ?? this.loading,
      loadingMore: loadingMore ?? this.loadingMore,
      hasMore: hasMore ?? this.hasMore,
      error: clearError ? null : (error ?? this.error),
      adopted: adopted ?? this.adopted,
    );
  }
}

/// The outcome of writing or clearing a comment, as the editor needs to
/// report it (frame D3: the result is stated, never assumed).
enum CommentSaveOutcome {
  /// A comment where there was none — the backend sent the client a push for
  /// it (docs/31 B3: creation only, never an edit).
  created,

  /// An existing comment was rewritten. Deliberately silent for the client.
  updated,

  removed,
}

/// The client's session history, and the trainer's comment on any of it
/// (docs/chat/41-trainer-mobile-v2-plan.md T3).
///
/// Paged rather than fetched whole: a year of training is hundreds of
/// sessions with all their sets, and the trainer reads the newest few.
class ClientSessionsController extends Notifier<ClientSessionsState> {
  ClientSessionsController(this.clientId);

  final int clientId;

  int _nextPage = 0;

  /// Guards against a stale page landing after a refresh reset the list.
  int _generation = 0;

  ClientDetailRepository get _repo => ref.read(clientDetailRepositoryProvider);

  @override
  ClientSessionsState build() {
    Future.microtask(refresh);
    return const ClientSessionsState();
  }

  Future<void> refresh() async {
    final generation = ++_generation;
    _nextPage = 0;
    state = state.copyWith(loading: true, clearError: true);
    try {
      final page = await _repo.fetchWorkoutSessions(
        clientId,
        page: 0,
        size: clientSessionPageSize,
      );
      if (generation != _generation) return;
      _nextPage = 1;
      state = ClientSessionsState(
        sessions: page.sessions,
        loading: false,
        hasMore: !page.isLast,
        adopted: state.adopted,
      );
    } catch (error) {
      if (generation != _generation) return;
      state = ClientSessionsState(loading: false, error: error, adopted: state.adopted);
    }
  }

  Future<void> loadMore() async {
    if (state.loadingMore || !state.hasMore) return;
    final generation = _generation;
    state = state.copyWith(loadingMore: true);
    try {
      final page = await _repo.fetchWorkoutSessions(
        clientId,
        page: _nextPage,
        size: clientSessionPageSize,
      );
      if (generation != _generation) return;
      _nextPage++;
      state = state.copyWith(
        sessions: [...state.sessions, ...page.sessions],
        loadingMore: false,
        hasMore: !page.isLast,
      );
    } catch (_) {
      if (generation != _generation) return;
      // The rows already read stay on screen; the footer offers another try.
      state = state.copyWith(loadingMore: false);
    }
  }

  /// Reads one session by id and makes it readable through [ClientSessionsState.byId]
  /// — the entry for a chat result card (docs/chat/83 §2.8). Returns the row from the
  /// loaded list when it is already there, so a recent session costs no request.
  /// Throws what the repository throws (a 404 for a deleted or foreign session).
  Future<ClientWorkoutSession> openById(int sessionId) async {
    final known = state.byId(sessionId);
    if (known != null) return known;
    final fetched = await _repo.fetchWorkoutSession(clientId, sessionId);
    state = state.copyWith(adopted: [...state.adopted, fetched]);
    return fetched;
  }

  /// Writes the comment and replaces the row with what the server stored.
  /// Throws on failure — the editor is the one place that knows how to say so.
  Future<CommentSaveOutcome> saveComment(int sessionId, String comment) async {
    final hadComment = _sessionById(sessionId)?.hasTrainerComment ?? false;
    final updated = await _repo.putSessionComment(clientId, sessionId, comment);
    _replace(updated);
    return hadComment ? CommentSaveOutcome.updated : CommentSaveOutcome.created;
  }

  Future<CommentSaveOutcome> deleteComment(int sessionId) async {
    final updated = await _repo.deleteSessionComment(clientId, sessionId);
    _replace(updated);
    return CommentSaveOutcome.removed;
  }

  ClientWorkoutSession? _sessionById(int sessionId) => state.byId(sessionId);

  /// Swaps one row for the server's version of it. No refetch: the comment
  /// endpoints return the whole updated session, and re-reading page 0 would
  /// throw away every page loaded after it.
  void _replace(ClientWorkoutSession updated) {
    state = state.copyWith(
      sessions: [
        for (final session in state.sessions)
          session.id == updated.id ? updated : session,
      ],
      adopted: [
        for (final session in state.adopted)
          session.id == updated.id ? updated : session,
      ],
    );
  }
}

final clientSessionsControllerProvider =
    NotifierProvider.family<ClientSessionsController, ClientSessionsState, int>(
  ClientSessionsController.new,
);
