// ignore_for_file: avoid_print
import 'dart:io';

import 'package:lifey/core/ads/ad_ids.dart';

/// Release-readiness check for the six AdMob identifiers (`72` Prompt 11).
///
/// Four are Dart `--dart-define`s (`lib/core/ads/ad_ids.dart`); two are **app**
/// ids baked into the native manifests, which no Dart define can reach. All six
/// default to Google's public test publisher, so a build that forgets any of
/// them runs perfectly, shows "Test Ad" creatives to real users, earns nothing,
/// and reports no error anywhere (`72` §9 risk 2). This script is the thing
/// that reports it.
///
/// Run before shipping, from `mobile/`:
///
/// ```
/// dart run tool/check_release_ad_ids.dart \
///   --dart-define=ADMOB_BANNER_ANDROID=ca-app-pub-XXXX/YYYY ... # same defines as the release build
/// ```
///
/// Exits 1 and names every id still pointing at the test publisher.
const _androidManifest = 'android/app/src/main/AndroidManifest.xml';
const _iosPlist = 'ios/Runner/Info.plist';

/// The pure half: which of [labelled] entries still carry a Google test id.
/// Kept separate from the file reading so it can be unit-tested
/// (`test/core/ads/ad_ids_test.dart`).
List<String> testAdIdProblems(Map<String, String> labelled) {
  final problems = <String>[];
  labelled.forEach((label, value) {
    if (value.contains(googleTestAdIdPrefix)) {
      problems.add('$label still uses Google\'s test publisher ($googleTestAdIdPrefix)');
    }
  });
  return problems;
}

void main() {
  final files = <String, String>{};
  for (final path in [_androidManifest, _iosPlist]) {
    final file = File(path);
    if (!file.existsSync()) {
      print('FAIL  $path not found — run this from mobile/');
      exit(1);
    }
    files['$path (AdMob app id)'] = file.readAsStringSync();
  }

  final problems = testAdIdProblems({
    'ADMOB_BANNER_ANDROID': bannerAdUnitIdAndroid,
    'ADMOB_BANNER_IOS': bannerAdUnitIdIos,
    'ADMOB_INTERSTITIAL_ANDROID': interstitialAdUnitIdAndroid,
    'ADMOB_INTERSTITIAL_IOS': interstitialAdUnitIdIos,
    ...files,
  });

  if (problems.isEmpty) {
    print('OK — all six AdMob ids are real.');
    return;
  }

  print('Not release-ready — ${problems.length} of 6 AdMob ids are still test ids:\n');
  for (final problem in problems) {
    print('  - $problem');
  }
  print(
    '\nThe four unit ids come from --dart-define (lib/core/ads/ad_ids.dart);\n'
    'the two app ids are literals in the native manifests and must be edited there.',
  );
  exit(1);
}
