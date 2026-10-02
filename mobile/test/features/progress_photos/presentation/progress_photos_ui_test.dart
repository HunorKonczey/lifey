import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lifey/core/theme/app_theme.dart';
import 'package:lifey/features/body/presentation/body_screen.dart';
import 'package:lifey/features/measurements/application/body_measurement_controller.dart';
import 'package:lifey/features/measurements/domain/body_measurement.dart';
import 'package:lifey/features/progress_photos/application/progress_photo_controller.dart';
import 'package:lifey/features/progress_photos/domain/progress_photo.dart';
import 'package:lifey/features/progress_photos/presentation/progress_photo_viewer_screen.dart';
import 'package:lifey/features/progress_photos/presentation/progress_photos_tab.dart';
import 'package:lifey/features/progress_photos/presentation/widgets/photo_details_sheet.dart';
import 'package:lifey/l10n/app_localizations.dart';

class _FakePhotos extends ProgressPhotoController {
  _FakePhotos(this.initial, {this.failAdd = false});

  final List<ProgressPhoto> initial;
  final bool failAdd;
  final removed = <int>[];
  final added = <({DateTime takenOn, PhotoPose pose, String? note})>[];
  final edited = <({int id, DateTime takenOn, PhotoPose pose, String? note})>[];

  @override
  Future<List<ProgressPhoto>> build() async => initial;

  @override
  Future<ProgressPhoto> add(File file, {required DateTime takenOn, required PhotoPose pose, String? note}) async {
    if (failAdd) throw StateError('offline');
    added.add((takenOn: takenOn, pose: pose, note: note));
    return _photo(99, takenOn);
  }

  @override
  Future<void> edit(ProgressPhoto photo, {required DateTime takenOn, required PhotoPose pose, String? note}) async {
    edited.add((id: photo.id, takenOn: takenOn, pose: pose, note: note));
  }

  @override
  Future<void> remove(int id) async {
    removed.add(id);
    state = AsyncData([for (final p in state.value!) if (p.id != id) p]);
  }
}

class _NoMeasurements extends BodyMeasurementController {
  @override
  Stream<List<BodyMeasurement>> build() => Stream.value(const []);
}

ProgressPhoto _photo(int id, DateTime takenOn, {PhotoPose pose = PhotoPose.front, String? note}) => ProgressPhoto(
      id: id,
      takenOn: takenOn,
      pose: pose,
      note: note,
      createdAt: DateTime(2026, 6, 1),
      updatedAt: DateTime(2026, 6, 1),
    );

// A 1x1 transparent PNG, so Image.memory has something decodable.
final _png = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00,
  0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00, 0x0D, 0x49,
  0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00, 0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00,
  0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

Future<_FakePhotos> _pump(
  WidgetTester tester,
  List<ProgressPhoto> photos,
  Widget home, {
  bool failAdd = false,
  GoRouter? router,
}) async {
  tester.view.physicalSize = const Size(411 * 2.625, 923 * 2.625);
  tester.view.devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);
  final fake = _FakePhotos(photos, failAdd: failAdd);
  final overrides = [
    progressPhotoControllerProvider.overrideWith(() => fake),
    bodyMeasurementControllerProvider.overrideWith(_NoMeasurements.new),
    progressPhotoThumbnailProvider.overrideWith((ref, id) async => _png),
    progressPhotoImageProvider.overrideWith((ref, id) async => _png),
  ];
  final theme = AppTheme.dark;
  if (router != null) {
    await tester.pumpWidget(ProviderScope(
      overrides: overrides,
      child: MaterialApp.router(
        routerConfig: router,
        theme: theme,
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ));
  } else {
    await tester.pumpWidget(ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        theme: theme,
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: home,
      ),
    ));
  }
  await tester.pumpAndSettle();
  return fake;
}

void main() {
  testWidgets('empty timeline says photos are private and offers no grid', (tester) async {
    await _pump(tester, const [], const Scaffold(body: ProgressPhotosTab()));

    expect(find.text('No progress photos yet'), findsOneWidget);
    expect(find.textContaining('Only you can see'), findsOneWidget);
    expect(find.byType(GridView), findsNothing);
  });

  testWidgets('the timeline is a grid with one tile per photo, date and pose on it', (tester) async {
    await _pump(
      tester,
      [_photo(1, DateTime(2026, 6, 20)), _photo(2, DateTime(2026, 6, 1), pose: PhotoPose.side)],
      const Scaffold(body: ProgressPhotosTab()),
    );

    expect(find.byType(Image), findsNWidgets(2));
    expect(find.text('Jun 20 · Front'), findsOneWidget);
    expect(find.text('Jun 1 · Side'), findsOneWidget);
  });

  testWidgets('tapping a tile opens that photo in the viewer', (tester) async {
    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (_, __) => const Scaffold(body: ProgressPhotosTab())),
      GoRoute(
        path: '/progress-photos/:photoId',
        builder: (_, state) => ProgressPhotoViewerScreen(photoId: int.parse(state.pathParameters['photoId']!)),
      ),
    ]);
    await _pump(tester, [_photo(7, DateTime(2026, 6, 20), note: 'Week 6')], const SizedBox(), router: router);

    await tester.tap(find.byType(Image));
    await tester.pumpAndSettle();

    expect(find.text('Week 6'), findsOneWidget);
    expect(find.byTooltip('Delete photo'), findsOneWidget);
  });

  testWidgets('delete asks first, and confirming removes the photo', (tester) async {
    final fake = await _pump(
      tester,
      [_photo(7, DateTime(2026, 6, 20))],
      const ProgressPhotoViewerScreen(photoId: 7),
    );

    await tester.tap(find.byTooltip('Delete photo'));
    await tester.pumpAndSettle();
    expect(find.text('Delete this photo?'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(fake.removed, isEmpty);

    await tester.tap(find.byTooltip('Delete photo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(fake.removed, [7]);
  });

  testWidgets('the details sheet uploads a new photo with the chosen pose and note', (tester) async {
    final fake = await _pump(
      tester,
      const [],
      Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => showPhotoDetailsSheet(context, file: File('does-not-exist.jpg')),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ChoiceChip, 'Back'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), '  Week 1  ');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(fake.added, hasLength(1));
    expect(fake.added.single.pose, PhotoPose.back);
    expect(fake.added.single.note, 'Week 1');
  });

  testWidgets('a failed upload keeps the sheet open with the error', (tester) async {
    await _pump(
      tester,
      const [],
      Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => showPhotoDetailsSheet(context, file: File('does-not-exist.jpg')),
              child: const Text('open'),
            ),
          ),
        ),
      ),
      failAdd: true,
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.textContaining("Couldn't upload the photo"), findsOneWidget);
    expect(find.text('Photo details'), findsOneWidget);
  });

  testWidgets('editing an existing photo saves date, pose and note through edit()', (tester) async {
    final photo = _photo(5, DateTime(2026, 6, 20), pose: PhotoPose.side, note: 'old');
    final fake = await _pump(
      tester,
      [photo],
      Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => showPhotoDetailsSheet(context, existing: photo),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(fake.edited.single.id, 5);
    expect(fake.edited.single.pose, PhotoPose.side);
    expect(fake.edited.single.note, isNull);
  });

  testWidgets('the Body screen switches tabs, and the floating action follows the tab', (tester) async {
    await _pump(tester, const [], const BodyScreen());

    expect(find.text('Log'), findsOneWidget);
    expect(find.text('Add photo'), findsNothing);

    await tester.tap(find.text('Photos'));
    await tester.pumpAndSettle();

    expect(find.text('Add photo'), findsOneWidget);
    expect(find.text('Log'), findsNothing);
    expect(find.text('No progress photos yet'), findsOneWidget);
  });
}
