import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/ads/nav_reserved_space.dart';

/// Prompt 9's verify line asks for "a layout test that the slot never
/// overlaps the bottom navigation or a FAB" — done here as a deterministic
/// check on the pure layout math `main_shell.dart`/`banner_ad_slot.dart`
/// share, rather than measuring a rendered tree (impractical: the slot's
/// real content is a platform-view [AdWidget], see `banner_ad_slot_test.dart`).

void main() {
  group('bannerBottom', () {
    test('sits exactly on top of the nav\'s reserved slot — no gap, no overlap', () {
      const safeBottom = 34.0; // e.g. an iPhone home-indicator inset
      // The nav's own top edge, measured from the screen bottom, is exactly
      // navSlotHeight + safeAreaBottom (main_shell.dart's AdaptiveBottomNav).
      final navTopEdge = navSlotHeight + safeBottom;
      expect(bannerBottom(safeBottom), navTopEdge);
    });

    test('grows with the device safe area', () {
      expect(bannerBottom(40) - bannerBottom(0), 40);
    });
  });

  group('bannerSlotHeight', () {
    test('reserves the chrome row on top of the creative (`72` Prompt 7)', () {
      // The number every content padding and FAB offset reads. If it went
      // back to reporting only the ad's own height, the FAB would sit on the
      // "Reklám" row — the silent failure `72` §9 risk 1 describes.
      expect(bannerSlotHeight(50), 50 + bannerAdChromeHeight);
      expect(bannerSlotHeight(0), bannerAdChromeHeight);
    });
  });

  group('fabBottom', () {
    test('with no banner showing, keeps the pre-existing 16dp gap above the nav', () {
      const safeBottom = 20.0;
      expect(fabBottom(safeBottom), navSlotHeight + safeBottom + fabGap);
    });

    test('never overlaps the nav: the FAB\'s bottom edge is above the nav\'s top edge', () {
      for (final safeBottom in [0.0, 20.0, 34.0]) {
        final navTopEdge = navSlotHeight + safeBottom;
        expect(fabBottom(safeBottom), greaterThan(navTopEdge));
      }
    });

    test('never overlaps a showing banner: the FAB sits at least fabGap above its top edge', () {
      for (final safeBottom in [0.0, 20.0, 34.0]) {
        for (final bannerHeight in [50.0, 60.0, 90.0]) {
          final bannerTopEdge = bannerBottom(safeBottom) + bannerHeight;
          final fabEdge = fabBottom(safeBottom, bannerHeight: bannerHeight);
          expect(fabEdge, greaterThanOrEqualTo(bannerTopEdge + fabGap));
        }
      }
    });

    test('shifts up by exactly the banner\'s height when one appears', () {
      const safeBottom = 20.0;
      expect(
        fabBottom(safeBottom, bannerHeight: 60) - fabBottom(safeBottom, bannerHeight: 0),
        60,
      );
    });
  });
}
