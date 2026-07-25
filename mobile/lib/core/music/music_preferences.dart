import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'music_provider_id.dart';

const _providerKey = 'workout_music_provider';

/// Device-local choice of which music app the workout screen controls
/// (docs/music/46-workout-music-controls-plan.md §3.1).
///
/// Deliberately NOT part of the synced `UserSettings`: installed music apps
/// differ per device (Apple Music is rare on Android, YouTube Music can't be
/// controlled at all on iOS — see [MusicProviderIdX.isSupportedOnThisPlatform]),
/// so a choice that made sense on one device could be meaningless or wrong on
/// another. This is the one case in the app where the "per-device, not
/// synced" reasoning behind `WeighInReminderPreferences`/`HealthPreferences`
/// runs in the opposite direction of `UserSettings.defaultRestSeconds` et al.
/// Uses `shared_preferences`, matching `RecapPreferences` — a plain
/// non-secret per-device choice, not worth secure storage.
class MusicPreferences {
  Future<MusicProviderId?> selectedProvider() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_providerKey);
    if (raw == null) return null;
    return MusicProviderId.values.asNameMap()[raw];
  }

  Future<void> setSelectedProvider(MusicProviderId provider) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_providerKey, provider.name);
  }

  /// Clears the device-local choice on logout, so a different account
  /// signing in on this device doesn't inherit it.
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_providerKey);
  }
}

final musicPreferencesProvider = Provider<MusicPreferences>((ref) => MusicPreferences());
