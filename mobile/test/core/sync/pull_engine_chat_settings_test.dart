import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/local_db/app_database.dart';
import 'package:lifey/core/sync/pull_engine.dart';

/// Answers GET /settings with a configurable body and every other entity with an empty, harmless list.
class _SettingsAdapter implements HttpClientAdapter {
  Map<String, dynamic> settings = {};

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final headers = {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    };
    if (options.path == '/settings') {
      return ResponseBody.fromString(jsonEncode(settings), 200, headers: headers);
    }
    return ResponseBody.fromString('[]', 200, headers: headers);
  }
}

Map<String, dynamic> _server({
  bool chatPushEnabled = true,
  bool? chatOnlineVisible,
  String? quietStart,
  String? quietEnd,
}) =>
    {
      'unitSystem': 'METRIC',
      'theme': 'SYSTEM',
      'language': 'SYSTEM',
      'chatPushEnabled': chatPushEnabled,
      if (chatOnlineVisible != null) 'chatOnlineVisible': chatOnlineVisible,
      'chatQuietHoursStart': quietStart,
      'chatQuietHoursEnd': quietEnd,
    };

/// The chat switches of the settings pull (LIF-154): a change made on the web has to reach the phone, or the phone's next
/// whole-object save writes the old value back over it.
void main() {
  late AppDatabase db;
  late _SettingsAdapter adapter;
  late PullEngine pullEngine;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    final dio = Dio(BaseOptions(baseUrl: 'http://test'));
    adapter = _SettingsAdapter();
    dio.httpClientAdapter = adapter;
    pullEngine = PullEngine(db, dio);
  });

  tearDown(() => db.close());

  Future<UserSettingsRow> stored() => db.select(db.userSettingsTable).getSingle();

  test('the chat push switch, the online switch and the quiet hours come down from the server', () async {
    adapter.settings = _server(chatPushEnabled: false, chatOnlineVisible: false, quietStart: '22:00:00', quietEnd: '07:00:00');

    await pullEngine.pullAll();

    final row = await stored();
    expect(row.chatPushEnabled, isFalse);
    expect(row.chatOnlineVisible, isFalse);
    expect(row.chatQuietHoursStart, '22:00:00');
    expect(row.chatQuietHoursEnd, '07:00:00');
  });

  test('a window the user removed on the web is removed on the phone too', () async {
    adapter.settings = _server(quietStart: '22:00:00', quietEnd: '07:00:00');
    await pullEngine.pullAll();
    expect((await stored()).chatQuietHoursStart, '22:00:00');

    adapter.settings = _server();
    await pullEngine.pullAll();

    final row = await stored();
    expect(row.chatQuietHoursStart, isNull);
    expect(row.chatQuietHoursEnd, isNull);
  });

  test('a server that predates a switch says nothing, which reads as on', () async {
    adapter.settings = {'unitSystem': 'METRIC', 'theme': 'SYSTEM', 'language': 'SYSTEM'};

    await pullEngine.pullAll();

    final row = await stored();
    expect(row.chatPushEnabled, isTrue);
    expect(row.chatOnlineVisible, isTrue);
    expect(row.chatQuietHoursStart, isNull);
  });

  test('a change still waiting to be sent is not overwritten by the pull', () async {
    // The phone changed something offline: the server still holds the old values, and the pull must not undo the change.
    await db.into(db.userSettingsTable).insert(const UserSettingsTableCompanion(
          clientId: Value('singleton'),
          unitSystem: Value('METRIC'),
          theme: Value('SYSTEM'),
          language: Value('SYSTEM'),
          chatPushEnabled: Value(false),
        ));
    await db.into(db.pendingOperations).insert(PendingOperationsCompanion.insert(
          clientId: 'singleton',
          entityType: 'user_settings',
          operation: 'update',
          payloadJson: '{}',
          createdAt: DateTime.now(),
        ));
    adapter.settings = _server();

    await pullEngine.pullAll();

    expect((await stored()).chatPushEnabled, isFalse);
  });
}
