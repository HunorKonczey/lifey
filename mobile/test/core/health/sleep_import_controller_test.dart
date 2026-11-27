import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/health/health_preferences.dart';
import 'package:lifey/core/health/health_service.dart';
import 'package:lifey/core/health/sleep_health_importer.dart';
import 'package:lifey/core/health/sleep_import_controller.dart';
import 'package:lifey/core/local_db/app_database.dart';
import 'package:lifey/core/sync/outbox_writer.dart';
import 'package:lifey/core/sync/sync_engine.dart';
import 'package:lifey/features/sleep/data/sleep_session_repository.dart';

/// docs/integrations/89 G2.4 (D-G5): turning the sleep import on asks for the
/// sleep permissions and imports right away; turning it off only stops future
/// imports; a revoked Health Connect permission is reported.
void main() {
  late AppDatabase db;
  late _Prefs prefs;
  late _Service service;
  late _Importer importer;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    prefs = _Prefs();
    service = _Service();
    importer = _Importer(prefs, service, SleepSessionRepository(db, OutboxWriter(db, _NoopSyncEngine(db, Dio()))));
    container = ProviderContainer(overrides: [
      healthPreferencesProvider.overrideWithValue(prefs),
      healthServiceProvider.overrideWithValue(service),
      sleepHealthImporterProvider.overrideWithValue(importer),
    ]);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  test('starts from the stored opt-in, off by default', () async {
    expect((await container.read(sleepImportControllerProvider.future)).enabled, isFalse);
  });

  test('turning it on stores the opt-in, asks for the sleep permissions and imports at once', () async {
    await container.read(sleepImportControllerProvider.future);

    await container.read(sleepImportControllerProvider.notifier).setEnabled(true);

    expect(prefs.sleepEnabled, isTrue);
    expect(service.permissionRequests, 1);
    expect(importer.runs, 1);
    expect(container.read(sleepImportControllerProvider).value!.enabled, isTrue);
  });

  test('turning it off asks for nothing and imports nothing', () async {
    prefs.sleepEnabled = true;
    await container.read(sleepImportControllerProvider.future);

    await container.read(sleepImportControllerProvider.notifier).setEnabled(false);

    expect(prefs.sleepEnabled, isFalse);
    expect(service.permissionRequests, 0);
    expect(importer.runs, 0);
  });

  test('a permission Health Connect reports as revoked shows as missing', () async {
    prefs.sleepEnabled = true;
    service.granted = false;

    expect((await container.read(sleepImportControllerProvider.future)).permissionMissing, isTrue);
  });
}

class _Prefs extends HealthPreferences {
  _Prefs() : super(const FlutterSecureStorage());

  bool sleepEnabled = false;

  @override
  Future<bool> isSleepImportEnabled() async => sleepEnabled;

  @override
  Future<void> setSleepImportEnabled(bool enabled) async => sleepEnabled = enabled;
}

class _Service extends HealthService {
  int permissionRequests = 0;
  bool? granted;

  @override
  bool get isAvailable => true;

  @override
  Future<bool> requestSleepImportPermissions() async {
    permissionRequests++;
    return true;
  }

  @override
  Future<bool?> hasSleepImportPermissions() async => granted;
}

class _Importer extends SleepHealthImporter {
  _Importer(HealthPreferences prefs, HealthService service, SleepSessionRepository sessions)
      : super(prefs: prefs, service: service, sessions: sessions);

  int runs = 0;

  @override
  Future<int> import() async {
    runs++;
    return 0;
  }
}

class _NoopSyncEngine extends SyncEngine {
  _NoopSyncEngine(super.db, super.dio);

  @override
  Future<void> sync() async {}
}
