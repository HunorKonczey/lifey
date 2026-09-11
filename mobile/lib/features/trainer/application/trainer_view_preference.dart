import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _lastViewIsTrainerKey = 'trainer.lastViewIsTrainer';
const _introSeenKey = 'trainer.introSeen';

/// Device-local memory of which of the two shells the user last stood in
/// (docs/chat/41-trainer-mobile-v2-plan.md §2.1: "az utolsó választás
/// megjegyződik ... így az az edző, aki soha nem naplózik magának, nem lát
/// fölösleges lépést").
///
/// A plain non-secret flag, so `shared_preferences` rather than secure
/// storage — same call as `LocationPermissionPreferences`.
class TrainerViewPreference {
  Future<bool> lastViewWasTrainer() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_lastViewIsTrainerKey) ?? false;
  }

  Future<void> setLastViewWasTrainer(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_lastViewIsTrainerKey, value);
  }

  /// Whether the one-off "this is your trainer view" card has been shown.
  Future<bool> hasSeenIntro() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_introSeenKey) ?? false;
  }

  Future<void> setIntroSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_introSeenKey, true);
  }

  /// Fresh start for whoever logs into this device next — the same
  /// "per-account, not per-device" policy `AuthController.logout()` applies
  /// to the other device-local preferences.
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lastViewIsTrainerKey);
    await prefs.remove(_introSeenKey);
  }
}

final trainerViewPreferenceProvider =
    Provider<TrainerViewPreference>((ref) => TrainerViewPreference());

/// The stored flag, read once at startup so the router can consult it
/// *synchronously* when it picks its initial location. `app.dart` holds the
/// splash until this resolves, exactly as it already does for auth — without
/// that gate the app would land on the dashboard and then jump.
class LastViewIsTrainerController extends AsyncNotifier<bool> {
  @override
  Future<bool> build() => ref.read(trainerViewPreferenceProvider).lastViewWasTrainer();

  /// Records a switch. The in-memory value moves first: the next router
  /// redirect must not race the disk write.
  Future<void> set({required bool isTrainerView}) async {
    state = AsyncData(isTrainerView);
    await ref
        .read(trainerViewPreferenceProvider)
        .setLastViewWasTrainer(isTrainerView);
  }
}

final lastViewIsTrainerProvider =
    AsyncNotifierProvider<LastViewIsTrainerController, bool>(
  LastViewIsTrainerController.new,
);
