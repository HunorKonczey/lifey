import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/sync/logout_preflight.dart';

/// A preflight over a fake outbox: [pending] is what `pendingCount` reports,
/// and a successful `sync` empties it — like the real engine.
class _Fixture {
  _Fixture({this.pending = 0, this.online = true, this.syncBehaviour});

  int pending;
  bool online;
  int syncCalls = 0;

  /// Replaces the sync body: throw, hang, or leave changes behind.
  Future<void> Function(_Fixture f)? syncBehaviour;

  LogoutPreflight build({Duration timeout = const Duration(milliseconds: 50)}) => LogoutPreflight(
        pendingCount: () async => pending,
        isOnline: () async => online,
        sync: () async {
          syncCalls++;
          if (syncBehaviour != null) return syncBehaviour!(this);
          pending = 0;
        },
        timeout: timeout,
      );
}

void main() {
  group('plan', () {
    test('nothing queued: clean, whatever the connection', () async {
      for (final online in [true, false]) {
        final plan = await _Fixture(pending: 0, online: online).build().plan();
        expect(plan.isClean, isTrue);
        expect(plan.willUpload, isFalse);
        expect(plan.willLose, isFalse);
      }
    });

    test('queued and online: they will be uploaded first', () async {
      final plan = await _Fixture(pending: 3, online: true).build().plan();
      expect(plan.unsynced, 3);
      expect(plan.willUpload, isTrue);
      expect(plan.willLose, isFalse);
    });

    test('queued and offline: they will be lost, with the count', () async {
      final plan = await _Fixture(pending: 4, online: false).build().plan();
      expect(plan.unsynced, 4);
      expect(plan.willLose, isTrue);
      expect(plan.willUpload, isFalse);
    });
  });

  group('flush', () {
    test('online: the outbox is drained once before the wipe', () async {
      final f = _Fixture(pending: 5, online: true);
      final left = await f.build().flush();

      expect(f.syncCalls, 1);
      expect(left, 0);
    });

    test('offline: no upload is attempted and the changes stay counted', () async {
      final f = _Fixture(pending: 2, online: false);
      final left = await f.build().flush();

      expect(f.syncCalls, 0);
      expect(left, 2);
    });

    test('nothing queued: no network round trip at all', () async {
      final f = _Fixture(pending: 0, online: true);
      await f.build().flush();

      expect(f.syncCalls, 0);
    });

    test('a hanging upload is cut off by the timeout, and the logout can go on', () async {
      final f = _Fixture(pending: 2, online: true, syncBehaviour: (_) => Completer<void>().future);
      final left = await f.build(timeout: const Duration(milliseconds: 20)).flush();

      expect(f.syncCalls, 1);
      expect(left, 2);
    });

    test('a failing upload never throws out of the flush', () async {
      final f = _Fixture(pending: 1, online: true, syncBehaviour: (_) async => throw StateError('boom'));
      final left = await f.build().flush();

      expect(left, 1);
    });

    test('changes the server refused are reported as still queued', () async {
      final f = _Fixture(pending: 3, online: true, syncBehaviour: (f) async => f.pending = 1);
      expect(await f.build().flush(), 1);
    });
  });
}
