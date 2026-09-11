import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/features/trainer/client_detail/application/client_sessions_controller.dart';
import 'package:lifey/features/trainer/client_detail/data/client_detail_repository.dart';
import 'package:lifey/features/trainer/client_detail/domain/client_workout_session.dart';

ClientWorkoutSession _session(int id, {String? comment}) => ClientWorkoutSession(
      id: id,
      startedAt: DateTime.utc(2026, 7, 8, 17),
      finishedAt: DateTime.utc(2026, 7, 8, 18),
      templateName: 'Push day',
      trainerComment: comment,
      trainerCommentAt: comment == null ? null : DateTime.utc(2026, 7, 9),
    );

class _FakeRepository extends ClientDetailRepository {
  _FakeRepository({
    this.pages = const [],
    this.failPages = false,
    this.failFromPage,
  }) : super(Dio());

  final List<ClientSessionPage> pages;
  final bool failPages;

  /// Fails every request for this page number and beyond — the "the network
  /// went away halfway down the list" case.
  final int? failFromPage;

  final List<int> requestedPages = [];
  final List<({int sessionId, String comment})> writes = [];
  final List<int> deletes = [];

  Object? commentFailure;

  @override
  Future<ClientSessionPage> fetchWorkoutSessions(
    int clientId, {
    int page = 0,
    int size = 20,
  }) async {
    requestedPages.add(page);
    if (failPages || (failFromPage != null && page >= failFromPage!)) {
      throw Exception('offline');
    }
    if (page >= pages.length) {
      return const ClientSessionPage(sessions: [], isLast: true);
    }
    return pages[page];
  }

  @override
  Future<ClientWorkoutSession> putSessionComment(
    int clientId,
    int sessionId,
    String comment,
  ) async {
    if (commentFailure != null) throw commentFailure!;
    writes.add((sessionId: sessionId, comment: comment));
    return _session(sessionId, comment: comment);
  }

  @override
  Future<ClientWorkoutSession> deleteSessionComment(
    int clientId,
    int sessionId,
  ) async {
    if (commentFailure != null) throw commentFailure!;
    deletes.add(sessionId);
    return _session(sessionId);
  }
}

ProviderContainer _containerWith(_FakeRepository repo) {
  final container = ProviderContainer(
    overrides: [clientDetailRepositoryProvider.overrideWithValue(repo)],
  );
  addTearDown(container.dispose);
  return container;
}

/// The controller kicks its first load off in `build()`, so every test has to
/// let that microtask run before asserting.
Future<ClientSessionsState> _settled(
  ProviderContainer container,
  int clientId,
) async {
  container.listen(clientSessionsControllerProvider(clientId), (_, __) {});
  await Future<void>.delayed(Duration.zero);
  return container.read(clientSessionsControllerProvider(clientId));
}

void main() {
  group('loading', () {
    test('reads the first page and reports whether there is more', () async {
      final repo = _FakeRepository(pages: [
        ClientSessionPage(sessions: [_session(1), _session(2)], isLast: false),
      ]);
      final container = _containerWith(repo);

      final state = await _settled(container, 5);

      expect(repo.requestedPages, [0]);
      expect(state.loading, isFalse);
      expect(state.sessions.map((s) => s.id), [1, 2]);
      expect(state.hasMore, isTrue);
    });

    test('a failed first page keeps the error, not a silent empty list',
        () async {
      final container = _containerWith(_FakeRepository(failPages: true));

      final state = await _settled(container, 5);

      expect(state.error, isNotNull);
      expect(state.sessions, isEmpty);
      expect(state.loading, isFalse);
    });
  });

  group('paging', () {
    test('loadMore appends the next page and stops at the last one', () async {
      final repo = _FakeRepository(pages: [
        ClientSessionPage(sessions: [_session(1)], isLast: false),
        ClientSessionPage(sessions: [_session(2)], isLast: true),
      ]);
      final container = _containerWith(repo);
      await _settled(container, 5);

      await container
          .read(clientSessionsControllerProvider(5).notifier)
          .loadMore();

      final state = container.read(clientSessionsControllerProvider(5));
      expect(repo.requestedPages, [0, 1]);
      expect(state.sessions.map((s) => s.id), [1, 2]);
      expect(state.hasMore, isFalse);
    });

    test('loadMore does nothing once the last page has arrived', () async {
      final repo = _FakeRepository(pages: [
        ClientSessionPage(sessions: [_session(1)], isLast: true),
      ]);
      final container = _containerWith(repo);
      await _settled(container, 5);

      await container
          .read(clientSessionsControllerProvider(5).notifier)
          .loadMore();

      expect(repo.requestedPages, [0]);
    });

    test('a failed page keeps what was already read on screen', () async {
      final repo = _FakeRepository(
        pages: [ClientSessionPage(sessions: [_session(1)], isLast: false)],
        failFromPage: 1,
      );
      final container = _containerWith(repo);
      await _settled(container, 5);

      await container
          .read(clientSessionsControllerProvider(5).notifier)
          .loadMore();

      final state = container.read(clientSessionsControllerProvider(5));
      // Nothing is thrown away and no error state replaces the list: the
      // trainer was reading these rows, and the footer offers another try.
      expect(state.sessions.map((s) => s.id), [1]);
      expect(state.loadingMore, isFalse);
      expect(state.hasMore, isTrue);
      expect(state.error, isNull);
    });
  });

  group('comment', () {
    test('a first comment reports that the client was notified', () async {
      final repo = _FakeRepository(pages: [
        ClientSessionPage(sessions: [_session(1)], isLast: true),
      ]);
      final container = _containerWith(repo);
      await _settled(container, 5);

      final outcome = await container
          .read(clientSessionsControllerProvider(5).notifier)
          .saveComment(1, 'Nice pace');

      // The push only fires on a null -> non-null transition (docs/31 B3),
      // which is exactly what this outcome is for.
      expect(outcome, CommentSaveOutcome.created);
      expect(repo.writes.single.comment, 'Nice pace');
      expect(
        container.read(clientSessionsControllerProvider(5)).sessions.single
            .trainerComment,
        'Nice pace',
      );
    });

    test('rewriting an existing comment does not claim a notification',
        () async {
      final repo = _FakeRepository(pages: [
        ClientSessionPage(
          sessions: [_session(1, comment: 'Typo here')],
          isLast: true,
        ),
      ]);
      final container = _containerWith(repo);
      await _settled(container, 5);

      final outcome = await container
          .read(clientSessionsControllerProvider(5).notifier)
          .saveComment(1, 'Typo fixed');

      expect(outcome, CommentSaveOutcome.updated);
    });

    test('deleting clears the comment on the row', () async {
      final repo = _FakeRepository(pages: [
        ClientSessionPage(
          sessions: [_session(1, comment: 'Nice pace')],
          isLast: true,
        ),
      ]);
      final container = _containerWith(repo);
      await _settled(container, 5);

      final outcome = await container
          .read(clientSessionsControllerProvider(5).notifier)
          .deleteComment(1);

      expect(outcome, CommentSaveOutcome.removed);
      expect(repo.deletes, [1]);
      expect(
        container.read(clientSessionsControllerProvider(5)).sessions.single
            .hasTrainerComment,
        isFalse,
      );
    });

    test('a failed write throws and leaves the row untouched', () async {
      final repo = _FakeRepository(pages: [
        ClientSessionPage(sessions: [_session(1)], isLast: true),
      ]);
      repo.commentFailure = Exception('500');
      final container = _containerWith(repo);
      await _settled(container, 5);

      // The editor is the one place that knows how to report this, so the
      // controller must not swallow it — and nothing may look saved.
      await expectLater(
        container
            .read(clientSessionsControllerProvider(5).notifier)
            .saveComment(1, 'Nice pace'),
        throwsA(isA<Exception>()),
      );
      expect(
        container.read(clientSessionsControllerProvider(5)).sessions.single
            .hasTrainerComment,
        isFalse,
      );
    });

    test('a comment write does not refetch, so later pages survive', () async {
      final repo = _FakeRepository(pages: [
        ClientSessionPage(sessions: [_session(1)], isLast: false),
        ClientSessionPage(sessions: [_session(2)], isLast: true),
      ]);
      final container = _containerWith(repo);
      await _settled(container, 5);
      await container
          .read(clientSessionsControllerProvider(5).notifier)
          .loadMore();

      await container
          .read(clientSessionsControllerProvider(5).notifier)
          .saveComment(2, 'Good work');

      expect(repo.requestedPages, [0, 1]);
      expect(
        container.read(clientSessionsControllerProvider(5)).sessions.map((s) => s.id),
        [1, 2],
      );
    });
  });
}
