import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/features/auth/application/auth_controller.dart';
import 'package:lifey/features/auth/domain/auth_user.dart';
import 'package:lifey/features/chat/application/conversation_list_controller.dart';
import 'package:lifey/features/chat/domain/chat_conversation.dart';
import 'package:lifey/features/chat/domain/chat_peer.dart';
import 'package:lifey/features/chat/presentation/conversation_list_screen.dart';
import 'package:lifey/l10n/app_localizations.dart';

class _FakeAuthController extends AuthController {
  _FakeAuthController(this._roles);

  final List<String> _roles;

  @override
  Future<AuthUser?> build() async =>
      AuthUser(id: 7, email: 'me@example.com', roles: _roles);
}

class _FakeConversationListController extends ConversationListController {
  _FakeConversationListController(this._conversations);

  final List<ChatConversation> _conversations;

  @override
  Stream<List<ChatConversation>> build() => Stream.value(_conversations);
}

ChatConversation _conversation({
  required int id,
  required String name,
  required ChatPeerRole role,
  int unreadCount = 0,
  String? preview = 'Rendben',
  int? lastSenderId = 88,
  DateTime? archivedAt,
}) {
  return ChatConversation(
    id: id,
    peer: ChatPeer(
      userId: 80 + id,
      displayName: name,
      email: '$id@example.com',
      role: role,
    ),
    unreadCount: unreadCount,
    lastMessageAt: DateTime(2026, 8, 6, 14, 32),
    lastMessagePreview: preview,
    lastMessageSenderId: lastSenderId,
    archivedAt: archivedAt,
  );
}

Future<void> _pump(
  WidgetTester tester, {
  required List<String> roles,
  List<ChatConversation> conversations = const [],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authControllerProvider.overrideWith(() => _FakeAuthController(roles)),
        conversationListControllerProvider
            .overrideWith(() => _FakeConversationListController(conversations)),
      ],
      child: const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ConversationListScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('role-dependent chrome', () {
    testWidgets('a client sees the messages title and no new-conversation button',
        (tester) async {
      await _pump(
        tester,
        roles: ['ROLE_USER'],
        conversations: [
          _conversation(id: 1, name: 'Nagy Péter', role: ChatPeerRole.trainer),
        ],
      );

      expect(find.text('Messages'), findsOneWidget);
      expect(find.text('My clients'), findsNothing);
      // A client has no one to start a thread with — the relationship, and
      // with it the thread, comes from accepting an invite.
      expect(find.byType(FloatingActionButton), findsNothing);
    });

    testWidgets('a trainer sees the clients title and the new-conversation button',
        (tester) async {
      await _pump(
        tester,
        roles: ['ROLE_USER', 'ROLE_TRAINER'],
        conversations: [
          _conversation(id: 1, name: 'Kiss Anna', role: ChatPeerRole.client),
        ],
      );

      expect(find.text('My clients'), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsOneWidget);
    });
  });

  group('empty states', () {
    testWidgets('a client with no trainer is told how a thread starts', (tester) async {
      await _pump(tester, roles: ['ROLE_USER']);

      expect(find.text('No trainer yet'), findsOneWidget);
    });

    testWidgets('a trainer with no clients gets their own wording', (tester) async {
      await _pump(tester, roles: ['ROLE_USER', 'ROLE_TRAINER']);

      expect(find.text('No clients yet'), findsOneWidget);
      expect(find.text('No trainer yet'), findsNothing);
    });
  });

  group('dual role', () {
    testWidgets('a mixed list labels both kinds of peer', (tester) async {
      // A trainer who also has a trainer of their own: one list, told apart
      // by a text label rather than a colour or a second screen.
      await _pump(
        tester,
        roles: ['ROLE_USER', 'ROLE_TRAINER'],
        conversations: [
          _conversation(id: 1, name: 'Balogh Gábor', role: ChatPeerRole.trainer),
          _conversation(id: 2, name: 'Tóth Eszter', role: ChatPeerRole.client),
        ],
      );

      expect(find.text('YOUR TRAINER'), findsOneWidget);
      expect(find.text('YOUR CLIENT'), findsOneWidget);
    });

    testWidgets('a uniform list carries no labels at all', (tester) async {
      await _pump(
        tester,
        roles: ['ROLE_USER', 'ROLE_TRAINER'],
        conversations: [
          _conversation(id: 1, name: 'Tóth Eszter', role: ChatPeerRole.client),
          _conversation(id: 2, name: 'Szabó Dániel', role: ChatPeerRole.client),
        ],
      );

      expect(find.text('YOUR CLIENT'), findsNothing);
    });
  });

  group('row content', () {
    testWidgets('the preview is prefixed when the last message was ours', (tester) async {
      await _pump(
        tester,
        roles: ['ROLE_USER'],
        conversations: [
          _conversation(
            id: 1,
            name: 'Nagy Péter',
            role: ChatPeerRole.trainer,
            preview: 'Köszönöm a mai órát!',
            lastSenderId: 7,
          ),
        ],
      );

      expect(find.text('You: Köszönöm a mai órát!'), findsOneWidget);
    });

    testWidgets('an archived thread is marked closed but still listed', (tester) async {
      await _pump(
        tester,
        roles: ['ROLE_USER', 'ROLE_TRAINER'],
        conversations: [
          _conversation(
            id: 1,
            name: 'Kiss Luca',
            role: ChatPeerRole.client,
            archivedAt: DateTime(2026, 8, 1),
          ),
        ],
      );

      expect(find.text('Closed'), findsOneWidget);
      expect(find.text('Kiss Luca'), findsOneWidget);
    });

    testWidgets('a deleted last message shows the tombstone in the preview', (tester) async {
      await _pump(
        tester,
        roles: ['ROLE_USER'],
        conversations: [
          _conversation(id: 1, name: 'Nagy Péter', role: ChatPeerRole.trainer, preview: null),
        ],
      );

      expect(find.text('This message was deleted'), findsOneWidget);
    });
  });

  group('search', () {
    testWidgets('is hidden while the list is short', (tester) async {
      await _pump(
        tester,
        roles: ['ROLE_USER', 'ROLE_TRAINER'],
        conversations: [
          for (var i = 1; i <= 3; i++)
            _conversation(id: i, name: 'Client $i', role: ChatPeerRole.client),
        ],
      );

      expect(find.byIcon(Icons.search), findsNothing);
    });

    testWidgets('appears once a trainer has enough clients to need it', (tester) async {
      await _pump(
        tester,
        roles: ['ROLE_USER', 'ROLE_TRAINER'],
        conversations: [
          for (var i = 1; i <= 12; i++)
            _conversation(id: i, name: 'Client $i', role: ChatPeerRole.client),
        ],
      );

      expect(find.byIcon(Icons.search), findsOneWidget);
    });

    testWidgets('filters the list by name', (tester) async {
      await _pump(
        tester,
        roles: ['ROLE_USER', 'ROLE_TRAINER'],
        conversations: [
          for (var i = 1; i <= 11; i++)
            _conversation(id: i, name: 'Client $i', role: ChatPeerRole.client),
          _conversation(id: 12, name: 'Tóth Eszter', role: ChatPeerRole.client),
        ],
      );

      await tester.tap(find.byIcon(Icons.search));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Eszter');
      await tester.pumpAndSettle();

      expect(find.text('Tóth Eszter'), findsOneWidget);
      expect(find.text('Client 1'), findsNothing);
    });
  });
}
