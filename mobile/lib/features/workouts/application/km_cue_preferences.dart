import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kmCueVibrationKey = 'cardio.kmCueVibration';
const _kmCueSoundKey = 'cardio.kmCueSound';

/// What the runner gets at each kilometre (docs/cardio/61 §2 M35).
class KmCueSettings {
  const KmCueSettings({required this.vibration, required this.sound});

  /// Vibration on, sound off: the cue that works with the phone in a pocket
  /// and doesn't interrupt anything. M35 lists "only vibration" as a state
  /// in its own right — this is it, and turning both off is equally valid.
  static const KmCueSettings defaults = KmCueSettings(vibration: true, sound: false);

  final bool vibration;
  final bool sound;

  bool get isSilent => !vibration && !sound;

  KmCueSettings copyWith({bool? vibration, bool? sound}) => KmCueSettings(
        vibration: vibration ?? this.vibration,
        sound: sound ?? this.sound,
      );
}

/// Device-local switches for the kilometre cue — same storage choice and same
/// reasoning as [AutoPausePreferences] next door (a plain, non-secret
/// `shared_preferences` flag, deliberately *not* cleared on logout: it's a
/// workout convenience a returning user expects to stay put).
///
/// Deliberately **not** a place to choose the unit: that comes from the
/// profile's `UserSettings.unitSystem`, and M35's own closing line is why —
/// a unit settable in two places is a guaranteed bug report.
class KmCuePreferences {
  Future<KmCueSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return KmCueSettings(
      vibration: prefs.getBool(_kmCueVibrationKey) ?? KmCueSettings.defaults.vibration,
      sound: prefs.getBool(_kmCueSoundKey) ?? KmCueSettings.defaults.sound,
    );
  }

  Future<void> setVibrationEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kmCueVibrationKey, enabled);
  }

  Future<void> setSoundEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kmCueSoundKey, enabled);
  }
}

final kmCuePreferencesProvider = Provider<KmCuePreferences>((ref) => KmCuePreferences());
