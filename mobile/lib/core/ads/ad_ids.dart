/// Every AdMob identifier the Dart side uses, in one file (`72` Prompt 11).
///
/// Before this they were four string literals in two widgets, each with a
/// "swap before release" comment — which is exactly the shape of thing that
/// ships: a release built with them earns nothing, shows "Test Ad" banners to
/// real users, and reports no error anywhere (`72` §9 risk 2).
///
/// Now every id is a `--dart-define` with Google's public **test** id as the
/// default, so a normal `flutter run` still works with no setup, and a release
/// build is checkable: `dart run tool/check_release_ad_ids.dart` (which also
/// covers the two **app** ids, which live in the native manifests and cannot
/// come from a Dart define).
library;

import 'dart:io' show Platform;

/// The prefix of every Google-provided test id — publisher `3940256099942544`
/// is Google's own demo account, used by both the ad-unit ids below and the
/// app ids in `AndroidManifest.xml`/`Info.plist`.
const googleTestAdIdPrefix = 'ca-app-pub-3940256099942544';

bool isGoogleTestAdId(String id) => id.startsWith(googleTestAdIdPrefix);

const _testBannerAndroid = '$googleTestAdIdPrefix/6300978111';
const _testBannerIos = '$googleTestAdIdPrefix/2934735716';
const _testInterstitialAndroid = '$googleTestAdIdPrefix/1033173712';
const _testInterstitialIos = '$googleTestAdIdPrefix/4411468910';

const bannerAdUnitIdAndroid =
    String.fromEnvironment('ADMOB_BANNER_ANDROID', defaultValue: _testBannerAndroid);
const bannerAdUnitIdIos =
    String.fromEnvironment('ADMOB_BANNER_IOS', defaultValue: _testBannerIos);
const interstitialAdUnitIdAndroid =
    String.fromEnvironment('ADMOB_INTERSTITIAL_ANDROID', defaultValue: _testInterstitialAndroid);
const interstitialAdUnitIdIos =
    String.fromEnvironment('ADMOB_INTERSTITIAL_IOS', defaultValue: _testInterstitialIos);

/// All four, regardless of platform — the release check cares about both
/// platforms' ids from whichever machine it runs on.
const allAdUnitIds = [
  bannerAdUnitIdAndroid,
  bannerAdUnitIdIos,
  interstitialAdUnitIdAndroid,
  interstitialAdUnitIdIos,
];

String bannerAdUnitId() => Platform.isIOS ? bannerAdUnitIdIos : bannerAdUnitIdAndroid;

String interstitialAdUnitId() =>
    Platform.isIOS ? interstitialAdUnitIdIos : interstitialAdUnitIdAndroid;
