import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

/// One frame off the chat SSE stream.
class ChatStreamFrame {
  const ChatStreamFrame({required this.name, this.id, required this.data});

  /// `event:` — `message`, `read`, `deleted`, `typing` or `resync`.
  final String name;

  /// `id:`, present only on message frames, which is what makes it the cursor.
  final int? id;

  final Map<String, dynamic> data;
}

/// Reads `GET /chat/stream` and keeps it open
/// (docs/chat/40-trainer-chat-plan.md §4.4).
///
/// Dio rather than a dedicated SSE package: the app's `Dio` already carries the
/// bearer token, the base URL and the refresh-on-401 interceptor, and an SSE
/// body is a byte stream with a two-line framing rule — not worth a dependency
/// (and the project rule is to justify new ones).
///
/// The stream is **not** kept open in the background. The OS would kill it
/// anyway, and once the app is backgrounded push is the delivery channel — so
/// [connect] is bound to the foreground lifecycle by `ChatStreamController`.
class ChatStreamClient {
  ChatStreamClient(this._dio, this._path);

  final Dio _dio;
  final String _path;

  /// Reconnect delays; the last one repeats for as long as it keeps failing.
  static const _backoff = [
    Duration(seconds: 1),
    Duration(seconds: 2),
    Duration(seconds: 5),
    Duration(seconds: 15),
  ];

  StreamSubscription<String>? _subscription;
  CancelToken? _cancelToken;
  Timer? _retryTimer;
  bool _stopped = true;
  int _attempt = 0;

  /// Opens the stream and keeps reopening it until [disconnect].
  ///
  /// [lastEventId] is asked for on every attempt rather than passed once: after
  /// a drop, the newest message we hold may have moved on (a REST refresh, a
  /// send of our own), and replaying from a stale cursor would be wasted work.
  void connect({
    required Future<int?> Function() lastEventId,
    required void Function(ChatStreamFrame frame) onFrame,
    void Function(bool connected)? onConnectionChange,
  }) {
    if (!_stopped) return;
    _stopped = false;
    _attempt = 0;
    unawaited(_open(lastEventId, onFrame, onConnectionChange));
  }

  Future<void> disconnect() async {
    _stopped = true;
    _retryTimer?.cancel();
    _retryTimer = null;
    _cancelToken?.cancel('chat stream closed');
    _cancelToken = null;
    await _subscription?.cancel();
    _subscription = null;
  }

  Future<void> _open(
    Future<int?> Function() lastEventId,
    void Function(ChatStreamFrame frame) onFrame,
    void Function(bool connected)? onConnectionChange,
  ) async {
    if (_stopped) return;

    final cancelToken = CancelToken();
    _cancelToken = cancelToken;
    try {
      final cursor = await lastEventId();
      final response = await _dio.get<ResponseBody>(
        _path,
        cancelToken: cancelToken,
        options: Options(
          responseType: ResponseType.stream,
          headers: {
            'Accept': 'text/event-stream',
            if (cursor != null) 'Last-Event-ID': '$cursor',
          },
          // The whole point is a connection that stays quiet for minutes at a
          // time; Dio's default receive timeout would kill it between frames.
          receiveTimeout: null,
        ),
      );

      _attempt = 0;
      onConnectionChange?.call(true);

      var buffer = '';
      final completer = Completer<void>();
      _subscription = utf8.decoder
          .bind(response.data!.stream.map((chunk) => chunk.toList()))
          .listen(
        (chunk) {
          buffer += chunk;
          // Frames are separated by a blank line; whatever follows the last
          // separator is a partial frame and waits for the next chunk.
          var separator = buffer.indexOf('\n\n');
          while (separator != -1) {
            final raw = buffer.substring(0, separator);
            buffer = buffer.substring(separator + 2);
            final frame = parseChatStreamFrame(raw);
            if (frame != null) onFrame(frame);
            separator = buffer.indexOf('\n\n');
          }
        },
        onDone: () => completer.complete(),
        onError: (Object _) => completer.complete(),
        cancelOnError: true,
      );

      await completer.future;
      onConnectionChange?.call(false);
      // A clean end is the server's stream-timeout, not a failure: reconnect
      // straight away instead of sitting out a backoff on a healthy stream.
      if (!_stopped) unawaited(_open(lastEventId, onFrame, onConnectionChange));
    } catch (_) {
      onConnectionChange?.call(false);
      if (_stopped) return;
      _attempt++;
      final delay = _backoff[_attempt > _backoff.length ? _backoff.length - 1 : _attempt - 1];
      _retryTimer = Timer(delay, () => unawaited(_open(lastEventId, onFrame, onConnectionChange)));
    }
  }
}

/// Parses one SSE frame: `id:` / `event:` / one or more `data:` lines.
///
/// Top-level and public for its own test — the wire format is easy to get
/// subtly wrong and hard to notice, since a mis-parsed frame silently does
/// nothing at all.
ChatStreamFrame? parseChatStreamFrame(String raw) {
  var name = 'message';
  int? id;
  final dataLines = <String>[];

  for (final line in raw.split('\n')) {
    // A comment — the server's heartbeat is one, and it exists to keep proxies
    // from closing an idle connection, not to be handled.
    if (line.startsWith(':')) continue;
    final colon = line.indexOf(':');
    final field = colon == -1 ? line : line.substring(0, colon);
    var value = colon == -1 ? '' : line.substring(colon + 1);
    if (value.startsWith(' ')) value = value.substring(1);

    if (field == 'event') {
      name = value;
    } else if (field == 'id') {
      id = int.tryParse(value);
    } else if (field == 'data') {
      dataLines.add(value);
    }
  }

  if (dataLines.isEmpty) return null;
  try {
    final decoded = jsonDecode(dataLines.join('\n'));
    if (decoded is! Map<String, dynamic>) return null;
    return ChatStreamFrame(name: name, id: id, data: decoded);
  } catch (_) {
    // A malformed payload must not take the read loop down with it.
    return null;
  }
}
