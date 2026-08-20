import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _boxScoreOfferKey = 'cardio.boxScoreOffer';

/// Whether the one-time "shall we keep your box score?" offer has been
/// answered (docs/cardio/60 Q-D2, docs/cardio/61 §5 M44).
enum BoxScoreOffer {
  /// Never shown yet — the live GAME screen offers it once.
  unanswered,

  /// Accepted: the stepper opens on its own the first time, and the offer
  /// never returns.
  accepted,

  /// Declined. M44's promise is literal — "**Ha nem érdekel, többé nem
  /// kérdezzük**" — so this is permanent. The `Box` button stays available
  /// for someone who changes their mind (M44's hidden default state is "only
  /// the Box circle shows"), but nothing ever asks again.
  declined,
}

/// Device-local memory of that one question. Same storage and same reasoning
/// as [AutoPausePreferences]/[KmCuePreferences] next door: a plain,
/// non-secret `shared_preferences` value, deliberately not cleared on logout —
/// re-asking a returning user a question they already answered "no" to is
/// exactly what "többé nem kérdezzük" rules out.
class BoxScorePreferences {
  Future<BoxScoreOffer> offerState() async {
    final prefs = await SharedPreferences.getInstance();
    return switch (prefs.getString(_boxScoreOfferKey)) {
      'accepted' => BoxScoreOffer.accepted,
      'declined' => BoxScoreOffer.declined,
      _ => BoxScoreOffer.unanswered,
    };
  }

  Future<void> setOfferState(BoxScoreOffer state) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_boxScoreOfferKey, state.name);
  }
}

final boxScorePreferencesProvider =
    Provider<BoxScorePreferences>((ref) => BoxScorePreferences());
