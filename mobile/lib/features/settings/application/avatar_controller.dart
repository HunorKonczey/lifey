import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/avatar_repository.dart';

/// Holds the signed-in user's profile picture bytes (null if none set).
/// Upload/remove are online-only — errors propagate to the caller so the
/// Settings screen can show its usual error snackbar (see
/// docs/22-profile-picture-plan.md).
class AvatarController extends AsyncNotifier<Uint8List?> {
  AvatarRepository get _repo => ref.read(avatarRepositoryProvider);

  @override
  Future<Uint8List?> build() => _repo.fetch();

  Future<void> upload(File imageFile) async {
    final bytes = await _repo.upload(imageFile);
    state = AsyncData(bytes);
  }

  Future<void> remove() async {
    await _repo.delete();
    state = const AsyncData(null);
  }
}

final avatarControllerProvider =
    AsyncNotifierProvider<AvatarController, Uint8List?>(AvatarController.new);
