import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/features/chat/domain/chat_peer.dart';

ChatPeer _peer({String displayName = 'Kiss Anna', String email = 'anna@example.com'}) {
  return ChatPeer(
    userId: 88,
    displayName: displayName,
    email: email,
    role: ChatPeerRole.client,
  );
}

void main() {
  group('monogram', () {
    test('takes the initials of the first two words', () {
      expect(_peer().monogram, 'KA');
    });

    test('uses a single initial for a one-word name', () {
      expect(_peer(displayName: 'Anna').monogram, 'A');
    });

    test('ignores anything past the second word', () {
      expect(_peer(displayName: 'Kiss Anna Mária').monogram, 'KA');
    });

    test('tolerates extra whitespace between words', () {
      expect(_peer(displayName: '  Kiss   Anna  ').monogram, 'KA');
    });

    test('falls back to the email for a profile with no name at all', () {
      // The backend already falls back to the email as displayName, but a
      // blank one must still produce something renderable.
      expect(_peer(displayName: '').monogram, 'A');
    });

    test('never throws when there is nothing to work with', () {
      expect(_peer(displayName: '', email: '').monogram, '?');
    });
  });

  group('fromJson', () {
    test('maps the peer role the server reports', () {
      final peer = ChatPeer.fromJson(const {
        'userId': 7,
        'displayName': 'Nagy Péter',
        'email': 'peter@example.com',
        'role': 'TRAINER',
      });

      expect(peer.role, ChatPeerRole.trainer);
      expect(peer.userId, 7);
    });

    test('treats a missing email as empty rather than failing', () {
      final peer = ChatPeer.fromJson(const {
        'userId': 7,
        'displayName': 'Nagy Péter',
        'role': 'CLIENT',
      });

      expect(peer.email, '');
      expect(peer.role, ChatPeerRole.client);
    });
  });
}
