import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/location/location_service.dart';
import 'package:lifey/core/location/location_service_geolocator.dart';

void main() {
  test('locationServiceProvider resolves to the stub on a non-Android/iOS test run', () {
    // Mirrors music_controller_test.dart's reliance on musicServiceProvider
    // resolving to MusicServiceStub the same way — flutter test never
    // reports Platform.isAndroid/isIOS true, so this is what every widget
    // test that reads locationServiceProvider gets for free.
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final service = container.read(locationServiceProvider);
    expect(service, isA<LocationServiceStub>());
  });
}
