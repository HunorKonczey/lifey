/// Shared layout math for placing [BannerAdSlot] and `MainShell`'s
/// floating FAB/cards relative to `AdaptiveBottomNav` (`67` §5.2, `69`
/// §4.4, DV-10). Kept as pure functions — not read off a rendered tree — so
/// the "the slot never overlaps the bottom navigation or a FAB" verify line
/// is a deterministic layout test rather than an eyeball check.
library;

/// `AdaptiveBottomNav`'s own reserved height, excluding the device safe
/// area (58 dp bar + 26 dp bottom gap — see `main_shell.dart`).
const double navSlotHeight = 58.0 + 26.0;

/// Gap kept above whatever sits directly below the FAB (the nav, or the
/// banner when one is showing).
const double fabGap = 16.0;

/// Where [BannerAdSlot] sits, measured from the screen's bottom edge —
/// anchored directly above the nav's own reserved slot (`69` DV-10's
/// "anchored" variant).
double bannerBottom(double safeAreaBottom) => navSlotHeight + safeAreaBottom;

/// Height of [BannerAdSlot]'s chrome row — the "Reklám" label and the
/// remove-ads button that sit **above** the creative (`69` §4.4, drawn that
/// way in frame P15: a 28 dp row with 4 dp of padding above it).
///
/// It is a constant rather than a measured height because the slot's total
/// height has to be reported to `main_shell.dart` and the tab bodies the
/// moment an ad loads — see [bannerSlotHeight].
const double bannerAdChromeHeight = 32.0;

/// The slot's full reserved height for a creative of [adHeight]: the ad plus
/// its chrome row. Everything that pads content or positions a FAB reads this
/// number (via `bannerAdSlotHeightProvider`), so the chrome row can never be
/// the thing that makes a FAB sit on top of an ad.
double bannerSlotHeight(double adHeight) => adHeight + bannerAdChromeHeight;

/// Where the FAB (and `TrainerInviteCard`/`UpcomingWorkoutCard`) sit,
/// measured from the screen's bottom edge — above the nav, and above the
/// banner too whenever [bannerHeight] is non-zero, so a shown banner is
/// never covered by the FAB (`67` §5.2: "Never over a FAB").
double fabBottom(double safeAreaBottom, {double bannerHeight = 0}) =>
    navSlotHeight + safeAreaBottom + bannerHeight + fabGap;
