import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/settings_repository.dart';
import '../domain/user_settings.dart';

/// Streams the signed-in user's settings from the local cache.
///
/// NOTE: the local cache isn't currently scoped per signed-in user — if a
/// second account ever logs in on the same device, it would see the first
/// account's cached settings until something overwrites them. Today the app
/// is effectively single-user-per-device, but if multi-account-per-device
/// support is ever needed, clearing (or partitioning) the local db on logout
/// has to be added — see AuthController.logout().
class SettingsController extends StreamNotifier<UserSettings> {
  SettingsRepository get _repo => ref.read(settingsRepositoryProvider);

  @override
  Stream<UserSettings> build() => _repo.watch();

  Future<void> save(UserSettings settings) => _repo.save(settings);
}

final settingsControllerProvider =
    StreamNotifierProvider<SettingsController, UserSettings>(SettingsController.new);
