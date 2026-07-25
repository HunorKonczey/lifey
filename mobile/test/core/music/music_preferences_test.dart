import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/music/music_preferences.dart';
import 'package:lifey/core/music/music_provider_id.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('selectedProvider is null before anything is chosen', () async {
    final prefs = MusicPreferences();
    expect(await prefs.selectedProvider(), isNull);
  });

  test('setSelectedProvider persists the choice, read back by a new instance', () async {
    await MusicPreferences().setSelectedProvider(MusicProviderId.spotify);

    final selected = await MusicPreferences().selectedProvider();
    expect(selected, MusicProviderId.spotify);
  });

  test('choosing a different provider overwrites the previous one', () async {
    final prefs = MusicPreferences();
    await prefs.setSelectedProvider(MusicProviderId.spotify);
    await prefs.setSelectedProvider(MusicProviderId.appleMusic);

    expect(await prefs.selectedProvider(), MusicProviderId.appleMusic);
  });

  test('clear removes the stored choice', () async {
    final prefs = MusicPreferences();
    await prefs.setSelectedProvider(MusicProviderId.youtubeMusic);
    await prefs.clear();

    expect(await prefs.selectedProvider(), isNull);
  });
}
