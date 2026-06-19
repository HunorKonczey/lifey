import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../data/settings_repository.dart';
import '../domain/user_settings.dart';

/// Loads and updates the signed-in user's settings. Resolves to in-memory
/// defaults (no API call) while signed out, and reloads from the server
/// whenever the signed-in user changes.
class SettingsController extends AsyncNotifier<UserSettings> {
  SettingsRepository get _repo => ref.read(settingsRepositoryProvider);

  @override
  Future<UserSettings> build() async {
    final user = ref.watch(authControllerProvider).value;
    if (user == null) return const UserSettings.defaults();
    return _repo.fetch();
  }

  Future<void> save(UserSettings settings) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _repo.update(settings));
  }
}

final settingsControllerProvider =
    AsyncNotifierProvider<SettingsController, UserSettings>(SettingsController.new);
