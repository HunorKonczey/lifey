import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/location/location_service.dart';

void main() {
  group('LocationAvailability.canTrack', () {
    test('true only when granted, precise, and the device service is enabled', () {
      const ok = LocationAvailability(
        authorization: LocationAuthorization.granted,
        precise: true,
        serviceEnabled: true,
      );
      expect(ok.canTrack, isTrue);
    });

    test('false when not granted', () {
      const notGranted = LocationAvailability(
        authorization: LocationAuthorization.denied,
        precise: true,
        serviceEnabled: true,
      );
      expect(notGranted.canTrack, isFalse);
    });

    test('false when only approximate location was granted (iOS §3.2)', () {
      const approximate = LocationAvailability(
        authorization: LocationAuthorization.granted,
        precise: false,
        serviceEnabled: true,
      );
      expect(approximate.canTrack, isFalse);
    });

    test('false when device-wide Location Services is off', () {
      const serviceOff = LocationAvailability(
        authorization: LocationAuthorization.granted,
        precise: true,
        serviceEnabled: false,
      );
      expect(serviceOff.canTrack, isFalse);
    });
  });

  group('LocationServiceStub — availability', () {
    test('currentAvailability() starts at the given initial value', () async {
      final service = LocationServiceStub(
        initial: const LocationAvailability(
          authorization: LocationAuthorization.deniedForever,
          precise: true,
          serviceEnabled: true,
        ),
      );
      expect((await service.currentAvailability()).authorization, LocationAuthorization.deniedForever);
    });

    test('requestPermission() from notDetermined moves to granted', () async {
      final service = LocationServiceStub();
      final result = await service.requestPermission();
      expect(result.authorization, LocationAuthorization.granted);
    });

    test('requestPermission() from denied (askable again) moves to granted', () async {
      final service = LocationServiceStub(
        initial: const LocationAvailability(
          authorization: LocationAuthorization.denied,
          precise: true,
          serviceEnabled: true,
        ),
      );
      final result = await service.requestPermission();
      expect(result.authorization, LocationAuthorization.granted);
    });

    test('requestPermission() from deniedForever does not silently grant (system dialog no longer shows)', () async {
      final service = LocationServiceStub(
        initial: const LocationAvailability(
          authorization: LocationAuthorization.deniedForever,
          precise: true,
          serviceEnabled: true,
        ),
      );
      final result = await service.requestPermission();
      expect(result.authorization, LocationAuthorization.deniedForever);
    });

    test('availability replays the current snapshot to a subscriber that joins after a change', () async {
      final service = LocationServiceStub();
      service.emitAvailability(const LocationAvailability(
        authorization: LocationAuthorization.deniedForever,
        precise: true,
        serviceEnabled: true,
      ));

      // Subscribes only now — after the emit above already happened.
      final first = await service.availability.first;
      expect(first.authorization, LocationAuthorization.deniedForever);
    });

    test('availability pushes every subsequent emitAvailability() to an active subscriber', () async {
      final service = LocationServiceStub();
      final events = <LocationAuthorization>[];
      final sub = service.availability.listen((a) => events.add(a.authorization));
      addTearDown(sub.cancel);

      // Let the initial replay deliver before pushing more.
      await Future<void>.delayed(Duration.zero);

      service.emitAvailability(const LocationAvailability(
        authorization: LocationAuthorization.denied,
        precise: true,
        serviceEnabled: true,
      ));
      service.emitAvailability(const LocationAvailability(
        authorization: LocationAuthorization.granted,
        precise: true,
        serviceEnabled: true,
      ));
      await Future<void>.delayed(Duration.zero);

      expect(events, [
        LocationAuthorization.notDetermined, // the initial replay
        LocationAuthorization.denied,
        LocationAuthorization.granted,
      ]);
    });

    test('refresh() re-emits the current value even when nothing changed', () async {
      final service = LocationServiceStub();
      final events = <LocationAvailability>[];
      final sub = service.availability.skip(1).listen(events.add);
      addTearDown(sub.cancel);

      await service.refresh();
      await Future<void>.delayed(Duration.zero);

      expect(events, hasLength(1));
      expect(events.single.authorization, LocationAuthorization.notDetermined);
    });
  });

  group('LocationServiceStub — positionStream', () {
    test('delivers fixes pushed via emitFix() to an active subscriber', () async {
      final service = LocationServiceStub();
      final fixes = <LocationFix>[];
      final sub = service
          .positionStream(profile: LocationTrackingProfile.precise)
          .listen(fixes.add);
      addTearDown(sub.cancel);

      final now = DateTime(2026, 8, 12, 7, 0);
      service.emitFix(LocationFix(latitude: 47.5, longitude: 19.05, recordedAt: now));
      await Future<void>.delayed(Duration.zero);

      expect(fixes, hasLength(1));
      expect(fixes.single.latitude, 47.5);
      expect(fixes.single.longitude, 19.05);
      expect(fixes.single.recordedAt, now);
    });

    test('a fix with no altitude/accuracy/speed keeps them null, not a 0.0 sentinel', () async {
      final service = LocationServiceStub();
      LocationFix? received;
      final sub = service
          .positionStream(profile: LocationTrackingProfile.relaxed)
          .listen((fix) => received = fix);
      addTearDown(sub.cancel);

      service.emitFix(LocationFix(latitude: 0, longitude: 0, recordedAt: DateTime.now()));
      await Future<void>.delayed(Duration.zero);

      expect(received!.altitude, isNull);
      expect(received!.accuracy, isNull);
      expect(received!.speed, isNull);
    });
  });

  group('LocationServiceStub — settings shortcuts', () {
    test('openAppSettings()/openLocationSettings() no-op successfully', () async {
      final service = LocationServiceStub();
      expect(await service.openAppSettings(), isTrue);
      expect(await service.openLocationSettings(), isTrue);
    });
  });
}
