import 'dart:io';


import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/local_db/app_database.dart';
import 'package:lifey/features/chat/application/chat_share.dart';
import 'package:lifey/features/chat/data/chat_repository.dart';
import 'package:lifey/features/chat/domain/chat_card.dart';
import 'package:lifey/features/chat/domain/chat_conversation.dart';
import 'package:lifey/features/chat/domain/chat_peer.dart';
import 'package:lifey/features/my_trainers/data/my_trainers_repository.dart';
import 'package:lifey/features/my_trainers/domain/my_trainer.dart';

class _FakeChat extends ChatRepository {
  _FakeChat({this.conversations = const [], this.refreshed, this.failRefresh = false, this.failOpen = false})
      : super(AppDatabase(NativeDatabase.memory()), Dio(), () => 7);

  List<ChatConversation> conversations;
  final List<ChatConversation>? refreshed;
  final bool failRefresh;
  final bool failOpen;

  int refreshCalls = 0;
  final opened = <int>[];
  final sent = <({int conversationId, String body, ChatCard? card})>[];

  @override
  Stream<List<ChatConversation>> watchConversations() => Stream.value(conversations);

  @override
  Future<void> refreshConversations() async {
    refreshCalls++;
    if (failRefresh) throw Exception('offline');
    if (refreshed != null) conversations = refreshed!;
  }

  @override
  Future<int> openConversationWith(int peerUserId) async {
    if (failOpen) throw Exception('offline');
    opened.add(peerUserId);
    return 900 + peerUserId;
  }

  @override
  Future<void> send(int conversationId, String body, {File? image, ChatCard? card}) async {
    sent.add((conversationId: conversationId, body: body, card: card));
  }
}

class _FakeTrainers extends MyTrainersRepository {
  _FakeTrainers(this.trainers, {this.fail = false}) : super(Dio());

  final List<MyTrainer> trainers;
  final bool fail;

  @override
  Future<List<MyTrainer>> fetchActiveTrainers() async {
    if (fail) throw Exception('offline');
    return trainers;
  }
}

ChatConversation _conversation(int id, int peerId, String name, {DateTime? archivedAt}) => ChatConversation(
      id: id,
      peer: ChatPeer(userId: peerId, displayName: name, email: '$peerId@example.com', role: ChatPeerRole.trainer),
      unreadCount: 0,
      archivedAt: archivedAt,
    );

MyTrainer _trainer(int id, String name) => MyTrainer(
      trainerId: id,
      trainerEmail: '$id@example.com',
      trainerFirstName: name,
      activeSince: DateTime(2026, 1, 1),
    );

ProviderContainer _container(_FakeChat chat, _FakeTrainers trainers) {
  final container = ProviderContainer(overrides: [
    chatRepositoryProvider.overrideWithValue(chat),
    myTrainersRepositoryProvider.overrideWithValue(trainers),
  ]);
  addTearDown(container.dispose);
  return container;
}

final _card = WorkoutChatCard(
  occurredAt: DateTime.utc(2026, 10, 3, 7),
  workoutKind: ChatWorkoutKind.strength,
  title: 'Push day',
);

void main() {
  // Every fake repository opens its own throwaway in-memory database.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  group('who can be shared with', () {
    test('open threads come first, then trainers with no thread yet', () async {
      final chat = _FakeChat(conversations: [_conversation(1, 50, 'Edző Elek')]);
      final container = _container(chat, _FakeTrainers([_trainer(50, 'Edző Elek'), _trainer(60, 'Új Edző')]));

      final targets = await container.read(chatShareTargetsProvider.future);

      expect(targets.map((t) => t.peer.userId), [50, 60]);
      expect(targets[0].conversationId, 1);
      // Not written to yet: the thread is created on the first message.
      expect(targets[1].conversationId, isNull);
      expect(targets[1].peer.displayName, 'Új Edző');
    });

    test('an archived thread is readable but never a target', () async {
      final chat = _FakeChat(conversations: [
        _conversation(1, 50, 'Régi Edző', archivedAt: DateTime(2026, 8, 1)),
        _conversation(2, 51, 'Mostani Edző'),
      ]);
      final container = _container(chat, _FakeTrainers(const []));

      final targets = await container.read(chatShareTargetsProvider.future);

      expect(targets.map((t) => t.peer.userId), [51]);
    });

    test('with nobody at all the list is empty, so the buttons stay hidden', () async {
      final container = _container(_FakeChat(), _FakeTrainers(const []));

      expect(await container.read(chatShareTargetsProvider.future), isEmpty);
    });

    test('a cold cache is refreshed once before giving up', () async {
      final chat = _FakeChat(refreshed: [_conversation(1, 50, 'Edző Elek')]);
      final container = _container(chat, _FakeTrainers(const []));

      final targets = await container.read(chatShareTargetsProvider.future);

      expect(chat.refreshCalls, 1);
      expect(targets.map((t) => t.peer.userId), [50]);
    });

    test('offline, the cached threads are still offered', () async {
      final chat = _FakeChat(conversations: [_conversation(1, 50, 'Edző Elek')]);
      final container = _container(chat, _FakeTrainers(const [], fail: true));

      final targets = await container.read(chatShareTargetsProvider.future);

      expect(targets.map((t) => t.peer.userId), [50]);
    });

    test('offline with a cold cache is just empty, never an error', () async {
      final container = _container(_FakeChat(failRefresh: true), _FakeTrainers(const [], fail: true));

      expect(await container.read(chatShareTargetsProvider.future), isEmpty);
    });
  });

  group('sending', () {
    ChatShareTarget existing() =>
        ChatShareTarget(peer: _conversation(1, 50, 'Edző Elek').peer, conversationId: 1);
    ChatShareTarget fresh() => ChatShareTarget(peer: _conversation(0, 60, 'Új Edző').peer);

    test('an existing thread is written to directly, card and caption together', () async {
      final chat = _FakeChat();
      final id = await ChatShareService(chat).share(target: existing(), card: _card, caption: 'Nézd!');

      expect(id, 1);
      expect(chat.opened, isEmpty);
      expect(chat.sent.single.conversationId, 1);
      expect(chat.sent.single.body, 'Nézd!');
      expect(chat.sent.single.card, same(_card));
    });

    test('a person with no thread yet gets one created first', () async {
      final chat = _FakeChat();

      final id = await ChatShareService(chat).share(target: fresh(), card: _card);

      expect(chat.opened, [60]);
      expect(id, 960);
      expect(chat.sent.single.conversationId, 960);
    });

    test('creating the thread offline is the one thing that throws', () async {
      final chat = _FakeChat(failOpen: true);

      await expectLater(ChatShareService(chat).share(target: fresh(), card: _card), throwsException);
      expect(chat.sent, isEmpty);
    });

    test('the session id is filled in at send time when the card did not have it', () async {
      final chat = _FakeChat();

      await ChatShareService(chat).share(
        target: existing(),
        card: _card,
        resolveSessionId: () async => 481,
      );

      expect(chat.sent.single.card!.sessionId, 481);
    });

    test('a card that already knows its session never asks again', () async {
      final chat = _FakeChat();
      var asked = false;

      await ChatShareService(chat).share(
        target: existing(),
        card: _card.withSessionId(77),
        resolveSessionId: () async {
          asked = true;
          return 481;
        },
      );

      expect(asked, isFalse);
      expect(chat.sent.single.card!.sessionId, 77);
    });

    test('a session that never syncs still sends the card, just not tappable', () async {
      final chat = _FakeChat();

      await ChatShareService(chat).share(
        target: existing(),
        card: _card,
        resolveSessionId: () async => null,
      );

      expect(chat.sent.single.card, isNotNull);
      expect(chat.sent.single.card!.sessionId, isNull);
    });
  });
}
