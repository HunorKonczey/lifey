import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/ads/ad_ids.dart';

import '../../../tool/check_release_ad_ids.dart' show testAdIdProblems;

/// `72` Prompt 11 — the AdMob ids must not be able to ship as Google's test
/// ids without someone noticing.
///
/// **The state constant below is the point of this file.** It records, as a
/// deliberate and reviewable value, whether this repo is still on test ids.
/// The day real ids land, the last test here fails and forces whoever swapped
/// them to flip it — the same "a change to the enumerated state must be an
/// explicit edit" pattern as `gated_surfaces_test.dart` (D-P7). A silent
/// swap in either direction is what this prevents.
const kAdIdsAreStillTestIds = true;

void main() {
  group('isGoogleTestAdId', () {
    test('recognises every id the app currently defaults to', () {
      for (final id in allAdUnitIds) {
        expect(isGoogleTestAdId(id), isTrue, reason: '$id should be recognised as a test id');
      }
    });

    test('does not flag a real publisher id', () {
      expect(isGoogleTestAdId('ca-app-pub-1234567890123456/1234567890'), isFalse);
    });
  });

  group('testAdIdProblems', () {
    test('names each offending entry once, and only the offending ones', () {
      final problems = testAdIdProblems({
        'ADMOB_BANNER_ANDROID': '$googleTestAdIdPrefix/6300978111',
        'ADMOB_BANNER_IOS': 'ca-app-pub-1111111111111111/2222222222',
      });

      expect(problems, hasLength(1));
      expect(problems.single, contains('ADMOB_BANNER_ANDROID'));
    });

    test('finds an app id embedded in a manifest, not just a bare id', () {
      // The native app ids are attribute values inside XML/plist, so the check
      // has to be a `contains`, not an equality — this is the case that would
      // silently pass if it were written the other way.
      final problems = testAdIdProblems({
        'AndroidManifest.xml': '<meta-data android:value="$googleTestAdIdPrefix~3347511713" />',
      });

      expect(problems, hasLength(1));
    });

    test('is empty when everything is real', () {
      expect(
        testAdIdProblems({
          'ADMOB_BANNER_ANDROID': 'ca-app-pub-1111111111111111/2222222222',
          'Info.plist': '<string>ca-app-pub-1111111111111111~3333333333</string>',
        }),
        isEmpty,
      );
    });
  });

  test('the repo\'s own six ids match the recorded state (see kAdIdsAreStillTestIds)', () {
    final manifests = {
      'android/app/src/main/AndroidManifest.xml': File('android/app/src/main/AndroidManifest.xml'),
      'ios/Runner/Info.plist': File('ios/Runner/Info.plist'),
    };
    for (final entry in manifests.entries) {
      expect(entry.value.existsSync(), isTrue, reason: '${entry.key} must exist');
    }

    final problems = testAdIdProblems({
      'ADMOB_BANNER_ANDROID': bannerAdUnitIdAndroid,
      'ADMOB_BANNER_IOS': bannerAdUnitIdIos,
      'ADMOB_INTERSTITIAL_ANDROID': interstitialAdUnitIdAndroid,
      'ADMOB_INTERSTITIAL_IOS': interstitialAdUnitIdIos,
      for (final entry in manifests.entries) entry.key: entry.value.readAsStringSync(),
    });

    expect(
      problems.isNotEmpty,
      kAdIdsAreStillTestIds,
      reason: problems.isEmpty
          ? 'Real AdMob ids are configured now — set kAdIdsAreStillTestIds = false, '
              'and check that a release build actually passes the defines '
              '(dart run tool/check_release_ad_ids.dart).'
          : 'Still on test ids:\n  ${problems.join('\n  ')}',
    );
  });
}
