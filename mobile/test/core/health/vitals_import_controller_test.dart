import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/health/health_preferences.dart';
import 'package:lifey/core/health/health_service.dart';
import 'package:lifey/core/health/vitals_health_importer.dart';
import 'package:lifey/core/health/vitals_import_controller.dart';
import 'package:lifey/core/local_db/app_database.dart';
import 'package:lifey/core/sync/outbox_writer.dart';
import 'package:lifey/core/sync/sync_engine.dart';
import 'package:lifey/features/vitals/data/daily_vitals_repository.dart';

/// docs/integrations/89 G3.3 (D-G5): turning the vitals import on asks for the
/// resting-HR and HRV permissions and imports right away; turning it off only stops future
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
    importer = _Importer(prefs, service, DailyVitalsRepository(db, OutboxWriter(db, _NoopSyncEngine(db, Dio()))));
    container = ProviderContainer(overrides: [
      healthPreferencesProvider.overrideWithValue(prefs),
      healthServiceProvider.overrideWithValue(service),
      vitalsHealthImporterProvider.overrideWithValue(importer),
    ]);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  test('starts from the stored opt-in, off by default', () async {
    expect((await container.read(vitalsImportControllerProvider.future)).enabled, isFalse);
  });

  test('turning it on stores the opt-in, asks for the vitals permissions and imports at once', () async {
    await container.read(vitalsImportControllerProvider.future);

    await container.read(vitalsImportControllerProvider.notifier).setEnabled(true);

    expect(prefs.vitalsEnabled, isTrue);
    expect(service.permissionRequests, 1);
    expect(importer.runs, 1);
    expect(container.read(vitalsImportControllerProvider).value!.enabled, isTrue);
  });

  test('turning it off asks for nothing and imports nothing', () async {
    prefs.vitalsEnabled = true;
    await container.read(vitalsImportControllerProvider.future);

    await container.read(vitalsImportControllerProvider.notifier).setEnabled(false);

    expect(prefs.vitalsEnabled, isFalse);
    expect(service.permissionRequests, 0);
    expect(importer.runs, 0);
  });

  test('a permission Health Connect reports as revoked shows as missing', () async {
    prefs.vitalsEnabled = true;
    service.granted = false;

    expect((await container.read(vitalsImportControllerProvider.future)).permissionMissing, isTrue);
  });
}

class _Prefs extends HealthPreferences {
  _Prefs() : super(const FlutterSecureStorage());

  bool vitalsEnabled = false;

  @override
  Future<bool> isVitalsImportEnabled() async => vitalsEnabled;

  @override
  Future<void> setVitalsImportEnabled(bool enabled) async => vitalsEnabled = enabled;
}

class _Service extends HealthService {
  int permissionRequests = 0;
  bool? granted;

  @override
  bool get isAvailable => true;

  @override
  Future<bool> requestVitalsImportPermissions() async {
    permissionRequests++;
    return true;
  }

  @override
  Future<bool?> hasVitalsImportPermissions() async => granted;
}

class _Importer extends VitalsHealthImporter {
  _Importer(HealthPreferences prefs, HealthService service, DailyVitalsRepository vitals)
      : super(prefs: prefs, service: service, vitals: vitals);

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
