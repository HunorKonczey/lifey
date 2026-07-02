import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/settings_repository.dart';
import '../domain/user_settings.dart';

/// Streams the signed-in user's settings from the local cache.
///
/// The local cache still isn't scoped per signed-in user (it uses a single
/// singleton row/tables rather than partitioning by account), but
/// `AuthController.logout()` wipes the whole local database on sign-out, so a
/// second account signing in on the same device starts from an empty cache
/// instead of inheriting the first account's data.
class SettingsController extends StreamNotifier<UserSettings> {
  SettingsRepository get _repo => ref.read(settingsRepositoryProvider);

  @override
  Stream<UserSettings> build() => _repo.watch();

  Future<void> save(UserSettings settings) => _repo.save(settings);
}

final settingsControllerProvider =
    StreamNotifierProvider<SettingsController, UserSettings>(SettingsController.new);
