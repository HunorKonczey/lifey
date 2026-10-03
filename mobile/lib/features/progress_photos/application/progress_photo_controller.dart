import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/progress_photo_repository.dart';
import '../domain/progress_photo.dart';

/// The timeline, newest first (the server's order). Online-only: a failed
/// load surfaces as an [AsyncError] and the screen offers a retry (docs/80
/// §2.1, §5). Held in memory for the session; logout invalidates it (`AuthController`).
class ProgressPhotoController extends AsyncNotifier<List<ProgressPhoto>> {
  ProgressPhotoRepository get _repo => ref.read(progressPhotoRepositoryProvider);

  @override
  Future<List<ProgressPhoto>> build() => _repo.list();

  Future<void> refresh() async {
    state = await AsyncValue.guard(_repo.list);
  }

  /// Uploads and puts the new photo into the list in its date position,
  /// without a second round trip. Errors propagate so the sheet can show them.
  Future<ProgressPhoto> add(
    File file, {
    required DateTime takenOn,
    required PhotoPose pose,
    String? note,
  }) async {
    final photo = await _repo.upload(file, takenOn: takenOn, pose: pose, note: note);
    _put(photo);
    return photo;
  }

  Future<void> edit(ProgressPhoto photo, {required DateTime takenOn, required PhotoPose pose, String? note}) async {
    final updated = await _repo.update(photo.id, takenOn: takenOn, pose: pose, note: note);
    _put(updated);
  }

  Future<void> remove(int id) async {
    await _repo.delete(id);
    final current = state.value;
    if (current != null) state = AsyncData([for (final p in current) if (p.id != id) p]);
  }

  /// Inserts or replaces [photo], keeping the server's ordering: newest
  /// `takenOn` first, ties broken by newest id.
  void _put(ProgressPhoto photo) {
    final current = state.value ?? const <ProgressPhoto>[];
    final next = [for (final p in current) if (p.id != photo.id) p, photo]
      ..sort((a, b) {
        final byDate = b.takenOn.compareTo(a.takenOn);
        return byDate != 0 ? byDate : b.id.compareTo(a.id);
      });
    state = AsyncData(next);
  }
}

final progressPhotoControllerProvider =
    AsyncNotifierProvider<ProgressPhotoController, List<ProgressPhoto>>(ProgressPhotoController.new);

/// A photo's 256 px thumbnail bytes. autoDispose: the on-disk ETag cache is
/// what persists across sessions, there is no reason to also pin every viewed
/// thumbnail in memory.
final progressPhotoThumbnailProvider = FutureProvider.autoDispose.family<Uint8List?, int>((ref, id) {
  return ref.watch(progressPhotoRepositoryProvider).fetchThumbnail(id);
});

/// A photo's full-size bytes, for the viewer and the compare screen.
final progressPhotoImageProvider = FutureProvider.autoDispose.family<Uint8List?, int>((ref, id) {
  return ref.watch(progressPhotoRepositoryProvider).fetchImage(id);
});
