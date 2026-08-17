import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _gameFormatKey = 'cardio.gameFormat';
const _gameVenueKey = 'cardio.gameVenue';
const _gameGpsKey = 'cardio.gameGps';

/// The formats a match can be logged as (docs/cardio/61 §5 M45). Free-text
/// codes on the wire (`cardio_details.game_format` is a `varchar`), so a
/// future format needs no migration — this enum is only the set the picker
/// offers today.
enum GameFormat {
  fiveVsFive('5V5'),
  smallSided('SMALL_SIDED'),
  practice('PRACTICE'),
  match('MATCH');

  const GameFormat(this.code);

  /// What lands in `cardio_details.game_format`.
  final String code;

  static GameFormat? fromCode(String? code) {
    for (final format in values) {
      if (format.code == code) return format;
    }
    return null;
  }
}

/// What the setup sheet starts pre-filled with.
class GameSetup {
  const GameSetup({required this.format, required this.venue, this.gpsEnabled = false});

  /// M45's own rule: **the sheet never blocks the start**, so every field has
  /// a default and "Start" works on the first tap. The very first match ever
  /// defaults to a 5v5 indoors — the most common case, and both are one tap
  /// from anything else.
  static const GameSetup defaults = GameSetup(format: GameFormat.fiveVsFive, venue: 'INDOOR');

  final GameFormat format;

  /// `INDOOR` or `OUTDOOR`. Stored as the same string the backend's
  /// `cardio_details_venue_ck` constraint checks.
  final String venue;

  /// **Opt-in, and only outdoors** (C9.4). Indoors there is nothing for GPS to
  /// record and no reason to ask for the permission, so the toggle doesn't
  /// exist there rather than sitting switched off — see [recordsDistance].
  final bool gpsEnabled;

  bool get isOutdoor => venue == 'OUTDOOR';

  /// The single question the live screen asks. Indoors it is always false, so
  /// a stale "on" left over from an outdoor match can never start a GPS
  /// subscription in a hall.
  bool get recordsDistance => isOutdoor && gpsEnabled;

  GameSetup copyWith({GameFormat? format, String? venue, bool? gpsEnabled}) => GameSetup(
        format: format ?? this.format,
        venue: venue ?? this.venue,
        gpsEnabled: gpsEnabled ?? this.gpsEnabled,
      );
}

/// Remembers the **last** format/venue a match was started with, which is
/// what makes M45's "the sheet doesn't block you" true in practice: someone
/// who plays the same 5v5 in the same hall every week taps Start and nothing
/// else, forever.
///
/// Same storage choice and reasoning as its neighbours in this folder — a
/// plain, non-secret `shared_preferences` value, not cleared on logout.
class GameSetupPreferences {
  Future<GameSetup> load() async {
    final prefs = await SharedPreferences.getInstance();
    return GameSetup(
      format: GameFormat.fromCode(prefs.getString(_gameFormatKey)) ?? GameSetup.defaults.format,
      venue: prefs.getString(_gameVenueKey) ?? GameSetup.defaults.venue,
      gpsEnabled: prefs.getBool(_gameGpsKey) ?? GameSetup.defaults.gpsEnabled,
    );
  }

  Future<void> save(GameSetup setup) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_gameFormatKey, setup.format.code);
    await prefs.setString(_gameVenueKey, setup.venue);
    await prefs.setBool(_gameGpsKey, setup.gpsEnabled);
  }
}

final gameSetupPreferencesProvider =
    Provider<GameSetupPreferences>((ref) => GameSetupPreferences());
