import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _ownerUserIdKey = 'localData.ownerUserId';

/// Remembers which account the on-device data (the Drift cache, its outbox,
/// and the per-account preferences) belongs to.
///
/// `AuthController.logout()` wipes all of that, but a session can also end
/// *without* a logout: a failed token refresh only clears the tokens, so the
/// previous account's cache — and its still-unsynced outbox rows — used to be
/// inherited by whichever account signed in next, and those rows were then
/// pushed under the new account's token. Wiping on session expiry instead
/// would throw away the same user's offline edits every time their refresh
/// token lapsed, so the decision is deferred to the next sign-in, where the
/// incoming user id is known.
///
/// A plain non-secret id, so `shared_preferences` — same call as
/// `TrainerViewPreference`.
class LocalDataOwner {
  Future<int?> read() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_ownerUserIdKey);
  }

  Future<void> write(int userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_ownerUserIdKey, userId);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_ownerUserIdKey);
  }
}

final localDataOwnerProvider = Provider<LocalDataOwner>((ref) => LocalDataOwner());

/// Decides, at sign-in, whether the local data may be kept for [userId].
class LocalDataGuard {
  LocalDataGuard(this._owner, this._wipe);

  final LocalDataOwner _owner;

  /// Clears every piece of per-account local state. Must not touch the
  /// token pair — the caller saves the new one after [claim] returns.
  final Future<void> Function() _wipe;

  /// Makes [userId] the owner of the local data, wiping it first unless it
  /// already belongs to them. Returns whether a wipe happened.
  ///
  /// Must run *before* the new tokens are saved: the sync engine only drains
  /// while a token exists, so this is the last moment the previous owner's
  /// outbox can be dropped without it going out under [userId]'s account.
  ///
  /// [adoptUnowned] covers a cold start that is already signed in on an
  /// install predating this guard: there the data can only be this user's,
  /// so it is adopted rather than wiped. A fresh sign-in never adopts —
  /// unowned data there is exactly the orphan of an expired session.
  Future<bool> claim(int userId, {bool adoptUnowned = false}) async {
    final current = await _owner.read();
    if (current == userId) return false;
    if (current == null && adoptUnowned) {
      await _owner.write(userId);
      return false;
    }
    await _wipe();
    await _owner.write(userId);
    return true;
  }

  /// Called on logout, after the wipe — nobody owns an empty cache.
  Future<void> release() => _owner.clear();
}
