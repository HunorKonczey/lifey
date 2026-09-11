import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/features/trainer/clients/application/trainer_clients_controller.dart';
import 'package:lifey/features/trainer/clients/domain/trainer_client.dart';
import 'package:lifey/features/trainer/invites/data/trainer_invites_repository.dart';
import 'package:lifey/features/trainer/invites/domain/sent_invite.dart';
import 'package:lifey/features/trainer/invites/presentation/trainer_invites_screen.dart';
import 'package:lifey/l10n/app_localizations.dart';

class _FakeAdapter implements HttpClientAdapter {
  final List<String> methods = [];
  final List<String> paths = [];
  final List<Object?> bodies = [];
  Object body = <Object>[];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    methods.add(options.method);
    paths.add(options.path);
    bodies.add(options.data);
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

class _FakeClientsController extends TrainerClientsController {
  @override
  Future<List<TrainerClient>> build() async => const [];
}

class _FakeInvitesRepository extends TrainerInvitesRepository {
  _FakeInvitesRepository({this.invites = const []}) : super(Dio());

  final List<SentInvite> invites;

  final List<String> sent = [];
  final List<int> cancelled = [];
  Object? sendFailure;

  @override
  Future<List<SentInvite>> findPending() async => invites;

  @override
  Future<SentInvite> invite(String email) async {
    if (sendFailure != null) throw sendFailure!;
    sent.add(email);
    return SentInvite(
      id: 99,
      clientEmail: email,
      createdAt: DateTime.now(),
      expiresAt: DateTime.now().add(const Duration(hours: 24)),
    );
  }

  @override
  Future<void> cancel(int inviteId) async => cancelled.add(inviteId);
}

SentInvite _invite({int id = 1, String email = 'anna@example.com', int hoursLeft = 18}) {
  return SentInvite(
    id: id,
    clientEmail: email,
    createdAt: DateTime.now().subtract(const Duration(hours: 6)),
    // A minute of margin: `inHours` floors, so an exact boundary would flake
    // down by one.
    expiresAt: DateTime.now().add(Duration(hours: hoursLeft, minutes: 1)),
  );
}

Future<void> _pump(
  WidgetTester tester, {
  required _FakeInvitesRepository repo,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        trainerInvitesRepositoryProvider.overrideWithValue(repo),
        trainerClientsControllerProvider.overrideWith(_FakeClientsController.new),
      ],
      child: const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: TrainerInvitesScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('repository', () {
    late Dio dio;
    late _FakeAdapter adapter;
    late TrainerInvitesRepository repo;

    setUp(() {
      dio = Dio(BaseOptions(baseUrl: 'http://test'));
      adapter = _FakeAdapter();
      dio.httpClientAdapter = adapter;
      repo = TrainerInvitesRepository(dio);
    });

    test('lists pending invites with their expiry', () async {
      adapter.body = [
        {
          'id': 1,
          'clientEmail': 'anna@example.com',
          'createdAt': '2026-07-08T10:00:00Z',
          'expiresAt': '2026-07-09T10:00:00Z',
        },
      ];

      final invites = await repo.findPending();

      expect(adapter.paths.single, '/trainer/invites');
      expect(invites.single.clientEmail, 'anna@example.com');
      expect(invites.single.expiresAt, DateTime.utc(2026, 7, 9, 10));
    });

    test('posts the address exactly as given', () async {
      adapter.body = {
        'id': 2,
        'clientEmail': 'bela@example.com',
        'createdAt': '2026-07-08T10:00:00Z',
        'expiresAt': '2026-07-09T10:00:00Z',
      };

      await repo.invite('bela@example.com');

      expect(adapter.methods.single, 'POST');
      expect(adapter.bodies.single, {'email': 'bela@example.com'});
    });

    test('cancelling goes by invite id', () async {
      adapter.body = <Object>[];

      await repo.cancel(1);

      expect(adapter.methods.single, 'DELETE');
      expect(adapter.paths.single, '/trainer/invites/1');
    });
  });

  group('remaining time', () {
    test('counts down to the expiry', () {
      final invite = SentInvite(
        id: 1,
        clientEmail: 'a@example.com',
        createdAt: DateTime(2026, 7, 8, 10),
        expiresAt: DateTime(2026, 7, 9, 10),
      );

      expect(
        invite.remaining(now: DateTime(2026, 7, 8, 22)).inHours,
        12,
      );
    });

    test('never goes negative', () {
      final invite = SentInvite(
        id: 1,
        clientEmail: 'a@example.com',
        createdAt: DateTime(2026, 7, 8, 10),
        expiresAt: DateTime(2026, 7, 9, 10),
      );

      // A briefly stale list can still hold an expired invite; a negative
      // countdown would read as a bug.
      expect(invite.remaining(now: DateTime(2026, 7, 10)), Duration.zero);
    });
  });

  group('the screen', () {
    testWidgets('lists who has not answered, and how long they have',
        (tester) async {
      await _pump(
        tester,
        repo: _FakeInvitesRepository(invites: [_invite(hoursLeft: 18)]),
      );

      expect(find.text('anna@example.com'), findsOneWidget);
      expect(find.text('Expires in 18 hours'), findsOneWidget);
    });

    testWidgets('says so when nobody is pending', (tester) async {
      await _pump(tester, repo: _FakeInvitesRepository());

      expect(find.text('No invites are waiting for an answer.'), findsOneWidget);
    });

    testWidgets('refuses an address that is not one, without a round trip',
        (tester) async {
      final repo = _FakeInvitesRepository();
      await _pump(tester, repo: repo);

      await tester.enterText(find.byType(TextFormField), 'not-an-email');
      await tester.tap(find.text('Send invite'));
      await tester.pumpAndSettle();

      expect(find.text('That does not look like an email address.'), findsOneWidget);
      expect(repo.sent, isEmpty);
    });

    testWidgets('sends a valid one and clears the field', (tester) async {
      final repo = _FakeInvitesRepository();
      await _pump(tester, repo: repo);

      await tester.enterText(find.byType(TextFormField), 'bela@example.com');
      await tester.tap(find.text('Send invite'));
      await tester.pumpAndSettle();

      expect(repo.sent, ['bela@example.com']);
      expect(find.text('Invite sent.'), findsOneWidget);
      expect(find.text('bela@example.com'), findsNothing);
    });

    testWidgets('a rejected address keeps the server\'s own reason on screen',
        (tester) async {
      final repo = _FakeInvitesRepository();
      // The real shape: the backend answers 409 with its own message, and
      // friendlyError surfaces that rather than a generic failure.
      repo.sendFailure = DioException(
        requestOptions: RequestOptions(path: '/trainer/invites'),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: RequestOptions(path: '/trainer/invites'),
          statusCode: 409,
          data: const {'message': 'That person is already your client'},
        ),
      );
      await _pump(tester, repo: repo);

      await tester.enterText(find.byType(TextFormField), 'anna@example.com');
      await tester.tap(find.text('Send invite'));
      await tester.pumpAndSettle();

      // "Already your client" is a different problem from a typo, and the
      // trainer needs to know which.
      expect(
        find.text('That person is already your client'),
        findsOneWidget,
      );
    });

    testWidgets('taking an invite back asks first, naming the address',
        (tester) async {
      final repo = _FakeInvitesRepository(invites: [_invite()]);
      await _pump(tester, repo: repo);

      await tester.tap(find.byTooltip('Take back invite'));
      await tester.pumpAndSettle();

      expect(
        find.text('anna@example.com will no longer be able to accept it.'),
        findsOneWidget,
      );

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(repo.cancelled, [1]);
      expect(find.text('Invite taken back.'), findsOneWidget);
    });
  });
}
