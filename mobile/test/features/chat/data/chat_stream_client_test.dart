import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/features/chat/data/chat_stream_client.dart';

/// The SSE wire format is easy to get subtly wrong and hard to notice — a
/// mis-parsed frame silently does nothing at all.
void main() {
  group('parseChatStreamFrame', () {
    test('reads the event name, the id and the JSON payload', () {
      final frame = parseChatStreamFrame(
        'event: message\nid: 4310\ndata: {"conversationId":12}',
      );

      expect(frame!.name, 'message');
      expect(frame.id, 4310);
      expect(frame.data['conversationId'], 12);
    });

    test('defaults to the message event when the server omits the name', () {
      expect(parseChatStreamFrame('data: {"a":1}')!.name, 'message');
    });

    test('leaves the cursor alone for a frame without an id', () {
      // Read receipts deliberately carry no id, so Last-Event-ID keeps meaning
      // "the newest message I have".
      expect(parseChatStreamFrame('event: read\ndata: {"conversationId":12}')!.id, isNull);
    });

    test('ignores heartbeat comments', () {
      expect(parseChatStreamFrame(': ping'), isNull);
    });

    test('joins multi-line data the way the wire format splits it', () {
      expect(parseChatStreamFrame('data: {"a":\ndata: 1}')!.data['a'], 1);
    });

    test('strips exactly one leading space after the colon, not more', () {
      expect(parseChatStreamFrame('event:  read\ndata: {}')!.name, ' read');
      expect(parseChatStreamFrame('event:read\ndata: {}')!.name, 'read');
    });

    test('survives a payload that is not JSON instead of taking the loop down', () {
      expect(parseChatStreamFrame('event: message\ndata: not json'), isNull);
    });
  });
}
