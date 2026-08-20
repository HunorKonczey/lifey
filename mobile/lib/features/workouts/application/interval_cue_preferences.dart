import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _intervalCueVibrationKey = 'cardio.intervalCueVibration';
const _intervalCueSoundKey = 'cardio.intervalCueSound';

/// What the rider gets at a section change (docs/cardio/60 Q-D4, decided
/// 2026-08-17: "legyen, kikapcsolhatóan").
class IntervalCueSettings {
  const IntervalCueSettings({required this.vibration, required this.sound});

  /// Vibration on, sound off — the same default as the kilometre cue, and for
  /// the same reason: a buzz works with the phone clipped to the handlebars
  /// and interrupts nothing. On a bike the sound matters more than on a run
  /// (music is usually playing and the bar mount swallows the buzz), which is
  /// exactly why it's a switch rather than a decision made here.
  static const IntervalCueSettings defaults =
      IntervalCueSettings(vibration: true, sound: false);

  final bool vibration;
  final bool sound;

  IntervalCueSettings copyWith({bool? vibration, bool? sound}) => IntervalCueSettings(
        vibration: vibration ?? this.vibration,
        sound: sound ?? this.sound,
      );
}

/// Device-local switches for the interval player's section-change cue — same
/// storage choice and same reasoning as [KmCuePreferences] next door.
class IntervalCuePreferences {
  Future<IntervalCueSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return IntervalCueSettings(
      vibration:
          prefs.getBool(_intervalCueVibrationKey) ?? IntervalCueSettings.defaults.vibration,
      sound: prefs.getBool(_intervalCueSoundKey) ?? IntervalCueSettings.defaults.sound,
    );
  }

  Future<void> setVibrationEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_intervalCueVibrationKey, enabled);
  }

  Future<void> setSoundEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_intervalCueSoundKey, enabled);
  }
}

final intervalCuePreferencesProvider =
    Provider<IntervalCuePreferences>((ref) => IntervalCuePreferences());

/// Which plan a given ride is playing back.
///
/// Device-local and deliberately *not* a column on the session: no session
/// ever references a plan (docs/cardio/60 D-C7.1), and this is a continuation
/// detail of one screen — what the live screen needs to resume the right
/// section after an app kill, nothing anyone else reads. The executed
/// sections themselves are what gets persisted and synced, as INTERVAL
/// splits.
class IntervalPlanSessionMemory {
  static String _key(String sessionClientId) => 'cardio.intervalPlan.$sessionClientId';

  Future<void> remember(String sessionClientId, String planClientId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(sessionClientId), planClientId);
  }

  Future<String?> planFor(String sessionClientId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key(sessionClientId));
  }

  /// Called when the ride ends — the plan has done its job, and the splits it
  /// produced are already on the session.
  Future<void> forget(String sessionClientId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(sessionClientId));
  }
}

final intervalPlanSessionMemoryProvider =
    Provider<IntervalPlanSessionMemory>((ref) => IntervalPlanSessionMemory());
