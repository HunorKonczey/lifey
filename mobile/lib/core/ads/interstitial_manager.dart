import 'dart:io' show Platform;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../features/workouts/application/workout_session_controller.dart';
import '../entitlements/entitlement_providers.dart';
import 'interstitial_ad_loader.dart';
import 'interstitial_preferences.dart';

/// Google's public **test** interstitial ad unit ids — distinct from the
/// banner ones in `banner_ad_slot.dart` and the app ids in `Info.plist`/
/// `AndroidManifest.xml` (`67` Prompt 8). Swap for the real per-platform ids
/// from the AdMob console before release.
String interstitialAdUnitId() => Platform.isIOS
    ? 'ca-app-pub-3940256099942544/4411468910'
    : 'ca-app-pub-3940256099942544/1033173712';

/// Where [InterstitialManager.maybeShow] is called from (`67` §5.3) —
/// "exactly two places", and only these.
enum InterstitialReason { mealLogged, workoutSaved }

/// The six eligibility conditions of `67` §5.3, all required — a pure
/// function so each can be tested independently of Riverpod, a real ad SDK,
/// or `shared_preferences`.
bool isInterstitialEligible({
  required bool adsEnabled,
  required bool hasActiveSession,
  required bool shownThisSession,
  required Duration foregroundDuration,
  required bool openedFromPush,
  required DateTime? lastShownAt,
  required DateTime now,
}) {
  if (!adsEnabled) return false;
  if (hasActiveSession) return false;
  if (shownThisSession) return false;
  if (foregroundDuration < InterstitialManager.minForegroundDuration) return false;
  if (openedFromPush) return false;
  if (lastShownAt != null && now.difference(lastShownAt) < InterstitialManager.minInterval) {
    return false;
  }
  return true;
}

/// `InterstitialManager.maybeShow(context, reason)` (`67` §5.3) — called
/// from exactly two places: after a meal is successfully logged
/// (`log_meal_screen.dart`) and after a workout session is successfully
/// saved (`log_session_screen.dart`, `cardio_session_screen.dart`).
///
/// Watched once at app root (`LifeyApp`), same as `EntitlementRefresher` —
/// its `WidgetsBindingObserver` is what tracks "foregrounded for ≥ 60 s"
/// (reset on every fresh resume, so a cold start's very first frame is
/// always exactly 0s in) and clears the push-origin flag on the same
/// transition. [markOpenedFromPush] is called by `PushTapHandler`.
class InterstitialManager with WidgetsBindingObserver {
  InterstitialManager(
    this._ref, {
    InterstitialAdLoader? loader,
    DateTime Function()? now,
  })  : _loader = loader ?? PlatformInterstitialAdLoader(),
        _now = now ?? DateTime.now {
    WidgetsBinding.instance.addObserver(this);
    _foregroundedAt = _now();
  }

  static const minForegroundDuration = Duration(seconds: 60);
  static const minInterval = Duration(hours: 4);

  final Ref _ref;
  final InterstitialAdLoader _loader;
  final DateTime Function() _now;

  late DateTime _foregroundedAt;

  /// In-memory only, deliberately — see `67` §5.3's "not already shown this
  /// app session" condition, distinct from the persisted rate limit below.
  bool _shownThisSession = false;

  bool _openedFromPush = false;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _foregroundedAt = _now();
      // A push tap that brought the app forward only suppresses the very
      // session it opened — a normal return to the app later still allows
      // an interstitial.
      _openedFromPush = false;
    }
  }

  void markOpenedFromPush() => _openedFromPush = true;

  void dispose() => WidgetsBinding.instance.removeObserver(this);

  bool get _hasActiveSession =>
      (_ref.read(workoutSessionControllerProvider).value ?? const []).any((s) => s.inProgress);

  Future<void> maybeShow(BuildContext context, InterstitialReason reason) async {
    final lastShownAt = await _ref.read(interstitialPreferencesProvider).lastShownAt();
    final now = _now();

    final eligible = isInterstitialEligible(
      adsEnabled: _ref.read(adsEnabledProvider),
      hasActiveSession: _hasActiveSession,
      shownThisSession: _shownThisSession,
      foregroundDuration: now.difference(_foregroundedAt),
      openedFromPush: _openedFromPush,
      lastShownAt: lastShownAt,
      now: now,
    );
    if (!eligible) return;

    final loaded = await _loader.load(interstitialAdUnitId(), const AdRequest());
    if (loaded == null || !context.mounted) return;

    _shownThisSession = true;
    await _ref.read(interstitialPreferencesProvider).markShown(now);
    await loaded.show();
  }
}

final interstitialManagerProvider = Provider<InterstitialManager>((ref) {
  final manager = InterstitialManager(ref);
  ref.onDispose(manager.dispose);
  return manager;
});
