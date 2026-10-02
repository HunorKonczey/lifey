import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/features/progress_photos/application/progress_photo_controller.dart';
import 'package:lifey/features/progress_photos/data/progress_photo_repository.dart';
import 'package:lifey/features/progress_photos/domain/progress_photo.dart';

ProgressPhoto _p(int id, DateTime takenOn) => ProgressPhoto(
      id: id,
      takenOn: takenOn,
      pose: PhotoPose.front,
      createdAt: DateTime(2026, 6, 1),
      updatedAt: DateTime(2026, 6, 1),
    );

class _FakeRepo implements ProgressPhotoRepository {
  _FakeRepo(this.photos);

  List<ProgressPhoto> photos;
  final deleted = <int>[];
  ProgressPhoto? nextUpload;
  bool failList = false;

  @override
  Future<List<ProgressPhoto>> list() async {
    if (failList) throw StateError('offline');
    return photos;
  }

  @override
  Future<ProgressPhoto> upload(File file, {required DateTime takenOn, required PhotoPose pose, String? note}) async =>
      nextUpload!;

  @override
  Future<ProgressPhoto> update(int id, {required DateTime takenOn, required PhotoPose pose, String? note}) async =>
      ProgressPhoto(
        id: id,
        takenOn: takenOn,
        pose: pose,
        note: note,
        createdAt: DateTime(2026, 6, 1),
        updatedAt: DateTime(2026, 6, 2),
      );

  @override
  Future<void> delete(int id) async => deleted.add(id);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _FakeRepo repo;
  late ProviderContainer container;

  Future<void> start(List<ProgressPhoto> photos) async {
    repo = _FakeRepo(photos);
    container = ProviderContainer(overrides: [progressPhotoRepositoryProvider.overrideWithValue(repo)]);
    addTearDown(container.dispose);
    await container.read(progressPhotoControllerProvider.future);
  }

  List<int> ids() => container.read(progressPhotoControllerProvider).value!.map((p) => p.id).toList();

  test('add puts the photo in its date position, ties by newest id', () async {
    await start([_p(1, DateTime(2026, 6, 20)), _p(2, DateTime(2026, 6, 1))]);
    repo.nextUpload = _p(3, DateTime(2026, 6, 10));
    await container.read(progressPhotoControllerProvider.notifier).add(File('x'), takenOn: DateTime(2026, 6, 10), pose: PhotoPose.front);
    expect(ids(), [1, 3, 2]);

    repo.nextUpload = _p(4, DateTime(2026, 6, 10));
    await container.read(progressPhotoControllerProvider.notifier).add(File('x'), takenOn: DateTime(2026, 6, 10), pose: PhotoPose.front);
    expect(ids(), [1, 4, 3, 2]);
  });

  test('edit re-sorts when the date changes', () async {
    final photos = [_p(1, DateTime(2026, 6, 20)), _p(2, DateTime(2026, 6, 1))];
    await start(photos);

    await container
        .read(progressPhotoControllerProvider.notifier)
        .edit(photos[1], takenOn: DateTime(2026, 7, 1), pose: PhotoPose.side, note: 'n');

    expect(ids(), [2, 1]);
    expect(container.read(progressPhotoControllerProvider).value!.first.note, 'n');
  });

  test('remove deletes on the server and drops it from the list', () async {
    await start([_p(1, DateTime(2026, 6, 20)), _p(2, DateTime(2026, 6, 1))]);

    await container.read(progressPhotoControllerProvider.notifier).remove(1);

    expect(repo.deleted, [1]);
    expect(ids(), [2]);
  });

  test('a failed load is an error state, and refresh recovers', () async {
    repo = _FakeRepo([_p(1, DateTime(2026, 6, 20))])..failList = true;
    container = ProviderContainer(overrides: [progressPhotoRepositoryProvider.overrideWithValue(repo)]);
    addTearDown(container.dispose);
    await expectLater(container.read(progressPhotoControllerProvider.future), throwsStateError);
    expect(container.read(progressPhotoControllerProvider).hasError, isTrue);

    repo.failList = false;
    await container.read(progressPhotoControllerProvider.notifier).refresh();

    expect(ids(), [1]);
  });
}
