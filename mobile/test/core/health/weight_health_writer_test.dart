import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';
import 'package:lifey/core/health/health_preferences.dart';
import 'package:lifey/core/health/health_service.dart';
import 'package:lifey/core/health/weight_health_writer.dart';

/// Copying a logged weigh-in to Apple Health / Health Connect (LIF-109): only when the integration is on, only the user's own
/// entry, and never an error for the weigh-in.
class _Prefs extends HealthPreferences {
  _Prefs({required this.enabled}) : super(const FlutterSecureStorage());

  final bool enabled;

  @override
  Future<bool> isEnabled() async => enabled;
}

class _Service extends HealthService {
  _Service({this.available = true, this.canWrite = true, this.throwOnWrite = false, this.writeResult = true});

  final bool available;
  final bool canWrite;
  final bool throwOnWrite;
  final bool writeResult;
  final writes = <({double kg, DateTime at})>[];

  @override
  bool get isAvailable => available;

  @override
  Future<bool> canWriteBodyMass() async => canWrite;

  @override
  Future<bool> writeBodyMass({required double kg, required DateTime at}) async {
    if (throwOnWrite) throw StateError('store gone');
    writes.add((kg: kg, at: at));
    return writeResult;
  }
}

void main() {
  final at = DateTime(2026, 10, 11, 7, 30);

  group('WeightHealthWriter', () {
    test('writes the weight and the time of the entry when the integration is on', () async {
      final service = _Service();

      final written = await WeightHealthWriter(_Prefs(enabled: true), service).write(kg: 82.4, at: at);

      expect(written, isTrue);
      expect(service.writes.single.kg, 82.4);
      expect(service.writes.single.at, at);
    });

    test('writes nothing when the user has not connected Health', () async {
      final service = _Service();

      final written = await WeightHealthWriter(_Prefs(enabled: false), service).write(kg: 82.4, at: at);

      expect(written, isFalse);
      expect(service.writes, isEmpty);
    });

    test('writes nothing where there is no health store', () async {
      final service = _Service(available: false);

      expect(await WeightHealthWriter(_Prefs(enabled: true), service).write(kg: 82.4, at: at), isFalse);
      expect(service.writes, isEmpty);
    });

    test('a store that throws, or refuses, is an answer of false - never an error', () async {
      expect(await WeightHealthWriter(_Prefs(enabled: true), _Service(throwOnWrite: true)).write(kg: 82.4, at: at), isFalse);
      expect(await WeightHealthWriter(_Prefs(enabled: true), _Service(writeResult: false)).write(kg: 82.4, at: at), isFalse);
    });
  });

  group('healthWeightWriteAvailableProvider', () {
    Future<bool> available({bool enabled = true, bool available = true, bool canWrite = true}) async {
      final container = ProviderContainer(overrides: [
        healthPreferencesProvider.overrideWithValue(_Prefs(enabled: enabled)),
        healthServiceProvider.overrideWithValue(_Service(available: available, canWrite: canWrite)),
      ]);
      addTearDown(container.dispose);
      return container.read(healthWeightWriteAvailableProvider.future);
    }

    test('needs the integration on and the write permission', () async {
      expect(await available(), isTrue);
      expect(await available(enabled: false), isFalse);
      // An install from before the write path only ever asked for READ.
      expect(await available(canWrite: false), isFalse);
      expect(await available(available: false), isFalse);
    });
  });

  test('the integration reads everything and writes body weight only', () {
    expect(healthDataAccess, hasLength(healthDataTypes.length), reason: 'the plugin demands one access per type');
    for (final (i, type) in healthDataTypes.indexed) {
      expect(
        healthDataAccess[i],
        type == HealthDataType.WEIGHT ? HealthDataAccess.READ_WRITE : HealthDataAccess.READ,
        reason: type.name,
      );
    }
  });
}
